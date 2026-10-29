#!/usr/bin/env python3
"""Check that STR-04 and QUA-07 findings agree with the form attributes the
pre-review says OOD builds.

    python3 references/check-form.py <findings.json> <pre-review-dir>

Each app's <pre-review-dir>/<app_id>/form.json lists its form attributes.
OOD builds every attribute listed under `form:` (`in_form`), whether or not
it has an `attributes:` entry (one without is a text_field); `ood` is set
("auto", "builtin" or "global") for one OOD's dashboard defines itself.
The model has called such attributes undefined, and has asked for bounds
on OOD's own fields, which numeric-field-bounds does not judge. Reading
STR-04 and QUA-07 records whose result is FAIL or WARN, with the tag after
the defect_key's first ":":

    MISMATCH <app_id> <key>: <result>, but form.json lists <attr> under form:, so OOD builds it (<what>)
        an undefined-variable:<attr> or undefined-attribute:<attr> STR-04
        record for an attribute in form:.
    MISMATCH <app_id> <key>: <result>, but <attrs> is an attribute OOD defines and bounds itself (...); remove the record
    MISMATCH <app_id> <key>: <result>, but <attrs> are attributes OOD defines and bounds itself (...); drop them from the record and its row and keep <others>
        a missing-min, missing-pattern or missing-min-max QUA-07 record
        about OOD's attributes: the attribute its tag names
        (missing-pattern:<attr>), or else each one whose form.json line the
        evidence cites in the form file.

An app without form.json is not judged. Exit 0 when clean, 1 on any problem
line, 2 when the findings cannot be read. The last line is a summary.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from repo_paths import parse_citations  # noqa: E402

UNDEFINED_TAGS = ("undefined-variable", "undefined-attribute")
BOUNDS_TAGS = ("missing-min", "missing-pattern", "missing-min-max")
WHAT = {"auto": "an auto attribute", "builtin": "a built-in attribute", "global": "a global attribute"}


def load(path):
    with open(path) as f:
        return json.load(f)


def form_of(pre, app_id, cache):
    """The app's form.json, or None without a readable one."""
    if app_id not in cache:
        try:
            form = load(os.path.join(pre, str(app_id), "form.json"))
            cache[app_id] = form if isinstance(form, dict) and isinstance(form.get("attributes"), list) else None
        except (OSError, ValueError):
            cache[app_id] = None
    return cache[app_id]


def cited_attrs(record, form):
    """The attributes whose form-file line the record's evidence cites."""
    ffile = form.get("file") or "form.yml"
    lines = set()
    for path, nums in parse_citations(record.get("evidence")):
        if path == ffile or path.endswith("/" + ffile):
            lines.update(nums)
    return [a for a in form["attributes"] if isinstance(a, dict) and a.get("line") in lines]


def problem(record, form):
    attrs = {a.get("name"): a for a in form["attributes"] if isinstance(a, dict)}
    base, _, qual = record["tag"].partition(":")
    head = "MISMATCH {} {}: {}, but".format(record.get("app_id"), record.get("defect_key"), record["result"])
    if record.get("rule") == "STR-04" and base in UNDEFINED_TAGS and qual:
        a = attrs.get(qual)
        if a and a.get("in_form"):
            return "{} form.json lists {} under form:, so OOD builds it ({})".format(
                head, qual, WHAT.get(a.get("ood"), "a " + str(a.get("widget") or "text_field")))
    elif record.get("rule") == "QUA-07" and base in BOUNDS_TAGS:
        about = [attrs[qual]] if qual in attrs else cited_attrs(record, form)
        ood = [a["name"] for a in about if a.get("ood")]
        rest = [a["name"] for a in about if not a.get("ood")]
        if ood and not rest:
            return "{} {} {} OOD defines and bounds itself (numeric-field-bounds does not judge {}); " \
                   "remove the record".format(head, ", ".join(ood),
                                              "is an attribute" if len(ood) == 1 else "are attributes",
                                              "it" if len(ood) == 1 else "them")
        if ood:
            return "{} {} are attributes OOD defines and bounds itself (numeric-field-bounds does not judge " \
                   "them); drop them from the record and its row and keep {}".format(
                       head, ", ".join(ood), ", ".join(rest))
    return None


def main(argv):
    if len(argv) != 3:
        print("usage: check-form.py <findings.json> <pre-review-dir>")
        return 2
    try:
        findings = load(argv[1])
        if not isinstance(findings, list):
            raise ValueError("not a list of findings")
    except (OSError, ValueError) as e:
        print("error: could not read {}: {}".format(argv[1], e))
        return 2
    cache, lines = {}, []
    for r in findings:
        if not isinstance(r, dict) or not isinstance(r.get("defect_key"), str) or ":" not in r["defect_key"]:
            continue
        result = str(r.get("result", "")).strip().upper()
        if result not in ("FAIL", "WARN"):
            continue
        form = form_of(argv[2], r.get("app_id"), cache)
        if form is None:
            continue
        line = problem(dict(r, tag=r["defect_key"].split(":", 1)[1], result=result), form)
        if line:
            lines.append(line)
    for line in lines:
        print(line)
    print("form: {} problems".format(len(lines)))
    return 1 if lines else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
