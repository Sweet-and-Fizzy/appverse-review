#!/usr/bin/env python3
"""Keep a fill session's changes to the Draft feedback only when they help.

    python3 references/fill-guard.py needs-fill <feedback.json>
    python3 references/fill-guard.py snapshot <snapdir> <file>...
    python3 references/fill-guard.py digest <snapdir> <file>...
    python3 references/fill-guard.py plugin-status <git-dir>
    python3 references/fill-guard.py verify <snapdir> <report.md> \\
        <findings.json> <meta.json> <feedback.json> <before-checks> <after-checks>

needs-fill prints true when feedback.json has an empty opening or an item
with empty text, otherwise false (also for a missing or malformed file).

snapshot copies each file into snapdir and records in MANIFEST which paths
existed, so a file the session creates counts as a change too.

digest prints a sha256 over the snapshot (MANIFEST and every saved file)
and the given files (the check-all baseline). The gate emits it as a step
output, which the fill session cannot write, and the guard compares it
before trusting the snapshot: the session's permissions are what keep it
out of these files, and this checks that they did. plugin-status does the
same for the plugin checkout the guard's scripts run from: a sha256 of its
`git status --porcelain` (untracked files included, since a planted module
would be imported), or "error" when git cannot read it.

verify runs after the session and after the workflow has re-run prepare and
render. The changes are kept only if: findings.json and meta.json are
unchanged; the report is unchanged outside the Draft feedback section; the
report has exactly one Draft feedback heading carrying the
feedback-generated marker; check-all printed no problem line that was not
there before; and feedback.json keeps every opening and text that was
already filled, unchanged, and fills at least one that was empty. The last
check is the one check-all cannot make: an item with no text falls back to
its summaries and still passes the floor, so a fill that blanked or broke
the sentences would otherwise look fine. On the first failure every
snapshotted file is restored (one that did not exist is deleted) and verify
exits 1; otherwise it exits 0. If the check itself raises, every file is
restored and verify exits 3.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from feedback_terms import DRAFT_HEADING_RE, draft_section_bounds  # noqa: E402

PROBLEM_WORDS = ("MISSING", "INVALID", "MISMATCH", "UNCITED", "BAD")
GENERATED = "<!-- feedback-generated -->"


def load_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def filled(value):
    return isinstance(value, str) and bool(value.strip())


def needs_fill(path):
    doc = load_json(path)
    if not isinstance(doc, dict):
        return False
    items = doc.get("items") if isinstance(doc.get("items"), list) else []
    return not filled(doc.get("opening")) or any(isinstance(i, dict) and not filled(i.get("text")) for i in items)


def snapshot(snapdir, paths):
    os.makedirs(snapdir, exist_ok=True)
    rows = []
    for n, path in enumerate(paths):
        if os.path.exists(path):
            shutil.copyfile(path, os.path.join(snapdir, str(n)))
            rows.append("present\t" + path)
        else:
            rows.append("absent\t" + path)
    with open(os.path.join(snapdir, "MANIFEST"), "w", encoding="utf-8") as f:
        f.write("\n".join(rows) + "\n")


def manifest(snapdir):
    with open(os.path.join(snapdir, "MANIFEST"), encoding="utf-8") as f:
        rows = [line.rstrip("\n").split("\t", 1) for line in f if line.strip()]
    return [(n, state, path) for n, (state, path) in enumerate(rows)]


def saved(snapdir, path):
    """The snapshot's bytes for path, or None when it did not exist."""
    for n, state, p in manifest(snapdir):
        if p == path:
            if state != "present":
                return None
            with open(os.path.join(snapdir, str(n)), "rb") as f:
                return f.read()
    return None


def current(path):
    try:
        with open(path, "rb") as f:
            return f.read()
    except OSError:
        return None


def restore(snapdir):
    for n, state, path in manifest(snapdir):
        if state == "present":
            tmp = path + ".restore-tmp"
            shutil.copyfile(os.path.join(snapdir, str(n)), tmp)
            os.replace(tmp, path)
        elif os.path.exists(path):
            os.remove(path)


