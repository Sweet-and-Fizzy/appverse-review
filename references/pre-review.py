#!/usr/bin/env python3
"""Pre-review facts: run the static-analysis tools and the shell syntax check
before the model, so that they run and are recorded on every review rather
than when the model chooses to run them, and write the results as JSON.

    references/run-pre-review.sh <target-dir> <out-dir> [--catalog URL] [--no-catalog]

Exit 0 whenever the script ran to completion, whatever the tools found; exit 2
only when <target-dir> is missing (or the arguments do not parse). A tool that
is absent, crashes, or times out is data in the output, never a script failure.

Files written to <out-dir> (any previous *.json, tool-table.md, stripped/ and
the per-app dirs named in the previous apps.json are removed first):

  summary.json   {"schema": "pre-review/1", "target": <abs path>,
                  "generated_at": <ISO 8601 UTC>, "checks": [...]}
                 one record per check, in the fixed order syntax, shellcheck,
                 semgrep, bandit, trivy, catalog, each with name, status
                 (ran | not_installed | failed_to_run | skipped), version,
                 command, exit_code, output_file, files_examined, note,
                 finding_count (int, or null when the tool did not run) and
                 top_codes (up to five most frequent codes, most frequent
                 first, ties by code): shellcheck SC<n>, semgrep check_id,
                 bandit test_id, trivy VulnerabilityID / ID.
  syntax.json    one entry per shell file (*.sh, *.bash, *.sh.erb): path
                 (repo-relative), stripped (ERB tags removed first), ok
                 (bash -n passed), stderr (first 500 chars). Written even
                 when there is no bash, with every file ok false and the
                 reason in stderr. Under a bash older than 4 a failure's
                 stderr starts "bash <ver> rejected this file (may be valid
                 on bash >= 4): ".
  shellcheck.json  shellcheck's objects concatenated across files, "file" set
                 to the repo-relative source path (.sh.erb scanned stripped).
  semgrep.json, bandit.json, trivy.json  the tool's own JSON, verbatim.
  stripped/<path>.sh  the ERB-stripped copy of each .sh.erb, for inspection.
  trivy-empty.yaml, trivy-empty.ignore  empty files passed to trivy as its
                 --config and --ignorefile.
  tool-table.md  the Check tiers line and the Tool / Status / Result table,
                 rendered from summary.json for the security skill to paste.
  apps.json      [{app_id, path, app_type, readme}]: the app shape, resolved
                 as target-setup.md section 3 does. A root appverse.yml with
                 an apps: list is a monorepo, one app per apps[].path (app_id
                 its last path component, made unique); otherwise one app,
                 app_id "root", path ".". app_type is batch_connect |
                 passenger | companion | widget | unknown, from the declared
                 app_type (inline apps[] entry, then <path>/appverse.yml),
                 then the manifest role, then the entry-point files
                 (config.ru / passenger_wsgi.py / app.js => passenger;
                 form.yml(.erb) or submit.yml(.erb) => batch_connect). readme
                 is the repo-relative README, a monorepo app without its own
                 falling back to the root README; null when there is none.
                 An apps[].path outside the target or missing is listed
                 (app_type unknown) but never read.
  <app_id>/readme.json  {file, headings [{level, text, line}], placeholders
                 [{line, text, phrase}] (lines containing a phrase from
                 readme-placeholders.txt, case-insensitive), screenshots
                 [{line, alt, target}] (image links outside code fences;
                 badge images excluded), env_vars [{line, text, match}]
                 (match heading | assignment ([A-Z_]{3,}=) | phrase
                 ("environment variable")), rungs {what it launches,
                 prerequisites, installation, configuration, known
                 limitations, troubleshooting, screenshots, environment
                 variables, info panel, architecture: {heading, line,
                 placeholder} or null}}. A rung is the first heading whose
                 words contain a synonym (RUNGS); placeholder is true when
                 the heading or every content line of its section (to the
                 next heading of the same or a higher level; HTML comments
                 and fence markers are not content) is a placeholder line.
                 Headings inside code fences or HTML comments are ignored.
  <app_id>/form.json  {file (form.yml, else form.yml.erb, ERB stripped),
                 submit_file, error (the YAML parse error, else null),
                 attributes [{name, widget, min, max, pattern, required,
                 line, defined, in_form, interpolated_in_submit,
                 submit_lines, reaches_scheduler}]}: every attributes: key,
                 then every form: name not defined there (line is the form:
                 item's). interpolated_in_submit: the name appears in an
                 ERB tag in submit.yml.erb, at submit_lines;
                 reaches_scheduler: its value reaches a <%= %> tag under
                 script.* or batch_connect.template, directly or through a
                 variable assigned from it in a <% %> tag. PyYAML is used
                 when importable, else a built-in subset parser; the form
                 record's note says which.

summary.json also carries "facts": one record per fact scanner (readme,
form), with the record fields above plus per_app {app_id: status}. An app's
status is ran, skipped (no README / no form file / path not read) or
failed_to_run (form did not parse; the error is in the note and in
form.json); the record's status is failed_to_run if any app's is, else ran if
any app's is, else skipped. A fact file is absent when its app was skipped.

A tool's JSON is absent when the tool did not run. Status rules: no applicable
files -> skipped ("no applicable files"); binary not on PATH -> not_installed
(note = install hint); raised, timed out (300 s, or PRE_REVIEW_TIMEOUT), or
exited with a crash code (shellcheck >= 2, semgrep >= 2, bandit >= 2,
trivy != 0) -> failed_to_run (note = first 500 chars of stderr; for trivy its
FATAL line, else its last non-empty stderr line); otherwise ran. The syntax
check runs bash -n with the first bash on PATH; under a bash older than 4 a
pass stands, a failure may be a false one (bash 3.2 rejects ;;& and other
bash 4 syntax), so it carries the prefix above and the syntax note says so.
The catalog check is a placeholder: always skipped.

Tool commands are the ones in security-tools.md: shellcheck --norc -f json
-S info per file, and trivy run from the out-dir with an empty --config and
--ignorefile, so a target's .shellcheckrc, trivy.yaml, or .trivyignore changes
nothing (the note says the target shipped one). A target that ships
.semgrepignore or .bandit, which those tools honour, is named in that tool's
note as possibly suppressing findings.

Only regular files are examined: a symlink counts when it resolves to a regular
file inside the target; any other symlink, FIFO or device is never read, is
excluded from every tool's file list and from files_examined, and (when it has
a shell suffix) is listed in syntax.json as ok false with the reason in stderr.
A shell file over 1 MB is neither syntax-checked nor shellchecked (ok false,
"skipped: file larger than 1 MB"). An out-dir inside the target is excluded
from the walk; out-dir == target is refused (exit 2). semgrep's
files_examined is the length of its own paths.scanned when present, else the
tree size; semgrep applies its own ignore list (tests/, vendored dirs).
"""
import argparse
import json
import os
import re
import shutil
import stat
import subprocess
import sys
from datetime import datetime, timezone

SCHEMA = "pre-review/1"
SKIP_DIRS = {".git", "vendor", "node_modules"}
SHELL_SUFFIXES = (".sh", ".bash", ".sh.erb")
MANIFEST_NAMES = {"package.json", "requirements.txt", "Gemfile.lock", "Dockerfile"}
TIMEOUT = int(os.environ.get("PRE_REVIEW_TIMEOUT") or 300)
STDERR_CHARS = 500
MAX_SHELL_BYTES = 1024 * 1024
NO_FILES = "no applicable files"
TOO_LARGE = "skipped: file larger than 1 MB"
ERB_LITERAL = "\x00ERB-LITERAL\x00"
SEMGREP_RULESETS = "rulesets p/security-audit, p/secrets"
SEMGREP_NOTE = ("files_examined is the tree size; semgrep applies its own ignore list "
                "(tests/, vendored dirs)")
