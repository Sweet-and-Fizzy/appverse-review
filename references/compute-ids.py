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


def compute_id(finding):
    key = "{}\0{}\0{}".format(
        finding["app_id"],
        finding["rule"],
        finding["defect_key"],
    )
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:16]


def main():
    findings = json.load(sys.stdin)
    for f in findings:
        f["id"] = compute_id(f)
    json.dump(findings, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