def outside_section(text):
    lines = text.splitlines()
    bounds = draft_section_bounds(lines)
    if bounds is None:
        return lines
    return lines[:bounds[0]] + lines[bounds[1]:]


def problem_lines(path):
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError:
        return set()
    return {l for l in lines if l.startswith("[") and any(w in l for w in PROBLEM_WORDS)}


def texts(doc):
    """{"opening": str, <group>: text} for a feedback document."""
    if not isinstance(doc, dict):
        return {}
    out = {"opening": doc.get("opening") if isinstance(doc.get("opening"), str) else ""}
    for item in doc.get("items", []) if isinstance(doc.get("items"), list) else []:
        if isinstance(item, dict) and isinstance(item.get("group"), str):
            out[item["group"]] = item.get("text") if isinstance(item.get("text"), str) else ""
    return out


def failure(snapdir, report, findings, meta, feedback, before, after):
    for path in (findings, meta):
        if current(path) != saved(snapdir, path):
            return "{} changed".format(os.path.basename(path))
    old_report = saved(snapdir, report)
    new_report = current(report)
    if new_report is None:
        return "the report is gone"
    new_text = new_report.decode("utf-8", "replace")
    if old_report is not None and outside_section(old_report.decode("utf-8", "replace")) != outside_section(new_text):
        return "the report changed outside the Draft feedback section"
    headings = [l for l in new_text.splitlines() if DRAFT_HEADING_RE.match(l)]
    bounds = draft_section_bounds(new_text.splitlines())
    if len(headings) != 1 or bounds is None or \
            GENERATED not in "\n".join(new_text.splitlines()[bounds[0]:bounds[1]]):
        return "the report does not have exactly one generated Draft feedback section"
    new_problems = problem_lines(after) - problem_lines(before)
    if new_problems:
        return "new checker problem: " + sorted(new_problems)[0]
    old_fb = saved(snapdir, feedback)
    try:
        old = texts(json.loads(old_fb.decode("utf-8"))) if old_fb else {}
    except ValueError:
        old = {}
    new = texts(load_json(feedback))
    for key, value in old.items():
        if filled(value) and new.get(key) != value:
            return "an already-written sentence changed ({})".format(key)
    if not any(not filled(old.get(key, "")) and filled(value) for key, value in new.items()):
        return "no empty sentence was filled"
    return None


def digest(snapdir, extra):
    h = hashlib.sha256()
    names = sorted(os.listdir(snapdir)) if os.path.isdir(snapdir) else []
    for name in names:
        h.update(name.encode() + b"\0" + (current(os.path.join(snapdir, name)) or b"") + b"\0")
    for path in extra:
        h.update(path.encode() + b"\0" + (current(path) or b"") + b"\0")
    return h.hexdigest()


def plugin_status(path):
    try:
        out = subprocess.run(["git", "-C", path, "status", "--porcelain"], capture_output=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return "error"
    return hashlib.sha256(out).hexdigest()


def main(argv):
    if len(argv) >= 3 and argv[1] == "needs-fill":
        print("true" if needs_fill(argv[2]) else "false")
        return 0
    if len(argv) >= 4 and argv[1] == "snapshot":
        snapshot(argv[2], argv[3:])
        print("fill-guard: snapshot of {} files".format(len(argv) - 3))
        return 0
    if len(argv) == 3 and argv[1] == "plugin-status":
        print(plugin_status(argv[2]))
        return 0
    if len(argv) >= 3 and argv[1] == "digest":
        print(digest(argv[2], argv[3:]))
        return 0
    if len(argv) == 9 and argv[1] == "verify":
        snapdir, report, findings, meta, feedback, before, after = argv[2:]
        try:
            reason = failure(snapdir, report, findings, meta, feedback, before, after)
        except Exception as e:  # noqa: BLE001 - an unchecked fill must never stand
            restore(snapdir)
            print("fill-guard: restored (guard error: {})".format(e))
            return 3
        if reason:
            restore(snapdir)
            print("fill-guard: restored ({})".format(reason))
            return 1
        print("fill-guard: kept")
        return 0
    print(__doc__.split("\n\n")[1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
