#!/usr/bin/env python3
"""Pre-review facts: run the static-analysis tools and the shell syntax check
before the model, so that they run and are recorded on every review rather
than when the model chooses to run them, and write the results as JSON.

    references/run-pre-review.sh <target-dir> <out-dir> [--catalog URL] [--no-catalog]

Exit 0 whenever the script ran to completion, whatever the tools found; exit 2
only when <target-dir> is missing, references/readme-placeholders.txt cannot
be read, or the arguments do not parse. A tool that
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
                 bandit test_id, trivy VulnerabilityID / ID. The shellcheck
                 record adds artifact_count: its findings that tool_artifact
                 calls artefacts of linting OOD's job-script files one at a
                 time.
  syntax.json    one entry per shell file (*.sh, *.bash, *.sh.erb): path
                 (repo-relative), stripped (ERB tags removed first), ok
                 (bash -n passed), stderr (first 500 chars). Written even
                 when there is no bash, with every file ok false and the
                 reason in stderr. Under a bash older than 4 a failure's
                 stderr starts "bash <ver> rejected this file (may be valid
                 on bash >= 4): ". erb_control_line (int or null): for a
                 .sh.erb that failed, the line of the nearest ERB control
                 tag (if, elsif, else, unless, end, case, when, a do or {
                 block, ...) within ERB_CONTROL_WINDOW (3) lines of the line
                 bash reported; stripping both branches of a conditional
                 can leave an orphan (a stray `|& tee` after an if/else
                 whose branches each end in a line continuation), so such
                 a failure may be an artefact of stripping. null otherwise.
  shellcheck.json  shellcheck's objects concatenated across files, "file" set
                 to the repo-relative source path (.sh.erb scanned stripped).
  semgrep.json, bandit.json, trivy.json  the tool's own JSON, verbatim.
  stripped/<path>.sh  the ERB-stripped copy of each .sh.erb, for inspection.
  trivy-empty.yaml, trivy-empty.ignore  empty files passed to trivy as its
                 --config and --ignorefile.
  tool-table.md  the Check tiers line and the Tool / Status / Result table,
                 rendered from summary.json for the security skill to paste
                 (shellcheck with artefacts: "N findings (codes), M of them
                 linted in isolation from the job-script family").
  apps.json      [{app_id, path, app_type, readme}]: the app shape, resolved
                 as target-setup.md section 3 does. A root appverse.yml with
                 an apps: list is a monorepo, one app per apps[].path (app_id
                 its normalised subpath, e.g. apps/good-app, made unique);
                 otherwise one app, app_id "root", path ".". app_type is
                 batch_connect |
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
                 [{line, text, phrase}] (lines outside code fences
                 containing a phrase from readme-placeholders.txt,
                 case-insensitive), screenshots
                 [{line, alt, target}] (image links outside code fences;
                 badge images excluded), env_vars [{line, text, match}]
                 (match heading | assignment ([A-Z_]{3,}=) | phrase
                 ("environment variable")), rungs {what it launches,
                 prerequisites, installation, configuration, known
                 limitations, troubleshooting, screenshots, environment
                 variables, info panel, architecture: {heading, line,
                 placeholder, match} or null}, stub, content_line_count,
                 content_chars, baseline_rating}.
                 baseline_rating is the Documentation rating these facts
                 support (readme_lines.baseline_rating): the highest rung
                 whose requirements, and every lower rung's, are met by a
                 non-placeholder rungs entry (screenshots: or a screenshots
                 entry; environment variables: or an env_vars assignment or
                 phrase), else "Below minimal". The quality skill starts
                 from it and may lower it only with a stated reason;
                 check-rating.py enforces both directions.
                 A rung is the first heading whose
                 words contain one of its synonyms (RUNGS); one heading can
                 satisfy several rungs; placeholder is true when
                 the heading or every content line of its section (to the
                 next heading of the same or a higher level; HTML comments
                 and fence markers are not content) is a placeholder line.
                 Headings inside code fences or HTML comments are ignored.
                 match is "heading", except that with no Overview-type
                 heading, the first descriptive paragraph (four or more
                 words; not a list, quote, table, image, badge, HTML or
                 placeholder line) between the H1 and the next heading
                 fills "what it launches" as {heading: the H1, line: the
                 paragraph's, placeholder: false, match: "intro"}.
                 content_line_count counts content lines: not blank, a
                 heading, in a fence or HTML comment, a placeholder line, a
                 contact line (contains '@' or starts with Contact), a
                 badge/image line (starts with '![' or '[!['), or a table's
                 header or |---| row (readme_line_kinds). content_chars
                 sums those lines' stripped lengths. stub is true when
                 content_chars is under STUB_CONTENT_CHARS (100: broken-app
                 has 0, every other fixture README 176 or more; characters,
                 so re-wrapping a paragraph moves it only by the spaces at
                 its line breaks), or when every heading whose own body (to
                 the next heading) holds a content or placeholder line is placeholder text and
                 no content line precedes the first heading. It is the
                 one stub decision: STR-01 reads it, and check-rating.py
                 accepts the stub rating line only against it.
  <app_id>/form.json  {file (form.yml, else form.yml.erb, ERB stripped),
                 submit_file, erb_sentinel ("ERBVALUE": a min, max or
                 pattern computed by a <%= %> tag is recorded as that
                 string, so a non-null bound is a bound even when its value
                 is not known), error (the YAML parse error, else null),
                 attributes [{name, widget, min, max, pattern, required,
                 line, defined, in_form, interpolated_in_submit,
                 submit_lines, reaches_scheduler}]}: every attributes: key,
                 then every form: name not defined there (line is the form:
                 item's). interpolated_in_submit: the name appears in an
                 ERB tag in submit.yml.erb, at submit_lines;
                 reaches_scheduler: its value reaches a <%= %> tag under
                 script.* or batch_connect.template, directly, through a
                 variable assigned from it in a <% %> tag (statements split
                 on newlines and ;), or through a block parameter over it
                 (x.split.each do |opt|). A reference is the bare name,
                 context.<name> or @<name>. min, max, pattern and required
                 fall back to the attribute's html_options (whether OOD
                 renders html_options min/max as bounds is unverified).
                 PyYAML is used when importable, else a built-in subset
                 parser; the form record's note says which. The subset
                 parser refuses (as a parse error) anchors, aliases, tags,
                 merge keys and a second document, which it cannot read
                 correctly.

  <app_id>/template.json  (Batch Connect and unknown app types) {dir,
                 files (every file under template/ that was scanned),
                 icons [{file, line, name, kind}] (Icon= in a .desktop, a
                 button-icon property in xfce4-panel.xml: value attribute in
                 either order, else its <value> element; read from the raw
                 text, so an ERB name stays as written; kind desktop |
                 xfce4-panel), absolute_paths [{file, line, text}]
                 (SITE_PATH: /scratch, /project(s), /home, /opt, /usr/local,
                 /usr/share, /appl, /apps, /sw, /software, /data, /work after
                 a line start, space, quote, = or :; sought in the stripped
                 and the raw text, so a path inside an ERB tag counts; one
                 per (line, text)), numeric_literals [{file, line, value}]
                 (shell files only: bare integers and hex, except 0, 1,
                 ports 22/80/443, array indices, sleep's argument, exit
                 statuses, kill -N, chmod/umask modes, $? comparisons,
                 redirect fds, decimals and dotted versions, path parts,
                 hex colours, and any literal on a line with a # comment or
                 after one), hex_colors [{file, line, value}] (#rrggbb in
                 any file), commented_code [{file, line, count}] (shell
                 files only: a run of consecutive #-lines, count its length,
                 with three or more non-blank comment lines, at least one
                 reading as shell (an assignment, $, |, <, >, ;, &&, a
                 backtick, or a first word in SHELL_WORDS), whose text with
                 the # removed passes bash -n; a block bash rejects is not
                 code, so under bash < 4 a block in bash 4 syntax is not
                 reported and the record's note says so), skipped_files
                 [{file, reason}] (refused under the shell-file rule, or
                 binary)}. .erb files are ERB-stripped first, so a literal
                 inside a tag is not seen. Candidates only; every file is
                 repo-relative (with the app subpath).
  <app_id>/entry_point.json  (Passenger and companion) {file (config.ru, else
                 passenger_wsgi.py, else app.js), language (ruby | python |
                 node), parses (true | false | "not_checked" when ruby /
                 node is not on PATH; Python is checked in process with
                 compile(), so no .pyc lands in the target), error (starts
                 with the interpreter and version; paths repo-relative),
                 dependency_manifest (Gemfile; requirements.txt,
                 pyproject.toml, Pipfile, setup.py; package.json; or
                 null), consistent (Python: every third-party import in the
                 app's .py files, except setup.py, tests/ and test_*.py,
                 with stdlib and local modules (src/ layout included)
                 excluded, is named in requirements.txt, with IMPORT_DIST
                 for names that differ; null when not judged: Ruby, Node,
                 another Python manifest), note}.
  <app_id>/security.json  (every app type) the candidate sites the
                 security skill must answer (security-tools.md, "Candidate
                 enumeration"): {counts {kind: n} for every kind in
                 SEC_KINDS order, scope (batch_connect: submit / form /
                 connection files, template/**, Dockerfile / Containerfile
                 / *.def anywhere in the app; all_source for any other type:
                 every file but docs, licences, images, fonts, lock files and
                 test code), plus the root appverse.yml's shared_paths),
                 files (scanned), attributes (form attribute names, from
                 form.json's reading, else the form file's line scan),
                 candidates [{kind, check, rule, tag, file, line, text,
                 note}] sorted by file, line and kind (interpolation adds
                 attributes, guarded (sanitised or validated),
                 presence_checked, quoted), skipped_files [{file,
                 reason}]}. Comment lines are never candidates; text is the
                 trimmed source line, at most 200 chars. A binary under
                 template/ is a binary_in_template candidate at line 1
                 unless its magic bytes say image or font AND its extension
                 agrees (then skipped); elsewhere it is skipped. One
                 candidate per (file, line,
                 kind, tag). tool_finding candidates (one per tool, code and
                 file, from shellcheck.json / semgrep.json / bandit.json;
                 _tool_finding_candidates) add tool, code, lines (at most
                 TOOL_LINES_CAP; lines_total when cut), level and artifact;
                 over TOOL_FINDING_CEILING of them collapse to one per tool
                 and code (file null, lines "file:line", and counts
                 tool_finding_collapsed true). tool_notes lists a tool file
                 that could not be read or items that were skipped. The
                 record's note gives each app's non-zero counts ("root:
                 interpolation 7, config_flag 2", or "no candidates"), then
                 the collapse as a sentence and the tool_notes.

summary.json also carries "facts": one record per fact scanner (readme,
form, template, entry_point, security), with the record fields above plus
per_app {app_id: status}. An app's status is ran, skipped (no README / no
form file for a batch_connect or unknown app / no template/ / no entry
point / no in-scope file / path not read), not_applicable (form or template
for a Passenger, companion or widget app; entry_point for any app but
Passenger or companion) or failed_to_run (form did not parse; the error is in the note
and in form.json); a README, form, submit, template or entry-point file is
read only under the shell-file rule (a regular file, or a symlink resolving
to one inside the target; at most 1 MB), else the app is skipped with the
reason in the note. The record's status is failed_to_run if any app's is,
else ran if any app's is, else not_applicable if every app's is, else
skipped. A fact file is absent when its app was skipped or not_applicable.

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
import posixpath
import re
import shutil
import stat
import subprocess
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from readme_lines import (  # noqa: E402,F401  (re-exported for check-evidence and tests)
    PlaceholdersMissing, CONTACT_LINE, PLACEHOLDERS_FILE, _markdown_lines, _read, _readme_parse, load_placeholders, readme_line_kinds,
    baseline_rating,
)
import catalog_facts  # noqa: E402

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
# A bash -n failure in an ERB-stripped file this many lines or fewer from a
# stripped ERB control tag may be an orphan the stripping left (both branches
# of an if/else stripped together), not an error in any rendered template.
# 3 covers the orphan on the line after an <% end %> and a continued command
# or blank lines between; further away the tag cannot be the cause.
ERB_CONTROL_WINDOW = 3
ERB_CODE_TAG = re.compile(r"<%(?![%=#])-?(.*?)-?%>", re.S)
ERB_CONTROL = re.compile(
    r"^\s*(if|elsif|else|unless|end|case|when|while|until|for|begin|rescue|ensure)\b"
    r"|\bdo\s*(\|[^|]*\|)?\s*$|\{\s*(\|[^|]*\|)?\s*$|^\s*\}", re.S)
BASH_LINE = re.compile(r": line (\d+):")
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
    target (not into its .git, see _inside); rejected maps every other entry
    (a symlink leading outside or nowhere, a FIFO, a device) to the reason it
    was not read."""
    exclude_real = os.path.realpath(exclude) if exclude else None
    files, rejected = [], {}
    for root, dirs, names in os.walk(target):
        # .git in any case: a case-insensitive filesystem lists .GIT as is.
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS and d.casefold() != ".git"
                   and os.path.realpath(os.path.join(root, d)) != exclude_real]
        for name in names:
            full = os.path.join(root, name)
            rel = os.path.relpath(full, target).replace(os.sep, "/")
            mode = os.lstat(full).st_mode
            if stat.S_ISLNK(mode):
                real = os.path.realpath(full)
                if not os.path.exists(real):
                    rejected[rel] = DANGLING
                elif not _inside(target, real):
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
    """(finding_count, codes, note) from a tool's parsed JSON. A wrong-shape
    JSON document (a tool version change, a mock, or a corrupted run) gets
    a note instead of a crash: a shellcheck item with no `code` is skipped
    rather than counted as the literal string 'SCNone'; a `results` object
    that is not a list (semgrep/bandit) or a `data` that is not a dict
    (semgrep/bandit's own .get call) is treated as empty."""
    if name == "shellcheck":
        if not isinstance(data, list):
            return 0, [], "shellcheck JSON was not a list"
        codes = [i.get("code") for i in data if isinstance(i, dict) and i.get("code") is not None]
        return len(data), ["SC%s" % c for c in codes], ""
    if name in ("semgrep", "bandit"):
        key = "check_id" if name == "semgrep" else "test_id"
        if not isinstance(data, dict):
            return 0, [], "%s JSON was not an object" % name
        results = data.get("results")
        if results is None:
            results = []
        elif not isinstance(results, list):
            return 0, [], "%s results was not a list" % name
        results = [r for r in results if isinstance(r, dict)]
        return len(results), [str(r.get(key)) for r in results], ""
    codes = []  # trivy
    if not isinstance(data, dict):
        return 0, [], "trivy JSON was not an object"
    for res in data.get("Results") or []:
        if not isinstance(res, dict):
            continue
        for kind, key in (("Vulnerabilities", "VulnerabilityID"),
                          ("Misconfigurations", "ID"), ("Secrets", "ID")):
            codes.extend(str(i.get(key) or i.get("ID") or i.get("RuleID") or "")
                         for i in res.get(kind) or [] if isinstance(i, dict))
    return len(codes), codes, ""


