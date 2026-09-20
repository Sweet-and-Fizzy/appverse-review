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


SCHEMA_VERSION = "1.1"

SOLID = "solid"
SOME_NOTES = "some_notes"
NEEDS_ATTENTION = "needs_attention"

SEVERITY_ORDER = ["critical", "high", "medium", "low", "info"]
SECURITY_ATTENTION_SEVERITIES = {"critical", "high", "medium"}

GRADE_LEVELS = {
    "documentation": {
        "minimal": NEEDS_ATTENTION,
        "adequate": SOME_NOTES,
        "strong": SOLID,
        "exemplary": SOLID,
    },
    "portability": {
        "not_portable": NEEDS_ATTENTION,
        "partially_portable": SOME_NOTES,
        "portable": SOLID,
    },
}

# A below-threshold finding beside a top grade means the aspect skill
# contradicted itself.
GRADE_RULES = {"documentation": "QUA-01", "portability": "QUA-02"}

# The report states signals as Low/Medium/High; the artifact level is the
# machine value behind each.
REPORTED_SIGNAL_LEVELS = {
    "low": SOLID,
    "medium": SOME_NOTES,
    "high": NEEDS_ATTENTION,
}

MAINTENANCE_ANCHOR = "#maintenance-signals"

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


def _warn(message):
    print("warning: {}".format(message), file=sys.stderr)


def _anchor(slug, app_index):
    # Every app repeats the same report headings; pandoc de-duplicates the
    # second and later occurrences as slug-1, slug-2, ...
    if app_index == 0:
        return "#{}".format(slug)
    return "#{}-{}".format(slug, app_index)


def _normalize_grade(grade):
    return str(grade).lower().strip().replace(" ", "_").replace("-", "_")


def derive_security_indicator(app_findings, app_index):
    # Findings carry no category field, so security findings are the OODT- rules.
    severities = [
        str(f.get("severity", "")).lower()
        for f in app_findings
        if f.get("rule", "").startswith("OODT-")
    ]
    if not severities:
        level = SOLID
        summary = "No security findings"
    else:
        if any(s in SECURITY_ATTENTION_SEVERITIES for s in severities):
            level = NEEDS_ATTENTION
        else:
            level = SOME_NOTES
        labels = SEVERITY_ORDER + sorted(set(severities) - set(SEVERITY_ORDER))
        summary = ", ".join(
            "{} {}".format(severities.count(s), s.capitalize())
            for s in labels
            if s in severities
        )
    return {"level": level, "summary": summary, "anchor": _anchor("security", app_index)}


def derive_grade_indicator(axis, app_id, assessments, app_findings, app_index):
    grade = assessments.get(axis)
    level = GRADE_LEVELS[axis].get(_normalize_grade(grade))
    if level is None:
        _warn("app '{}': unrecognized {} grade '{}'; indicator omitted".format(
            app_id, axis, grade))
        return None
    rule = GRADE_RULES[axis]
    if level == SOLID and any(f.get("rule") == rule for f in app_findings):
        _warn("app '{}': {} finding present but {} grade is '{}'".format(
            app_id, rule, axis, grade))
    return {
        "level": level,
        "summary": assessments.get("{}_summary".format(axis), ""),
        "anchor": _anchor(axis, app_index),
    }


def derive_maintenance_indicator(assessment, repo_findings):
    summary = assessment.get("summary", "")
    stale = any(f.get("rule") == "MNT-01" for f in repo_findings)
    waived = bool(assessment.get("waiver_brand_new"))
    if stale:
        level = NEEDS_ATTENTION
        if waived:
            _warn("MNT-01 finding contradicts the brand-new-app waiver; MNT-01 wins")
    elif waived:
        level = SOME_NOTES
        if "waiver" not in summary.lower():
            summary = "{} (brand-new-app waiver)".format(summary).strip()
    elif assessment.get("active_within_12mo"):
        # No open issues leaves issues_responded null, which counts in favor.
        good_signals = sum(
            1 for name, value in assessment.get("signals", {}).items()
            if value is True or (name == "issues_responded" and value is None)
        )
        level = SOLID if good_signals >= 2 else SOME_NOTES
    else:
        level = NEEDS_ATTENTION
    return {"level": level, "summary": summary, "anchor": MAINTENANCE_ANCHOR}


def cross_check_reported(scope, reported, indicators):
    for axis, stated in (reported or {}).items():
        expected = REPORTED_SIGNAL_LEVELS.get(str(stated).lower().strip())
        computed = indicators.get(axis, {}).get("level")
        if expected and computed and expected != computed:
            _warn("{}: report states {} signal '{}' but computed level is {}".format(
                scope, axis, stated, computed))


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
    apps_without_assessments = []
    for app_index, app_meta in enumerate(meta.get("apps", [])):
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

        # Indicators are all-or-nothing per app: without the quality grades a
        # lone security level would read as a complete assessment.
        assessments = app_meta.get("assessments")
        if assessments:
            indicators = {"security": derive_security_indicator(app_f, app_index)}
            for axis in ("portability", "documentation"):
                indicator = derive_grade_indicator(axis, app_id, assessments, app_f, app_index)
                if indicator:
                    indicators[axis] = indicator
            cross_check_reported(
                "app '{}'".format(app_id), app_meta.get("reported_signals"), indicators)
            app_entry["indicators"] = indicators
        else:
            apps_without_assessments.append(app_id)
        apps.append(app_entry)

    if apps_without_assessments:
        _warn("no assessments in meta for app(s) {}; indicators omitted".format(
            ", ".join(apps_without_assessments)))

    repo_level = {
        "findings": repo_findings,
        "criteria": repo_criteria,
    }
    maintenance_assessment = meta.get("maintenance_assessment")
    if maintenance_assessment:
        repo_indicators = {
            "maintenance": derive_maintenance_indicator(maintenance_assessment, repo_findings),
        }
        cross_check_reported(
            "repo",
            {"maintenance": maintenance_assessment.get("reported_signal")},
            repo_indicators)
        repo_level["indicators"] = repo_indicators
    else:
        _warn("no maintenance_assessment in meta; repo-level indicators omitted")

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
        "repo_level": repo_level,
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
