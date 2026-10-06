#!/usr/bin/env python3
"""Check that a review's meta.json carries what the artifact and the portal
need.

    python3 references/check-meta.py <meta.json>

The assembler builds the artifact from meta.json, and the portal refuses an
artifact without a reviewed commit. This checks the fields the model writes
(review-app SKILL.md section 5): recommendation.decision is one of the four
outcomes and recommendation.note is not empty; not_archived and public are
pass, fail or not checked (as the assembler reads them); apps is a non-empty list whose entries have an app_id
and a decision (one of the four outcomes; check-decisions.py reads them); and,
after stamp-meta.py, sha and repo_url are present.

Output: one MISSING or INVALID line per problem, then a summary line.
Exit 0 when complete, 1 when a field is missing or invalid, 2 when the file
cannot be read or is not a JSON object.
"""
import json
import sys

from report_parse import positional_args, normalize_decision


def main(argv):
    argv = positional_args(argv, ["meta.json"], description=(__doc__ or "").split("\n\n")[0])
    if isinstance(argv, int):
        return argv
    try:
        with open(argv[1], encoding="utf-8") as f:
            meta = json.load(f)
    except (OSError, ValueError) as e:
        print("error: cannot read meta.json %s (%s)" % (argv[1], e))
        return 2
    if not isinstance(meta, dict):
        print("error: meta.json is not a JSON object")
        return 2
    problems = []
    rec = meta.get("recommendation")
    if not isinstance(rec, dict):
        problems.append("MISSING meta field: recommendation (an object with decision and note)")
    else:
        d = rec.get("decision")
        if not isinstance(d, str) or not d.strip():
            problems.append("MISSING meta field: recommendation.decision")
        elif normalize_decision(d) is None:
            problems.append("INVALID meta field: recommendation.decision %r is not Accept, Accept with "
                            "suggestions, Request changes or Reject" % d)
        if not isinstance(rec.get("note"), str) or not rec["note"].strip():
            problems.append("MISSING meta field: recommendation.note (the Overall recommendation paragraph)")
    for key in ("not_archived", "public"):
        v = meta.get(key)
        if v is None:
            problems.append("MISSING meta field: %s (pass, fail or not checked)" % key)
        elif str(v).strip().lower().replace("_", " ") not in ("pass", "fail", "not checked"):
            problems.append("INVALID meta field: %s %r is not pass, fail or not checked" % (key, v))
    apps = meta.get("apps")
    if not isinstance(apps, list) or not apps:
        problems.append("MISSING meta field: apps (one entry per app)")
    else:
        for i, a in enumerate(apps):
            if not isinstance(a, dict) or not a.get("app_id"):
                problems.append("INVALID meta field: apps[%d] has no app_id" % i)
                continue
            d = a.get("decision")
            if not isinstance(d, str) or not d.strip():
                problems.append("MISSING meta field: apps[%d].decision (%s's Per-app decision, or the "
                                "recommendation for a single-app repo)" % (i, a["app_id"]))
            elif normalize_decision(d) is None:
                problems.append("INVALID meta field: apps[%d].decision %r is not Accept, Accept with "
                                "suggestions, Request changes or Reject" % (i, d))
    for key in ("sha", "repo_url"):
        if not meta.get(key):
            problems.append("MISSING meta field: %s (stamp-meta.py writes it)" % key)
    for p in problems:
        print(p)
    print("meta: %s" % ("complete" if not problems else "%d problem%s" % (len(problems), "" if len(problems) == 1 else "s")))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