def _with_findings(rec, data):
    count, codes, note = _findings(rec["name"], data)
    rec["finding_count"], rec["top_codes"] = count, most_frequent(codes)
    if note:
        rec["note"] = "; ".join(x for x in (rec["note"], note) if x)
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


def erb_control_lines(text):
    """Line numbers (1-based) spanned by ERB control tags in text: a <% %>
    (not <%= or <%#) whose code opens, continues or closes a block."""
    text = text.replace("<%%", ERB_LITERAL)
    lines = set()
    for m in ERB_CODE_TAG.finditer(text):
        if ERB_CONTROL.search(m.group(1).strip()):
            first = text.count("\n", 0, m.start()) + 1
            lines.update(range(first, first + m.group(0).count("\n") + 1))
    return lines


def near_erb_control(stderr, control_lines):
    """The control-tag line nearest the first `line N` in a bash -n stderr,
    when it is within ERB_CONTROL_WINDOW lines; else None."""
    m = BASH_LINE.search(stderr or "")
    if not m or not control_lines:
        return None
    n = int(m.group(1))
    best = min(control_lines, key=lambda c: (abs(c - n), c))
    return best if abs(best - n) <= ERB_CONTROL_WINDOW else None


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
        for e in entries:
            e.setdefault("erb_control_line", None)
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
        control = None
        if stripped and not ok and not error:
            with open(os.path.join(target, rel), encoding="utf-8", errors="surrogateescape") as f:
                control = near_erb_control(stderr, erb_control_lines(f.read()))
        entries.append({"path": rel, "stripped": stripped, "ok": ok,
                        "stderr": stderr[:STDERR_CHARS], "erb_control_line": control,
                        "_scan": scan})
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
    results, worst, unread, malformed = [], 0, [], 0
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
        if not isinstance(items, list):
            malformed += 1
            continue
        for item in items:
            if not isinstance(item, dict):
                malformed += 1
                continue
            item["file"] = rel
            results.append(item)
    _write_json(out, "shellcheck.json", results)
    n_stripped = sum(1 for f in files if f.endswith(".sh.erb") and f not in unread)
    notes = []
    if n_stripped:
        notes.append("%d .sh.erb file(s) scanned ERB-stripped" % n_stripped)
    if unread:
        notes.append("not scanned (unreadable): " + ", ".join(unread))
    if large:
        notes.append("not scanned (larger than 1 MB): " + ", ".join(large))
    if malformed:
        notes.append("%d shellcheck finding(s) skipped (malformed JSON shape)" % malformed)
    rec = record("shellcheck", "ran", version=version, command=command, exit_code=worst,
                 output_file="shellcheck.json", files_examined=len(files) - len(unread),
                 note="; ".join(notes))
    cache = {}
    rec = _with_findings(rec, results)
    rec["artifact_count"] = sum(1 for it in results if tool_artifact(
        target, it.get("file"), "SC%s" % it.get("code"), it.get("message"), cache))
    return rec


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

RUNGS = (
    ("what it launches", ("overview", "about", "description")),
    ("prerequisites", ("requirements", "requirement", "prerequisites", "prerequisite", "dependencies",
                       "defaults", "getting started")),
    ("installation", ("install", "installation", "installing", "setup", "set up", "deploy",
                      "deployment", "deploying")),
    ("configuration", ("configuration", "configure", "configuring", "customize", "customization",
                       "customizing")),
    ("known limitations", ("known limitations", "limitations", "caveats", "known issues")),
    ("troubleshooting", ("troubleshooting", "faq", "common problems")),
    ("screenshots", ("screenshots", "screenshot")),
    ("environment variables", ("environment variables", "environment variable", "environment")),
    ("info panel", ("info panel",)),
    ("architecture", ("architecture", "how it works")),
)
# readme.json "stub": fewer content characters than this (the sum of the
# stripped lengths of the lines readme_line_kinds calls "content"), or every
# section body placeholder text. Characters, not lines, so the verdict does
# not change when a paragraph is hard-wrapped or joined onto one line.
# broken-app (a title and a contact line) has 0 and must be a stub; every
# other fixture README has 176 or more and must not.
STUB_CONTENT_CHARS = 100
APP_TYPES = {"batch-connect-basic": "batch_connect", "batch-connect-vnc": "batch_connect",
             "batch_connect": "batch_connect", "batch-connect": "batch_connect",
             "passenger_app": "passenger", "passenger": "passenger",
             "companion_app": "companion", "companion": "companion",
             "widget": "widget", "dashboard": "widget"}
PASSENGER_ENTRY = ("config.ru", "passenger_wsgi.py", "app.js")
RESERVED_IDS = {"stripped", "root"}
OUTSIDE_APP = "app path outside target, not read"


def _skip_note(app):
    """"<app_id>: <reason>", with the declared path in parentheses when it
    differs from the id (an outside-target app's id is sanitised)."""
    if app.get("path") not in (None, app["app_id"]):
        return "%s (%s): %s" % (app["app_id"], app["path"], app["_skip"])
    return "%s: %s" % (app["app_id"], app["_skip"])
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


def _safe_no_alias_loader(yaml):
    """A yaml.SafeLoader subclass that refuses anchors, aliases, explicit
    tags and merge keys with the same wording _SubsetYaml uses for the same
    refusals, instead of expanding them (an alias bomb: nested anchored
    aliases like &a [*b,*b,...] re-used under min: *h can blow up to
    gigabytes in memory before any construction step sees it)."""

    class _NoAliasSafeLoader(yaml.SafeLoader):
        def compose_node(self, parent, index):
            if self.check_event(yaml.events.AliasEvent):
                event = self.peek_event()
                raise YamlError("line %d, column %d: aliases (*) are not supported"
                                % (event.start_mark.line + 1, event.start_mark.column + 1))
            event = self.peek_event()
            if event.anchor is not None:
                raise YamlError("line %d, column %d: anchors (&) are not supported"
                                % (event.start_mark.line + 1, event.start_mark.column + 1))
            if event.tag is not None:
                raise YamlError("line %d, column %d: tags (!) are not supported"
                                % (event.start_mark.line + 1, event.start_mark.column + 1))
            return super(_NoAliasSafeLoader, self).compose_node(parent, index)

        def flatten_mapping(self, node):
            for key_node, _ in node.value:
                if key_node.tag == "tag:yaml.org,2002:merge":
                    raise YamlError("line %d, column %d: merge keys (<<) are not supported"
                                    % (key_node.start_mark.line + 1, key_node.start_mark.column + 1))
            return super(_NoAliasSafeLoader, self).flatten_mapping(node)

    return _NoAliasSafeLoader


def load_yaml(text, name):
    """Parse YAML with PyYAML when importable, else the built-in subset parser.
    Raises YamlError whose message names the file, line and column. Under
    PyYAML, anchors, aliases, explicit tags and merge keys are refused before
    any node is composed (see _safe_no_alias_loader), matching what the
    subset parser refuses and its wording, so a crafted alias bomb cannot
    expand in memory."""
    yaml = _yaml_module()
    if yaml is None:
        return _SubsetYaml(text).parse()
    try:
        return yaml.load(text, Loader=_safe_no_alias_loader(yaml))
    except YamlError:
        raise
    except yaml.YAMLError as e:
        raise YamlError(" ".join(str(e).replace('"<unicode string>"', name).split()))


class _SubsetYaml:
    """Block mappings and sequences, plain/quoted scalars, single- or
    multi-line flow collections, | and > block scalars, comments, a leading
    ---. Enough for form.yml, appverse.yml and manifest.yml; anything else
    raises YamlError('line N, column M: ...'). Duplicate keys: last wins."""

    def __init__(self, text):
        self.lines = []  # (lineno, indent, content)
        for n, line in enumerate(text.splitlines(), 1):
            body = self._strip_comment(line).rstrip()
            if body.strip() == "---" or body.startswith("--- "):
                if self.lines:
                    raise YamlError("line %d, column 1: a second YAML document is not supported" % n)
                continue
            if not body.strip() or body.strip() == "...":
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
            if key == "<<":
                raise YamlError("line %d, column %d: merge keys (<<) are not supported" % (n, ind + 1))
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

    @staticmethod
    def _unsupported(text, n, col):
        if text and text[0] in "&*!":
            what = {"&": "anchors (&)", "*": "aliases (*)", "!": "tags (!)"}[text[0]]
            raise YamlError("line %d, column %d: %s are not supported" % (n, col + 1, what))

    def _value(self, rest, n, col, indent):
        rest = rest.strip()
        self._unsupported(rest, n, col)
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
                    if k == "<<":
                        err("merge keys (<<) are not supported")
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

    @classmethod
    def _scalar(cls, text, n, col):
        cls._unsupported(text, n, col)
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


class Refused(Exception):
    """A fact file that is not read: the message says which and why."""


def _refusal(target, path):
    """Why a fact file is not read (the shell-file walk's rule: a regular
    file, or a symlink resolving to one inside the target; at most 1 MB),
    or None when it may be read."""
    mode = os.lstat(path).st_mode
    if stat.S_ISLNK(mode):
        real = os.path.realpath(path)
        if not os.path.exists(real):
            return DANGLING
        if not _inside(target, real):
            return OUTSIDE
        if not os.path.isfile(real):
            return NOT_REGULAR
    elif not stat.S_ISREG(mode):
        return NOT_REGULAR
    if os.path.getsize(path) > MAX_SHELL_BYTES:
        return TOO_LARGE
    return None


def _read_fact(target, path, rel):
    """The text of a fact file, or Refused("<rel>: <reason>")."""
    why = _refusal(target, path)
    if why:
        raise Refused("%s: %s" % (rel, why))
    return _read(path)


def _inside(target, path):
    """Whether path resolves inside target and not into a .git directory,
    which is never part of what is reviewed and holds a clone's config (a
    symlink to .git/config would otherwise put the config, and any
    credential in it, into the stripped copies). Any component of the
    resolved path that casefolds to .git counts: the target's own .git, a
    nested or submodule one, and one spelt .GIT, which a case-insensitive
    filesystem (macOS) resolves to the same directory. Such a path is
    refused as OUTSIDE."""
    root_real = os.path.realpath(target)
    real = os.path.realpath(path)
    if os.path.commonpath([real, root_real]) != root_real:
        return False
    rel = os.path.relpath(real, root_real)
    return not any(part.casefold() == ".git" for part in rel.split(os.sep))


def _load_file(target, path, rel):
    """Parsed YAML of a file, or None when it is absent, refused, or does not
    parse."""
    if not os.path.lexists(path):
        return None
    try:
        data = load_yaml(_read_fact(target, path, rel), rel)
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
                not os.path.isdir(os.path.join(app_dir, name)):
            return name
    return None


def _app_id(path, taken):
    """A monorepo app's app_id is its normalised subpath itself (finding-codes.md:
    apps/good-app, not the basename good-app), so the per-app fact directory
    <out>/<app_id>/ nests under <out>/apps/. A subpath that collides with a
    reserved name (RESERVED_IDS) or an already-taken id, or is "." or "root"
    handled elsewhere, falls back to a dash-sanitised form, then a numbered
    suffix."""
    base = path.strip("/") or "app"
    app_id = base
    if app_id in RESERVED_IDS or app_id in taken:
        app_id = re.sub(r"[^A-Za-z0-9._/-]", "-", base).strip(".-") or "app"
    k = 2
    while app_id in RESERVED_IDS or app_id in taken:
        app_id, k = "%s-%d" % (base, k), k + 1
    return app_id


def resolve_apps(target):
    """App shape as target-setup.md section 3: a root appverse.yml with an
    apps: list is a monorepo (each apps[].path an app, id its normalised
    subpath, e.g. apps/good-app, per finding-codes.md); otherwise the repo is
    one app, id "root", path ".".

    Returns a list of {app_id, path, app_type, readme, _dir, _skip}: readme
    is the repo-relative README (a monorepo app without its own falls back to
    the root README), _dir the absolute app directory, _skip why the app is
    not read (outside the target, or missing) or None. The monorepo app_type
    precedence is the inline apps[] entry, then <path>/appverse.yml, then
    <path>/manifest.yml role, then entry-point files."""
    root_meta = _load_file(target, os.path.join(target, "appverse.yml"), "appverse.yml") or {}
    root_readme = _find_readme(target)
    apps_decl = root_meta.get("apps")
    if not isinstance(apps_decl, list) or not apps_decl:
        manifest = _load_file(target, os.path.join(target, "manifest.yml"), "manifest.yml") or {}
        return [{"app_id": "root", "path": ".",
                 "app_type": _app_type([root_meta.get("app_type"), manifest.get("role")], target),
                 "readme": root_readme, "_dir": target, "_skip": None}]
    apps, taken = [], set()
    for entry in apps_decl:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str) or not entry["path"].strip():
            continue
        path = os.path.normpath(entry["path"].strip()).replace(os.sep, "/")
        full = os.path.join(target, path)
        skip = None
        if os.path.isabs(path) or not _inside(target, full):
            skip = OUTSIDE_APP
        elif not os.path.isdir(full):
            skip = MISSING_APP
        if skip == OUTSIDE_APP:
            # never an id with ".." or a leading "/": nothing joins it to a directory, but it is still an id
            app_id = _app_id(re.sub(r"[^A-Za-z0-9._-]", "-", path).strip(".-") or "app", taken)
        else:
            app_id = "root" if path == "." and "root" not in taken else _app_id(path, taken)
        taken.add(app_id)
        if skip:
            apps.append({"app_id": app_id, "path": path, "app_type": "unknown", "readme": None,
                         "_dir": None, "_skip": skip})
            continue
        sub = _load_file(target, os.path.join(full, "appverse.yml"), path + "/appverse.yml") or {}
        manifest = _load_file(target, os.path.join(full, "manifest.yml"), path + "/manifest.yml") or {}
        own = _find_readme(full)
        apps.append({"app_id": app_id, "path": path,
                     "app_type": _app_type([entry.get("app_type"), sub.get("app_type"),
                                            manifest.get("role")], full),
                     "readme": (own if path == "." else path + "/" + own) if own else root_readme,
                     "_dir": full, "_skip": None})
    return apps


def _public(app):
    return {k: v for k, v in app.items() if not k.startswith("_")}


def _norm_heading(text):
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"[`*_]", "", text).lower()
    return " ".join(re.findall(r"[a-z0-9]+", text))


def _rungs_for(text):
    """Every rung a heading satisfies ("Requirements and Setup" is both
    prerequisites and installation)."""
    words = " " + _norm_heading(text) + " "
    return [rung for rung, synonyms in RUNGS if any(" " + s + " " in words for s in synonyms)]


