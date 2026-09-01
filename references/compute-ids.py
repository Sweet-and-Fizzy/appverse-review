#!/usr/bin/env python3
"""Compute stable finding IDs from identity fields.

Reads a findings JSON array from stdin, adds an `id` field to each finding,
and writes the result to stdout.

    python3 references/compute-ids.py < findings.json
    python3 references/compute-ids.py < findings.json > findings-with-ids.json

The ID is the first 16 hex characters of SHA-256 over the three identity
fields joined by NUL bytes:

    id = sha256(app_id + "\\0" + rule + "\\0" + defect_key)[:16]

See finding-codes.md for the full identity design.
"""

import hashlib
import json
import sys

IDENTITY_FIELDS = ("app_id", "rule", "defect_key")


def compute_id(finding, index):
    for field in IDENTITY_FIELDS:
        if field not in finding:
            print(
                "error: finding #{} missing required field '{}': {}".format(
                    index, field, json.dumps(finding, default=str)[:120]
                ),
                file=sys.stderr,
            )
            sys.exit(1)
    key = "{}\0{}\0{}".format(
        finding["app_id"],
        finding["rule"],
        finding["defect_key"],
    )
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:16]


def main():
    findings = json.load(sys.stdin)

    seen_ids = {}
    for i, f in enumerate(findings):
        fid = compute_id(f, i)
        f["id"] = fid
        if fid in seen_ids:
            prior = seen_ids[fid]
            print(
                "warning: duplicate ID {} — finding #{} ({}) collides with "
                "finding #{} ({})".format(
                    fid, i, f.get("defect_key", "?"), prior[0], prior[1]
                ),
                file=sys.stderr,
            )
        else:
            seen_ids[fid] = (i, f.get("defect_key", "?"))

    json.dump(findings, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
