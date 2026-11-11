#!/usr/bin/env python3
"""Check that a finding resting only on a static-tool result uses the rule
and tag security-tools.md gives the tool's code.

    python3 references/check-tools.py <findings.json> <pre-review-dir> [--tools-doc <security-tools.md>]

Each app's <pre-review-dir>/<app_id>/security.json lists its tool_finding
candidates (tool, code, file, lines). A FAIL or WARN record is a tool record
when its summary leads with a candidate's code, as a tool row's does
(`SC2164: ...`, `SC2148, SC2154: ...`, or a further `; B110: ...`), and
every citation in its evidence falls in such a candidate's file and lines:
the tool result is its only evidence. A code mentioned in passing does not
count. A record that also cites evidence of its
own is the review's finding, with the tool as corroboration, and is not
judged. For a tool record, with the tag after the defect_key's first ":":

    MISMATCH <app_id> <key>: <result> under <rule>, but its only evidence is <tool> <code>, which security-tools.md files under <rule> <tag>; re-key it as <rule> <anchor>:<tag>
        a code the "Tool finding codes: rule and tag" table lists, recorded
        under another rule or tag ({var_name} in a tag matches any name).
    MISMATCH <app_id> <key>: <result> under <OODT rule>, but its only evidence is shellcheck <code>, which security-tools.md does not file under a security rule; file it under the QUA rule its defect belongs to
        a shellcheck code the table does not list, recorded under an OODT
        rule. An unlisted bandit or semgrep code is the review's call, since
        most of their rules are security rules.

An app without security.json is not judged. Exit 0 when clean, 1 on any
problem line, 2 when the findings or the table cannot be read. The last line
is a summary.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from repo_paths import parse_citations  # noqa: E402

TOOLS_DOC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "security-tools.md")
TABLE_HEADING = "### Tool finding codes: rule and tag"
CELL_SPLIT_RE = re.compile(r"(?<!\\)\|")  # a cell may hold an escaped \|
CODE_RE = re.compile(r"^[A-Z]+[0-9]+$")
# The codes a summary leads with: at its start or after "; ", before a ":".
LEAD_RE = re.compile(r"(?:^|;)\s*([A-Za-z][\w.\-]*(?:\s*,\s*[A-Za-z][\w.\-]*)*)\s*:")
RULE_RE = re.compile(r"^[A-Z]+-[0-9]+$")
TAG_RE = re.compile(r"^`([^`]+)`$")


class TableError(Exception):
    pass


def load_table(path=TOOLS_DOC):
    """{code: (rule, tag)} from the doc's code table."""
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError as e:
        raise TableError("could not read {}: {}".format(path, e))
    start = text.find(TABLE_HEADING)
    if start < 0:
        raise TableError("{} has no '{}' section".format(path, TABLE_HEADING))
    table = {}
    for line in text[start:].splitlines()[1:]:
        if line.startswith("#"):
            break
        cells = [c.strip() for c in CELL_SPLIT_RE.split(line.strip().strip("|"))]
        if not CODE_RE.match(cells[0]):
            continue
        tag = TAG_RE.match(cells[3]) if len(cells) > 3 else None
        if not (RULE_RE.match(cells[2]) and tag):
            # A code row read wrong would turn that code into an unlisted one.
            raise TableError("{}: cannot read the rule and tag of the {} row".format(path, cells[0]))
        table[cells[0]] = (cells[2], tag.group(1))
    if not table:
        raise TableError("{}: the '{}' table has no rows".format(path, TABLE_HEADING))
    return table


def load(path):
    with open(path) as f:
        return json.load(f)


def candidates_of(pre, app_id, cache):
    """The app's tool_finding candidates, or None without a readable security.json."""
    if app_id not in cache:
        try:
            sec = load(os.path.join(pre, str(app_id), "security.json"))
            cands = sec.get("candidates") if isinstance(sec, dict) else None
            cache[app_id] = [dict(c, lines=lines_of(c)) for c in cands
                             if isinstance(c, dict) and c.get("kind") == "tool_finding"
                             and isinstance(c.get("code"), str) and isinstance(c.get("file"), str)
                             and lines_of(c)] if isinstance(cands, list) else None
        except (OSError, ValueError):
            cache[app_id] = None
    return cache[app_id]