OUTSIDE = "symlink outside target, not checked"
DANGLING = "dangling symlink (No such file or directory), not checked"
NOT_REGULAR = "not a regular file, not checked"
INSTALL_HINTS = {
    "shellcheck": "apt install shellcheck / brew install shellcheck",
    "bandit": "pip install bandit",
    "semgrep": "pip install semgrep",
    "trivy": "brew install trivy / see https://aquasecurity.github.io/trivy",
}
# Config files a target can ship to change what a tool reports. shellcheck and
# trivy are run so that theirs are ignored; semgrep and bandit honour theirs.
TOOL_CONFIGS = {
    "shellcheck": ((".shellcheckrc",), "its suppressions were ignored"),
    "trivy": (("trivy.yaml", ".trivyignore"), "its suppressions were ignored"),
    "semgrep": ((".semgrepignore",), "it may suppress findings"),
    "bandit": ((".bandit",), "it may suppress findings"),
}
SHELLCHECK = ["shellcheck", "--norc", "-f", "json", "-S", "info"]
SEMGREP = ["semgrep", "--config=p/security-audit", "--config=p/secrets", "--metrics=off",
           "--exclude", "vendor", "--exclude", "node_modules", "--json"]
BANDIT = ["bandit", "-r", "<dir>", "-f", "json"]
TRIVY = ["trivy", "fs", "--format", "json", "--scanners", "vuln,misconfig,secret",
         "--skip-dirs", "vendor", "--skip-dirs", "node_modules"]
TRIVY_EMPTY_CONFIG = "trivy-empty.yaml"
TRIVY_EMPTY_IGNORE = "trivy-empty.ignore"
TABLE_TOOLS = ("shellcheck", "semgrep", "bandit", "trivy")


def strip_erb(text):
    """Remove ERB tags, keeping each tag's newlines so line numbers survive.

    Order matters: comments first (so a %> inside a comment ends nothing else),
    then <%= %> -> ERBVALUE (so TIMEOUT=<%= x %> stays valid shell), then bare
    <% %> -> empty. re.S so multi-line tags match. A <%% literal (ERB renders
    it as <%) is set aside first and restored after, so the text after it
    reaches bash -n instead of being eaten as a tag.
    """
    def keep_newlines(match, filler=""):
        return filler + "\n" * match.group(0).count("\n")

    text = text.replace("<%%", ERB_LITERAL)
    text = re.sub(r"<%#.*?%>", lambda m: keep_newlines(m), text, flags=re.S)
    text = re.sub(r"<%=.*?%>", lambda m: keep_newlines(m, "ERBVALUE"), text, flags=re.S)
    text = re.sub(r"<%.*?%>", lambda m: keep_newlines(m), text, flags=re.S)
    return text.replace(ERB_LITERAL, "<%")


def _classify(target, exclude=None):
    """Walk target (skipping SKIP_DIRS and the exclude dir, not following
    symlinked dirs). Return (files, rejected): files are sorted repo-relative
    paths of regular files, or symlinks that resolve to a regular file inside
    target; rejected maps every other entry (a symlink leading outside or
    nowhere, a FIFO, a device) to the reason it was not read."""
    root_real = os.path.realpath(target)
    exclude_real = os.path.realpath(exclude) if exclude else None
    files, rejected = [], {}
    for root, dirs, names in os.walk(target):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS
                   and os.path.realpath(os.path.join(root, d)) != exclude_real]
        for name in names:
            full = os.path.join(root, name)
            rel = os.path.relpath(full, target).replace(os.sep, "/")
            mode = os.lstat(full).st_mode
            if stat.S_ISLNK(mode):
                real = os.path.realpath(full)
                if not os.path.exists(real):
                    rejected[rel] = DANGLING
                elif os.path.commonpath([real, root_real]) != root_real:
                    rejected[rel] = OUTSIDE
                elif not os.path.isfile(real):
                    rejected[rel] = NOT_REGULAR
                else:
                    files.append(rel)
            elif stat.S_ISREG(mode):
                files.append(rel)
            else:
                rejected[rel] = NOT_REGULAR
    return sorted(files), rejected


def _walk(target, exclude=None):
    """Every examinable file under target as a sorted repo-relative path."""
    return _classify(target, exclude)[0]


def find_shell_files(target, exclude=None):
    return [p for p in _walk(target, exclude) if p.endswith(SHELL_SUFFIXES)]


def find_py_files(target, exclude=None):
    return [p for p in _walk(target, exclude) if p.endswith(".py")]


def find_manifests(target, exclude=None):
    return [p for p in _walk(target, exclude)
            if p.rsplit("/", 1)[-1] in MANIFEST_NAMES or p.endswith(".def")]


def count_files(target, exclude=None):
    return len(_walk(target, exclude))


def _too_large(target, rel):
    try:
        return os.path.getsize(os.path.join(target, rel)) > MAX_SHELL_BYTES
    except OSError:
        return False


def _arg(rel):
    """A repo-relative path as a tool argument: ./-x.sh is never an option."""
    return "./" + rel


def _failure(err, stdout):
    """failed_to_run note text: stderr, or stdout when stderr is empty."""
    return err if (err or "").strip() else (stdout or "")


def _trivy_failure(err, stdout):
    """trivy logs progress before failing: its FATAL line, else the last
    non-empty line, says why."""
    lines = [l.strip() for l in _failure(err, stdout).splitlines() if l.strip()]
    return next((l for l in lines if "FATAL" in l), lines[-1] if lines else "")


def run(cmd, timeout=None, cwd=None):
    """Run cmd; return (returncode, stdout, stderr, error). error is a string
    when the process could not be run or timed out, else None."""
    timeout = TIMEOUT if timeout is None else timeout
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                           errors="replace", timeout=timeout)
        return p.returncode, p.stdout, p.stderr, None
    except subprocess.TimeoutExpired:
        return None, "", "", "timed out after %d s" % timeout
    except Exception as e:  # OSError and friends: the tool could not start
        return None, "", "", "%s: %s" % (type(e).__name__, e)


def tool_version(name):
    """First line of `<name> --version` that carries a version number (stdout,
    then stderr), else its first non-empty line; '' if absent. shellcheck's
    first line is a banner ("ShellCheck - shell script analysis tool")."""
    if shutil.which(name) is None:
        return ""
    rc, out, err, error = run([name, "--version"], timeout=60)
    lines = [l.strip() for l in (out or "").splitlines() + (err or "").splitlines() if l.strip()]
    return next((l for l in lines if re.search(r"\d", l)), lines[0] if lines else "")


def record(name, status, version="", command="", exit_code=None, output_file=None,
           files_examined=0, note="", finding_count=None, top_codes=None):
    return {"name": name, "status": status, "version": version, "command": command,
            "exit_code": exit_code, "output_file": output_file,
            "files_examined": files_examined, "note": note,
            "finding_count": finding_count, "top_codes": top_codes or []}


def most_frequent(codes, n=5):
    """The n most frequent codes, most frequent first, ties by code."""
    counts = {}
    for c in codes:
        counts[c] = counts.get(c, 0) + 1
    return [c for c, _ in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[:n]]


def _findings(name, data):
    """(finding_count, codes) from a tool's parsed JSON."""
    if name == "shellcheck":
        return len(data), ["SC%s" % i.get("code") for i in data]
    if name in ("semgrep", "bandit"):
        key = "check_id" if name == "semgrep" else "test_id"
        results = data.get("results") or []
        return len(results), [str(r.get(key)) for r in results]
    codes = []  # trivy
    for res in data.get("Results") or []:
        for kind, key in (("Vulnerabilities", "VulnerabilityID"),
                          ("Misconfigurations", "ID"), ("Secrets", "ID")):
            codes.extend(str(i.get(key) or i.get("ID") or i.get("RuleID") or "")
                         for i in res.get(kind) or [])
    return len(codes), codes


def _with_findings(rec, data):
    count, codes = _findings(rec["name"], data)
    rec["finding_count"], rec["top_codes"] = count, most_frequent(codes)
    return rec


