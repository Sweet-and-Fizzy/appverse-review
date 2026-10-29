#!/usr/bin/env python3
"""Check that the STR-01 license finding agrees with the license file the
pre-review found.

    python3 references/check-license.py <findings.json> <pre-review-dir>

The pre-review's license.json lists the repo's root license files as
GitHub's license detection (licensee) names and ranks them (`found`, best
first; `file` is the best, or null). Whether one holds an open-source
license stays the model's to judge. Reading only STR-01 FAIL records whose
tag (the defect_key after its first ":") is missing-license:

    MISMATCH <app_id> <key>: FAIL, but license.json finds <file> (key a FAIL for a license that is not open source on the file it reads)
        a FAIL keyed on a path that is none of the files found, which is
        how a review reports LICENSE missing when the license is LICENSE.txt.
    MISSING root LICENSE:missing-license (license.json finds no license file; record a STR-01 FAIL in place of any PASS with that key)
        no license file and no FAIL.

Without license.json (a pre-review from before this check) nothing is
judged. Exit 0 when clean or not judged, 1 on any problem line, 2 when an
input cannot be read or license.json is not the shape the pre-review writes. The last line is a summary.
"""
import json
import os
import sys

TAG = "missing-license"


def license_fails(findings):
    """(app_id, defect_key) of the STR-01 missing-license FAIL records."""
    out = []
    for r in findings:
        if not isinstance(r, dict) or r.get("rule") != "STR-01":
            continue
        if str(r.get("result", "")).strip().upper() != "FAIL":
            continue
        key = r.get("defect_key")
        if isinstance(key, str) and key.rpartition(":")[2] == TAG:
            out.append((r.get("app_id") or "root", key))
    return out


def problems(fact, fails):
    best, found = fact["file"], fact["found"]
    if not best:
        return [] if fails else [
            "MISSING root LICENSE:{} (license.json finds no license file; record a STR-01 FAIL in place of "
            "any PASS with that key)".format(TAG)]
    return ["MISMATCH {} {}: FAIL, but license.json finds {} (key a FAIL for a license that is not "
            "open source on the file it reads)".format(app_id, key, ", ".join(found))
            for app_id, key in fails if key.rpartition(":")[0] not in found]


def valid(fact):
    """Whether fact is the shape check_license writes."""
    return (isinstance(fact, dict) and (fact.get("file") is None or isinstance(fact.get("file"), str))
            and isinstance(fact.get("found"), list) and all(isinstance(n, str) for n in fact["found"])
            and (fact["file"] is None) == (not fact["found"]))


def load(path):
    with open(path) as f:
        return json.load(f)


def main(argv):
    if len(argv) != 3:
        print("usage: check-license.py <findings.json> <pre-review-dir>")
        return 2
    findings_path, pre = argv[1], argv[2]
    try:
        findings = load(findings_path)
        if not isinstance(findings, list):
            raise ValueError("not a list of findings")
    except (OSError, ValueError) as e:
        print("error: could not read {}: {}".format(findings_path, e))
        return 2
    fact_path = os.path.join(pre, "license.json")
    if not os.path.exists(fact_path):
        print("license: not judged (no license.json in {})".format(pre))
        return 0
    try:
        fact = load(fact_path)
    except (OSError, ValueError) as e:
        print("error: could not read {}: {}".format(fact_path, e))
        return 2
    if not valid(fact):
        print("error: {} is not a license/1 fact (file a string or null, found a list of names)".format(fact_path))
        return 2
    lines = problems(fact, license_fails(findings))
    for line in lines:
        print(line)
    print("license: {}, {} problems".format(fact.get("file") or "none", len(lines)))
    return 1 if lines else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
