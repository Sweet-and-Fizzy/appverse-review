#!/usr/bin/env python3
"""Assemble the review artifact from metadata + findings.

The orchestrator emits two small JSON files:
  - review-<slug>.meta.json    (review context, recommendation, per-app decisions)
  - review-<slug>.findings.json (structured finding records from all aspects)

This script merges them into the full artifact envelope per ARTIFACT-SCHEMA.md,
splitting findings into repo-level vs per-app, deriving criteria from findings,
and adding the schema version and report paths.

Usage:
    python3 references/assemble-artifact.py \\
        --meta  review-owner-repo.meta.json \\
        --findings review-owner-repo.findings.json \\
        --md    review-owner-repo.md \\
        [--pdf  review-owner-repo.pdf] \\
        [--html review-owner-repo.html] \\
        [--plugin-version 0.3.0] \\
        > review-owner-repo.artifact.json

If --findings is omitted, the artifact is emitted with empty findings arrays.
If --plugin-version is omitted, it defaults to "unknown".
"""

import argparse
import json
import sys
from collections import defaultdict
from datetime import datetime, timezone


SCHEMA_VERSION = "1.0"

REPO_CRITERIA_MECHANISMS = {
    "missing-license": "license",
    "missing-readme": "readme_substantive",
    "readme-not-substantive": "readme_substantive",
}

PER_APP_CRITERIA_RULES = {
    "STR-02": "metadata",
    "STR-03": "yaml_valid",
    "STR-04": "references",
    "STR-07": "structure",
}


def _mechanism_tag(finding):
    dk = finding.get("defect_key", "")
    return dk.split(":")[-1] if ":" in dk else ""


def derive_repo_criteria(findings, meta):
    criteria = {
        "license": "pass",
        "readme_substantive": "pass",
    }
    archived = meta.get("not_archived")
    if archived is not None:
        criteria["not_archived"] = archived
    for f in findings:
        tag = _mechanism_tag(f)
        if tag in REPO_CRITERIA_MECHANISMS:
            criteria[REPO_CRITERIA_MECHANISMS[tag]] = "fail"
    return criteria


def derive_app_criteria(app_findings):
    criteria = {
        "metadata": "pass",
        "yaml_valid": "pass",
        "structure": "pass",
        "references": "pass",
    }
    for f in app_findings:
        rule = f.get("rule", "")
        if rule in PER_APP_CRITERIA_RULES:
            criteria[PER_APP_CRITERIA_RULES[rule]] = "fail"
    return criteria


def split_findings_by_app(findings):
    by_app = defaultdict(list)
    repo_level = []
    for f in findings:
        rule = f.get("rule", "")
        if rule.startswith("MNT-"):
            repo_level.append(f)
        else:
            app_id = f.get("app_id", "root")
            by_app[app_id].append(f)
    return repo_level, dict(by_app)


def normalize_decision(decision_text):
    mapping = {
        "accept": "accept",
        "accept with suggestions": "accept_with_suggestions",
        "request changes": "request_changes",
        "reject": "reject",
    }
    return mapping.get(decision_text.lower().strip(), decision_text.lower().strip().replace(" ", "_"))


def assemble(meta, findings, md_path, pdf_path, html_path, plugin_version):
    repo_findings, app_findings_map = split_findings_by_app(findings)
    repo_criteria = derive_repo_criteria(findings, meta)

    recommendation = meta.get("recommendation", {})
    if isinstance(recommendation.get("decision"), str):
        recommendation["decision"] = normalize_decision(recommendation["decision"])

    apps = []
    for app_meta in meta.get("apps", []):
        app_id = app_meta.get("app_id", "root")
        app_f = app_findings_map.get(app_id, [])
        app_entry = {
            "app_id": app_id,
            "name": app_meta.get("name", app_id),
            "findings": app_f,
            "criteria": derive_app_criteria(app_f),
        }
        if "decision" in app_meta:
            app_entry["decision"] = normalize_decision(app_meta["decision"])
        apps.append(app_entry)

    if not apps and app_findings_map:
        for app_id, app_f in app_findings_map.items():
            apps.append({
                "app_id": app_id,
                "name": app_id,
                "findings": app_f,
                "criteria": derive_app_criteria(app_f),
            })

    artifact = {
        "schema_version": SCHEMA_VERSION,
        "reviewed": {
            "repo_url": meta.get("repo_url", ""),
            "sha": meta.get("sha", ""),
            "ref": meta.get("ref", ""),
            "at": meta.get("at", datetime.now(timezone.utc).isoformat()),
            "tool_version": "appverse-review@{}".format(plugin_version),
            "repo_shape": meta.get("repo_shape", "unknown"),
        },
        "recommendation": recommendation,
        "repo_level": {
            "findings": repo_findings,
            "criteria": repo_criteria,
        },
        "apps": apps,
        "artifacts": {
            "report_md": md_path or "",
            "report_pdf": pdf_path or "",
            "report_html": html_path or "",
        },
        "run_meta": {
            "model": meta.get("model", "unknown"),
        },
    }

    return artifact


def main():
    parser = argparse.ArgumentParser(description="Assemble review artifact")
    parser.add_argument("--meta", required=True, help="Path to review metadata JSON")
    parser.add_argument("--findings", help="Path to findings JSON")
    parser.add_argument("--md", help="Path to markdown report")
    parser.add_argument("--pdf", help="Path to PDF report")
    parser.add_argument("--html", help="Path to HTML report (stable anchors)")
    parser.add_argument("--plugin-version", default="unknown")
    args = parser.parse_args()

    with open(args.meta) as f:
        meta = json.load(f)

    findings = []
    if args.findings:
        try:
            with open(args.findings) as f:
                findings = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError) as e:
            print("warning: could not load findings: {}".format(e), file=sys.stderr)

    artifact = assemble(meta, findings, args.md, args.pdf, args.html, args.plugin_version)
    json.dump(artifact, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
