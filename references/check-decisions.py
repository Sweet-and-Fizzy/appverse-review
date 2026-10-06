#!/usr/bin/env python3
"""Check that each decision is at least as severe as the review's findings call for.

    python3 references/check-decisions.py <meta.json> <findings.json>

The severity scale (finding-codes.md) maps a FAIL to a decision floor: High
warrants Request changes and Critical warrants Reject. Only the findings the
decision rubric treats as blocking set a floor; documentation, portability
and code-quality findings never do, since below-target ratings are Accept
with suggestions:

  - A security FAIL (aspect "security", or an OODT rule) at High or Critical
    sets the floor for every app, wherever in the repo it was found.
    Installing any one app clones the whole repo (review-rubric.md, Repo
    shapes).
  - A structure gate FAIL (an STR rule) or the upkeep gate (MNT-01) at High
    or Critical sets the floor for its own app, or for every app when the
    finding is repo-level (its app_id is not one of meta.json's apps, as
    "root" is in a monorepo).
  - A failed repo gate in meta.json (not_archived or public is "fail") sets
    Request changes for every app.
  - The recommendation is held to every repo-wide floor, and in a monorepo to
    the strictest per-app decision (it rolls them up).

Severity and result are read case-insensitively. A decision may be stricter
than its floor; only a milder one is reported. Missing or unknown decisions
are check-meta.py's to report, so they are skipped here.

Output: one MISMATCH line per decision below its floor, then a summary line.
Exit 0 when every decision meets its floor, 1 when one does not, 2 when an
input cannot be read.
"""
import json
import sys

from report_parse import positional_args, DECISIONS, DECISION_NAMES, decision_rank as rank

NAME = {i: DECISION_NAMES[d] for i, d in enumerate(DECISIONS)}
FLOOR = {"high": DECISIONS.index("request changes"), "critical": DECISIONS.index("reject")}


def load(path, what):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        print("error: cannot read %s %s (%s)" % (what, path, e))
        return None


def main(argv):
    argv = positional_args(argv, ["meta.json", "findings.json"], description=(__doc__ or "").split("\n\n")[0])
    if isinstance(argv, int):
        return argv
    meta = load(argv[1], "meta.json")
    findings = load(argv[2], "findings.json")
    if meta is None or findings is None:
        return 2
    if isinstance(findings, dict):
        findings = findings.get("findings")
    if not isinstance(meta, dict) or not isinstance(findings, list):
        print("error: meta.json must be an object and findings.json a list of findings")
        return 2

    apps = [a for a in meta.get("apps") or [] if isinstance(a, dict) and a.get("app_id")]
    app_ids = {a["app_id"] for a in apps}

    # The worst floor per target: an app_id, or "*" for every app.
    floors = {}

    def raise_floor(target, floor, reason):
        if target not in floors or floor > floors[target][0]:
            floors[target] = (floor, reason)

    for f in findings:
        if not isinstance(f, dict) or str(f.get("result", "")).strip().upper() != "FAIL":
            continue
        floor = FLOOR.get(str(f.get("severity", "")).strip().lower())
        if floor is None:
            continue
        rule = str(f.get("rule", "")).strip().upper()
        security = str(f.get("aspect", "")).strip().lower() == "security" or rule.startswith("OODT")
        if not (security or rule.startswith("STR") or rule == "MNT-01"):
            continue
        repo_wide = security or f.get("app_id") not in app_ids
        reason = "%s %s FAIL at %s%s" % (
            f.get("rule", "?"), str(f.get("severity")).strip().lower(), f.get("evidence", "?"),
            " (applies to every app)" if repo_wide and len(apps) > 1 else "")
        raise_floor("*" if repo_wide else f["app_id"], floor, reason)
    for gate in ("not_archived", "public"):
        if str(meta.get(gate, "")).strip().lower() == "fail":
            raise_floor("*", DECISIONS.index("request changes"), "the %s gate FAIL in meta.json" % gate)

    problems = []
    for a in apps:
        have = rank(a.get("decision"))
        if have is None:
            continue
        # The stricter of the repo-wide floor and the app's own, so one repair
        # reaches the right decision instead of climbing one floor per round.
        applicable = [floors[t] for t in ("*", a["app_id"]) if t in floors]
        if applicable:
            floor, reason = max(applicable, key=lambda x: x[0])
            if have < floor:
                problems.append("MISMATCH decision %s: %s, but %s needs at least %s"
                                % (a["app_id"], NAME[have], reason, NAME[floor]))
    rec = meta.get("recommendation") if isinstance(meta.get("recommendation"), dict) else {}
    have = rank(rec.get("decision"))
    if have is not None:
        need = [floors["*"]] if "*" in floors else []
        ranked = [(rank(a.get("decision")), a["app_id"]) for a in apps]
        ranked = [r for r in ranked if r[0] is not None]
        if len(apps) > 1 and ranked:
            top, app_id = max(ranked)
            need.append((top, "%s's Per-app decision (the recommendation rolls them up)" % app_id))
        if need:
            floor, reason = max(need, key=lambda x: x[0])
            if have < floor:
                problems.append("MISMATCH decision recommendation: %s, but %s needs at least %s"
                                % (NAME[have], reason, NAME[floor]))

    for p in problems:
        print(p)
    print("decisions: %d app%s against %d High/Critical floor%s, %d problem%s" % (
        len(apps), "" if len(apps) == 1 else "s", len(floors), "" if len(floors) == 1 else "s",
        len(problems), "" if len(problems) == 1 else "s"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
