#!/usr/bin/env python3
"""Decide the Draft feedback's items and write them as stubs for the model.

    python3 references/prepare-feedback.py <findings.json> <meta.json> \\
        <checks.json> <feedback.json>

Writes feedback.json: {"app_name", "opening", "items": [...]}, one item per
group of fix-items (report_parse.is_fix_item) with the same level, rule and
base tag. Each item has group, level, locations, defect_keys, summaries and
text. The model fills `opening` and each `text`; render-feedback.py builds
the section from the file. Everything else is regenerated on every run, so
the model never decides which findings get a sentence, how they group or
what level they are.

Level: Must fix when the finding sets a decision floor
(report_parse.sets_floor); otherwise Should fix at High or Medium and a
Suggestion at Low, raised to Should fix by checks.json's
feedback_levels.should_at_low. A failed meta gate (not_archived, public)
adds a Must fix item with fixed text, since it sets a floor with no finding.

Re-running merges with an existing feedback.json: `opening` carries over,
and an item's `text` carries over only when its group and its defect keys
are unchanged, so a sentence never names files its item no longer has.

Degraded input (unreadable meta, checks or feedback.json, non-string text)
prints a warning and still writes the file. Exit 2 only when the findings
cannot be read or the output cannot be written.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from report_parse import defect_tag, is_fix_item, sets_floor  # noqa: E402
from feedback_terms import evidence_locations, subject_words  # noqa: E402

LEVELS = ("must", "should", "suggestion")
SEVERITY_RANK = {"critical": 0, "high": 1, "medium": 2, "low": 3, "info": 4}
META_GATES = (
    ("not_archived", "The repository is archived on GitHub; unarchive it so the catalog can list it."),
    ("public", "The repository is not public; make it public so the catalog can read it."),
)


def warn(message):
    print("warning: " + message, file=sys.stderr)


def group_tag(defect_key):
    """The base tag items group on: the mechanism tag without its qualifier,
    except an `other:<slug>` tag, whose slug is the tag."""
    tag = defect_tag(defect_key)
    if tag != "other":
        return tag
    parts = str(defect_key).split(":", 1)[1].split(":")
    return "other:" + parts[1] if len(parts) > 1 else "other"


def level_of(finding, should_at_low):
    if sets_floor(finding):
        return "must"
    if str(finding.get("severity", "")).strip().lower() in ("critical", "high", "medium"):
        return "should"
    raised = should_at_low.get(str(finding.get("rule", "")).strip().upper(), [])
    if "*" in raised or group_tag(finding.get("defect_key")) in raised:
        return "should"
    return "suggestion"


def finding_locations(finding):
    """[(path or label, [lines])]: the cited files, or for a repo-level
    finding with no file the floor's subject words as one label, so the
    label alone satisfies check-feedback-floor.py."""
    locations = evidence_locations(finding.get("evidence"))
    if locations:
        return locations
    words = subject_words(finding.get("defect_key"))
    if not words:
        return []
    # A two-letter subject word is an initialism ("ci"), so it is written in
    # capitals; otherwise only the label's first letter is.
    words = [w.upper() if len(w) <= 2 else w for w in words]
    label = " ".join(words)
    return [(label[:1].upper() + label[1:], [])]


def location_pairs(locations):
    return {(path, line) for path, lines in locations for line in (lines or [None])}


def fold_targets(fix_items):
    """{id(finding): mixin} for each QUA-02 hardcoded-* finding whose cited
    lines all fall on its app's site-specific-mixin finding's lines: the
    mixin is the Not portable rating, and those are the values it is about,
    so they join its item instead of listing the same lines twice."""
    mixins = {}
    for f in fix_items:
        if str(f.get("rule", "")).upper() == "QUA-02" and group_tag(f.get("defect_key")) == "site-specific-mixin":
            mixins.setdefault(f.get("app_id"), f)
    folded = {}
    for f in fix_items:
        mixin = mixins.get(f.get("app_id"))
        if not mixin or str(f.get("rule", "")).upper() != "QUA-02":
            continue
        if not group_tag(f.get("defect_key")).startswith("hardcoded-"):
            continue
        mine = location_pairs(evidence_locations(f.get("evidence")))
        theirs = location_pairs(evidence_locations(mixin.get("evidence")))
        their_paths = {p for p, _ in theirs}
        if mine and all(pair in theirs or (pair[1] is None and pair[0] in their_paths) for pair in mine):
            folded[id(f)] = mixin
    return folded


def build_items(findings, meta, should_at_low):
    fix_items = [f for f in findings if isinstance(f, dict) and is_fix_item(f)]
    folded = fold_targets(fix_items)
    groups = {}
    for f in fix_items:
        owner = folded.get(id(f), f)
        level = level_of(owner, should_at_low)
        key = "{}:{}:{}".format(level, str(owner.get("rule", "")).strip().upper(), group_tag(owner.get("defect_key")))
        g = groups.setdefault(key, {"level": level, "rule": key.split(":")[1], "findings": []})
        g["findings"].append(f)
    items = []
    for key, g in groups.items():
        # A folded finding sorts after the mixin it joined, so the item leads
        # with the rating finding's own locations.
        g["findings"].sort(key=lambda f: id(f) in folded)
        merged = []
        index = {}
        for f in g["findings"]:
            for path, lines in finding_locations(f):
                if path not in index:
                    index[path] = len(merged)
                    merged.append((path, []))
                for line in lines:
                    if line not in merged[index[path]][1]:
                        merged[index[path]][1].append(line)
        # `text` follows `group` so the pair is a unique anchor for a model
        # filling the file with an exact-match edit; every item's text starts
        # out the same, so the text line alone is not.
        items.append({
            "group": key,
            "text": "",
            "level": g["level"],
            "locations": [p + (":" + ",".join(ls) if ls else "") for p, ls in merged],
            "defect_keys": [str(f.get("defect_key") or "") for f in g["findings"]],
            "summaries": [str(f.get("summary", "")) for f in g["findings"]],
            "_rank": (LEVELS.index(g["level"]),
                      min(SEVERITY_RANK.get(str(f.get("severity", "")).lower(), 4) for f in g["findings"]),
                      g["rule"], merged[0][0] if merged else ""),
        })
    for gate, text in META_GATES:
        if str(meta.get(gate, "")).strip().lower() == "fail":
            items.append({"group": "must:meta:" + gate, "text": text, "level": "must", "locations": [],
                          "defect_keys": [], "summaries": [],
                          "_rank": (0, SEVERITY_RANK["high"], "META", gate)})
    items.sort(key=lambda i: i["_rank"])
    for item in items:
        del item["_rank"]
    return items


def app_name(meta):
    apps = meta.get("apps") if isinstance(meta.get("apps"), list) else []
    if len(apps) == 1 and isinstance(apps[0], dict):
        return str(apps[0].get("name", ""))
    if len(apps) > 1:
        return str(meta.get("repo_url", "")).rstrip("/").rsplit("/", 1)[-1]
    return ""


def merge(items, old):
    """The feedback document: `items` with text carried over from `old`
    where the group and its defect keys are unchanged."""
    old = old if isinstance(old, dict) and isinstance(old.get("items"), list) else {}
    previous = {}
    for o in old.get("items", []):
        if isinstance(o, dict) and isinstance(o.get("group"), str):
            previous[o["group"]] = o
    for item in items:
        if item["group"].startswith("must:meta:"):
            continue
        o = previous.get(item["group"])
        keys = o.get("defect_keys") if o else None
        if o and isinstance(keys, list) and sorted(map(str, keys)) == sorted(item["defect_keys"]) \
                and isinstance(o.get("text"), str):
            item["text"] = o["text"]
    opening = old.get("opening")
    return {"opening": opening if isinstance(opening, str) else "", "items": items}


def load(path, what):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        warn("cannot read {} {} ({}); treated as absent".format(what, path, e))
        return None


def main(argv):
    if len(argv) != 5:
        print("usage: prepare-feedback.py <findings.json> <meta.json> <checks.json> <feedback.json>", file=sys.stderr)
        return 2
    findings_path, meta_path, checks_path, out_path = argv[1:]
    try:
        with open(findings_path, encoding="utf-8") as f:
            findings = json.load(f)
    except (OSError, ValueError) as e:
        print("error: cannot read findings {} ({})".format(findings_path, e), file=sys.stderr)
        return 2
    if not isinstance(findings, list):
        print("error: findings {} is not a JSON array".format(findings_path), file=sys.stderr)
        return 2
    meta = load(meta_path, "meta")
    if not isinstance(meta, dict):
        meta = {}
    checks = load(checks_path, "checks")
    should_at_low = (checks or {}).get("feedback_levels", {}).get("should_at_low", {}) \
        if isinstance(checks, dict) else {}
    old = load(out_path, "feedback") if os.path.exists(out_path) else None
    if old is not None and not (isinstance(old, dict) and isinstance(old.get("items"), list)):
        warn("feedback {} is not an object with an items list; treated as absent".format(out_path))
        old = None
    doc = merge(build_items(findings, meta, should_at_low), old)
    doc = {"app_name": app_name(meta), "opening": doc["opening"], "items": doc["items"]}
    try:
        tmp = out_path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(doc, f, indent=2, ensure_ascii=False)
            f.write("\n")
        os.replace(tmp, out_path)
    except OSError as e:
        print("error: cannot write {} ({})".format(out_path, e), file=sys.stderr)
        return 2
    print("prepare-feedback: {} items ({} with text)".format(
        len(doc["items"]), sum(1 for i in doc["items"] if i["text"])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
