#!/usr/bin/env python3
"""Check that STR-02 findings agree with the app metadata the pre-review
resolved.

    python3 references/check-metadata.py <findings.json> <pre-review-dir>

The pre-review's metadata.json holds each app's catalog fields resolved the
way the hub's sync resolves them (metadata_facts.py), with the required fields
that are missing; catalog.json holds the catalog's verdict on each app's
app_type. The model judges STR-02 itself, and on a monorepo it has read the
wrong file (OOD's manifest.yml, or apps.json's app_type, which is OOD's kind
of app). Reading only STR-02 FAIL records, whose tag is the defect_key after
its first ":" (a leading "other:" is ignored, the form an earlier review used
before app-type-not-in-vocabulary joined the vocabulary):

    MISSING <app_id> missing-field:<field> (metadata.json lists it missing; record a STR-02 FAIL)
        a declared app's required field is missing and no FAIL says so. In a
        monorepo, one app_id "root" FAIL answers a maintainer field for every
        app when the root declares no maintainer and no app declares one.
    MISMATCH <app_id> missing-field:<field>: FAIL, but metadata.json resolves it from <source>
        a FAIL for a field the app has (one not in its missing list, or
        software when software_missing is false); for a
        monorepo "root" FAIL on a maintainer field, the root declares it.
    MISMATCH <app_id> missing-field:<field>: FAIL, but <field> is not a field the catalog requires
        a declared app's FAIL for a field outside the required set (role,
        implementation_tags): the catalog rejects nothing for it.
    MISMATCH <app_id> app-type-not-in-vocabulary: FAIL, but catalog.json lists '<value>' as a known app type

For an inferred app (no appverse.yml), a FAIL for a catalog-only field
(software, app_type, maintainer.name, maintainer.support_url) or an
app-type-not-in-vocabulary FAIL is a MISMATCH:

    MISMATCH <app_id> missing-field:<field>: FAIL, but the repo is inferred (no appverse.yml), and the catalog requires no <field> of it
    MISMATCH <app_id> app-type-not-in-vocabulary: FAIL, but the repo is inferred (no appverse.yml) and declares no catalog app_type

Its manifest.yml fields (name, category, role, description) stay the
rubric's to judge. Apps whose status is unparsed, refused or skipped
declare nothing to judge. Without catalog.json, or with no entry for an app,
the app_type rule is skipped. Without metadata.json (a pre-review from before
this check) nothing is judged.

Exit 0 when clean or not judged, 1 on any problem line, 2 when an input
cannot be read. The last line is a summary.
"""
import json
import os
import sys

MAINTAINER = ("maintainer.name", "maintainer.support_url")
# The fields the hub rejects an app without (metadata_facts.REQUIRED, plus
# software, which it reports on its own).
# Fields only appverse.yml declares. An inferred repo has none, and the hub
# lists its app without them (RepoSyncService::syncInferredMemberApp).
CATALOG_ONLY = ("software", "app_type", "maintainer.name", "maintainer.support_url")
CATALOG_REQUIRED = ("name", "description", "app_type", "software", "maintainer.name", "maintainer.support_url")
APP_TYPE_TAG = "app-type-not-in-vocabulary"


def tag_of(record):
    key = record.get("defect_key")
    if not isinstance(key, str) or ":" not in key:
        return ""
    tag = key.split(":", 1)[1]
    return tag[len("other:"):] if tag.startswith("other:") else tag


def str02_fails(findings):
    """{(app_id, tag)} of the STR-02 FAIL records."""
    out = set()
    for r in findings:
        if isinstance(r, dict) and r.get("rule") == "STR-02" and str(r.get("result", "")).strip().upper() == "FAIL":
            out.add((r.get("app_id"), tag_of(r)))
    return out


def is_missing(app, field):
    """Whether the fact lists field as missing for app. software is reported
    on its own (software_missing), not among the required fields."""
    if field == "software":
        return bool(app.get("software_missing"))
    return field in app["missing"]


def root_answers(fact, declared, field):
    """Whether one "root" record answers this maintainer field for every app:
    a monorepo whose root and apps declare no maintainer."""
    return (fact.get("shape") == "monorepo" and fact.get("root_maintainer") is None and declared
            and all(field in a["missing"] and a["fields"].get(field, {}).get("source") is None
                    for a in declared))


