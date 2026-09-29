#!/usr/bin/env python3
"""Pre-review facts: run the static-analysis tools and the shell syntax check
once, before the model, and write the results as JSON.

    references/run-pre-review.sh <target-dir> <out-dir> [--catalog URL] [--no-catalog]

Exit 0 whenever the script ran to completion, whatever the tools found; exit 2
only when <target-dir> is missing (or the arguments do not parse). A tool that
is absent, crashes, or times out is data in the output, never a script failure.

Files written to <out-dir> (any previous *.json and stripped/ are removed first):

  summary.json   {"schema": "pre-review/1", "target": <abs path>,
                  "generated_at": <ISO 8601 UTC>, "checks": [...]}
                 one record per check, in the fixed order syntax, shellcheck,
                 semgrep, bandit, trivy, catalog, each with name, status
                 (ran | not_installed | failed_to_run | skipped), version,
                 command, exit_code, output_file, files_examined, note.
  syntax.json    one entry per shell file (*.sh, *.bash, *.sh.erb): path
                 (repo-relative), stripped (ERB tags removed first), ok
                 (bash -n passed), stderr (first 500 chars).
  shellcheck.json  shellcheck's objects concatenated across files, "file" set
                 to the repo-relative source path (.sh.erb scanned stripped).
  semgrep.json, bandit.json, trivy.json  the tool's own JSON, verbatim.
  stripped/<path>.sh  the ERB-stripped copy of each .sh.erb, for inspection.

A tool's JSON is absent when the tool did not run. Status rules: no applicable
files -> skipped ("no applicable files"); binary not on PATH -> not_installed
(note = install hint); raised, timed out (300 s), or exited with a crash code
(shellcheck >= 2, semgrep >= 2, bandit >= 2, trivy != 0) -> failed_to_run
(note = first 500 chars of stderr); otherwise ran. The catalog check is a
placeholder: always skipped. Tool commands are the ones in security-tools.md.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone

SCHEMA = "pre-review/1"
SKIP_DIRS = {".git", "vendor", "node_modules"}
SHELL_SUFFIXES = (".sh", ".bash", ".sh.erb")
MANIFEST_NAMES = {"package.json", "requirements.txt", "Gemfile.lock", "Dockerfile"}
TIMEOUT = 300
STDERR_CHARS = 500
NO_FILES = "no applicable files"
INSTALL_HINTS = {
    "shellcheck": "apt install shellcheck / brew install shellcheck",
    "bandit": "pip install bandit",
    "semgrep": "pip install semgrep",
    "trivy": "brew install trivy / see https://aquasecurity.github.io/trivy",
}
SHELLCHECK = ["shellcheck", "-f", "json", "-S", "warning"]
SEMGREP = ["semgrep", "--config=p/security-audit", "--config=p/secrets", "--metrics=off",
           "--exclude", "vendor", "--exclude", "node_modules", "--json"]
BANDIT = ["bandit", "-r", "<dir>", "-f", "json"]
TRIVY = ["trivy", "fs", "--format", "json", "--scanners", "vuln,misconfig,secret",
         "--skip-dirs", "vendor", "--skip-dirs", "node_modules"]


def strip_erb(text):
    """Remove ERB tags, keeping each tag's newlines so line numbers survive.

    Order matters: comments first (so a %> inside a comment ends nothing else),
    then <%= %> -> ERBVALUE (so TIMEOUT=<%= x %> stays valid shell), then bare
    <% %> -> empty. re.S so multi-line tags match.
    """
    def keep_newlines(match, filler=""):
        return filler + "\n" * match.group(0).count("\n")

    text = re.sub(r"<%#.*?%>", lambda m: keep_newlines(m), text, flags=re.S)
    text = re.sub(r"<%=.*?%>", lambda m: keep_newlines(m, "ERBVALUE"), text, flags=re.S)
    text = re.sub(r"<%.*?%>", lambda m: keep_newlines(m), text, flags=re.S)
    return text


def _walk(target):
    """Every file under target as a sorted repo-relative path, skipping SKIP_DIRS."""
    found = []
    for root, dirs, files in os.walk(target):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            rel = os.path.relpath(os.path.join(root, name), target)
            found.append(rel.replace(os.sep, "/"))
    return sorted(found)


def find_shell_files(target):
    return [p for p in _walk(target) if p.endswith(SHELL_SUFFIXES)]


def find_py_files(target):
    return [p for p in _walk(target) if p.endswith(".py")]


def find_manifests(target):
    return [p for p in _walk(target)
            if p.rsplit("/", 1)[-1] in MANIFEST_NAMES or p.endswith(".def")]


def count_files(target):
    return len(_walk(target))


def run(cmd, timeout=TIMEOUT, cwd=None):
    """Run cmd; return (returncode, stdout, stderr, error). error is a string
    when the process could not be run or timed out, else None."""
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
           files_examined=0, note=""):
    return {"name": name, "status": status, "version": version, "command": command,
            "exit_code": exit_code, "output_file": output_file,
            "files_examined": files_examined, "note": note}


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


def check_syntax(target, out):
    """bash -n on every shell file (ERB-stripped copy for .sh.erb). Returns
    (summary record, syntax entries). Entries carry the path scanned in
    '_scan' for shellcheck; it is dropped before syntax.json is written."""
    files = find_shell_files(target)
    command = "bash -n <file> (per shell file; .sh.erb checked as its ERB-stripped copy)"
    if not files:
        _write_json(out, "syntax.json", [])
        return record("syntax", "skipped", command=command, output_file="syntax.json",
                      note=NO_FILES), []
    bash = shutil.which("bash")
    if bash is None:
        return record("syntax", "not_installed", command=command, files_examined=len(files),
                      note="bash not found on PATH"), []
    entries = []
    for rel in files:
        stripped = rel.endswith(".sh.erb")
        scan = _stripped_copy(target, out, rel) if stripped else rel
        rc, _, err, error = run([bash, "-n", scan], cwd=target)
        if error:
            ok, stderr = False, error
        else:
            ok, stderr = rc == 0, err.replace(scan, rel)
        entries.append({"path": rel, "stripped": stripped, "ok": ok,
                        "stderr": stderr[:STDERR_CHARS], "_scan": scan})
    _write_json(out, "syntax.json", [{k: v for k, v in e.items() if k != "_scan"} for e in entries])
    failed = sum(1 for e in entries if not e["ok"])
    return record("syntax", "ran", version=tool_version("bash"), command=command,
                  exit_code=1 if failed else 0, output_file="syntax.json",
                  files_examined=len(files),
                  note="%d of %d files failed bash -n" % (failed, len(files)) if failed else ""), entries


def check_shellcheck(target, out, syntax_entries):
    files = find_shell_files(target)
    command = " ".join(SHELLCHECK) + " <file> (per shell file; .sh.erb scanned as its ERB-stripped copy)"
    if not files:
        return record("shellcheck", "skipped", version=tool_version("shellcheck"), command=command,
                      note=NO_FILES)
    if shutil.which("shellcheck") is None:
        return record("shellcheck", "not_installed", command=command, files_examined=len(files),
                      note=INSTALL_HINTS["shellcheck"])
    scans = {e["path"]: e["_scan"] for e in syntax_entries}
    version = tool_version("shellcheck")
    results, worst = [], 0
    for rel in files:
        scan = scans.get(rel) or (_stripped_copy(target, out, rel) if rel.endswith(".sh.erb") else rel)
        rc, stdout, err, error = run(SHELLCHECK + [scan], cwd=target)
        if error or rc >= 2:
            return record("shellcheck", "failed_to_run", version=version, command=command,
                          exit_code=rc, files_examined=len(files),
                          note=("%s: %s" % (rel, error or err))[:STDERR_CHARS])
        worst = max(worst, rc)
        try:
            items = json.loads(stdout) if stdout.strip() else []
        except ValueError:
            return record("shellcheck", "failed_to_run", version=version, command=command,
                          exit_code=rc, files_examined=len(files),
                          note=("%s: output was not JSON: %s" % (rel, err or stdout))[:STDERR_CHARS])
        for item in items:
            item["file"] = rel
        results.extend(items)
    _write_json(out, "shellcheck.json", results)
    n_stripped = sum(1 for f in files if f.endswith(".sh.erb"))
    return record("shellcheck", "ran", version=version, command=command, exit_code=worst,
                  output_file="shellcheck.json", files_examined=len(files),
                  note="%d .sh.erb file(s) scanned ERB-stripped" % n_stripped if n_stripped else "")


def _run_json_tool(name, cmd, target, out, files_examined, crashed):
    """Run a whole-directory tool from the target root; its stdout JSON is
    written verbatim to <name>.json when it ran."""
    command = " ".join(cmd)
    if shutil.which(name) is None:
        return record(name, "not_installed", command=command, files_examined=files_examined,
                      note=INSTALL_HINTS[name])
    version = tool_version(name)
    rc, stdout, err, error = run(cmd, cwd=target)
    if error or crashed(rc):
        return record(name, "failed_to_run", version=version, command=command, exit_code=rc,
                      files_examined=files_examined, note=(error or err)[:STDERR_CHARS])
    try:
        json.loads(stdout)
    except ValueError:
        return record(name, "failed_to_run", version=version, command=command, exit_code=rc,
                      files_examined=files_examined,
                      note=("output was not JSON: " + (err or stdout))[:STDERR_CHARS])
    with open(os.path.join(out, name + ".json"), "w") as f:
        f.write(stdout)
    return record(name, "ran", version=version, command=command, exit_code=rc,
                  output_file=name + ".json", files_examined=files_examined)


def check_semgrep(target, out):
    n = count_files(target)
    if not n:
        return record("semgrep", "skipped", version=tool_version("semgrep"),
                      command=" ".join(SEMGREP + ["."]), note=NO_FILES)
    return _run_json_tool("semgrep", SEMGREP + ["."], target, out, n, lambda rc: rc >= 2)


def check_bandit(target, out):
    cmd = [a if a != "<dir>" else "." for a in BANDIT]
    n = len(find_py_files(target))
    if not n:
        return record("bandit", "skipped", version=tool_version("bandit"), command=" ".join(cmd),
                      note=NO_FILES)
    return _run_json_tool("bandit", cmd, target, out, n, lambda rc: rc >= 2)


def check_trivy(target, out):
    cmd = TRIVY + ["."]
    n = len(find_manifests(target))
    if not n:
        return record("trivy", "skipped", version=tool_version("trivy"), command=" ".join(cmd),
                      note=NO_FILES)
    return _run_json_tool("trivy", cmd, target, out, n, lambda rc: rc != 0)


def check_catalog(args):
    # Placeholder: catalog reads land in a later PR; --catalog is accepted and ignored.
    return record("catalog", "skipped", note="catalog reads land in a later PR")


def _prepare_out(out):
    os.makedirs(out, exist_ok=True)
    for name in os.listdir(out):
        if name.endswith(".json"):
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

    _write_json(out, "summary.json", {
        "schema": SCHEMA,
        "target": target,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "checks": checks,
    })
    for c in checks:
        print("%-10s %s%s" % (c["name"], c["status"], " (%s)" % c["note"] if c["note"] else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
