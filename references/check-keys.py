#!/usr/bin/env python3
"""Validate every finding's defect_key so its stable ID is stable.

    python3 references/check-keys.py review-<slug>.findings.json [--target <repo-dir>]

A key is "{anchor}:{tag}". The anchor must be a repo-relative path that
exists under --target (when given) or one of the allowed pseudo-anchors.
An absent-file tag (ABSENT_FILE_ANCHORS) instead takes its fixed expected
anchor, which must be "<app_id>/<anchor>" in a monorepo, and existence is not
checked; missing-entry-point takes "root", or the app subpath itself in a
monorepo. The tag must be in the rule's vocabulary (finding-codes.md), carrying
its qualifier where the vocabulary shows one, or "other:<slug>" where the slug
is neither a vocabulary tag in disguise nor one extended by a suffix. A
FAIL or WARN record whose evidence cites file:line groups, none of them in
its anchor file (or under it, for a directory anchor; in a monorepo a
citation relative to the app counts), is INVALID "(evidence does not cite
the anchor file)": the key then names a different place than the evidence.
Pseudo-anchors, absent-file tags and evidence with no citation are exempt.
Exit 0 when every key is valid, 1 when any is not (one INVALID line each),
2 when the input cannot be read.
"""
import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from repo_paths import PSEUDO_ANCHORS, exists_case_exact, parse_citations  # noqa: E402

# Absent-file tags (STR-01, STR-07, MNT-03): the file does not exist by
# definition, so the anchor is the fixed expected path, prefixed with the
# app_id in a monorepo. Keep in step with finding-codes.md.
# missing-license and missing-readme are not here: LICENSE and README.md are
# pseudo-anchors already, and STR-01 also covers an insufficient file that
# exists under another name (LICENSE.txt), which keeps its real path.
# missing-readme is repo-level only, even in a monorepo (special-cased in
# validate() beside missing-entry-point): a per-app README falls back to the
# root README, so the anchor is always the bare README.md.
ABSENT_FILE_ANCHORS = {
    "missing-manifest": ("manifest.yml",),
    "missing-appverse-yml": ("appverse.yml",),
    "missing-form": ("form.yml",),
    "missing-template-dir": ("template",),
    "missing-submit-yml": ("submit.yml.erb",),
    # One anchor for the app whichever entry point (Batch Connect script,
    # Rack, WSGI) it lacks: "root", or the app subpath itself in a monorepo
    # (special-cased in validate(); the <app_id>/<anchor> rule does not apply).
    "missing-entry-point": ("root",),
    # One key whether or not a CHANGELOG exists.
    "no-changelog": ("CHANGELOG.md",),
}
FINDING_CODES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "finding-codes.md")
RULE_HEADING = re.compile(r"^\*\*([A-Z]{3,4}-\d{2}):\*\*\s*$")
TAG_TOKEN = re.compile(r"`([^`]+)`")


def load_vocabulary(path=FINDING_CODES):
    """Return {rule: {tag_base: requires_qualifier}} from the mechanism-tag sections."""
    vocab = {}
    current = None
    try:
        with open(path) as f:
            for line in f:
                m = RULE_HEADING.match(line.strip())
                if m:
                    current = m.group(1)
                    vocab.setdefault(current, {})
                    continue
                if current is None:
                    continue
                if not line.strip() or line.startswith("#") or line.startswith("|"):
                    current = None  # a rule's block is the contiguous lines under its heading
                    continue
                for tok in TAG_TOKEN.findall(line):
                    base, _, qual = tok.partition(":")
                    # Sticky: once a base is seen requiring a qualifier (its
                    # "{qualifier}" form), later concrete examples of that
                    # same base (e.g. "missing-field:software") must not
                    # un-require it.
                    vocab[current][base] = vocab[current].get(base, False) or qual.startswith("{")
    except OSError as e:
        print("error: cannot read {}: {}".format(path, e), file=sys.stderr)
        sys.exit(2)
    return vocab


def norm(s):
    return re.sub(r"[-_]", "", s.lower())


def extended_tag(slug, bases):
    """Return the longest vocabulary tag the slug extends ('<tag>-...' or '<tag>_...'), else None."""
    s = slug.lower().replace("_", "-")
    hits = [b for b in bases if s.startswith(b.lower().replace("_", "-") + "-")]
    return max(hits, key=len) if hits else None


def not_repo_relative(path):
    return (
        os.path.isabs(path)
        or path.endswith("/")
        or path in ("..", ".")
        or any(seg == ".." for seg in path.split("/"))
    )


def anchor_uncited(finding, anchor, tag, app_id):
    """The INVALID reason for a FAIL/WARN record whose evidence cites a
    file:line but none in its own anchor file (or under it, for a
    directory anchor), else None. The key then names a different place
    than the evidence, so its stable ID would follow the wrong file.
    Pseudo-anchors, absent-file tags (the file does not exist) and
    evidence with no citation at all are exempt; in a monorepo a citation
    written relative to the app counts."""
    if str(finding.get("result") or "").upper() not in ("FAIL", "WARN"):
        return None
    if anchor in PSEUDO_ANCHORS or tag in ABSENT_FILE_ANCHORS or tag in ("missing-readme",) or anchor == app_id:
        return None
    paths = [p for p, _ in parse_citations(finding.get("evidence"))]
    if not paths:
        return None
    for p in paths:
        for full in (p, app_id + "/" + p if app_id != "root" else p):
            if full == anchor or full.startswith(anchor + "/"):
                return None
    return "evidence does not cite the anchor file"


