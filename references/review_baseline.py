#!/usr/bin/env python3
"""The baseline: the last review the hub sent to the contributor.

The workflow passes it in as a JSON document (environment variable
BASELINE_INPUT). This module validates it, decides what kind of review this
is relative to it, and owns the finding-ID derivation both sides share.

    BASELINE_INPUT='{...}' python3 references/review_baseline.py write \\
        <out.json> <target-sha>

`write` saves the validated baseline (plus `same_commit` and `comparable`)
to out.json and prints the repo's kind, `kind: plain|update|resubmission`,
followed by `, same commit` when the baseline was sent for this commit. A
malformed input is ignored with a `::warning::` line. Always exits 0: a bad
baseline must never fail the review.
"""

import hashlib
import json
import os
import re
import sys

import report_parse

DECISION_KIND = {
    "accept": "update",
    "accept_with_suggestions": "update",
    "request_changes": "resubmission",
    "reject": "resubmission",
}

_SHA = re.compile(r"[0-9a-fA-F]{7,40}")


def stable_id(finding):
    """Finding ID: first 16 hex of SHA-256 over app_id, rule, defect_key.

    `rule` may be null (the fields join as the string "None"); compute-ids.py
    and the hub must derive the same ID, so there is one implementation.
    """
    key = "{}\0{}\0{}".format(
        finding.get("app_id"), finding.get("rule"), finding.get("defect_key")
    )
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:16]


def _is_decision(value):
    # isinstance first: a list or object value is unhashable, so `in` on the dict raises.
    return isinstance(value, str) and value in DECISION_KIND


def _finding_problem(i, f):
    if not isinstance(f, dict):
        return "findings[{}] is not an object".format(i)
    for field in ("id", "app_id", "defect_key", "severity"):
        if not isinstance(f.get(field), str):
            return "findings[{}].{} is not a string".format(i, field)
    if "rule" not in f or not (f["rule"] is None or isinstance(f["rule"], str)):
        return "findings[{}].rule is not a string or null".format(i)
    if f.get("result") not in ("FAIL", "WARN"):
        return "findings[{}].result is not FAIL or WARN".format(i)
    if not isinstance(f.get("dismissed"), bool):
        return "findings[{}].dismissed is not a boolean".format(i)
    return None


def _problem(doc):
    if not isinstance(doc, dict):
        return "not a JSON object"
    sha = doc.get("sha")
    if not isinstance(sha, str) or not _SHA.fullmatch(sha):
        return "sha is not 7-40 hex characters"
    if not isinstance(doc.get("sent_at"), int) or isinstance(doc["sent_at"], bool):
        return "sent_at is not an integer"
    if not _is_decision(doc.get("recommendation")):
        return "recommendation is not a decision"
    apps = doc.get("apps")
    if not isinstance(apps, dict) or any(
        not isinstance(k, str) or not _is_decision(v) for k, v in apps.items()
    ):
        return "apps is not an object mapping app ids to decisions"
    if "findings" in doc:
        if not isinstance(doc["findings"], list):
            return "findings is not a list"
        for i, f in enumerate(doc["findings"]):
            problem = _finding_problem(i, f)
            if problem:
                return problem
    return None


def validate(raw, target_sha):
    """Return (doc, warning). Empty input is (None, None): no baseline."""
    if not raw or not raw.strip():
        return None, None
    try:
        doc = json.loads(raw)
    except ValueError as e:
        return None, "not valid JSON ({})".format(e)
    problem = _problem(doc)
    if problem:
        return None, problem
    a, b = target_sha.lower(), doc["sha"].lower()
    doc["same_commit"] = a.startswith(b) or b.startswith(a)
    doc["comparable"] = "findings" in doc
    return doc, None


def load(path):
    """Read a file `validate` wrote; None when there is no usable baseline."""
    if not path or not os.path.exists(path):
        return None
    try:
        with open(path) as f:
            doc = json.load(f)
        if not isinstance(doc, dict):
            raise ValueError("not a JSON object")
        return doc
    except (OSError, ValueError) as e:
        print(
            "warning: baseline {} unreadable ({}); treated as none".format(path, e),
            file=sys.stderr,
        )
        return None