def lines_of(cand):
    lines = cand.get("lines")
    if not isinstance(lines, list):
        lines = [cand.get("line")]
    return [n for n in lines if isinstance(n, int) and not isinstance(n, bool)]


def same_file(cited, cand_file, app_id):
    # Candidates are app-relative; a monorepo record may cite the repo path.
    # A single-app repo's paths are the repo's, so only an exact match counts.
    return cited == cand_file or (app_id != "root" and cited.endswith("/" + cand_file))


def tool_basis(record, cands):
    """The candidates a record rests on, when the tool result is its only
    evidence; [] otherwise."""
    summary = record.get("summary")
    if not isinstance(summary, str):
        return []
    led = {code.strip() for m in LEAD_RE.finditer(summary) for code in m.group(1).split(",")}
    named = [c for c in cands if c["code"] in led]
    if not named:
        return []
    cites = parse_citations(record.get("evidence"))
    if not cites:
        return []
    basis = []
    for path, nums in cites:
        here = [c for c in named if same_file(path, c["file"], record.get("app_id"))]
        if not here:
            return []
        lines = {n for c in here for n in c["lines"]}
        if any(n not in lines for n in nums):
            return []
        basis.extend(c for c in here if c not in basis and (not nums or set(nums) & set(c["lines"])))
    return basis


def tag_matches(tag, want):
    if "{" in want:
        return tag.split(":", 1)[0] == want.split(":", 1)[0]
    return tag == want


def problems(record, cands, table):
    anchor, _, tag = record["defect_key"].partition(":")
    rule = str(record.get("rule") or "").strip().upper()
    head = "MISMATCH {} {}: {} under {}, but its only evidence is".format(
        record.get("app_id"), record["defect_key"], record["result"], rule)
    out = []
    for code in dict.fromkeys(c["code"] for c in tool_basis(record, cands)):
        tool = next(c.get("tool") for c in cands if c["code"] == code)
        if code in table:
            want_rule, want_tag = table[code]
            if rule != want_rule or not tag_matches(tag, want_tag):
                shown = want_tag.replace("{var_name}", "<name>")
                out.append("{} {} {}, which security-tools.md files under {} {}; re-key it as {} {}:{}".format(
                    head, tool, code, want_rule, shown, want_rule, anchor, shown))
        elif tool == "shellcheck" and rule.startswith("OODT-"):
            out.append("{} shellcheck {}, which security-tools.md does not file under a security rule; "
                       "file it under the QUA rule its defect belongs to".format(head, code))
    return out


def main(argv):
    args = list(argv[1:])
    doc = TOOLS_DOC
    if "--tools-doc" in args:
        i = args.index("--tools-doc")
        if i + 1 >= len(args):
            print("usage: check-tools.py <findings.json> <pre-review-dir> [--tools-doc <security-tools.md>]")
            return 2
        doc = args[i + 1]
        del args[i:i + 2]
    if len(args) != 2:
        print("usage: check-tools.py <findings.json> <pre-review-dir> [--tools-doc <security-tools.md>]")
        return 2
    try:
        table = load_table(doc)
    except TableError as e:
        print("error: {}".format(e))
        return 2
    try:
        findings = load(args[0])
        if not isinstance(findings, list):
            raise ValueError("not a list of findings")
    except (OSError, ValueError) as e:
        print("error: could not read {}: {}".format(args[0], e))
        return 2
    cache, lines = {}, []
    for r in findings:
        if not isinstance(r, dict) or not isinstance(r.get("defect_key"), str) or ":" not in r["defect_key"]:
            continue
        if not isinstance(r.get("app_id"), str):
            continue
        result = str(r.get("result", "")).strip().upper()
        if result not in ("FAIL", "WARN"):
            continue
        cands = candidates_of(args[1], r.get("app_id"), cache)
        if not cands:
            continue
        lines.extend(problems(dict(r, result=result), cands, table))
    for line in lines:
        print(line)
    print("tools: {} problems".format(len(lines)))
    return 1 if lines else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