def problems(fact, catalog, fails):
    apps = fact.get("apps") or []
    by_id = {a["app_id"]: a for a in apps}
    declared = [a for a in apps if a.get("status") == "declared"]
    out = []
    for a in declared:
        aid = a["app_id"]
        for field in a["missing"]:
            tag = "missing-field:" + field
            if (aid, tag) in fails:
                continue
            if field in MAINTAINER and ("root", tag) in fails and root_answers(fact, declared, field):
                continue
            out.append("MISSING {} {} (metadata.json lists it missing; record a STR-02 FAIL)".format(aid, tag))
    verdicts = {}
    for c in (catalog or {}).get("apps") or []:
        if isinstance(c, dict):
            verdicts[c.get("app_id")] = ((c.get("checks") or {}).get("app_type") or {})
    root_maintainer = fact.get("root_maintainer") or {}
    for aid, tag in sorted(fails, key=lambda t: (str(t[0]), t[1])):
        app = by_id.get(aid)
        if app is not None and app.get("status") == "inferred":
            # The hub lists an inferred repo's app with no catalog fields of its
            # own; only the rubric's manifest.yml fields apply to it.
            if tag.startswith("missing-field:") and tag[len("missing-field:"):] in CATALOG_ONLY:
                field = tag[len("missing-field:"):]
                out.append("MISMATCH {} {}: FAIL, but the repo is inferred (no appverse.yml), and the catalog "
                           "requires no {} of it".format(aid, tag, field))
            elif tag == APP_TYPE_TAG:
                out.append("MISMATCH {} {}: FAIL, but the repo is inferred (no appverse.yml) and declares no "
                           "catalog app_type".format(aid, tag))
            continue
        if tag.startswith("missing-field:"):
            field = tag[len("missing-field:"):]
            if app is not None and app.get("status") == "declared" and not is_missing(app, field):
                if field not in CATALOG_REQUIRED:
                    out.append("MISMATCH {} {}: FAIL, but {} is not a field the catalog requires".format(
                        aid, tag, field))
                else:
                    source = app["fields"].get(field, {}).get("source")
                    out.append("MISMATCH {} {}: FAIL, but metadata.json resolves it from {}".format(aid, tag, source))
            elif app is None and aid == "root" and fact.get("shape") == "monorepo" and field in MAINTAINER \
                    and root_maintainer.get(field.split(".", 1)[1]):
                out.append("MISMATCH root {}: FAIL, but metadata.json resolves it from appverse.yml".format(tag))
        elif tag == APP_TYPE_TAG and app is not None and app.get("status") == "declared":
            verdict = verdicts.get(aid) or {}
            if verdict.get("status") == "known":
                out.append("MISMATCH {} {}: FAIL, but catalog.json lists '{}' as a known app type".format(
                    aid, tag, verdict.get("value")))
    return out


def load(path):
    with open(path) as f:
        return json.load(f)


def main(argv):
    if len(argv) != 3:
        print("usage: check-metadata.py <findings.json> <pre-review-dir>")
        return 2
    findings_path, pre = argv[1], argv[2]
    fact_path = os.path.join(pre, "metadata.json")
    try:
        findings = load(findings_path)
        if not isinstance(findings, list):
            raise ValueError("not a list of findings")
    except (OSError, ValueError) as e:
        print("error: could not read {}: {}".format(findings_path, e))
        return 2
    if not os.path.exists(fact_path):
        print("metadata: not judged (no metadata.json in {})".format(pre))
        return 0
    try:
        fact = load(fact_path)
        catalog_path = os.path.join(pre, "catalog.json")
        catalog = load(catalog_path) if os.path.exists(catalog_path) else None
    except (OSError, ValueError) as e:
        print("error: could not read the pre-review facts in {}: {}".format(pre, e))
        return 2
    lines = problems(fact, catalog, str02_fails(findings))
    for line in lines:
        print(line)
    print("metadata: {} apps, {} problems".format(len(fact.get("apps") or []), len(lines)))
    return 1 if lines else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