def _config_notes(name, target, out):
    """One note per config file the target ships for this tool, anywhere in
    the tree (shellcheck reads a .shellcheckrc from any parent directory)."""
    files, rejected = _classify(target, out)
    names, verdict = TOOL_CONFIGS[name]
    return ["target ships %s; %s" % (p, verdict)
            for p in sorted(files + list(rejected)) if p.rsplit("/", 1)[-1] in names]


def _add_notes(rec, notes):
    """Append notes to a record for a tool that ran or failed to run."""
    if notes and rec["status"] in ("ran", "failed_to_run"):
        rec["note"] = "; ".join(([rec["note"]] if rec["note"] else []) + notes)
    return rec


def _write_json(out, filename, data):
    with open(os.path.join(out, filename), "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def _stripped_copy(target, out, rel):
    """Write the ERB-stripped copy of rel to <out>/stripped/<rel>.sh; return its path."""
    with open(os.path.join(target, rel), encoding="utf-8", errors="surrogateescape") as f:
        text = strip_erb(f.read())
    dst = os.path.join(out, "stripped", rel + ".sh")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "w", encoding="utf-8", errors="surrogateescape") as f:
        f.write(text)
    return dst


def _bash_major(bash):
    """(major, version string) from `bash --version`; (None, '') if unreadable."""
    rc, out, err, error = run([bash, "--version"], timeout=60)
    m = re.search(r"version (\d+)(\.[\w.()-]*)?", (out or "") + (err or ""))
    if not m:
        return None, ""
    return int(m.group(1)), (m.group(1) + (m.group(2) or "")).split("(")[0]


def check_syntax(target, out):
    """bash -n on every shell file (ERB-stripped copy for .sh.erb). Returns
    (summary record, syntax entries). Entries carry the path scanned in
    '_scan' for shellcheck (None when the file could not be read); it is
    dropped before syntax.json is written. A file that cannot be read fails
    on its own entry; the rest are still checked. When bash is missing,
    nothing is checked and every file is listed ok false. Under a bash older
    than 4 every file is still checked; a failure's stderr is prefixed to say
    it may be false."""
    all_files, rejected = _classify(target, out)
    files = [p for p in all_files if p.endswith(SHELL_SUFFIXES)]
    refused = [{"path": p, "stripped": False, "ok": False, "stderr": why, "_scan": None}
               for p, why in sorted(rejected.items()) if p.endswith(SHELL_SUFFIXES)]
    command = "bash -n <file> (per shell file; .sh.erb checked as its ERB-stripped copy)"

    def write(entries):
        entries = sorted(entries, key=lambda e: e["path"])
        _write_json(out, "syntax.json", [{k: v for k, v in e.items() if k != "_scan"} for e in entries])
        return entries

    def unchecked(reason):
        return [{"path": p, "stripped": False, "ok": False, "stderr": "not checked: " + reason,
                 "_scan": None} for p in files]

    if not files:
        write(refused)
        return record("syntax", "skipped", command=command, output_file="syntax.json",
                      note=NO_FILES), []
    bash = shutil.which("bash")
    if bash is None:
        write(unchecked("bash not found on PATH") + refused)
        return record("syntax", "not_installed", command=command, output_file="syntax.json",
                      files_examined=len(files), note="bash not found on PATH"), []
    major, ver = _bash_major(bash)
    old_bash = major is not None and major < 4
    old_prefix = "bash %s rejected this file (may be valid on bash >= 4): " % ver
    entries, checked = [], []
    for rel in files:
        stripped = rel.endswith(".sh.erb")
        if _too_large(target, rel):
            entries.append({"path": rel, "stripped": False, "ok": False, "stderr": TOO_LARGE,
                            "_scan": None})
            continue
        checked.append(rel)
        try:
            scan = _stripped_copy(target, out, rel) if stripped else _arg(rel)
        except Exception as e:  # unreadable file: fail this entry, keep going
            entries.append({"path": rel, "stripped": stripped, "ok": False,
                            "stderr": ("%s: %s" % (type(e).__name__, e))[:STDERR_CHARS], "_scan": None})
            continue
        rc, _, err, error = run([bash, "-n", scan], cwd=target)
        if error:
            ok, stderr = False, error
        else:
            ok, stderr = rc == 0, err.replace(scan, rel)
            if old_bash and not ok:
                stderr = old_prefix + stderr
        entries.append({"path": rel, "stripped": stripped, "ok": ok,
                        "stderr": stderr[:STDERR_CHARS], "_scan": scan})
    entries = write(entries + refused)
    failed = sum(1 for e in entries if e["path"] in checked and not e["ok"])
    notes = []
    if old_bash:
        notes.append("bash %s on PATH: failures may be false; install bash >= 4 to confirm" % ver)
    if failed:
        notes.append("%d of %d files failed bash -n" % (failed, len(checked)))
    if len(checked) < len(files):
        notes.append("not checked (larger than 1 MB): " +
                     ", ".join(p for p in files if p not in checked))
    return record("syntax", "ran", version=tool_version("bash"), command=command,
                  exit_code=1 if failed else 0, output_file="syntax.json",
                  files_examined=len(checked), note="; ".join(notes)), entries


def check_shellcheck(target, out, syntax_entries):
    return _add_notes(_shellcheck(target, out, syntax_entries),
                      _config_notes("shellcheck", target, out))


def _shellcheck(target, out, syntax_entries):
    files = find_shell_files(target, out)
    command = " ".join(SHELLCHECK) + " <file> (per shell file; .sh.erb scanned as its ERB-stripped copy)"
    if not files:
        return record("shellcheck", "skipped", version=tool_version("shellcheck"), command=command,
                      note=NO_FILES)
    if shutil.which("shellcheck") is None:
        return record("shellcheck", "not_installed", command=command, files_examined=len(files),
                      note=INSTALL_HINTS["shellcheck"])
    large = [f for f in files if _too_large(target, f)]
    files = [f for f in files if f not in large]
    scans = {e["path"]: e["_scan"] for e in syntax_entries}
    version = tool_version("shellcheck")
    results, worst, unread = [], 0, []
    for rel in files:
        try:
            if rel.endswith(".sh.erb"):
                scan = scans.get(rel) or _stripped_copy(target, out, rel)
            else:
                open(os.path.join(target, rel), "rb").close()
                scan = _arg(rel)
        except Exception:  # unreadable file: skip it, name it in the note
            unread.append(rel)
            continue
        rc, stdout, err, error = run(SHELLCHECK + [scan], cwd=target)
        if error or rc >= 2:
            return record("shellcheck", "failed_to_run", version=version, command=command,
                          exit_code=rc, files_examined=len(files),
                          note=("%s: %s" % (rel, error or _failure(err, stdout)))[:STDERR_CHARS])
        worst = max(worst, rc)
        try:
            items = json.loads(stdout) if stdout.strip() else []
        except ValueError:
            return record("shellcheck", "failed_to_run", version=version, command=command,
                          exit_code=rc, files_examined=len(files),
                          note=("%s: output was not JSON: %s" % (rel, _failure(err, stdout)))[:STDERR_CHARS])
        for item in items:
            item["file"] = rel
        results.extend(items)
    _write_json(out, "shellcheck.json", results)
    n_stripped = sum(1 for f in files if f.endswith(".sh.erb") and f not in unread)
    notes = []
    if n_stripped:
        notes.append("%d .sh.erb file(s) scanned ERB-stripped" % n_stripped)
    if unread:
        notes.append("not scanned (unreadable): " + ", ".join(unread))
    if large:
        notes.append("not scanned (larger than 1 MB): " + ", ".join(large))
    rec = record("shellcheck", "ran", version=version, command=command, exit_code=worst,
                 output_file="shellcheck.json", files_examined=len(files) - len(unread),
                 note="; ".join(notes))
    return _with_findings(rec, results)