def kind_for(app_id, baseline):
    """plain, update or resubmission for one app (or the repo, as "root")."""
    if not baseline:
        return "plain"
    apps = baseline.get("apps", {})
    if app_id in apps:
        return DECISION_KIND[apps[app_id]]
    if app_id in ("root", ""):
        return DECISION_KIND[baseline["recommendation"]]
    return "plain"


def _open_ids(findings):
    """Stable IDs of the current FAIL/WARN findings (PASS rows carry none)."""
    return {
        stable_id(f)
        for f in findings
        if str(f.get("result", "")).strip().upper() in ("FAIL", "WARN")
    }


def _baseline_entries(baseline):
    """Baseline findings by ID; empty when there is nothing to compare with."""
    if not baseline or not baseline.get("comparable"):
        return {}
    return {f["id"]: f for f in baseline["findings"]}


def statuses(findings, baseline):
    """{stable_id: "new" | "still_open"} for each current FAIL/WARN finding.

    IDs are derived from the current findings, never read from an `id` field:
    findings written during the review session have none yet.
    """
    if not baseline or not baseline.get("comparable"):
        return {}
    known = _baseline_entries(baseline)
    return {i: "still_open" if i in known else "new" for i in _open_ids(findings)}


def not_found(findings, baseline):
    """Baseline findings no longer present, in baseline order; dismissed ones
    are left out because the contributor already answered them."""
    if not baseline or not baseline.get("comparable"):
        return []
    current = _open_ids(findings)
    return [
        f for f in baseline["findings"] if f["id"] not in current and not f["dismissed"]
    ]


def dismissed_last_time(finding, baseline):
    """The finding is still open and the contributor dismissed it last time."""
    entry = _baseline_entries(baseline).get(stable_id(finding))
    return bool(entry and entry["dismissed"])


def reviewer_only(finding, baseline):
    """A still-open finding on an app that was already accepted, which does
    not set a decision floor: it stays in the full review but is not
    re-sent to the contributor."""
    return (
        stable_id(finding) in _baseline_entries(baseline)
        and kind_for(finding.get("app_id"), baseline) == "update"
        and not report_parse.sets_floor(finding)
    )


def feedback_findings(findings, baseline):
    """The fix-items the contributor feedback names."""
    return [
        f
        for f in findings
        if report_parse.is_fix_item(f) and not reviewer_only(f, baseline)
    ]


def greeting(baseline, name):
    """Opening line of the feedback; empty when nothing changed since the last send."""
    if baseline and baseline.get("same_commit"):
        return ""
    kind = kind_for("root", baseline)
    if kind == "update":
        return "Thank you for the update to {}.".format(name)
    if kind == "resubmission":
        return "Thank you for the updates to {}.".format(name)
    return "Thank you for submitting {} to Appverse.".format(name)


def reminder(findings, baseline):
    """One sentence pointing at the reviewer-only findings the feedback omits."""
    n = sum(1 for f in findings if reviewer_only(f, baseline))
    if n == 0:
        return ""
    if n == 1:
        return "One finding from the last review is still open; it is listed in the full review."
    return "{} findings from the last review are still open; they are listed in the full review.".format(n)


def main(argv):
    if len(argv) != 4 or argv[1] != "write":
        print("usage: review_baseline.py write <out.json> <target-sha>", file=sys.stderr)
        return 2
    out, target_sha = argv[2], argv[3]
    doc, warning = validate(os.environ.get("BASELINE_INPUT", ""), target_sha)
    if warning:
        print("::warning::baseline input ignored: {}".format(warning))
    if doc is None:
        print("kind: plain")
        return 0
    with open(out, "w") as f:
        json.dump(doc, f, indent=2)
        f.write("\n")
    print("kind: {}{}".format(kind_for("root", doc), ", same commit" if doc["same_commit"] else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