def validate(finding, vocab, target):
    rule = finding.get("rule") or "<missing>"
    key = finding.get("defect_key")
    if not key:
        return rule, "<missing>", "no defect_key"
    if ":" not in key:
        return rule, key, "no anchor"
    anchor, _, tag = key.partition(":")
    if not tag:
        return rule, key, "empty tag"
    app_id = finding.get("app_id") or "root"
    if app_id != "root" and not_repo_relative(app_id):
        return rule, key, "app_id must be a repo-relative path"
    if not_repo_relative(anchor):
        return rule, key, "anchor must be a repo-relative path"
    expected = ABSENT_FILE_ANCHORS.get(tag)
    if tag == "missing-entry-point":
        if anchor != app_id:
            return rule, key, "absent-file tag 'missing-entry-point' must use anchor 'root' (or the app subpath in a monorepo)"
    elif tag == "missing-readme":
        if anchor != "README.md":
            return rule, key, "missing-readme is repo-level; use README.md"
    elif expected is not None:
        if app_id != "root":
            # A monorepo's anchors are repo-root-relative, so the app prefix is required.
            if anchor in expected:
                return rule, key, "absent-file anchor must be '{}/{}' in a monorepo".format(app_id, anchor)
            allowed = {app_id + "/" + e for e in expected}
        else:
            allowed = set(expected)
        if anchor not in allowed:
            if len(expected) == 1:
                return rule, key, "absent-file tag '{}' must use anchor '{}' (or '<app_id>/{}' in a monorepo)".format(
                    tag, expected[0], expected[0])
            return rule, key, "absent-file tag '{}' must use one of {} (or '<app_id>/<anchor>' in a monorepo)".format(
                tag, ", ".join("'{}'".format(e) for e in expected))
    elif anchor not in PSEUDO_ANCHORS:
        looks_like_path = "/" in anchor or "." in anchor
        if target is not None:
            resolved_target = os.path.realpath(target)
            resolved_anchor = os.path.realpath(os.path.join(target, anchor))
            in_target = resolved_anchor == resolved_target or resolved_anchor.startswith(
                resolved_target + os.sep
            )
            if not in_target:
                return rule, key, "anchor must be a repo-relative path"
            if not exists_case_exact(resolved_target, anchor):
                return rule, key, "anchor is not a repo path or allowed pseudo-anchor"
        elif not looks_like_path:
            return rule, key, "anchor is not a repo path or allowed pseudo-anchor"
    if rule not in vocab:
        return rule, key, "unknown rule '{}'".format(rule)
    if tag.startswith("other:"):
        slug = tag[len("other:"):]
        if not slug:
            return rule, key, "other: needs a slug"
        for base in vocab[rule]:
            if norm(base) == norm(slug):
                return rule, key, "other:{} is the vocabulary tag '{}'".format(slug, base)
        base = extended_tag(slug, vocab[rule])
        if base is not None:
            return rule, key, "other:{} extends the vocabulary tag '{}'; use '{}' or a distinct slug".format(
                slug, base, base)
        return rule, key, None
    reason = anchor_uncited(finding, anchor, tag, app_id)
    if reason:
        return rule, key, reason
    base, _, qual = tag.partition(":")
    rule_vocab = vocab[rule]
    if base not in rule_vocab:
        return rule, key, "tag '{}' not in {} vocabulary; use other:<slug> for a novel defect".format(base, rule)
    if rule_vocab[base] and not qual:
        return rule, key, "tag '{}' requires a qualifier".format(base)
    return rule, key, None


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("findings")
    ap.add_argument("--target", default=None, help="reviewed repo checkout; enables path-existence checks")
    ap.add_argument("--vocabulary", default=FINDING_CODES)
    args = ap.parse_args(argv[1:])
    if args.target is not None and (not args.target or not os.path.isdir(args.target)):
        # An empty --target would silently mean the cwd and reject every real path.
        print("error: --target is not a directory: '{}'".format(args.target), file=sys.stderr)
        return 2
    try:
        with open(args.findings) as f:
            findings = json.load(f)
    except (OSError, ValueError) as e:
        print("error: {}".format(e), file=sys.stderr)
        return 2
    if not isinstance(findings, list) or not all(isinstance(x, dict) for x in findings):
        print("error: findings must be a JSON list of objects", file=sys.stderr)
        return 2
    vocab = load_vocabulary(args.vocabulary)
    bad = 0
    for f in findings:
        rule, key, reason = validate(f, vocab, args.target)
        if reason:
            bad += 1
            print("INVALID {} {} ({})".format(rule, key, reason))
    print("finding keys: {}/{} valid".format(len(findings) - bad, len(findings)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