def _run_json_tool(name, cmd, target, out, files_examined, crashed, note="", cwd=None,
                   failure=_failure):
    """Run a whole-directory tool (from the target root unless cwd is given);
    its stdout JSON is written verbatim to <name>.json when it ran. Returns
    (record, parsed JSON or None)."""
    command = " ".join(cmd)
    if shutil.which(name) is None:
        return record(name, "not_installed", command=command, files_examined=files_examined,
                      note=INSTALL_HINTS[name]), None
    version = tool_version(name)
    rc, stdout, err, error = run(cmd, cwd=cwd or target)
    if error or crashed(rc):
        return record(name, "failed_to_run", version=version, command=command, exit_code=rc,
                      files_examined=files_examined,
                      note=(error or failure(err, stdout))[:STDERR_CHARS]), None
    try:
        data = json.loads(stdout)
    except ValueError:
        return record(name, "failed_to_run", version=version, command=command, exit_code=rc,
                      files_examined=files_examined,
                      note=("output was not JSON: " + _failure(err, stdout))[:STDERR_CHARS]), None
    with open(os.path.join(out, name + ".json"), "w") as f:
        f.write(stdout)
    rec = record(name, "ran", version=version, command=command, exit_code=rc,
                 output_file=name + ".json", files_examined=files_examined, note=note)
    return _with_findings(rec, data), data


def _out_inside(target, out):
    """The out-dir as a target-relative path when it lies inside the target
    (it is not part of the app, so the whole-tree tools skip it), else None."""
    rel = os.path.relpath(out, target)
    return None if rel == ".." or rel.startswith(".." + os.sep) else rel.replace(os.sep, "/")


def check_semgrep(target, out):
    n = count_files(target, out)
    if not n:
        return record("semgrep", "skipped", version=tool_version("semgrep"),
                      command=" ".join(SEMGREP + ["."]), note=NO_FILES)
    cmd = list(SEMGREP)
    rel_out = _out_inside(target, out)
    if rel_out:  # a leading / anchors semgrep's pattern at the target root
        cmd[-1:-1] = ["--exclude", "/" + rel_out]
    rec, data = _run_json_tool("semgrep", cmd + ["."], target, out, n, lambda rc: rc >= 2,
                               note=SEMGREP_NOTE)
    scanned = ((data or {}).get("paths") or {}).get("scanned") if isinstance(data, dict) else None
    if isinstance(scanned, list):
        rec["files_examined"] = len(scanned)
        rec["note"] = "files_examined is semgrep's paths.scanned"
    if rec["status"] in ("ran", "failed_to_run"):
        rec["note"] = "; ".join(x for x in (rec["note"], SEMGREP_RULESETS) if x)
    return _add_notes(rec, _config_notes("semgrep", target, out))


def check_bandit(target, out):
    cmd = [a if a != "<dir>" else "." for a in BANDIT]
    n = len(find_py_files(target, out))
    if not n:
        return record("bandit", "skipped", version=tool_version("bandit"), command=" ".join(cmd),
                      note=NO_FILES)
    rec, _ = _run_json_tool("bandit", cmd, target, out, n, lambda rc: rc >= 2)
    return _add_notes(rec, _config_notes("bandit", target, out))


def check_trivy(target, out):
    """trivy runs from the out-dir on the absolute target path, with empty
    config and ignore files: a target's trivy.yaml could otherwise set
    `output:` and write anywhere, and its .trivyignore could hide findings."""
    config = os.path.join(out, TRIVY_EMPTY_CONFIG)
    ignore = os.path.join(out, TRIVY_EMPTY_IGNORE)
    rel_out = _out_inside(target, out)  # trivy matches --skip-dirs from the scan root
    cmd = TRIVY + (["--skip-dirs", rel_out] if rel_out else []) + [
        "--config", config, "--ignorefile", ignore, target]
    n = len(find_manifests(target, out))
    if not n:
        return record("trivy", "skipped", version=tool_version("trivy"), command=" ".join(cmd),
                      note=NO_FILES)
    for path in (config, ignore):
        open(path, "w").close()
    rec, _ = _run_json_tool("trivy", cmd, target, out, n, lambda rc: rc != 0, cwd=out,
                            failure=_trivy_failure)
    return _add_notes(rec, _config_notes("trivy", target, out))


# ---------------------------------------------------------------------------
# Fact scanners: app shape (apps.json) and per-app facts under <out>/<app_id>/.

PLACEHOLDERS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "readme-placeholders.txt")
RUNGS = (
    ("what it launches", ("overview", "about", "description")),
    ("prerequisites", ("requirements", "requirement", "prerequisites", "prerequisite", "dependencies")),
    ("installation", ("install", "installation", "installing", "setup", "set up", "deploy",
                      "deployment", "deploying")),
    ("configuration", ("configuration", "configure", "configuring", "customize", "customization",
                       "customizing")),
    ("known limitations", ("known limitations", "limitations", "caveats")),
    ("troubleshooting", ("troubleshooting", "faq", "common problems")),
    ("screenshots", ("screenshots", "screenshot")),
    ("environment variables", ("environment variables", "environment variable")),
    ("info panel", ("info panel",)),
    ("architecture", ("architecture", "how it works")),
)
APP_TYPES = {"batch-connect-basic": "batch_connect", "batch-connect-vnc": "batch_connect",
             "batch_connect": "batch_connect", "batch-connect": "batch_connect",
             "passenger_app": "passenger", "passenger": "passenger",
             "companion_app": "companion", "companion": "companion",
             "widget": "widget", "dashboard": "widget"}
PASSENGER_ENTRY = ("config.ru", "passenger_wsgi.py", "app.js")
RESERVED_IDS = {"stripped", "root"}
OUTSIDE_APP = "app path outside target, not read"
MISSING_APP = "app directory not found"


class YamlError(Exception):
    pass


def _yaml_module():
    try:
        import yaml
        return yaml
    except Exception:
        return None


def yaml_parser_note():
    return ("YAML parser: PyYAML" if _yaml_module()
            else "YAML parser: built-in subset (PyYAML not importable)")


def load_yaml(text, name):
    """Parse YAML with PyYAML when importable, else the built-in subset parser.
    Raises YamlError whose message names the file, line and column."""
    yaml = _yaml_module()
    if yaml is None:
        return _SubsetYaml(text).parse()
    try:
        return yaml.safe_load(text)
    except yaml.YAMLError as e:
        raise YamlError(" ".join(str(e).replace('"<unicode string>"', name).split()))