def _stub(headings, kinds, lines, phrase_of):
    """(stub, content_line_count, content_chars): stub when the content
    lines hold fewer than STUB_CONTENT_CHARS characters (each line's
    stripped length, summed), or when every heading whose own body (to the
    next heading of any level) holds a content or placeholder line is
    placeholder text (its heading text carries a phrase, or its body lines
    are all placeholder lines) and the preamble (the lines before the first
    heading) holds no content line either: real prose above the first
    heading counts, so a README with real text there and placeholder
    sections is not a stub."""
    count = kinds.count("content")
    chars = sum(len(lines[i].strip()) for i, k in enumerate(kinds) if k == "content")
    short = chars < STUB_CONTENT_CHARS
    first = headings[0]["line"] if headings else len(kinds) + 1
    if "content" in kinds[:first - 1]:
        return short, count, chars
    bodies = []
    for idx, h in enumerate(headings):
        end = headings[idx + 1]["line"] if idx + 1 < len(headings) else len(kinds) + 1
        body = [kinds[n - 1] for n in range(h["line"] + 1, end) if kinds[n - 1] in ("content", "placeholder")]
        if body:
            bodies.append(bool(phrase_of(h["text"])) or "content" not in body)
    return short or (bool(bodies) and all(bodies)), count, chars


def scan_readme(text, placeholders):
    """readme.json for one README's text (file set by the caller)."""
    parsed = _readme_parse(text, placeholders)
    lines, flags, headings, heading_lines, underlines, table_rules, placeholder_rows, phrase_of = parsed
    placeholder_lines = {r["line"] for r in placeholder_rows}
    stub, content_line_count, content_chars = _stub(headings, readme_line_kinds(text, placeholders, parsed),
                                                    lines, phrase_of)

    rungs = dict((r, None) for r, _ in RUNGS)
    for idx, h in enumerate(headings):
        # The README's title (its first heading, at level 1) names the app,
        # not a section: "# Custom Conda Environment" is no Environment
        # variables section.
        if idx == 0 and h["level"] == 1:
            continue
        todo = [r for r in _rungs_for(h["text"]) if rungs[r] is None]
        if not todo:
            continue
        end = next((g["line"] for g in headings[idx + 1:] if g["level"] <= h["level"]), len(lines) + 1)
        content = [n for n in range(h["line"] + 1, end)
                   if lines[n - 1].strip() and not flags[n - 1][1] and n not in heading_lines
                   and n not in underlines and n not in table_rules
                   and not re.match(r"^ {0,3}(`{3,}|~{3,})", lines[n - 1])]
        placeholder = bool(phrase_of(h["text"])) or all(n in placeholder_lines for n in content)
        for rung in todo:
            rungs[rung] = {"heading": h["text"], "line": h["line"], "placeholder": placeholder,
                           "match": "heading"}
    # No Overview-type heading: a descriptive paragraph directly under the H1,
    # before the next heading, says what the app launches.
    h1 = next((h for h in headings if h["level"] == 1), None)
    if rungs["what it launches"] is None and h1:
        end = next((g["line"] for g in headings if g["line"] > h1["line"]), len(lines) + 1)
        for n in range(h1["line"] + 1, end):
            text_ = lines[n - 1].strip()
            if not text_ or any(flags[n - 1]) or n in underlines or n in placeholder_lines:
                continue
            if re.match(r"^(?:[-*+] |\d+[.)] |>|\||!\[|\[!\[|<|`{3,}|~{3,})", text_):
                continue
            if len(re.findall(r"[A-Za-z]{2,}", text_)) >= 4:
                rungs["what it launches"] = {"heading": h1["text"], "line": n, "placeholder": False,
                                             "match": "intro"}
                break

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
            if "environment variables" in _rungs_for(next(h["text"] for h in headings
                                                           if h["line"] == i + 1)):
                env_vars.append({"line": i + 1, "text": line.strip(), "match": "heading"})
            continue
        if re.search(r"[A-Z_]{3,}=", line):
            env_vars.append({"line": i + 1, "text": line.strip(), "match": "assignment"})
        elif "environment variable" in line.lower():
            env_vars.append({"line": i + 1, "text": line.strip(), "match": "phrase"})

    facts = {"headings": headings, "placeholders": placeholder_rows, "screenshots": screenshots,
             "env_vars": env_vars, "rungs": rungs, "stub": stub,
             "content_line_count": content_line_count, "content_chars": content_chars}
    facts["baseline_rating"] = baseline_rating(facts)
    return facts


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


ERB_TAG = re.compile(r"<%(?!%)(#|=|-)?(.*?)-?%>", re.S)
ASSIGN_STMT = re.compile(r"^\s*@?([a-z_]\w*)\s*(?:\|\||\+|-|\*)?=(?!=|~)(.*)$")
BLOCK_STMT = re.compile(r"^(.*?)(?:\bdo|\{)\s*\|([^|]*)\|")


def _erb_tags(text):
    """[(kind, start line, body, offset)] for every ERB tag but comments:
    kind "out" for <%= %>, "code" for <% %> and <%- %>."""
    tags = []
    for m in ERB_TAG.finditer(text):
        if m.group(1) == "#":
            continue
        tags.append(("out" if m.group(1) == "=" else "code", text.count("\n", 0, m.start()) + 1,
                     m.group(2), m.start()))
    return tags


def _ref_word(name):
    """A reference to name in Ruby: the bare name, context.<name> or @<name>."""
    return re.compile(r"(?:(?<![\w@$.])|(?<=\bcontext\.)|(?<=(?<![\w@])@))%s(?![\w?!])" % re.escape(name))


def _erb_taint(tags, names):
    """{variable: attributes it carries}: each name carries itself; a
    variable assigned in a <% %> tag (statements split on newlines and ;)
    carries what its right-hand side references; a block parameter
    (x.each do |v| / { |v| ) carries what the receiver references."""
    taint = {n: {n} for n in names}
    changed = True
    while changed:
        changed = False
        for kind, _, body, _ in tags:
            if kind != "code":
                continue
            for stmt in re.split(r"[\n;]", body):
                m = ASSIGN_STMT.match(stmt)
                b = None if m else BLOCK_STMT.match(stmt)
                if m:
                    targets, source = [m.group(1)], m.group(2)
                elif b:
                    targets = [t.strip(" *&()") for t in b.group(2).split(",")]
                    source = b.group(1)
                else:
                    continue
                carried = set()
                for var, srcs in list(taint.items()):
                    if _ref_word(var).search(source):
                        carried |= srcs
                for t in targets:
                    old = taint.get(t, set())
                    if t and not carried <= old:
                        taint[t] = old | carried
                        changed = True
    return taint


def _submit_refs(text, names):
    """{name: (lines, reaches_scheduler)} for a submit.yml.erb text: the lines
    where the name appears inside an ERB tag, and whether its value reaches
    script.* or batch_connect.template through a <%= %> tag (directly, or
    through a variable assigned from it, or a block parameter over it, in a
    <% %> tag)."""
    paths = _yaml_paths(strip_erb(text).splitlines())
    tags = _erb_tags(text)
    taint = _erb_taint(tags, names)
    out = {}
    for n in names:
        lines, reaches = [], False
        pat = _ref_word(n)
        for kind, start, body, _ in tags:
            for k, seg in enumerate(body.split("\n")):
                if pat.search(seg):
                    lines.append(start + k)
            if kind == "out" and not reaches:
                vars_ = [v for v, srcs in taint.items() if n in srcs]
                if any(_ref_word(v).search(body) for v in vars_):
                    path = paths[start - 1] if start - 1 < len(paths) else []
                    reaches = path[:1] == ["script"] or path[:2] == ["batch_connect", "template"]
        out[n] = (sorted(set(lines)), reaches)
    return out


def _num(value):
    """min/max as written: a number or string kept, anything else as text."""
    if value is None or (isinstance(value, (int, float, str)) and not isinstance(value, bool)):
        return value
    return str(value)


