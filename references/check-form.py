#!/usr/bin/env python3
"""Check that STR-04 and QUA-07 findings agree with the form attributes the
pre-review says OOD defines.

    python3 references/check-form.py <findings.json> <pre-review-dir>

Each app's <pre-review-dir>/<app_id>/form.json lists its form attributes;
`ood` is set ("auto", "builtin" or "global") for one OOD's dashboard defines
itself, and `widget` and `min` then carry OOD's defaults where the form sets
none. The model has called OOD's own attributes undefined, and its selects
free text. Reading STR-04 and QUA-07 records whose result is FAIL or WARN,
with the tag after the defect_key's first ":":

    MISMATCH <app_id> <key>: <result>, but form.json lists <attr> as one OOD defines (<kind>)
        an undefined-variable:<attr> or undefined-attribute:<attr> STR-04
        record for an attribute OOD defines.
    MISMATCH <app_id> <key>: <result>, but form.json has <attr> as a <widget>, which takes no free text
    MISMATCH <app_id> <key>: <result>, but form.json has <attr> as a number_field with min <n>
        a missing-pattern:<attr> QUA-07 record for an OOD attribute whose
        widget takes no free text, or a number field OOD gives a floor.

An app without form.json is not judged. Exit 0 when clean, 1 on any problem
line, 2 when the findings cannot be read. The last line is a summary.
"""
import json
import os
import sys

# The widgets row_candidates treats as taking no free text.
CONSTRAINED = {"select", "radio_button", "radio", "check_box", "checkbox", "hidden_field", "resolution_field"}
UNDEFINED_TAGS = ("undefined-variable:", "undefined-attribute:")
PATTERN_TAG = "missing-pattern:"


def tag_of(record):
    key = record.get("defect_key")
    return key.split(":", 1)[1] if isinstance(key, str) and ":" in key else ""


def load(path):
    with open(path) as f:
        return json.load(f)


def form_attrs(pre, app_id, cache):
    """{name: attribute} from the app's form.json, or None without one."""
    if app_id not in cache:
        path = os.path.join(pre, str(app_id), "form.json")
        try:
            form = load(path)
            cache[app_id] = {a["name"]: a for a in form.get("attributes") or [] if isinstance(a, dict)}
        except (OSError, ValueError, AttributeError, KeyError, TypeError):
            cache[app_id] = None
    return cache[app_id]


def problem(record, attrs):
    tag, result = tag_of(record), str(record.get("result", "")).strip().upper()
    head = "MISMATCH {} {}: {}, but form.json".format(record.get("app_id"), record.get("defect_key"), result)
    if record.get("rule") == "STR-04" and tag.startswith(UNDEFINED_TAGS):
        name = tag.split(":", 1)[1]
        a = attrs.get(name)
        if a and a.get("ood"):
            return "{} lists {} as one OOD defines ({})".format(head, name, a["ood"])
    elif record.get("rule") == "QUA-07" and tag.startswith(PATTERN_TAG):
        name = tag[len(PATTERN_TAG):]
        a = attrs.get(name)
        if a and a.get("ood"):
            if a.get("widget") in CONSTRAINED:
                return "{} has {} as a {}, which takes no free text".format(head, name, a["widget"])
            if a.get("widget") == "number_field" and a.get("min") is not None:
                return "{} has {} as a number_field with min {}".format(head, name, a["min"])
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
        if not isinstance(r, dict) or str(r.get("result", "")).strip().upper() not in ("FAIL", "WARN"):
            continue
        attrs = form_attrs(argv[2], r.get("app_id"), cache)
        line = problem(r, attrs) if attrs else None
        if line:
            lines.append(line)
    for line in lines:
        print(line)
    print("form: {} problems".format(len(lines)))
    return 1 if lines else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