class _SubsetYaml:
    """Block mappings and sequences, plain/quoted scalars, single- or
    multi-line flow collections, | and > block scalars, comments, a leading
    ---. Enough for form.yml, appverse.yml and manifest.yml; anything else
    raises YamlError('line N, column M: ...'). Duplicate keys: last wins."""

    def __init__(self, text):
        self.lines = []  # (lineno, indent, content)
        raw = text.splitlines()
        i = 0
        while i < len(raw):
            line = raw[i]
            n = i + 1
            i += 1
            body = self._strip_comment(line).rstrip()
            if not body.strip() or body.strip() in ("---", "..."):
                continue
            lead = len(body) - len(body.lstrip(" "))
            if body[lead:lead + 1] == "\t":
                raise YamlError("line %d, column %d: tab character in indentation" % (n, lead + 1))
            self.lines.append([n, lead, body[lead:]])
        self.pos = 0

    @staticmethod
    def _opens_quote(text, k):
        """A quote opens a quoted scalar only at the start of one (so the
        apostrophe in a plain scalar like Pitzer's is not a quote)."""
        return text[k] in "'\"" and (k == 0 or text[k - 1] in " \t[{,:-")

    def _strip_comment(self, line):
        quote = None
        for k, ch in enumerate(line):
            if quote:
                if ch == quote:
                    quote = None
            elif self._opens_quote(line, k):
                quote = ch
            elif ch == "#" and (k == 0 or line[k - 1] in " \t"):
                return line[:k]
        return line

    def parse(self):
        if not self.lines:
            return None
        value = self._block(self.lines[0][1])
        if self.pos < len(self.lines):
            n, ind = self.lines[self.pos][0], self.lines[self.pos][1]
            raise YamlError("line %d, column %d: unexpected indentation" % (n, ind + 1))
        return value

    def _block(self, indent):
        if self.lines[self.pos][2].startswith("- ") or self.lines[self.pos][2] == "-":
            return self._seq(indent)
        return self._map(indent)

    def _map(self, indent):
        out = {}
        while self.pos < len(self.lines):
            n, ind, content = self.lines[self.pos][:3]
            if ind < indent:
                break
            if ind > indent:
                raise YamlError("line %d, column %d: unexpected indentation" % (n, ind + 1))
            if content.startswith("- "):
                break
            key, rest = self._split_key(content, n, ind)
            self.pos += 1
            out[key] = self._value(rest, n, ind + len(content) - len(rest), indent)
        return out

    def _seq(self, indent):
        out = []
        while self.pos < len(self.lines):
            n, ind, content = self.lines[self.pos][:3]
            if ind < indent or not (content.startswith("- ") or content == "-"):
                if ind > indent:
                    raise YamlError("line %d, column %d: unexpected indentation" % (n, ind + 1))
                break
            if ind > indent:
                raise YamlError("line %d, column %d: unexpected indentation" % (n, ind + 1))
            rest = content[1:].lstrip(" ")
            if not rest:
                self.pos += 1
                out.append(self._nested(indent, n))
                continue
            item_ind = ind + (len(content) - len(rest))
            if self._is_key(rest):  # "- key: value" starts a mapping at item_ind
                self.lines[self.pos][1:3] = [item_ind, rest]
                out.append(self._map(item_ind))
            else:
                self.pos += 1
                out.append(self._value(rest, n, item_ind, indent))
        return out

    def _nested(self, indent, n):
        if self.pos < len(self.lines) and self.lines[self.pos][1] > indent:
            return self._block(self.lines[self.pos][1])
        return None

    @staticmethod
    def _is_key(text):
        return bool(re.match(r"""^(?:"[^"]*"|'[^']*'|[^\s\[\]{}#&*!|>'"%@`][^:#]*?)\s*:(?:\s|$)""", text))

    def _split_key(self, content, n, ind):
        m = re.match(r"""^("[^"]*"|'[^']*'|[^\s\[\]{}#&*!|>'"%@`][^#]*?)\s*:(?:\s+|$)(.*)$""", content)
        if not m:
            raise YamlError("line %d, column %d: expected a 'key: value' mapping entry" % (n, ind + 1))
        key = m.group(1)
        if key[:1] in "'\"":
            key = key[1:-1]
        return key, m.group(2)

    def _value(self, rest, n, col, indent):
        rest = rest.strip()
        if not rest:
            nxt = self.lines[self.pos] if self.pos < len(self.lines) else None
            if nxt and nxt[1] == indent and (nxt[2].startswith("- ") or nxt[2] == "-"):
                return self._seq(indent)  # "key:" then "- item" at the key's own indent
            return self._nested(indent, n)
        if rest[:1] in "|>":
            parts = []
            while self.pos < len(self.lines) and self.lines[self.pos][1] > indent:
                parts.append(self.lines[self.pos][2])
                self.pos += 1
            return ("\n" if rest[0] == "|" else " ").join(parts)
        if rest[:1] in "[{":
            text = rest
            while not self._balanced(text):
                if self.pos >= len(self.lines):
                    raise YamlError("line %d, column %d: flow %s '%s' is never closed"
                                    % (n, col + 1, "sequence" if rest[0] == "[" else "mapping", rest[0]))
                text += " " + self.lines[self.pos][2]
                self.pos += 1
            return self._flow(text, n, col)
        if rest[:1] not in "'\"":  # a plain scalar continues on more-indented lines
            while self.pos < len(self.lines) and self.lines[self.pos][1] > indent:
                rest += " " + self.lines[self.pos][2]
                self.pos += 1
        return self._scalar(rest, n, col)

    def _balanced(self, text):
        depth, quote = 0, None
        for k, ch in enumerate(text):
            if quote:
                if ch == quote:
                    quote = None
            elif self._opens_quote(text, k):
                quote = ch
            elif ch in "[{":
                depth += 1
            elif ch in "]}":
                depth -= 1
        return depth <= 0 and quote is None

    def _flow(self, text, n, col):
        # ":" is an indicator only before a space, a flow indicator or the end
        tokens = re.findall(r'"(?:[^"\\]|\\.)*"|\'[^\']*\'|[\[\]{},]|:(?=[\s,\]}]|$)'
                            r'|(?:[^\[\]{},:"\']|:(?![\s,\]}]|$))+', text)
        tokens = [t.strip() for t in tokens if t.strip()]
        pos = [0]

        def err(msg):
            raise YamlError("line %d, column %d: %s" % (n, col + 1, msg))

        def item():
            if pos[0] >= len(tokens):
                err("unexpected end of flow collection")
            t = tokens[pos[0]]
            if t == "[":
                pos[0] += 1
                seq = []
                while tokens[pos[0]:pos[0] + 1] != ["]"]:
                    value = item()
                    if tokens[pos[0]:pos[0] + 1] == [":"]:  # [a, key: value] single-pair map
                        pos[0] += 1
                        value = {value: item()}
                    seq.append(value)
                    if tokens[pos[0]:pos[0] + 1] == [","]:
                        pos[0] += 1
                    elif tokens[pos[0]:pos[0] + 1] != ["]"]:
                        err("expected ',' or ']' in flow sequence")
                pos[0] += 1
                return seq
            if t == "{":
                pos[0] += 1
                mapping = {}
                while tokens[pos[0]:pos[0] + 1] != ["}"]:
                    k = item()
                    if tokens[pos[0]:pos[0] + 1] != [":"]:
                        err("expected ':' in flow mapping")
                    pos[0] += 1
                    mapping[k] = item()
                    if tokens[pos[0]:pos[0] + 1] == [","]:
                        pos[0] += 1
                    elif tokens[pos[0]:pos[0] + 1] != ["}"]:
                        err("expected ',' or '}' in flow mapping")
                pos[0] += 1
                return mapping
            if t in ",:]}":
                err("unexpected '%s' in flow collection" % t)
            pos[0] += 1
            return self._scalar(t, n, col)

        value = item()
        if pos[0] != len(tokens):
            err("unexpected text after flow collection")
        return value

    @staticmethod
    def _scalar(text, n, col):
        if text[:1] == '"':
            if len(text) < 2 or not text.endswith('"'):
                raise YamlError("line %d, column %d: unclosed double-quoted string" % (n, col + 1))
            return text[1:-1].replace('\\"', '"').replace("\\\\", "\\")
        if text[:1] == "'":
            if len(text) < 2 or not text.endswith("'"):
                raise YamlError("line %d, column %d: unclosed single-quoted string" % (n, col + 1))
            return text[1:-1].replace("''", "'")
        low = text.lower()
        if low in ("null", "~"):
            return None
        if low in ("true", "yes", "on"):
            return True
        if low in ("false", "no", "off"):
            return False
        if re.match(r"^[-+]?\d+$", text):
            return int(text)
        if re.match(r"^[-+]?(\d+\.\d*|\.\d+)([eE][-+]?\d+)?$", text):
            return float(text)
        return text


def _read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def _inside(target, path):
    root_real = os.path.realpath(target)
    real = os.path.realpath(path)
    return os.path.commonpath([real, root_real]) == root_real


def _load_file(path, rel):
    """Parsed YAML of a file, or None when it is absent or does not parse."""
    if not os.path.isfile(path):
        return None
    try:
        data = load_yaml(_read(path), rel)
    except Exception:
        return None
    return data if isinstance(data, dict) else None