def scan_form(target, app_dir):
    """form.json for one app directory, or None when it has no form file. A
    parse failure is returned as {"error": ...}; a form or submit file that
    may not be read (symlink out of the target, not regular, over 1 MB)
    raises Refused."""
    present = lambda f: os.path.lexists(os.path.join(app_dir, f))
    rel = next((f for f in ("form.yml", "form.yml.erb") if present(f)), None)
    if rel is None:
        return None
    submit = next((f for f in ("submit.yml.erb", "submit.yml") if present(f)), None)
    result = {"file": rel, "submit_file": submit, "erb_sentinel": "ERBVALUE", "error": None,
              "attributes": []}
    text = _read_fact(target, os.path.join(app_dir, rel), rel)
    submit_text = _read_fact(target, os.path.join(app_dir, submit), submit) if submit else None
    if rel.endswith(".erb"):
        text = strip_erb(text)
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
    refs = _submit_refs(submit_text, names) if submit else {}
    for name in names:
        spec = attrs.get(name)
        spec = spec if isinstance(spec, dict) else {}
        html = spec.get("html_options") if isinstance(spec.get("html_options"), dict) else {}
        lines, reaches = refs.get(name, ([], False))
        result["attributes"].append({
            "name": name,
            "widget": spec.get("widget"),
            "min": _num(spec.get("min", html.get("min"))),
            "max": _num(spec.get("max", html.get("max"))),
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
              "ran" if "ran" in statuses else
              "not_applicable" if statuses == {"not_applicable"} else "skipped")
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
            notes.append(_skip_note(app))
            continue
        if not app["readme"]:
            per_app[app["app_id"]] = "skipped"
            notes.append("%s: no README" % app["app_id"])
            continue
        try:
            data = scan_readme(_read_fact(target, os.path.join(target, app["readme"]), app["readme"]),
                               placeholders)
        except Refused as e:
            per_app[app["app_id"]] = "skipped"
            notes.append("%s: %s" % (app["app_id"], e))
            continue
        except Exception as e:
            per_app[app["app_id"]] = "failed_to_run"
            notes.append(("%s: %s: %s" % (app["app_id"], type(e).__name__, e))[:STDERR_CHARS])
            continue
        n += 1
        _write_json(_app_dir_out(out, app), "readme.json", dict([("file", app["readme"])] + list(data.items())))
        per_app[app["app_id"]] = "ran"
    return _fact_record("readme", "README headings, placeholder lines (references/readme-placeholders.txt), "
                        "screenshots, env vars, rungs", per_app, notes, n, "<app_id>/readme.json")


def check_form(target, apps, out):
    per_app, notes, n = {}, [yaml_parser_note()], 0
    for app in apps:
        if app["_skip"]:
            per_app[app["app_id"]] = "skipped"
            notes.append(_skip_note(app))
            continue
        try:
            data = scan_form(target, app["_dir"])
        except Refused as e:
            per_app[app["app_id"]] = "skipped"
            notes.append("%s: %s" % (app["app_id"], e))
            continue
        except Exception as e:
            per_app[app["app_id"]] = "failed_to_run"
            notes.append(("%s: %s: %s" % (app["app_id"], type(e).__name__, e))[:STDERR_CHARS])
            continue
        if data is None:
            # form.yml applies only to batch_connect (and unknown, whose
            # type resolution fell through to entry-point files); a
            # Passenger, companion or widget app has no form by contract, so
            # its absence is not_applicable, not skipped.
            per_app[app["app_id"]] = ("not_applicable" if app["app_type"] not in
                                      ("batch_connect", "unknown") else "skipped")
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


# template.json: candidates the quality skill judges (QUA-02, QUA-04, QUA-06, QUA-08).
SITE_PATH = re.compile(r"(^|[\s\"'=:])(/(?:scratch|projects?|home|opt|usr/local|usr/share|appl|apps|sw|"
                       r"software|data|work)[/\w.-]*)")
# A bare integer or hex literal: not part of a word, a decimal, a path, a
# $N parameter, a hex colour, a word-number (cuda-11) or a date; nor a
# redirect's fd (2>, >&2).
NUMERIC = re.compile(r"(?<![\w.$/&#])(?<!\w-)(0[xX][0-9a-fA-F]+|\d+)(?![\w./<>])(?!-\w)")
NUMERIC_OK = {"0", "1", "22", "80", "443"}
# the text before a literal that makes it not a magic number: sleep's
# argument, an exit status, a kill signal, a chmod/umask mode, a $? comparison
NUMERIC_CONTEXT = re.compile(r"(\bsleep\s+[\"']?|\bexit\s+|\bkill\s+-|\b(?:chmod|umask)\s+(?:-\w+\s+)*"
                             r"|\$\?[\"']?\s+-(?:eq|ne|gt|ge|lt|le)\s+[\"']?)$")
HEX_COLOR = re.compile(r"(?<![\w&])#[0-9a-fA-F]{6}(?![\w])")
COMMENT = re.compile(r"(^|\s)#")
COMMENT_LINE = re.compile(r"^\s*#")
UNCOMMENT = re.compile(r"^\s*#+ ?")
# a commented line reads as shell when it carries one of these, or starts with SHELL_WORDS
SHELL_TOKEN = re.compile(r"[A-Za-z_]\w*=|\$[\w{(?]|[|<>;`]|&&")
SHELL_WORDS = {"if", "for", "while", "until", "case", "function", "cd", "export", "module", "mkdir",
               "rm", "cp", "mv", "echo", "source", "set", "exec", "kill", "sleep", "chmod"}
DESKTOP_ICON = re.compile(r"^\s*Icon\s*=\s*(.*?)\s*$")
PROPERTY_TAG = re.compile(r"<property\b[^>]*>", re.S)
BUTTON_ICON = re.compile(r"""\bname\s*=\s*["']button-icon["']""")
VALUE_ATTR = re.compile(r"""\bvalue\s*=\s*["']([^"']*)["']""")
SHEBANG_SHELL = re.compile(r"^#!\s*\S*/(?:env\s+)?(?:ba|z|k|da)?sh\b")
NO_TEMPLATE = "no template/ directory"


def _is_shell(rel, text):
    base = rel[:-4] if rel.endswith(".erb") else rel
    return rel.endswith(SHELL_SUFFIXES) or base.endswith((".sh", ".bash")) or \
        bool(SHEBANG_SHELL.match(text.split("\n", 1)[0]))


def _has_comment(line):
    return bool(COMMENT.search(line)) and not line.startswith("#!")


def _numeric_literals(lines):
    """[(line, value)]: bare integers/hex, except 0, 1, the ports 22/80/443,
    array indices ([N]), the NUMERIC_CONTEXT cases (sleep, exit, kill -N,
    chmod/umask modes, $? comparisons) and any literal on a line that has a
    # comment or follows one."""
    found = []
    for i, line in enumerate(lines):
        if _has_comment(line) or (i > 0 and _has_comment(lines[i - 1])):
            continue
        for m in NUMERIC.finditer(line):
            value, before, after = m.group(1), line[:m.start()], line[m.end():]
            if value in NUMERIC_OK or NUMERIC_CONTEXT.search(before) or \
                    (before.endswith("[") and after.startswith("]")):
                continue
            found.append((i + 1, value))
    return found


def _commented_code(lines, bash):
    """[(first line, count)]: runs of consecutive #-lines (a line-1 shebang
    excluded; count is the run's length) holding three or more non-blank
    comment lines, at least one of which reads as shell (SHELL_TOKEN or a
    first word in SHELL_WORDS), whose text with the # removed passes
    bash -n. A run bash rejects is not code, whatever bash's version (an old
    bash rejects bash 4 syntax, so such a block goes unreported there)."""
    runs, start = [], None
    for i, line in enumerate(lines + [""]):
        is_comment = COMMENT_LINE.match(line) and not (i == 0 and line.startswith("#!"))
        if is_comment and start is None:
            start = i
        elif not is_comment and start is not None:
            runs.append((start, i))
            start = None
    found = []
    for a, b in runs:
        text = [UNCOMMENT.sub("", l, count=1) for l in lines[a:b]]
        body = [t for t in text if t.strip()]
        if len(body) < 3 or bash is None or not any(
                SHELL_TOKEN.search(t) or t.split()[0] in SHELL_WORDS for t in body):
            continue
        try:
            p = subprocess.run([bash, "-n"], input="\n".join(text) + "\n", capture_output=True,
                               text=True, errors="replace", timeout=60)
        except Exception:
            continue
        if p.returncode == 0:
            found.append((a + 1, b - a))
    return found


def _line_at(text, pos):
    return text.count("\n", 0, pos) + 1


def _icons(rel, text):
    """[(line, name, kind)] from the raw text (an ERB tag stays as written):
    Icon= in a .desktop; a button-icon property in xfce4-panel.xml, its value
    from the tag's value attribute (either order), else the first <value>
    element's value attribute or text, else the property's own text."""
    name = rel.rsplit("/", 1)[-1]
    base = name[:-4] if name.endswith(".erb") else name
    found = []
    if base.endswith(".desktop"):
        for i, line in enumerate(text.split("\n")):
            m = DESKTOP_ICON.match(line)
            if m:
                found.append((i + 1, m.group(1), "desktop"))
    elif base == "xfce4-panel.xml":
        for tag in PROPERTY_TAG.finditer(text):
            if not BUTTON_ICON.search(tag.group(0)):
                continue
            m = VALUE_ATTR.search(tag.group(0))
            if m:
                value = m.group(1)
            elif tag.group(0).endswith("/>"):
                continue
            else:
                end = text.find("</property>", tag.end())
                inner = text[tag.end():end if end >= 0 else len(text)]
                v = re.search(r"<value\b([^>]*)>(.*?)</value>|<value\b([^>]*)/>", inner, re.S)
                if v:
                    attr = VALUE_ATTR.search(v.group(1) or v.group(3) or "")
                    value = attr.group(1) if attr else (v.group(2) or "").strip()
                else:
                    value = re.sub(r"<[^>]*>", "", inner).strip()
            found.append((_line_at(text, tag.start()), value, "xfce4-panel"))
    return found


def _site_paths(raw, stripped):
    """[(line, text)]: SITE_PATH over the ERB-stripped text, then over the raw
    text (a path inside an ERB tag); one per (line, text), and a raw match
    dropped when a stripped match on its line extends it (/projects/ vs
    /projects/ERBVALUE/runs)."""
    found = []
    for i, line in enumerate(stripped.split("\n")):
        for m in SITE_PATH.finditer(line):
            if (i + 1, m.group(2)) not in found:
                found.append((i + 1, m.group(2)))
    if raw is not stripped:
        for i, line in enumerate(raw.split("\n")):
            for m in SITE_PATH.finditer(line):
                t = m.group(2)
                if not any(l == i + 1 and s.startswith(t) for l, s in found):
                    found.append((i + 1, t))
    return sorted(found, key=lambda x: x[0])


def _app_rel(app_dir, target):
    rel = os.path.relpath(app_dir, target).replace(os.sep, "/")
    return "" if rel == "." else rel + "/"


def scan_template(app_dir, target):
    """template.json for one app directory, or None when it has no template/
    directory. Every file under template/ is read under the shell-file rule
    (refused and binary files are listed in skipped_files); .erb files are
    ERB-stripped first (site paths are also sought in the raw text, icons
    only there). absolute_paths, hex_colors and icons come from every file,
    numeric_literals and commented_code from shell files (by suffix or
    shebang). A template/ that is itself a symlink leaving the target (or
    not a directory) raises Refused."""
    prefix = _app_rel(app_dir, target)
    tdir = os.path.join(app_dir, "template")
    if not os.path.lexists(tdir):
        return None
    if os.path.islink(tdir) and not _inside(target, tdir):
        raise Refused("%stemplate: %s" % (prefix, OUTSIDE))
    if not os.path.isdir(tdir):
        raise Refused("%stemplate: not a directory, not checked" % prefix)
    files, rejected = _classify(tdir)
    for r, why in list(rejected.items()):  # _classify's bound is template/; ours is the target
        if why == OUTSIDE and _refusal(target, os.path.join(tdir, r)) in (None, TOO_LARGE):
            files.append(r)
            del rejected[r]
    files.sort()
    bash = shutil.which("bash")
    result = {"dir": prefix + "template", "files": [], "icons": [], "absolute_paths": [],
              "numeric_literals": [], "hex_colors": [], "commented_code": [], "skipped_files": []}
    skipped = [(r, why) for r, why in rejected.items()]
    for r in files:
        rel = prefix + "template/" + r
        try:
            raw = _read_fact(target, os.path.join(tdir, r), rel)
        except Refused as e:
            skipped.append((r, str(e).split(": ", 1)[1]))
            continue
        if "\x00" in raw:
            skipped.append((r, "binary file, not scanned"))
            continue
        result["files"].append(rel)
        text = strip_erb(raw) if rel.endswith(".erb") else raw
        lines = text.split("\n")
        for line, name, kind in _icons(rel, raw):
            result["icons"].append({"file": rel, "line": line, "name": name, "kind": kind})
        for line, path in _site_paths(raw, text):
            result["absolute_paths"].append({"file": rel, "line": line, "text": path})
        for i, line in enumerate(lines):
            for m in HEX_COLOR.finditer(line):
                result["hex_colors"].append({"file": rel, "line": i + 1, "value": m.group(0)})
        if _is_shell(rel, text):
            for line, value in _numeric_literals(lines):
                result["numeric_literals"].append({"file": rel, "line": line, "value": value})
            for line, count in _commented_code(lines, bash):
                result["commented_code"].append({"file": rel, "line": line, "count": count})
    result["skipped_files"] = [{"file": prefix + "template/" + r, "reason": why}
                               for r, why in sorted(skipped)]
    return result

# entry_point.json: the Passenger entry point's parse and its dependency manifest.
ENTRY_LANGUAGE = {"config.ru": "ruby", "passenger_wsgi.py": "python", "app.js": "node"}
DEPENDENCY_MANIFESTS = {"ruby": ("Gemfile",), "python": ("requirements.txt", "pyproject.toml",
                                                          "Pipfile", "setup.py"),
                        "node": ("package.json",)}
# import name -> distribution name, where they differ (normalized: lower case, _ for -.)
IMPORT_DIST = {"yaml": "pyyaml", "dotenv": "python_dotenv", "pil": "pillow", "sklearn": "scikit_learn",
               "bs4": "beautifulsoup4", "cv2": "opencv_python", "dateutil": "python_dateutil",
               "jwt": "pyjwt", "ldap": "python_ldap", "magic": "python_magic", "zmq": "pyzmq"}


def _norm_dist(name):
    return re.sub(r"[-_.]+", "_", name).lower()


def _python_imports(app_dir, target, files):
    """Top-level names of the absolute imports in the app's .py files."""
    import ast
    names = set()
    for rel in files:
        try:
            tree = ast.parse(_read_fact(target, os.path.join(app_dir, rel), rel))
        except Exception:
            continue
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                names.update(a.name.split(".")[0] for a in node.names)
            elif isinstance(node, ast.ImportFrom) and not node.level and node.module:
                names.add(node.module.split(".")[0])
    return names


def _stdlib_names(names=getattr(sys, "stdlib_module_names", None)):
    """Standard-library top-level module names: sys.stdlib_module_names
    (3.10+), else the builtins plus what the stdlib directories hold."""
    if names:
        return set(names)
    import sysconfig
    found = set(sys.builtin_module_names)
    paths = sysconfig.get_paths()
    dirs = {paths.get("stdlib"), paths.get("platstdlib")}
    dirs |= {os.path.join(d, "lib-dynload") for d in list(dirs) if d}
    for d in filter(None, dirs):
        try:
            entries = os.listdir(d)
        except OSError:
            continue
        for n in entries:
            if n.endswith(".py") or n.endswith(".so") or n.endswith(".pyd"):
                found.add(n.split(".")[0])
            elif n not in ("site-packages", "dist-packages") and os.path.isdir(os.path.join(d, n)):
                found.add(n)
    return found


def _py_skip(rel):
    """Files whose imports are not the app's runtime dependencies: setup.py,
    anything under a tests/ directory, test_*.py."""
    parts = rel.split("/")
    return parts[-1] == "setup.py" or parts[-1].startswith("test_") or "tests" in parts[:-1]


def _python_consistency(app_dir, target, manifest, exclude):
    """(consistent, note): every third-party import (not stdlib, not a module
    or package in the app) is named in requirements.txt. Best effort: a
    manifest other than requirements.txt is not judged."""
    stdlib = _stdlib_names()
    files = [p for p in _classify(app_dir, exclude)[0] if p.endswith(".py") and not _py_skip(p)]
    local = set()
    for p in _classify(app_dir, exclude)[0]:
        if not p.endswith(".py"):
            continue
        parts = p.split("/")
        if parts[0] == "src" and len(parts) > 1:  # src layout: src/<pkg>/ or src/<mod>.py
            parts = parts[1:]
        local.add(parts[0][:-3] if len(parts) == 1 else parts[0])
    third = sorted(n for n in _python_imports(app_dir, target, files)
                   if n not in stdlib and n not in local and n != "__future__")
    if manifest is None:
        return (False, "no dependency manifest; third-party imports: " + ", ".join(third)) if third \
            else (True, "no dependency manifest; no third-party imports")
    if manifest != "requirements.txt":
        return None, "not checked: %s is not read" % manifest
    declared = set()
    for line in _read_fact(target, os.path.join(app_dir, manifest), manifest).splitlines():
        m = re.match(r"\s*([A-Za-z0-9][A-Za-z0-9._-]*)", line)
        if m and not line.lstrip().startswith(("#", "-")):
            declared.add(_norm_dist(m.group(1)))
    missing = [n for n in third if _norm_dist(n) not in declared
               and IMPORT_DIST.get(n.lower()) not in declared]
    if missing:
        return False, "not in requirements.txt: " + ", ".join(missing)
    return True, ("third-party imports all in requirements.txt: " + ", ".join(third)) if third \
        else "no third-party imports"


def _parse_entry(language, app_dir, target, rel, shown):
    """(parses, error): True / False, or "not_checked" when the checker is
    absent. error starts with the interpreter and its version; paths in it
    are shown (the repo-relative path, with the app subpath)."""
    text = _read_fact(target, os.path.join(app_dir, rel), shown)
    if language == "python":
        ver = "python %d.%d.%d" % sys.version_info[:3]
        try:  # the py_compile check, in process, so no .pyc lands in the target
            compile(text, shown, "exec")
            return True, None
        except SyntaxError as e:
            return False, ("%s: line %s: %s" % (ver, e.lineno, e.msg))[:STDERR_CHARS]
        except ValueError as e:  # e.g. null bytes, on Pythons that raise ValueError for them
            return False, ("%s: %s" % (ver, e))[:STDERR_CHARS]
    tool = {"ruby": ["ruby", "-c"], "node": ["node", "--check"]}[language]
    if shutil.which(tool[0]) is None:
        return "not_checked", "%s not found on PATH" % tool[0]
    rc, _, err, error = run(tool + [_arg(rel)], timeout=60, cwd=app_dir)
    if error:
        return "not_checked", error
    if rc == 0:
        return True, None
    err = (err.strip() or "exit %s" % rc).replace(_arg(rel), shown)
    ver = " ".join(tool_version(tool[0]).split()[:2])  # "ruby 2.6.10p210", "v24.2.0"
    ver = ver if ver.startswith(tool[0]) else "%s %s" % (tool[0], ver)
    return False, ("%s: %s" % (ver, err))[:STDERR_CHARS]


def scan_entry_point(app_dir, target, exclude=None):
    """entry_point.json for one app directory, or None when it has no
    Passenger entry point (config.ru, passenger_wsgi.py, app.js, first found).
    An entry point that may not be read raises Refused."""
    prefix = _app_rel(app_dir, target)
    entry = next((f for f in PASSENGER_ENTRY if os.path.lexists(os.path.join(app_dir, f))), None)
    if entry is None:
        return None
    language = ENTRY_LANGUAGE[entry]
    parses, error = _parse_entry(language, app_dir, target, entry, prefix + entry)
    manifest = next((f for f in DEPENDENCY_MANIFESTS[language]
                     if os.path.lexists(os.path.join(app_dir, f))), None)
    if language == "python":
        consistent, note = _python_consistency(app_dir, target, manifest, exclude)
    else:
        consistent, note = None, "not checked: %s dependency consistency is not judged" % language
    return {"file": prefix + entry, "language": language, "parses": parses, "error": error,
            "dependency_manifest": prefix + manifest if manifest else None,
            "consistent": consistent, "note": note}


def _app_fact(name, scan, applies, missing, target, apps, out):
    """Run scan(app) for each app whose type applies; (per_app, notes, n)."""
    per_app, notes, n = {}, [], 0
    for app in apps:
        app_id = app["app_id"]
        if app["_skip"]:
            per_app[app_id] = "skipped"
            notes.append(_skip_note(app))
            continue
        if app["app_type"] not in applies:
            per_app[app_id] = "not_applicable"
            continue
        try:
            data = scan(app)
        except Refused as e:
            per_app[app_id] = "skipped"
            notes.append("%s: %s" % (app_id, e))
            continue
        except Exception as e:
            per_app[app_id] = "failed_to_run"
            notes.append(("%s: %s: %s" % (app_id, type(e).__name__, e))[:STDERR_CHARS])
            continue
        if data is None:
            per_app[app_id] = "skipped"
            notes.append("%s: %s" % (app_id, missing))
            continue
        n += len(data["files"]) if name in ("template", "security") else 1
        _write_json(_app_dir_out(out, app), name + ".json", data)
        per_app[app_id] = "ran"
    return per_app, notes, n


def check_template(target, apps, out):
    per_app, notes, n = _app_fact("template", lambda a: scan_template(a["_dir"], target),
                                  ("batch_connect", "unknown"), NO_TEMPLATE, target, apps, out)
    bash = shutil.which("bash") if "ran" in per_app.values() else ""
    if bash is None:
        notes.insert(0, "bash not found on PATH: commented_code not checked")
    elif bash:
        major, ver = _bash_major(bash)
        if major is not None and major < 4:
            notes.insert(0, "bash %s on PATH: a commented block using bash 4 syntax is not "
                            "reported as commented_code" % ver)
    return _fact_record("template", "template/ scan: icons, site paths, numeric literals, "
                        "commented-out code (bash -n)", per_app, notes, n, "<app_id>/template.json")


def check_entry_point(target, apps, out):
    per_app, notes, n = _app_fact("entry_point", lambda a: scan_entry_point(a["_dir"], target, out),
                                  ("passenger", "companion"), "no Passenger entry point", target, apps, out)
    return _fact_record("entry_point", "Passenger entry point: compile() / ruby -c / node --check, "
                        "dependency manifest", per_app, notes, n, "<app_id>/entry_point.json")


# security.json: the candidate sites the security skill must answer (R4).
SEC_KINDS = ("interpolation", "unquoted_expansion", "eval_exec", "network_call",
             "file_write_outside_job", "permission_change", "credential_string", "config_flag",
             "binary_in_template", "tool_finding")
# kind -> (manifest check id, rule, default mechanism tag)
SEC_KIND = {
    "interpolation": ("sec-interpolation", "OODT-01", "unsanitized-user-input"),
    "unquoted_expansion": ("sec-interpolation", "OODT-01", "unquoted-variable"),
    "eval_exec": ("sec-eval-exec", "OODT-01", "eval-exec"),
    "network_call": ("sec-network-call", "OODT-04", "unexpected-network-call"),
    "file_write_outside_job": ("sec-file-write-outside-job", "OODT-07", "dotfile-write"),
    "permission_change": ("sec-permissive-mode", "OODT-03", "permissive-file-mode"),
    "credential_string": ("sec-credential-string", "OODT-02", "hardcoded-credential"),
    "config_flag": ("sec-config-flag", "OODT-08", None),
    "binary_in_template": ("sec-binary-in-template", "OODT-04", "binary-in-template"),
    "tool_finding": ("sec-tool-finding", None, None),
}
# tool_finding: shellcheck levels below this are excluded (style); semgrep
# severities below this are excluded (INFO). bandit has no excluded level.
SHELLCHECK_EXCLUDED_LEVELS = ("style",)
SEMGREP_EXCLUDED_SEVERITIES = ("INFO",)
TOOL_FINDING_CEILING = 15
# a tool_finding candidate's lines list is cut to this many entries
# (lines_total then gives the full count)
TOOL_LINES_CAP = 20
# shellcheck codes that are artefacts of linting OOD's job-script files one
# at a time: OOD sources before.sh, then runs script.sh, then after.sh, in
# one shell, so a fragment has no shebang (SC2148), reads variables the
# others set (SC2154), and sources files shellcheck was not given (SC1090,
# SC1091). A finding is an artefact only in an OOD job-script file
# (OOD_JOB_SCRIPT), and SC2154 only for a variable a sibling before.sh*
# assigns or one of OOD's contract names (OOD_CONTRACT_VARS).
ARTIFACT_CODES = ("SC2148", "SC2154", "SC1090", "SC1091")
OOD_JOB_SCRIPT = re.compile(r"\.sh\.erb$|(?:^|/)template/(?:before|script|after)\.sh[^/]*$")
OOD_CONTRACT_VARS = ("port", "host", "display", "password", "app_port", "csrftoken")
SC2154_VAR = re.compile(r"^(\w+) is referenced but not assigned")
TEXT_CAP = 200
NO_SCOPE = "no in-scope files"
BC_FILES = ("submit.yml.erb", "submit.yml", "form.yml", "form.yml.erb", "connection.yml",
            "connection.yml.erb")
FORM_FILES = ("form.yml", "form.yml.erb", "manifest.yml", "appverse.yml")
CONTAINER_DEF = re.compile(r"^(?:Dockerfile|Containerfile)(?:\..*)?$|\.(?:def|dockerfile)$", re.I)
NOT_SOURCE = re.compile(
    r"(?:^|/)(?:LICEN[SC]E|COPYING|CHANGELOG|CHANGES|NOTICE|AUTHORS)[^/]*$"
    r"|\.(?:md|markdown|rst|txt|adoc|png|jpe?g|gif|ico|svg|webp|bmp|pdf|woff2?|ttf|eot|otf|lock)$"
    r"|(?:^|/)package-lock\.json$", re.I)
# Test code (never run by the deployed app) is left out of an all-source scope.
TEST_PATH = re.compile(r"(?:^|/)(?:tests?|spec|__tests__)/|(?:^|/)test_[^/]*\.py$|_test\.(?:rb|py|go)$"
                       r"|_spec\.rb$|\.(?:test|spec)\.[jt]sx?$")
# Dependency manifests name their package index by URL; that is not a call.
DEP_MANIFEST = re.compile(r"(?:^|/)(?:Gemfile|[^/]*\.gemspec|package\.json|pyproject\.toml|Pipfile"
                          r"|setup\.cfg|setup\.py|environment\.ya?ml)$")
SLASH_EXT = (".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx", ".vue", ".java", ".go", ".c", ".h",
             ".cpp", ".css", ".scss", ".php")
MARKUP_EXT = (".html", ".htm", ".xml")
# A command word's position: line start, after ; & | ( { ` ! $( or a keyword.
SH_POS = r"(?:^|[;&|({`!]|\$\(|\b(?:then|do|else|elif|if|while|until|sudo|exec|time|nohup|xargs|command|env|RUN)\s)\s*"
# In another language, a command is the start of a string (["curl", ...] or "curl ...").
STR_POS = r"(?:\[\s*)?[\"'`]\s*"
NET_CMD = r"(curl|wget|ssh|scp|sftp|nc|ncat|netcat|socat|telnet)"
NET_SH = re.compile(SH_POS + NET_CMD + r"(?=\s|$|;|\))")
NET_STR = re.compile(STR_POS + NET_CMD + r"(?=[\s\"'])")
NET_CLIENT = re.compile(
    r"\brequests\.(?:get|post|put|delete|patch|head|request|Session)\b|\burllib\.request\b"
    r"|\burlopen\s*\(|\bhttp\.client\b|\bhttpx\.\w+|\bsocket\.(?:socket|create_connection)\s*\("
    r"|\bsmtplib\.SMTP|\bparamiko\b|Net::HTTP|\bopen-uri\b|\bURI\.open\b|\b(?:TCP|UDP)Socket\b"
    r"|\bFaraday\b|\bHTTParty\b|\bRestClient\b|\bfetch\s*\(\s*[\"'`]https?://|\baxios\b"
    r"|\bXMLHttpRequest\b|\bhttps?\.(?:request|get)\s*\(")
URL = re.compile(r"\b(?:https?|ftp|wss?)://([^\s'\"<>()`]+)")
URL_LOCAL = re.compile(r"^(?:localhost|127\.|0\.0\.0\.0|\[::1?\]|unix:|[$<{%]|#\{|ERBVALUE"
                       r"|(?:[\w-]+\.)*(?:example\.(?:com|org|net|edu)|w3\.org|xmlsoap\.org|purl\.org)"
                       r"(?:[:/]|$))", re.I)
URL_PROSE = re.compile(r"^\s*(?:echo|printf|help|label|description|summary)\b|xmlns|<!DOCTYPE|\"-//", re.I)
URL_SCHEMA = re.compile(r"\.(?:dtd|xsd)$", re.I)
ERB_ANY = re.compile(r"<%.*?%>")
EVAL_SH = [
    (re.compile(SH_POS + r"eval(?=\s)"), "eval-exec", "eval"),
    (re.compile(SH_POS + r"exec\s+(?:-\w+\s+)*[\"']?(?:\$(?![@*]|\{[@*])|<%=)"), "eval-exec",
     "exec of a variable command"),
    (re.compile(SH_POS + r"(?:source|\.)\s+[\"']?(?:\$|<%=)"), "eval-exec", "source of a variable path"),
]
EVAL_ANY = [
    (re.compile(r"\b(?:ba|z|k|da)?sh\s+(?:-\w+\s+)*-\w*c\s+[\"']?[^\"']*(?:\$|<%=)"), "eval-exec",
     "shell -c with a variable"),
    (re.compile(r"(?:source|\.|\b(?:ba|z)?sh)\s+<\(\s*(?:curl|wget)\b"), "curl-pipe-exec",
     "download sourced into a shell"),
    (re.compile(r"(?<![\w.$])(?:eval|exec)\s*\("), "eval-exec", "eval()/exec()"),
    (re.compile(r"\bnew\s+Function\s*\("), "eval-exec", "new Function()"),
    (re.compile(r"\bos\.(?:system|popen)\s*\("), "command-injection", "os.system()/os.popen()"),
    (re.compile(r"\bchild_process\b.*\bexec(?:Sync)?\s*\(|\bexecSync\s*\(|(?<![\w.])cp\.exec\s*\("),
     "command-injection", "child_process exec"),
    (re.compile(r"(?<![\w.:])(?:system|exec|spawn|IO\.popen|Open3\.\w+)\s*[(\[{]?\s*[\"'].*#\{"
                r"|`[^`]*#\{|%x[(\[{][^)\]}]*#\{"), "command-injection",
     "shell command string with #{} interpolation"),
]
PIPE_SH = re.compile(r"\|\s*(?:sudo\s+(?:-\S+\s+)*)?(?:\S*/)?(?:ba|z|k|da)?sh(?=\s|$|;|\))")
SUBPROCESS = re.compile(r"\bsubprocess\.\w+\s*\(")
SHELL_TRUE = re.compile(r"\bshell\s*=\s*True\b")
OUT_TARGET = re.compile(r"[\"']?(?:\$HOME\b|\$\{HOME\}|~(?=/|[\s\"']|$)|/(?!dev/|proc/self/)[\w.~-])")
REDIRECT = re.compile(r"(?<![<>&\d])(?:\d?>>?|&>>?)\s*(\S+)")
WRITE_CMD = re.compile(SH_POS + r"(cp|mv|install|ln|tee|rsync)\s+([^;&|]*)")
CRON_SH = re.compile(SH_POS + r"(crontab|systemctl\s+--user\s+(?:enable|start))(?=\s|$)")
CRON_STR = re.compile(r"[\"']\s*crontab\b")
PERSIST_PATH = re.compile(r"\.ssh/|authorized_keys|\.(?:bashrc|bash_profile|bash_login|profile|zshrc"
                          r"|zprofile|cshrc|tcshrc)\b|/etc/cron|\.config/systemd/user|\.config/autostart")
WRITE_VERB = re.compile(r"\bopen\s*\([^)]*[\"'][wa]b?\+?[\"']|\.write\w*\s*\(|\bwrite_text\b"
                        r"|\bFile\.(?:write|open)\b|\bFileUtils\.|\bshutil\.(?:copy|move)"
                        r"|\bwriteFile|\bappendFile|>>")
PERM_SH = re.compile(SH_POS + r"(chmod|chown|chgrp|umask|setfacl)(?=\s|$)")
PERM_ANY = re.compile(r"\bos\.(chmod|chown|umask|fchmod)\s*\(|\bFileUtils\.(chmod|chown)\w*"
                      r"|\bFile\.(chmod|chown)\b|\bfs\.(chmod|chown)(?:Sync)?\s*\(")
MODE = re.compile(r"(?<![\w.])0?[oO]?([0-7]{3,4})(?![\w.])")
CRED_WORD = (r"[\w.-]*?(?:pass(?:word|wd|phrase)|(?<![a-z])pass|secret|token|api[_-]?key|apikey"
             r"|access[_-]?key|private[_-]?key|credential)s?(?![a-z])[\w.-]*")
CRED_QUOTED = re.compile(r"(?i)(?<![\w.-])(" + CRED_WORD + r")[\"']?\s*(?:=|:|=>)\s*([\"'])([^\"'\s]{4,})\2")
CRED_BARE = re.compile(r"(?i)(?<![\w.-])(" + CRED_WORD + r")\s*[=:]\s*(?![\"'\s])"
                       r"([A-Za-z0-9_+/=-]{8,})(?=\s|$|;|,)")
CRED_FLAG = re.compile(r"(?i)--([\w.-]*?(?:password|passwd|token|secret|api-?key)[\w.-]*)[= ]"
                       r"[\"']?([^\s\"'$<]{4,})")
CRED_KEY_SKIP = re.compile(r"(?i)[_.-](?:dir|path|file|url|uri|name|env|var|header|type|field|label|prefix"
                           r"|len|length|endpoint|id|count|size|limit|expir\w*|ttl|timeout)$")
CRED_VALUE_SKIP = re.compile(r"(?i)^(?:/|~|\./|\$|<%|%\(|\{|ERBVALUE|ENV\b|os\.environ|https?:)"
                             r"|^(?:true|false|none|null|nil|required|optional|string|text|hidden"
                             r"|password|token|secret|password_field)$")
CRED_SHAPE = re.compile(r"-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY(?: BLOCK)?-----|\bAKIA[0-9A-Z]{16}\b"
                        r"|\bgh[pousr]_[A-Za-z0-9]{36}\b|\bxox[baprs]-[A-Za-z0-9-]{10,}")
# (pattern, rule, tag, note, shell family only)
CONFIG_FLAGS = [
    (re.compile(r"(?<![\d.])0\.0\.0\.0(?![\d.])|\bINADDR_ANY\b|\[::\]"
                r"|(?:--(?:host|ip|bind|listen|address)[= ]\s*|\bhost\s*[=:]\s*|\bbind\s*[=:(]\s*)"
                r"[\"'\[]*::\]?(?![\w:.])|\b(?:listen|bind|serve)\s*\([^)]*[\"']::[\"']"),
     "OODT-05", "bind-all-interfaces", "binds all interfaces; OOD's node proxy needs a non-loopback "
     "bind, so this is a finding only when the service has no authentication", False),
    (re.compile(r"(?i)Access-Control-Allow-Origin[\"']?\s*[:,]?\s*[\"']?\*|\ballow_origin\s*=\s*[\"']\*"
                r"|\b(?:origins?|allow_origins?|cors_origins?|cors_allowed_origins)\s*[:=]\s*\[?\s*[\"']\*[\"']"
                r"|\bCORS_(?:ORIGIN_ALLOW_ALL|ALLOW_ALL_ORIGINS)\s*=\s*True|\bCORS\(\s*app\s*\)|\bcors\(\s*\)"),
     "OODT-05", "cors-wildcard", "CORS open to all origins", False),
    (re.compile(r"--no-auth\b|--disable-auth\b|--auth[= ]none\b|--allow-unauthenticated\b"
                r"|--[\w.-]*?\b(?:token|password)\s*=\s*(?:''|\"\"|(?=\s|\\|$))"
                r"|\.(?:token|password)\s*=\s*(?:''|\"\")"),
     "OODT-05", "disabled-auth", "authentication disabled or empty", False),
    (re.compile(r"\bdisable_check_xsrf\s*=\s*True|\bWTF_CSRF_ENABLED\s*=\s*False|\bxsrf_cookies\s*=\s*False"
                r"|@csrf_exempt\b|\bskip_before_action\s+:verify_authenticity_token"
                r"|\bprotect_from_forgery\s+with:\s*:null_session"),
     "OODT-05", "disabled-xsrf", "CSRF/XSRF protection disabled", False),
    (re.compile(r"--disable-ssl\b|--no-ssl\b|--no-check-certificate\b|--insecure\b"
                r"|\bcurl\b[^|;&]*\s-k\b|\bverify\s*=\s*False\b|\bverify_ssl\s*=\s*False\b"
                r"|\bssl_verify\w*\s*[:=]\s*(?:false|False|0)\b|\bVERIFY_NONE\b|\brejectUnauthorized\s*:\s*false"
                r"|\bNODE_TLS_REJECT_UNAUTHORIZED\s*=\s*[\"']?0|\bPYTHONHTTPSVERIFY\s*=\s*[\"']?0"
                r"|\bsslVerify\s+false"),
     "OODT-08", "disabled-ssl", "TLS verification disabled", False),
    (re.compile(SH_POS + r"set\s+(?:-[a-wyzA-Z]*x|-o\s+xtrace)|^#!.*\s-[a-z]*x\b|\bbash\s+-x\b"),
     "OODT-08", "debug-tracing-enabled", "shell tracing on; trace output goes to the job's own "
     "output.log; world-readable only if the job directory is", True),
    (re.compile(r"\bapp\.run\([^)]*\bdebug\s*=\s*True|^\s*DEBUG\s*=\s*True\b"
                r"|\bFLASK_DEBUG\s*=\s*[\"']?(?:1|true|True)\b"),
     "OODT-08", "debug-tracing-enabled", "debug mode on", False),
    (re.compile(r"(?i)\bdisable_host_check\b|\bdisableHostCheck\s*:\s*true|--disable-host-check\b"
                r"|\ballow_remote_access\s*=\s*True|\bALLOWED_HOSTS\s*=\s*\[\s*[\"']\*|\bconfig\.hosts\.clear\b"),
     "OODT-08", "dns-rebinding-relaxed", "host checking relaxed", False),
    (re.compile(r"\bPIP_(?:EXTRA_)?INDEX_URL\s*=|--(?:extra-)?index-url\b|--trusted-host\b"),
     "OODT-08", "supply-chain-untrusted-index", "package index override", False),
]
PRESENCE = re.compile(r"\b(?:if|unless)\b|\s\?\s[^:]*\s:\s|\|\||\.presence\b|\.blank\?|\.present\?"
                      r"|\.empty\?|\.nil\?|\.fetch\s*\(")
# A reference followed by a presence predicate is a test, not the output.
PRESENCE_TEST = re.compile(r"(?:\.\w+)*?\.(?:blank|present|empty|nil|zero|positive|negative)\?"
                           r"|(?:\.\w+)*?\s*(?:==|!=|=~|!~|<=?|>=?)(?!=)")
# A reference whose method chain ends in a sanitiser, or wrapped in one.
SANITISE_AFTER = re.compile(r"(?:\.\w+[?!]?(?:\([^()]*\))?)*?\.(to_i|to_f|shellescape)\b")
SANITISE_BEFORE = re.compile(r"(Shellwords\.(?:escape|shellescape)|Integer|Float)\(\s*$")
# The note on an unguarded interpolation line names what _sanitised looks
# for, so the reviewer knows the check was made, not merely absent from view.
NO_SANITISER_NOTE = "no sanitiser (shellescape/to_i/to_f/Integer/Float/Shellwords.escape) on this line"
# An enclosing condition that validates: a regex match or an allow-list check.
VALIDATE = re.compile(r"=~|!~|\.match\??\s*\(|\.include\?\s*\(|\.in\?\s*\(")
ERB_COMMENT = re.compile(r"<%#.*?%>", re.S)
SH_ASSIGN = re.compile(r"^\s*(?:export\s+|local\s+|readonly\s+|declare\s+(?:-\w+\s+)*)?([A-Za-z_]\w*)=(.*)$")


def _family(rel, text):
    """shell | hash (# comments: Python, Ruby, YAML, config) | slash (// comments) | markup."""
    base = rel[:-4] if rel.endswith(".erb") else rel
    if _is_shell(rel, text) or CONTAINER_DEF.search(base.rsplit("/", 1)[-1]):
        return "shell"
    if base.endswith(SLASH_EXT):
        return "slash"
    if base.endswith(MARKUP_EXT):
        return "markup"
    return "hash"


def _is_comment(line, family, n):
    s = line.strip()
    if family in ("shell", "hash"):
        return s.startswith("#") and not (n == 1 and s.startswith("#!"))
    if family == "slash":
        return s.startswith(("//", "/*", "* ", "*/")) or s == "*"
    return s.startswith("<!--")


def _scan_quotes(line, upto=None, family=None):
    """Walk line to upto (None: the end) with ERB tags opaque. Returns (quote
    open at upto, index where a trailing comment starts or None)."""
    q, i, n = "", 0, len(line) if upto is None else upto
    while i < n:
        if line.startswith("<%", i):
            j = line.find("%>", i + 2)
            if j < 0:
                break
            i = j + 2
            continue
        c = line[i]
        if q:
            if c == "\\" and q == '"':
                i += 1
            elif c == q:
                q = ""
        elif c == "\\":
            i += 1
        elif c in "'\"":
            q = c
        elif family == "hash" and c == "`":
            q = c  # a Ruby backtick command is a string
        elif family == "hash" and line.startswith("%x", i) and line[i + 2:i + 3] in ("(", "[", "{"):
            q = {"(": ")", "[": "]", "{": "}"}[line[i + 2]]
            i += 3
            continue
        elif family in ("shell", "hash") and c == "#" and i > 0 and line[i - 1] in " \t":
            return q, i
        elif family == "slash" and line.startswith("//", i) and (i == 0 or line[i - 1] != ":"):
            return q, i
        i += 1
    return q, None


def _code_part(line, family):
    """line without its trailing comment (a # after a space, or //, outside quotes)."""
    if family == "markup":
        return line
    cut = _scan_quotes(line, family=family)[1]
    return line if cut is None else line[:cut]


def _cred_hits(code):
    """[(note)] for credential literals on a line."""
    hits = []
    for m in CRED_QUOTED.finditer(code):
        if not CRED_KEY_SKIP.search(m.group(1)) and not CRED_VALUE_SKIP.search(m.group(3)):
            hits.append("literal assigned to %s" % m.group(1))
    for m in CRED_BARE.finditer(code):
        if not CRED_KEY_SKIP.search(m.group(1)) and not CRED_VALUE_SKIP.search(m.group(2)) \
                and re.search(r"\d", m.group(2)) and re.search(r"[A-Za-z]", m.group(2)):
            hits.append("literal assigned to %s" % m.group(1))
    for m in CRED_FLAG.finditer(code):
        if not CRED_VALUE_SKIP.search(m.group(2)):
            hits.append("literal passed as --%s" % m.group(1))
    m = CRED_SHAPE.search(code)
    if m:
        hits.append("credential-shaped string %s" % m.group(0)[:30])
    return hits


def _perm_note(cmd, rest):
    """cmd, the mode when one is given, and whether it leaves the file (or,
    for umask, new files) world-writable."""
    if cmd == "umask":
        m = re.match(r"\s*\(?\s*(0?[oO]?[0-7]{1,4})\b", rest)
        if not m:
            return cmd
        return "umask %s, %s" % (m.group(1), "world-writable" if not int(m.group(1)[-1]) & 2
                                 else "not world-writable")
    if cmd not in ("chmod", "fchmod"):
        return cmd
    m = MODE.search(rest)
    sym = re.search(r"(?:^|[\s,(])([ugoa]*[-+=][rwxXst]+(?:,[ugoa]*[-+=][rwxXst]+)*)", rest)
    if m:
        mode, worldw = m.group(0), bool(int(m.group(1)[-1]) & 2)
    elif sym:
        mode = sym.group(1)
        worldw = bool(re.search(r"(?:^|,)[ao]*\+[rwxXst]*w|(?:^|,)\+[rwxXst]*w|(?:^|,)[ao]*=[rwxXst]*w",
                                mode))
    else:
        return cmd
    return "%s %s, %s" % (cmd, mode, "world-writable" if worldw else "not world-writable")


# crontab as a whole word, or cron as its own path segment (/etc/cron.d/,
# /var/spool/cron/, cron.daily) - never a substring of a word (acronyms.txt).
CRON_TARGET = re.compile(r"\bcrontab\b|(?:^|/)cron(?:\.\w+|/|$)")


def _write_target(target):
    t = target.strip("\"'")
    if ".ssh/" in t or "authorized_keys" in t:
        return "ssh-key-write"
    if CRON_TARGET.search(t) or "systemd/user" in t:
        return "cron-install"
    if re.search(r"(?:^|/)\.\w", t):
        return "dotfile-write"
    return "write-outside-job"


def _line_hits(code, family, urls=True):
    """[(kind, tag, rule, note)] for one non-comment line's code part (every
    kind but interpolation, unquoted_expansion and binary_in_template)."""
    hits = []
    shell = family == "shell"
    # eval_exec
    if shell:
        for pat, tag, note in EVAL_SH:
            if pat.search(code):
                hits.append(("eval_exec", tag, None, note))
    for pat, tag, note in EVAL_ANY:
        if pat.search(code):
            hits.append(("eval_exec", tag, None, note))
    if PIPE_SH.search(code):
        dl = re.search(r"\b(?:curl|wget)\b", code)
        hits.append(("eval_exec", "curl-pipe-exec" if dl else "eval-exec",
                     None, "download piped into a shell" if dl else "piped into a shell"))
    # network_call
    m = (NET_SH if shell else NET_STR).search(code) or (None if shell else NET_SH.search(code))
    if m:
        hits.append(("network_call", None, None, m.group(1) + " command"))
    m = NET_CLIENT.search(code)
    if m:
        hits.append(("network_call", None, None, m.group(0) + " client"))
    if urls and not URL_PROSE.search(code):
        for m in URL.finditer(code):
            if URL_LOCAL.match(m.group(1)) or URL_SCHEMA.search(m.group(1)) or \
                    re.search(r"href\s*[=:]\s*[\"']?$", code[:m.start()]):
                continue
            hits.append(("network_call", None, None, "URL " + m.group(0)[:80]))
            break
    # file_write_outside_job
    if shell:
        plain = ERB_ANY.sub("ERBVALUE", code)  # a %> closing a tag is not a redirect
        for m in REDIRECT.finditer(plain):
            if OUT_TARGET.match(m.group(1)):
                hits.append(("file_write_outside_job", _write_target(m.group(1)), None,
                             "redirect to " + m.group(1)))
        for m in WRITE_CMD.finditer(plain):
            args = [a for a in m.group(2).split() if not a.startswith("-")]
            dests = args if m.group(1) == "tee" else args[-1:] if len(args) > 1 else []
            for d in dests:
                if OUT_TARGET.match(d):
                    hits.append(("file_write_outside_job", _write_target(d), None,
                                 "%s to %s" % (m.group(1), d)))
        m = CRON_SH.search(code)
        if m:
            hits.append(("file_write_outside_job", "cron-install", None, m.group(1)))
    elif CRON_STR.search(code):
        hits.append(("file_write_outside_job", "cron-install", None, "crontab command"))
    elif PERSIST_PATH.search(code) and WRITE_VERB.search(code):
        p = PERSIST_PATH.search(code).group(0)
        hits.append(("file_write_outside_job", _write_target(p), None, "write to " + p))
    # permission_change
    if shell:
        for m in PERM_SH.finditer(code):
            hits.append(("permission_change", None, None, _perm_note(m.group(1), code[m.end():])))
    m = PERM_ANY.search(code)
    if m:
        cmd = next(g for g in m.groups() if g)
        hits.append(("permission_change", None, None, _perm_note(cmd, code[m.end():])))
    # credential_string
    for note in _cred_hits(code):
        hits.append(("credential_string", None, None, note))
    # config_flag
    for pat, rule, tag, note, shell_only in CONFIG_FLAGS:
        if (shell or not shell_only) and pat.search(code):
            hits.append(("config_flag", tag, rule, note))
    return hits


def _subprocess_shell(lines, family, i):
    """The line number of shell=True when a subprocess call starting on line
    i (0-based) passes it (the call read to its closing paren, 15 lines at
    most), else None."""
    code = _code_part(lines[i], family)
    m = SUBPROCESS.search(code)
    if not m:
        return None
    depth = 0
    for k in range(i, min(i + 15, len(lines))):
        seg = _code_part(lines[k], family)
        if k == i:
            seg = seg[m.end() - 1:]
        if SHELL_TRUE.search(seg):
            return k + 1
        depth += seg.count("(") - seg.count(")")
        if depth <= 0:
            return None
    return None


def _shell_taint(texts, taint):
    """{shell variable: attributes}: variables assigned (VAR=, export VAR=)
    from a <%= %> tag carrying a form attribute, or from a tainted variable,
    across the given template texts."""
    carried = {}
    changed = True
    while changed:
        changed = False
        for text in texts:
            for line in text.split("\n"):
                m = SH_ASSIGN.match(line)
                if not m:
                    continue
                srcs = set()
                for t in ERB_TAG.finditer(m.group(2)):
                    if t.group(1) == "=":
                        for var, attrs in taint.items():
                            if _ref_word(var).search(t.group(2)):
                                srcs |= attrs
                for var, attrs in carried.items():
                    if re.search(r"\$\{?%s\b" % re.escape(var), m.group(2)):
                        srcs |= attrs
                if srcs and not srcs <= carried.get(m.group(1), set()):
                    carried[m.group(1)] = carried.get(m.group(1), set()) | srcs
                    changed = True
    return carried


def _sanitised(body, names):
    """(every output reference to one of names in body is sanitised,
    the sanitisers seen). A reference followed by a presence predicate
    (.blank?, .present?, .zero? ...) or a comparison (==, =~, <) is a test,
    not output (x == "1" ? 'lab' : 'tree' outputs a literal); the rest must
    end in .to_i / .to_f / .shellescape or sit inside Shellwords.escape(),
    Integer() or Float()."""
    ok, seen = True, set()
    for v in names:
        for m in _ref_word(v).finditer(body):
            after = body[m.end():]
            if PRESENCE_TEST.match(after):
                continue
            a, b = SANITISE_AFTER.match(after), SANITISE_BEFORE.search(body[:m.start()])
            if a or b:
                seen.add("." + a.group(1) if a else b.group(1) + "()")
            else:
                ok = False
    return ok, seen


def _interpolations(text, family, attrs, yaml_paths=None):
    """[(line, attributes, guarded, presence_checked, quoted, note)]: one per
    line holding a <%= %> tag that carries a form attribute, directly,
    through a variable or a block parameter. guarded: for every such tag,
    the value is sanitised (.to_i, .to_f, .shellescape, Shellwords.escape(),
    Integer(), Float()) or an enclosing ERB if / unless / elsif validates it
    (=~, match, include?, in?). presence_checked: every such tag has its own
    presence test (if, unless, ternary, ||, .presence, .blank?, .present?,
    .empty?, .nil?, fetch) or sits under a condition that references the
    attribute. quoted: every such tag sits inside quotes on its line
    (lexical; the note says whether YAML or shell quotes, and that shell
    double quotes still expand $(...))."""
    tags = _erb_tags(text)
    taint = _erb_taint(tags, list(attrs))
    lines = text.split("\n")
    stack, per_line = [], {}
    for kind, start, body, pos in tags:
        if kind == "code":
            for stmt in re.split(r"[\n;]", body):
                s = stmt.strip()
                if re.match(r"^(?:if|unless|while|until|case)\b", s) and not re.search(r"\bend\s*$", s):
                    stack.append(s)
                elif re.match(r"^elsif\b", s) and stack:
                    stack[-1] = (stack[-1] or "") + " " + s
                elif re.match(r"^end\b", s) or s == "}":
                    if stack:
                        stack.pop()
                elif re.search(r"\bdo\s*(?:\|[^|]*\|)?\s*$|\{\s*(?:\|[^|]*\|)?\s*$", s) or s == "begin":
                    stack.append(None)
            continue
        carriers = [v for v in taint if _ref_word(v).search(body)]
        found = set()
        for v in carriers:
            found |= taint[v]
        if not found or _is_comment(lines[start - 1], family, start):
            continue
        guarded, presence, sanitisers = True, True, set()
        for a in found:
            names = [v for v, srcs in taint.items() if a in srcs]
            conds = [c for c in stack if c and any(_ref_word(v).search(c) for v in names)]
            ok, seen = _sanitised(body, [v for v in carriers if a in taint[v]])
            sanitisers |= seen
            if not (ok or any(VALIDATE.search(c) for c in conds)):
                guarded = False
            if not (PRESENCE.search(body) or conds):
                presence = False
        line = lines[start - 1]
        col = pos - (text.rfind("\n", 0, pos) + 1)
        q = _scan_quotes(line, col)[0]
        entry = per_line.setdefault(start, {"attrs": set(), "guarded": True, "presence": True,
                                           "quoted": True, "quotes": set(), "via": set(),
                                           "sanitisers": set()})
        entry["attrs"] |= found
        entry["guarded"] = entry["guarded"] and guarded
        entry["presence"] = entry["presence"] and presence
        entry["quoted"] = entry["quoted"] and bool(q)
        entry["quotes"].add(q)
        entry["via"] |= {v for v in carriers if v not in attrs}
        entry["sanitisers"] |= sanitisers
    out = []
    for start in sorted(per_line):
        e = per_line[start]
        parts = ["%s (%s)" % (a, attrs[a]) if attrs.get(a) else a for a in sorted(e["attrs"])]
        note = ", ".join(parts)
        if e["via"]:
            note += " via " + ", ".join(sorted(e["via"]))
        if yaml_paths is not None and start - 1 < len(yaml_paths) and yaml_paths[start - 1]:
            note += "; under " + ".".join(yaml_paths[start - 1])
        if e["sanitisers"]:
            note += "; sanitised by " + ", ".join(sorted(e["sanitisers"]))
        elif not e["guarded"]:
            note += "; " + NO_SANITISER_NOTE
        kind = "YAML" if yaml_paths is not None else "shell" if family == "shell" else None
        if e["quotes"] == {""}:
            note += "; unquoted"
        else:
            note += "; " + ("quoted" if e["quoted"] else "partly quoted") + \
                (" (%s)" % kind if kind else "")
            if kind == "shell" and '"' in e["quotes"]:
                note += ", still expands $(...)"
        out.append((start, sorted(e["attrs"]), e["guarded"], e["presence"], e["quoted"], note))
    return out


def _form_attrs(target, app_dir):
    """{attribute name: widget} from form.json's reading of the app's form;
    when the form does not parse (or its submit file is refused), the names
    from the line scan of the form file, widget None."""
    try:
        form = scan_form(target, app_dir)
    except Refused:
        form = None
    if form and not form["error"]:
        return {a["name"]: a["widget"] for a in form["attributes"]}
    rel = next((f for f in ("form.yml", "form.yml.erb") if os.path.lexists(os.path.join(app_dir, f))), None)
    if rel is None:
        return {}
    try:
        text = _read_fact(target, os.path.join(app_dir, rel), rel)
    except Refused:
        return {}
    attr_lines, form_lines = _attr_lines(strip_erb(text))
    return {n: None for n in list(attr_lines) + [f for f in form_lines if f not in attr_lines]}


def _shared_paths(target):
    """[(repo-relative path, reason or None)] for the root appverse.yml's
    shared_paths."""
    meta = _load_file(target, os.path.join(target, "appverse.yml"), "appverse.yml") or {}
    paths = meta.get("shared_paths")
    out = []
    for p in paths if isinstance(paths, list) else []:
        if not isinstance(p, str) or not p.strip():
            continue
        rel = os.path.normpath(p.strip()).replace(os.sep, "/")
        full = os.path.join(target, rel)
        if os.path.isabs(rel) or not _inside(target, full):
            out.append((rel, "shared path outside target, not read"))
        elif not os.path.lexists(full):
            out.append((rel, "shared path not found"))
        else:
            out.append((rel, None))
    return out


def _security_scope(app_dir, target, app_type, exclude):
    """(scope, {repo-relative path: absolute path}, [(path, reason)]).
    batch_connect: submit / form / connection files, template/**, container
    definitions (Dockerfile, Containerfile, *.def) anywhere in the app;
    any other type: every file in the app but docs, licences, images, fonts
    and lock files. Both add the root appverse.yml's shared_paths."""
    files, skipped = {}, []

    def walk(root, relroot, keep):
        found, rejected = _classify(root, exclude)
        for r, why in rejected.items():
            if why == OUTSIDE and _refusal(target, os.path.join(root, r)) in (None, TOO_LARGE):
                found.append(r)
            elif keep(r):
                skipped.append((relroot + r, why))
        for r in found:
            if keep(r):
                files[relroot + r] = os.path.join(root, r)

    prefix = _app_rel(app_dir, target)
    source = lambda r: not NOT_SOURCE.search(r) and not TEST_PATH.search(r)
    if app_type == "batch_connect":
        scope = "batch_connect"
        for name in BC_FILES:
            if os.path.lexists(os.path.join(app_dir, name)):
                files[prefix + name] = os.path.join(app_dir, name)
        tdir = os.path.join(app_dir, "template")
        if os.path.isdir(tdir) and _inside(target, tdir):
            walk(tdir, prefix + "template/", lambda r: True)
        elif os.path.lexists(tdir):
            skipped.append((prefix + "template", OUTSIDE if os.path.islink(tdir) else NOT_REGULAR))
        walk(app_dir, prefix, lambda r: bool(CONTAINER_DEF.search(r.rsplit("/", 1)[-1])))
    else:
        scope = "all_source"
        walk(app_dir, prefix, source)
    for rel, why in _shared_paths(target):
        full = os.path.join(target, rel)
        if why:
            skipped.append((rel, why))
        elif os.path.isdir(full) and not os.path.islink(full):
            walk(full, rel + "/", source)
        elif _refusal(target, full) in (None, TOO_LARGE):
            files[rel] = full
        else:
            skipped.append((rel, _refusal(target, full)))
    return scope, files, skipped


IMAGE_FONT_MAGIC = ((b"\x89PNG\r\n\x1a\n", "png"), (b"\xff\xd8\xff", "jpeg"), (b"GIF87a", "gif"),
                    (b"GIF89a", "gif"), (b"\x00\x00\x01\x00", "ico"), (b"wOFF", "woff"),
                    (b"wOF2", "woff2"), (b"\x00\x01\x00\x00", "ttf"), (b"OTTO", "otf"),
                    (b"true", "ttf"))
# The extensions a magic-byte kind may legitimately wear; a file whose bytes
# say font or image but whose name does not match is not exempted by magic
# alone (a renamed/disguised binary is still a candidate).
MAGIC_EXTS = {"png": (".png",), "jpeg": (".jpg", ".jpeg"), "gif": (".gif",),
              "ico": (".ico",), "woff": (".woff",), "woff2": (".woff2",),
              "ttf": (".ttf",), "otf": (".otf",)}


def _binary_kind(path):
    """None for a text file; the image / font type named by its magic bytes
    when the file's extension matches that type; else "binary" (including a
    magic match whose extension does not agree)."""
    with open(path, "rb") as f:
        head = f.read(8192)
    if b"\0" not in head:
        return None
    kind = next((k for magic, k in IMAGE_FONT_MAGIC if head.startswith(magic)), None)
    if kind is None:
        return "binary"
    ext = os.path.splitext(path)[1].lower()
    return kind if ext in MAGIC_EXTS.get(kind, ()) else "binary"


def _tool_path(path):
    """A tool's reported path as a repo-relative path: bandit writes
    ./template/proxy.py when run on ".", semgrep and shellcheck may too."""
    if not isinstance(path, str) or not path:
        return None
    path = posixpath.normpath(path.replace(os.sep, "/"))
    while path.startswith("./"):
        path = path[2:]
    return path


def _before_assigned(target, rel, cache):
    """Names assigned (NAME=..., with export/local/readonly/declare) in the
    before.sh* files beside rel (the same directory); read under the
    shell-file rule, so a refused file assigns nothing."""
    d = posixpath.dirname(rel)
    if d not in cache:
        names = set()
        full_dir = os.path.join(target, d) if target else None
        try:
            entries = sorted(os.listdir(full_dir)) if full_dir and _inside(target, full_dir) else []
        except OSError:
            entries = []
        for name in entries:
            if not re.match(r"^before\.sh", name):
                continue
            full = os.path.join(full_dir, name)
            if _refusal(target, full):
                continue
            try:
                text = _read(full)
            except (OSError, ValueError):
                continue
            for line in text.splitlines():
                m = SH_ASSIGN.match(line)
                if m:
                    names.add(m.group(1))
        cache[d] = names
    return cache[d]


def tool_artifact(target, rel, code, message, cache=None):
    """Whether a shellcheck finding is an artefact of linting OOD's job-script
    files one at a time (ARTIFACT_CODES, OOD_JOB_SCRIPT, OOD_CONTRACT_VARS)."""
    if code not in ARTIFACT_CODES or not isinstance(rel, str) or not OOD_JOB_SCRIPT.search(rel):
        return False
    if code == "SC2154":
        m = SC2154_VAR.match(message or "")
        if not m:
            return False
        name = m.group(1)
        return name in OOD_CONTRACT_VARS or name in _before_assigned(target, rel, {} if cache is None else cache)
    return True


def _load_tool_json(out, name, shape, notes):
    """The parsed <out>/<name>.json, or None when absent; when unreadable,
    not JSON, or not of shape (list or dict), None plus a note."""
    path = os.path.join(out, name + ".json")
    if not os.path.isfile(path):
        return None
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as e:
        notes.append("%s.json not read (%s)" % (name, type(e).__name__))
        return None
    if not isinstance(data, shape):
        notes.append("%s.json not read (expected a JSON %s)" % (name, "list" if shape is list else "object"))
        return None
    return data


def _int_line(value):
    return value if isinstance(value, int) and not isinstance(value, bool) and value > 0 else None


def _tool_finding_candidates(files, out, target=None, notes=None):
    """tool_finding candidates from shellcheck.json / semgrep.json /
    bandit.json in out (pre-review's out-dir), one per (tool, code, file),
    filtered to files (the app's security scope, {repo-relative: absolute});
    a tool's path is normalised first (a leading ./ dropped). shellcheck
    style level and semgrep INFO severity are excluded; bandit has no
    severity floor. A candidate is artifact true when every one of its
    findings is a tool_artifact. A tool file that cannot be read, or is not
    the JSON shape its tool writes, gives no candidates and a note in notes;
    an item that is not an object or has no positive integer line is
    skipped. lines holds at most TOOL_LINES_CAP entries (lines_total the
    full count when cut). out may be None (no tool-finding candidates then)."""
    notes = [] if notes is None else notes
    if not out:
        return []
    groups = {}  # (tool, code, file) -> {"lines": set, "level", "text", "artifact"}
    cache = {}
    skipped = {}

    def add(tool, code, path, line, level, text, artifact=False):
        rel, line = _tool_path(path), _int_line(line)
        if line is None or rel is None:
            skipped[tool] = skipped.get(tool, 0) + 1
            return
        if rel not in files:
            return
        g = groups.setdefault((tool, code, rel), {"lines": set(), "level": level, "text": text,
                                                  "artifact": True})
        g["lines"].add(line)
        g["artifact"] = g["artifact"] and artifact

    def text_of(value):
        return value if isinstance(value, str) else ""

    for item in _load_tool_json(out, "shellcheck", list, notes) or []:
        if not isinstance(item, dict):
            skipped["shellcheck"] = skipped.get("shellcheck", 0) + 1
            continue
        level = item.get("level")
        if level in SHELLCHECK_EXCLUDED_LEVELS:
            continue
        code, message = "SC%s" % item.get("code"), text_of(item.get("message"))
        rel = _tool_path(item.get("file"))
        add("shellcheck", code, rel, item.get("line"), level, message,
            tool_artifact(target, rel, code, message, cache))

    data = _load_tool_json(out, "semgrep", dict, notes)
    results = (data or {}).get("results") or []
    for r in results if isinstance(results, list) else []:
        if not isinstance(r, dict):
            skipped["semgrep"] = skipped.get("semgrep", 0) + 1
            continue
        extra = r.get("extra") if isinstance(r.get("extra"), dict) else {}
        if extra.get("severity") in SEMGREP_EXCLUDED_SEVERITIES:
            continue
        start = r.get("start") if isinstance(r.get("start"), dict) else {}
        add("semgrep", str(r.get("check_id")), r.get("path"), start.get("line"), extra.get("severity"),
            text_of(extra.get("message")))

    data = _load_tool_json(out, "bandit", dict, notes)
    results = (data or {}).get("results") or []
    for r in results if isinstance(results, list) else []:
        if not isinstance(r, dict):
            skipped["bandit"] = skipped.get("bandit", 0) + 1
            continue
        add("bandit", str(r.get("test_id")), r.get("filename"), r.get("line_number"),
            r.get("issue_severity"), text_of(r.get("issue_text")))

    for tool in ("shellcheck", "semgrep", "bandit"):
        if skipped.get(tool):
            notes.append("%s.json: %d item(s) with no file or line skipped" % (tool, skipped[tool]))

    def capped(cand):
        if len(cand["lines"]) > TOOL_LINES_CAP:
            cand["lines_total"] = len(cand["lines"])
            cand["lines"] = cand["lines"][:TOOL_LINES_CAP]
        return cand

    cands = []
    for (tool, code, rel), g in groups.items():
        lines = sorted(g["lines"])
        cands.append({"kind": "tool_finding", "check": "sec-tool-finding", "rule": None, "tag": None,
                      "tool": tool, "code": code, "file": rel, "lines": lines, "line": lines[0],
                      "level": g["level"], "text": g["text"].strip()[:TEXT_CAP], "note": "",
                      "artifact": g["artifact"]})
    cands.sort(key=lambda c: (c["file"], c["lines"][0], c["tool"], c["code"]))

    if len(cands) > TOOL_FINDING_CEILING:
        collapsed = {}
        for c in cands:
            key = (c["tool"], c["code"])
            if key not in collapsed:
                collapsed[key] = {"kind": "tool_finding", "check": "sec-tool-finding", "rule": None,
                                  "tag": None, "tool": c["tool"], "code": c["code"], "file": None,
                                  "lines": ["%s:%d" % (c["file"], n) for n in c["lines"]],
                                  "line": None, "level": c["level"], "text": c["text"], "note": "",
                                  "artifact": c["artifact"]}
            else:
                collapsed[key]["lines"].extend("%s:%d" % (c["file"], n) for n in c["lines"])
                collapsed[key]["artifact"] = collapsed[key]["artifact"] and c["artifact"]
        cands = sorted(collapsed.values(), key=lambda c: (c["tool"], c["code"]))
    return [capped(c) for c in cands]


def scan_security(app_dir, target, app_type, exclude=None):
    """security.json for one app directory, or None when nothing is in scope.
    Every in-scope file is read under the shell-file rule (refused files are
    listed in skipped_files); a binary under template/ is a
    binary_in_template candidate, elsewhere it is skipped. exclude doubles as
    the pre-review out-dir: when given, tool_finding candidates are read from
    its shellcheck.json / semgrep.json / bandit.json."""
    scope, files, skipped = _security_scope(app_dir, target, app_type, exclude)
    prefix = _app_rel(app_dir, target)
    attrs = _form_attrs(target, app_dir)
    tpl = prefix + "template/"
    cands, scanned, texts = [], [], {}

    def add(kind, rel, line, text, tag=None, rule=None, note="", **extra):
        check, krule, ktag = SEC_KIND[kind]
        cand = {"kind": kind, "check": check, "rule": rule or krule,
                "tag": tag if tag is not None else ktag, "file": rel, "line": line,
                "text": text.strip()[:TEXT_CAP], "note": note}
        cand.update(extra)
        cands.append(cand)

    for rel in sorted(files):
        full = files[rel]
        why = _refusal(target, full)
        bkind = _binary_kind(full) if rel.startswith(tpl) and why in (None, TOO_LARGE) else None
        if bkind == "binary":
            add("binary_in_template", rel, 1, "binary file (%d bytes)" % os.path.getsize(full),
                note="cannot be audited")
            continue
        if bkind:
            skipped.append((rel, "%s file (by its magic bytes), not a candidate" % bkind))
            continue
        if why:
            skipped.append((rel, why))
            continue
        raw = _read(full)
        if "\x00" in raw:
            skipped.append((rel, "binary file, not scanned"))
            continue
        scanned.append(rel)
        texts[rel] = raw
    for rel in scanned:
        raw = texts[rel]
        name = rel.rsplit("/", 1)[-1]
        family = _family(rel, strip_erb(raw) if rel.endswith(".erb") else raw)
        raw_lines = raw.split("\n")
        lines = ERB_COMMENT.sub(lambda m: "\n" * m.group(0).count("\n"), raw).split("\n")
        form_file = rel == prefix + name and name in FORM_FILES
        if attrs and rel.endswith(".erb") and (rel.startswith(tpl) or rel == prefix + "submit.yml.erb"):
            paths = _yaml_paths(strip_erb(raw).splitlines()) if not rel.startswith(tpl) else None
            for line, found, guarded, presence, quoted, note in _interpolations(raw, family, attrs, paths):
                add("interpolation", rel, line, raw_lines[line - 1], note=note, attributes=found,
                    guarded=guarded, presence_checked=presence, quoted=quoted)
        seen = set()
        for i, line in enumerate(lines):
            if not line.strip() or _is_comment(line, family, i + 1):
                continue
            code = _code_part(line, family)
            hits = _line_hits(code, family, urls=not (form_file or DEP_MANIFEST.search(rel)))
            if family != "shell":
                n = _subprocess_shell(lines, family, i)
                if n:
                    hits.append(("eval_exec", "command-injection", None,
                                 "subprocess call with shell=True (line %d)" % n))
            for kind, tag, rule, note in hits:
                if (i, kind, tag) in seen:
                    continue
                seen.add((i, kind, tag))
                add(kind, rel, i + 1, raw_lines[i], tag=tag, rule=rule, note=note)
    # unquoted_expansion: $VAR of a shell variable carrying a form attribute
    shell_tpl = [r for r in scanned if r.startswith(tpl) and
                 _family(r, strip_erb(texts[r]) if r.endswith(".erb") else texts[r]) == "shell"]
    if attrs and shell_tpl:
        taint = {}
        for r in shell_tpl:
            if r.endswith(".erb"):
                for var, srcs in _erb_taint(_erb_tags(texts[r]), list(attrs)).items():
                    taint[var] = taint.get(var, set()) | srcs
        carried = _shell_taint([texts[r] for r in shell_tpl if r.endswith(".erb")], taint)
        for r in shell_tpl:
            lines = texts[r].split("\n")
            for i, line in enumerate(lines):
                if _is_comment(line, "shell", i + 1) or re.match(r"^\s*(?:export\s+|local\s+)?\w+=\S*\s*$", line):
                    continue
                code = _code_part(line, "shell")
                for var, srcs in sorted(carried.items()):
                    for m in re.finditer(r"\$(?:\{%s\}|%s\b)" % (re.escape(var), re.escape(var)), code):
                        before, after = code[:m.start()], code[m.end():]
                        if _scan_quotes(code, m.start())[0] or ("[[" in before and "]]" in after):
                            continue
                        add("unquoted_expansion", r, i + 1, line,
                            note="$%s unquoted; carries %s" % (var, ", ".join(sorted(srcs))))
                        break
                    else:
                        continue
                    break
    order = {k: n for n, k in enumerate(SEC_KINDS)}
    cands.sort(key=lambda c: (c["file"], c["line"], order[c["kind"]]))
    tool_notes = []
    tool_cands = _tool_finding_candidates(files, exclude, target, tool_notes)
    collapsed = any(c.get("line") is None for c in tool_cands)
    cands = cands + tool_cands
    if not scanned and not cands and not skipped:
        return None
    counts = {k: sum(1 for c in cands if c["kind"] == k) for k in SEC_KINDS}
    if collapsed:
        counts["tool_finding_collapsed"] = True
    return {"counts": counts, "scope": scope, "files": scanned, "attributes": list(attrs),
            "candidates": cands, "tool_notes": tool_notes,
            "skipped_files": [{"file": f, "reason": r} for f, r in sorted(set(skipped))]}


def check_security(target, apps, out):
    results = {}

    def scan(app):
        results[app["app_id"]] = scan_security(app["_dir"], target, app["app_type"], out)
        return results[app["app_id"]]

    per_app, skip_notes, n = _app_fact("security", scan, ("batch_connect", "passenger", "companion",
                                                          "widget", "unknown"),
                                       NO_SCOPE, target, apps, out)
    notes = []
    for app in apps:
        app_id = app["app_id"]
        if per_app.get(app_id) == "ran":
            data = results[app_id]
            nz = ["%s %d" % (k, v) for k, v in data["counts"].items() if k in SEC_KINDS and v]
            text = ", ".join(nz) or "no candidates"
            if data["counts"].get("tool_finding_collapsed"):
                text += ("; more than %d tool-finding candidates, so they are collapsed to one per tool "
                         "and code" % TOOL_FINDING_CEILING)
            if data.get("tool_notes"):
                text += "; " + "; ".join(data["tool_notes"])
            notes.append("%s: %s" % (app_id, text))
        else:
            notes += [x for x in skip_notes if x.startswith(app_id + ": ")]
    return _fact_record("security", "candidate sites per kind (references/security-tools.md, "
                        "Candidate enumeration)", per_app, notes, n, "<app_id>/security.json")


def _origin_repo(target):
    """The reviewed repo's owner/repo from its git origin remote, or None."""
    try:
        r = subprocess.run(["git", "-C", target, "config", "--get", "remote.origin.url"],
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=10)
    except Exception:
        return None
    return catalog_facts.repo_key(r.stdout.strip()) if r.returncode == 0 else None


def _catalog_source(args):
    return args.catalog or os.environ.get("APPVERSE_CATALOG") or catalog_facts.DEFAULT_CATALOG


def check_catalog(args, target, apps, out):
    """Read the catalog and compare each app's declared software, app_type and
    implementation_tags with it (references/catalog_facts.py). Writes
    catalog.json (the comparison per app) and catalog-checks.md (the report's
    Catalog checks block, which the orchestrator pastes). Skipped with
    --no-catalog; a catalog that cannot be read in full is failed_to_run, and
    catalog-checks.md then says the checks were not run."""
    def write_block(lines):
        with open(os.path.join(out, "catalog-checks.md"), "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
    if args.no_catalog:
        write_block(catalog_facts.not_read_block("--no-catalog"))
        return record("catalog", "skipped", note="--no-catalog", output_file="catalog-checks.md")
    source = _catalog_source(args)
    try:
        cat = catalog_facts.read_catalog(source)
    except Exception as e:
        reason = ("%s: %s" % (type(e).__name__, e))[:STDERR_CHARS]
        write_block(catalog_facts.not_read_block("the catalog could not be read"))
        return record("catalog", "failed_to_run", command=source, output_file="catalog-checks.md",
                      note=reason)
    root_path = os.path.join(target, "appverse.yml")
    root_meta = _load_file(target, root_path, "appverse.yml")
    entries = {}
    if root_meta is None:
        shape = "unparsed" if os.path.lexists(root_path) else "inferred"
        root_meta = {}
    else:
        decl_apps = root_meta.get("apps")
        for e in decl_apps if isinstance(decl_apps, list) else []:
            if isinstance(e, dict) and isinstance(e.get("path"), str) and e["path"].strip():
                entries[os.path.normpath(e["path"].strip()).replace(os.sep, "/")] = e
        shape = "monorepo" if entries else "single"
    monorepo = shape == "monorepo"
    this_repo = _origin_repo(target)
    per_app, facts = [], []
    for app in apps:
        if app.get("_skip"):
            continue
        entry = entries.get(app["path"]) if monorepo else None
        sub = _load_file(target, os.path.join(app["_dir"], "appverse.yml"),
                         app["path"] + "/appverse.yml") if monorepo else None
        decl = catalog_facts.declared_values(root_meta, entry, sub, shape)
        res = catalog_facts.compare(cat, decl, this_repo)
        per_app.append((app["app_id"], res))
        facts.append({"app_id": app["app_id"], "declared": decl, "checks": res})
    _write_json(out, "catalog.json", {
        "schema": "catalog/1", "source": source, "pages": cat["pages"], "this_repo": this_repo,
        "counts": {k: len(cat[k]) for k in ("software", "app_types", "implementation_tags", "apps")},
        "app_types": cat["app_types"], "implementation_tags": cat["implementation_tags"],
        "apps": facts})
    write_block(catalog_facts.render(cat, per_app, monorepo))
    return record("catalog", "ran", command=source, output_file="catalog.json",
                  files_examined=sum(cat["pages"].values()),
                  note="%d apps, %d Software entries, %d app types, %d implementation tags" % (
                      len(cat["apps"]), len(cat["software"]), len(cat["app_types"]),
                      len(cat["implementation_tags"])))


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
    artefacts = rec.get("artifact_count") or 0
    return "%d finding%s (%s)%s" % (n, "" if n == 1 else "s",
                                   ", ".join(rec.get("top_codes") or []),
                                   ", %d of them linted in isolation from the job-script family" % artefacts
                                   if artefacts else "")


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
        if name.endswith(".json") or name in ("tool-table.md", "catalog-checks.md"):
            os.remove(os.path.join(out, name))
    shutil.rmtree(os.path.join(out, "stripped"), ignore_errors=True)


def main(argv):
    ap = argparse.ArgumentParser(
        prog="run-pre-review.sh",
        description="Run the static-analysis tools and the shell syntax check before the model.")
    ap.add_argument("target", help="app repo to check")
    ap.add_argument("out", help="directory for summary.json, syntax.json and the tool JSON")
    ap.add_argument("--catalog", metavar="URL",
                    help="Appverse catalog base URL, or a directory of catalog fixture JSON "
                         "(default: $APPVERSE_CATALOG, else %s)" % catalog_facts.DEFAULT_CATALOG)
    ap.add_argument("--no-catalog", action="store_true", help="skip catalog reads")
    args = ap.parse_args(argv)

    if not args.target or not os.path.isdir(args.target):
        print("error: target directory not found: %s" % args.target, file=sys.stderr)
        return 2
    try:
        load_placeholders()
    except PlaceholdersMissing as e:
        print("error: %s" % e, file=sys.stderr)
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

    try:
        apps = resolve_apps(target)
    except Exception as e:  # never fail the run: one unread root app
        apps = [{"app_id": "root", "path": ".", "app_type": "unknown", "readme": None, "_dir": None,
                 "_skip": ("app shape not resolved: %s: %s" % (type(e).__name__, e))[:STDERR_CHARS]}]
    checks.append(guarded("catalog", check_catalog, args, target, apps, out))
    _write_json(out, "apps.json", [_public(a) for a in apps])
    facts = [guarded("readme", check_readme, target, apps, out),
             guarded("form", check_form, target, apps, out),
             guarded("template", check_template, target, apps, out),
             guarded("entry_point", check_entry_point, target, apps, out),
             guarded("security", check_security, target, apps, out)]

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