def _app_type(declared, app_dir):
    """batch_connect | passenger | companion | widget | unknown: the first
    declared value that maps (appverse.yml app_type, then manifest role),
    else the entry-point files."""
    for value in declared:
        mapped = APP_TYPES.get(str(value or "").strip().lower())
        if mapped:
            return mapped
    if app_dir is None or not os.path.isdir(app_dir):
        return "unknown"
    names = set(os.listdir(app_dir))
    if names & set(PASSENGER_ENTRY):
        return "passenger"
    if names & {"form.yml", "form.yml.erb", "submit.yml.erb", "submit.yml"}:
        return "batch_connect"
    return "unknown"


def _find_readme(app_dir):
    if app_dir is None or not os.path.isdir(app_dir):
        return None
    for name in sorted(os.listdir(app_dir)):
        if name.lower() in ("readme.md", "readme.markdown", "readme") and \
                os.path.isfile(os.path.join(app_dir, name)):
            return name
    return None


def _app_id(path, taken):
    base = re.sub(r"[^A-Za-z0-9._-]", "-", path.rstrip("/").rsplit("/", 1)[-1]).strip(".") or "app"
    app_id = base
    if app_id in RESERVED_IDS or app_id in taken:
        app_id = re.sub(r"[^A-Za-z0-9._-]", "-", path.strip("/")).strip(".-") or "app"
    k = 2
    while app_id in RESERVED_IDS or app_id in taken:
        app_id, k = "%s-%d" % (base, k), k + 1
    return app_id


def resolve_apps(target):
    """App shape as target-setup.md section 3: a root appverse.yml with an
    apps: list is a monorepo (each apps[].path an app, id its last path
    component); otherwise the repo is one app, id "root", path ".".

    Returns a list of {app_id, path, app_type, readme, _dir, _skip}: readme
    is the repo-relative README (a monorepo app without its own falls back to
    the root README), _dir the absolute app directory, _skip why the app is
    not read (outside the target, or missing) or None. The monorepo app_type
    precedence is the inline apps[] entry, then <path>/appverse.yml, then
    <path>/manifest.yml role, then entry-point files."""
    root_meta = _load_file(os.path.join(target, "appverse.yml"), "appverse.yml") or {}
    root_readme = _find_readme(target)
    apps_decl = root_meta.get("apps")
    if not isinstance(apps_decl, list) or not apps_decl:
        manifest = _load_file(os.path.join(target, "manifest.yml"), "manifest.yml") or {}
        return [{"app_id": "root", "path": ".",
                 "app_type": _app_type([root_meta.get("app_type"), manifest.get("role")], target),
                 "readme": root_readme, "_dir": target, "_skip": None}]
    apps, taken = [], set()
    for entry in apps_decl:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str) or not entry["path"].strip():
            continue
        path = entry["path"].strip().rstrip("/") or "."
        app_id = _app_id(path, taken)
        taken.add(app_id)
        full = os.path.join(target, path)
        skip = None
        if os.path.isabs(path) or not _inside(target, full):
            skip = OUTSIDE_APP
        elif not os.path.isdir(full):
            skip = MISSING_APP
        if skip:
            apps.append({"app_id": app_id, "path": path, "app_type": "unknown", "readme": None,
                         "_dir": None, "_skip": skip})
            continue
        sub = _load_file(os.path.join(full, "appverse.yml"), path + "/appverse.yml") or {}
        manifest = _load_file(os.path.join(full, "manifest.yml"), path + "/manifest.yml") or {}
        own = _find_readme(full)
        apps.append({"app_id": app_id, "path": path,
                     "app_type": _app_type([entry.get("app_type"), sub.get("app_type"),
                                            manifest.get("role")], full),
                     "readme": (own if path == "." else path + "/" + own) if own else root_readme,
                     "_dir": full, "_skip": None})
    return apps


def _public(app):
    return {k: v for k, v in app.items() if not k.startswith("_")}


def load_placeholders(path=PLACEHOLDERS_FILE):
    try:
        lines = _read(path).splitlines()
    except OSError:
        return []
    return [l.strip() for l in lines if l.strip() and not l.startswith("# ")]


def _norm_heading(text):
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"[`*_]", "", text).lower()
    return " ".join(re.findall(r"[a-z0-9]+", text))


def _rung_for(text):
    words = " " + _norm_heading(text) + " "
    for rung, synonyms in RUNGS:
        if any(" " + s + " " in words for s in synonyms):
            return rung
    return None


def _markdown_lines(lines):
    """Per line: (in_fence, in_comment). A fence marker line counts as in the
    fence; a line that opens or closes an HTML comment counts as comment only
    when nothing but the comment is on it."""
    out, fence, comment = [], None, False
    for line in lines:
        s = line.strip()
        m = re.match(r"^ {0,3}(`{3,}|~{3,})", line)
        if fence is None and not comment and m:
            fence = m.group(1)[0] * len(m.group(1))
            out.append((True, False))
            continue
        if fence is not None:
            if s.startswith(fence) and not s.strip(fence[0]):
                fence = None
            out.append((True, False))
            continue
        if comment:
            if "-->" in s:
                comment = False
            out.append((False, True))
            continue
        if s.startswith("<!--"):
            closed = "-->" in s[4:]
            comment = not closed
            after = s[4:].split("-->", 1)[1].strip() if closed else ""
            out.append((False, not after))
            continue
        out.append((False, False))
    return out


def scan_readme(text, placeholders):
    """readme.json for one README's text (file set by the caller)."""
    lines = text.splitlines()
    flags = _markdown_lines(lines)
    low_phrases = [(p, p.lower()) for p in placeholders]

    def phrase_of(line):
        low = line.lower()
        return next((p for p, lp in low_phrases if lp in low), None)

    headings, underlines = [], set()
    for i, line in enumerate(lines):
        fence, comment = flags[i]
        if fence or comment:
            continue
        m = re.match(r"^ {0,3}(#{1,6})(?:\s+(.*?))?\s*$", line)
        if m:
            text_ = re.sub(r"\s+#+\s*$", "", m.group(2) or "").strip()
            headings.append({"level": len(m.group(1)), "text": text_, "line": i + 1})
            continue
        # setext: a === or --- line under a paragraph line
        m = re.match(r"^ {0,3}(=+|-+)\s*$", line)
        prev = lines[i - 1] if i else ""
        if m and prev.strip() and not any(flags[i - 1]) and i not in underlines \
                and not (headings and headings[-1]["line"] == i) \
                and not re.match(r"^ {0,3}([-*+] |\d+[.)] |>|\|)", prev):
            headings.append({"level": 1 if m.group(1)[0] == "=" else 2, "text": prev.strip(), "line": i})
            underlines.add(i + 1)
    heading_lines = {h["line"] for h in headings}
    # a table's header row and |---| rule are structure, not section content
    rule = re.compile(r"^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$")
    table_rules = set()
    for i, line in enumerate(lines):
        if i and "|" in line and rule.match(line) and "|" in lines[i - 1] and not flags[i][0]:
            table_rules |= {i, i + 1}

    placeholder_rows = []
    for i, line in enumerate(lines):
        p = phrase_of(line)
        if p:
            placeholder_rows.append({"line": i + 1, "text": line.strip(), "phrase": p})
    placeholder_lines = {r["line"] for r in placeholder_rows}

    rungs = dict((r, None) for r, _ in RUNGS)
    for idx, h in enumerate(headings):
        rung = _rung_for(h["text"])
        if not rung or rungs[rung] is not None:
            continue
        end = next((g["line"] for g in headings[idx + 1:] if g["level"] <= h["level"]), len(lines) + 1)
        content = [n for n in range(h["line"] + 1, end)
                   if lines[n - 1].strip() and not flags[n - 1][1] and n not in heading_lines
                   and n not in underlines and n not in table_rules
                   and not re.match(r"^ {0,3}(`{3,}|~{3,})", lines[n - 1])]
        placeholder = bool(phrase_of(h["text"])) or all(n in placeholder_lines for n in content)
        rungs[rung] = {"heading": h["text"], "line": h["line"], "placeholder": placeholder}

    screenshots, env_vars = [], []
    for i, line in enumerate(lines):
        fence, comment = flags[i]
        if comment:
            continue
        if not fence:
            for m in re.finditer(r"!\[([^\]]*)\]\(\s*<?([^)\s>]+)>?[^)]*\)", line):
                if not re.search(r"shields\.io|badge", m.group(2), re.I):
                    screenshots.append({"line": i + 1, "alt": m.group(1), "target": m.group(2)})
            for m in re.finditer(r"<img\b[^>]*\bsrc=[\"']([^\"']+)[\"'][^>]*>", line, re.I):
                if not re.search(r"shields\.io|badge", m.group(1), re.I):
                    alt = re.search(r"\balt=[\"']([^\"']*)[\"']", m.group(0), re.I)
                    screenshots.append({"line": i + 1, "alt": alt.group(1) if alt else "",
                                        "target": m.group(1)})
        if i + 1 in heading_lines:
            if "environment variable" in _norm_heading(line):
                env_vars.append({"line": i + 1, "text": line.strip(), "match": "heading"})
            continue
        if re.search(r"[A-Z_]{3,}=", line):
            env_vars.append({"line": i + 1, "text": line.strip(), "match": "assignment"})
        elif "environment variable" in line.lower():
            env_vars.append({"line": i + 1, "text": line.strip(), "match": "phrase"})

    return {"headings": headings, "placeholders": placeholder_rows, "screenshots": screenshots,
            "env_vars": env_vars, "rungs": rungs}


def _attr_lines(text):
    """{name: line} for the direct children of the top-level attributes:
    block, and {name: line} for the top-level form: list items (line scan
    of the ERB-stripped text, so it works with either YAML parser)."""
    attrs, form = {}, {}
    section, child = None, None
    for n, line in enumerate(text.splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        ind = len(line) - len(line.lstrip(" "))
        if ind == 0:
            m = re.match(r"^([\w-]+)\s*:", line)
            section = m.group(1) if m else None
            child = None
            continue
        if section == "attributes":
            if child is None:
                child = ind
            m = re.match(r"^\s*[\"']?([\w-]+)[\"']?\s*:", line)
            if ind == child and m:
                attrs.setdefault(m.group(1), n)
        elif section == "form":
            m = re.match(r"^\s*-\s*[\"']?([\w-]+)[\"']?\s*$", line)
            if m:
                form.setdefault(m.group(1), n)
    return attrs, form


def _yaml_paths(lines):
    """Per line of an ERB-stripped YAML text: the key path it sits under
    (list of keys), from indentation. A "- " item belongs to the key above it
    at a smaller or equal indent."""
    stack, paths = [], []  # stack of (indent, key)
    for line in lines:
        s = line.strip()
        if s and not s.startswith("#") and s not in ("---", "..."):
            ind = len(line) - len(line.lstrip(" "))
            body = s
            if s.startswith("- ") or s == "-":
                while stack and stack[-1][0] > ind:
                    stack.pop()
                body = s[1:].lstrip()
                ind += len(s) - len(body)
            m = re.match(r"^[\"']?([\w-]+)[\"']?\s*:(\s|$)", body)
            if m:
                while stack and stack[-1][0] >= ind:
                    stack.pop()
                stack.append((ind, m.group(1)))
        paths.append([k for _, k in stack])
    return paths


def _submit_refs(text, names):
    """{name: (lines, reaches_scheduler)} for a submit.yml.erb text: the lines
    where the name appears inside an ERB tag, and whether its value reaches
    script.* or batch_connect.template through a <%= %> tag (directly, or
    through a variable assigned from it in a <% %> tag)."""
    stripped_lines = strip_erb(text).splitlines()
    paths = _yaml_paths(stripped_lines)
    tags = []  # (kind, start line, body)
    for m in re.finditer(r"<%(?!%)(#|=|-)?(.*?)-?%>", text, flags=re.S):
        if m.group(1) == "#":
            continue
        start = text.count("\n", 0, m.start()) + 1
        tags.append(("out" if m.group(1) == "=" else "code", start, m.group(2)))
    word = lambda n: re.compile(r"(?<![\w@$.])%s(?![\w?!])" % re.escape(n))
    taint = {n: {n} for n in names}  # variable -> attributes it carries
    changed = True
    while changed:
        changed = False
        for kind, start, body in tags:
            if kind != "code":
                continue
            for stmt in body.splitlines():
                m = re.match(r"^\s*([a-z_]\w*)\s*(?:\|\||\+|-|\*)?=(?!=|~)(.*)$", stmt)
                if not m:
                    continue
                carried = set()
                for var, srcs in taint.items():
                    if word(var).search(m.group(2)):
                        carried |= srcs
                old = taint.get(m.group(1), set())
                if not carried <= old:
                    taint[m.group(1)] = old | carried
                    changed = True
    out = {}
    for n in names:
        lines, reaches = [], False
        pat = word(n)
        for kind, start, body in tags:
            for k, seg in enumerate(body.split("\n")):
                if pat.search(seg):
                    lines.append(start + k)
            if kind == "out" and not reaches:
                vars_ = [v for v, srcs in taint.items() if n in srcs]
                if any(word(v).search(body) for v in vars_):
                    path = paths[start - 1] if start - 1 < len(paths) else []
                    reaches = path[:1] == ["script"] or path[:2] == ["batch_connect", "template"]
        out[n] = (sorted(set(lines)), reaches)
    return out


def _num(value):
    """min/max as written: a number or string kept, anything else as text."""
    if value is None or (isinstance(value, (int, float, str)) and not isinstance(value, bool)):
        return value
    return str(value)


def scan_form(app_dir):
    """form.json for one app directory, or None when it has no form file.
    Raises nothing: a parse failure is returned as {"error": ...}."""
    rel = next((f for f in ("form.yml", "form.yml.erb") if os.path.isfile(os.path.join(app_dir, f))), None)
    if rel is None:
        return None
    submit = next((f for f in ("submit.yml.erb", "submit.yml")
                   if os.path.isfile(os.path.join(app_dir, f))), None)
    result = {"file": rel, "submit_file": submit, "error": None, "attributes": []}
    text = strip_erb(_read(os.path.join(app_dir, rel))) if rel.endswith(".erb") \
        else _read(os.path.join(app_dir, rel))
    try:
        data = load_yaml(text, rel)
    except YamlError as e:
        result["error"] = str(e)
        return result
    if data is None:
        data = {}
    if not isinstance(data, dict):
        result["error"] = "top level is not a mapping"
        return result
    attrs = data.get("attributes") if isinstance(data.get("attributes"), dict) else {}
    form = [f for f in (data.get("form") or []) if isinstance(f, str)] \
        if isinstance(data.get("form"), list) else []
    attr_lines, form_lines = _attr_lines(text)
    names = [str(k) for k in attrs] + [f for f in form if f not in attrs]
    refs = _submit_refs(_read(os.path.join(app_dir, submit)), names) if submit else {}
    for name in names:
        spec = attrs.get(name)
        spec = spec if isinstance(spec, dict) else {}
        html = spec.get("html_options") if isinstance(spec.get("html_options"), dict) else {}
        lines, reaches = refs.get(name, ([], False))
        result["attributes"].append({
            "name": name,
            "widget": spec.get("widget"),
            "min": _num(spec.get("min")),
            "max": _num(spec.get("max")),
            "pattern": spec.get("pattern", html.get("pattern")),
            "required": bool(spec.get("required", html.get("required", False))),
            "line": attr_lines.get(name) if name in attrs else form_lines.get(name),
            "defined": name in attrs,
            "in_form": name in form,
            "interpolated_in_submit": bool(lines),
            "submit_lines": lines,
            "reaches_scheduler": reaches,
        })
    return result


def _fact_record(name, command, per_app, notes, files_examined, output):
    statuses = set(per_app.values())
    status = ("failed_to_run" if "failed_to_run" in statuses else
              "ran" if "ran" in statuses else "skipped")
    rec = record(name, status, command=command, output_file=output,
                 files_examined=files_examined, note="; ".join(notes))
    rec["per_app"] = per_app
    return rec


def _app_dir_out(out, app):
    path = os.path.join(out, app["app_id"])
    os.makedirs(path, exist_ok=True)
    return path


def check_readme(target, apps, out):
    placeholders = load_placeholders()
    per_app, notes, n = {}, [], 0
    for app in apps:
        if app["_skip"]:
            per_app[app["app_id"]] = "skipped"
            notes.append("%s: %s" % (app["app_id"], app["_skip"]))
            continue
        if not app["readme"]:
            per_app[app["app_id"]] = "skipped"
            notes.append("%s: no README" % app["app_id"])
            continue
        try:
            data = scan_readme(_read(os.path.join(target, app["readme"])), placeholders)
        except Exception as e:
            per_app[app["app_id"]] = "failed_to_run"
            notes.append(("%s: %s: %s" % (app["app_id"], type(e).__name__, e))[:STDERR_CHARS])
            continue
        n += 1
        _write_json(_app_dir_out(out, app), "readme.json", dict([("file", app["readme"])] + list(data.items())))
        per_app[app["app_id"]] = "ran"
    return _fact_record("readme", "README headings, placeholder lines (references/readme-placeholders.txt), "
                        "screenshots, env vars, rungs", per_app, notes, n, "<app_id>/readme.json")


def check_form(apps, out):
    per_app, notes, n = {}, [yaml_parser_note()], 0
    for app in apps:
        if app["_skip"]:
            per_app[app["app_id"]] = "skipped"
            notes.append("%s: %s" % (app["app_id"], app["_skip"]))
            continue
        try:
            data = scan_form(app["_dir"])
        except Exception as e:
            per_app[app["app_id"]] = "failed_to_run"
            notes.append(("%s: %s: %s" % (app["app_id"], type(e).__name__, e))[:STDERR_CHARS])
            continue
        if data is None:
            per_app[app["app_id"]] = "skipped"
            continue
        n += 1
        _write_json(_app_dir_out(out, app), "form.json", data)
        if data["error"]:
            per_app[app["app_id"]] = "failed_to_run"
            notes.append(("%s: %s: %s" % (app["app_id"], data["file"], data["error"]))[:STDERR_CHARS])
        else:
            per_app[app["app_id"]] = "ran"
    return _fact_record("form", "form.yml / form.yml.erb (ERB stripped) attributes, cross-referenced "
                        "with submit.yml.erb", per_app, notes, n, "<app_id>/form.json")


def check_catalog(args):
    # Placeholder: catalog reads land in a later PR; --catalog is accepted and ignored.
    return record("catalog", "skipped", note="catalog reads land in a later PR")


def _tool_status(rec):
    if rec["status"] == "ran":
        stripped = "file(s) scanned ERB-stripped" in (rec["note"] or "")
        return "Run (ERB-stripped)" if rec["name"] == "shellcheck" and stripped else "Run"
    if rec["status"] == "not_installed":
        return "Not run (not installed)"
    if rec["status"] == "failed_to_run":
        return "Not run (failed)"
    return "Not run (%s)" % rec["note"]


def _tool_result(rec):
    n = rec.get("finding_count")
    if rec["status"] != "ran" or n is None:
        return "\u2014"
    if n == 0:
        return "0 findings"
    return "%d finding%s (%s)" % (n, "" if n == 1 else "s", ", ".join(rec.get("top_codes") or []))


def tool_table(checks):
    """The Check tiers line and the tool table, as the security skill pastes it."""
    by_name = {c["name"]: c for c in checks}
    rows = [by_name.get(t) or record(t, "failed_to_run") for t in TABLE_TOOLS]
    tiers = "Tiers 1\u20132" if any(r["status"] == "ran" for r in rows) else "Tier 1 only"
    lines = ["**Check tiers:** " + tiers, "",
             "Tier 3 not checked \u2014 no isolated execution environment.", "",
             "| Tool | Status | Result |", "|---|---|---|"]
    lines += ["| %s | %s | %s |" % (r["name"], _tool_status(r).replace("|", "\\|"),
                                    _tool_result(r)) for r in rows]
    return "\n".join(lines) + "\n"


def _prepare_out(out):
    os.makedirs(out, exist_ok=True)
    try:  # the previous run's per-app fact dirs, named in its apps.json
        with open(os.path.join(out, "apps.json")) as f:
            previous = [a.get("app_id") for a in json.load(f)]
    except Exception:
        previous = []
    for app_id in previous:
        if isinstance(app_id, str) and re.match(r"^[A-Za-z0-9_-][A-Za-z0-9._-]*$", app_id) \
                and app_id != "stripped":
            shutil.rmtree(os.path.join(out, app_id), ignore_errors=True)
    for name in os.listdir(out):
        if name.endswith(".json") or name == "tool-table.md":
            os.remove(os.path.join(out, name))
    shutil.rmtree(os.path.join(out, "stripped"), ignore_errors=True)


def main(argv):
    ap = argparse.ArgumentParser(
        prog="run-pre-review.sh",
        description="Run the static-analysis tools and the shell syntax check before the model.")
    ap.add_argument("target", help="app repo to check")
    ap.add_argument("out", help="directory for summary.json, syntax.json and the tool JSON")
    ap.add_argument("--catalog", metavar="URL", help="Appverse catalog base URL (not read yet)")
    ap.add_argument("--no-catalog", action="store_true", help="skip catalog reads")
    args = ap.parse_args(argv)

    if not args.target or not os.path.isdir(args.target):
        print("error: target directory not found: %s" % args.target, file=sys.stderr)
        return 2
    target = os.path.abspath(args.target)
    out = os.path.abspath(args.out)
    if os.path.realpath(out) == os.path.realpath(target):
        print("error: out-dir must not be the target: %s" % args.out, file=sys.stderr)
        return 2
    _prepare_out(out)

    checks, syntax_entries = [], []

    def guarded(name, fn, *a):
        try:
            return fn(*a)
        except Exception as e:
            return record(name, "failed_to_run", note=("%s: %s" % (type(e).__name__, e))[:STDERR_CHARS])

    def syntax():
        nonlocal syntax_entries
        rec, syntax_entries = check_syntax(target, out)
        return rec

    checks.append(guarded("syntax", syntax))
    checks.append(guarded("shellcheck", check_shellcheck, target, out, syntax_entries))
    checks.append(guarded("semgrep", check_semgrep, target, out))
    checks.append(guarded("bandit", check_bandit, target, out))
    checks.append(guarded("trivy", check_trivy, target, out))
    checks.append(guarded("catalog", check_catalog, args))

    try:
        apps = resolve_apps(target)
    except Exception as e:  # never fail the run: one unread root app
        apps = [{"app_id": "root", "path": ".", "app_type": "unknown", "readme": None, "_dir": None,
                 "_skip": ("app shape not resolved: %s: %s" % (type(e).__name__, e))[:STDERR_CHARS]}]
    _write_json(out, "apps.json", [_public(a) for a in apps])
    facts = [guarded("readme", check_readme, target, apps, out),
             guarded("form", check_form, apps, out)]

    _write_json(out, "summary.json", {
        "schema": SCHEMA,
        "target": target,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "checks": checks,
        "facts": facts,
    })
    with open(os.path.join(out, "tool-table.md"), "w", encoding="utf-8") as f:
        f.write(tool_table(checks))
    for c in checks + facts:
        print("%-10s %s%s" % (c["name"], c["status"], " (%s)" % c["note"] if c["note"] else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
