#!/usr/bin/env python3
"""Validate every finding's defect_key so its stable ID is stable.

    python3 references/check-keys.py review-<slug>.findings.json [--target <repo-dir>]

A key is "{anchor}:{tag}". The anchor must be a repo-relative path that
exists under --target (when given) or one of the allowed pseudo-anchors.
The tag must be in the rule's vocabulary (finding-codes.md), carrying its
qualifier where the vocabulary shows one, or "other:<slug>" where the slug is
not a vocabulary tag in disguise. Exit 0 when every key is valid, 1 when any
is not (one INVALID line each), 2 when the input cannot be read.
"""
import argparse
import json
import os
import re
import sys

PSEUDO_ANCHORS = {
    "LICENSE", "README.md", "CHANGELOG", "CHANGELOG.md", ".github/workflows",
    "releases", "issues", "contributors", "commits", "root",
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


def validate(finding, vocab, target):
    rule = finding.get("rule") or "<missing>"
    key = finding.get("defect_key")
    if not key:
        return rule, "<missing>", "no defect_key"
    if ":" not in key:
        return rule, key, "no anchor"
    anchor, _, tag = key.partition(":")
    if anchor not in PSEUDO_ANCHORS:
        if (
            os.path.isabs(anchor)
            or anchor.endswith("/")
            or anchor in ("..", ".")
            or any(seg == ".." for seg in anchor.split("/"))
        ):
            return rule, key, "anchor must be a repo-relative path"
        looks_like_path = "/" in anchor or "." in anchor
        if target is not None:
            resolved_target = os.path.realpath(target)
            resolved_anchor = os.path.realpath(os.path.join(target, anchor))
            in_target = resolved_anchor == resolved_target or resolved_anchor.startswith(
                resolved_target + os.sep
            )
            if not in_target:
                return rule, key, "anchor must be a repo-relative path"
            if not os.path.exists(resolved_anchor):
                return rule, key, "anchor is not a repo path or allowed pseudo-anchor"
        elif not looks_like_path:
            return rule, key, "anchor is not a repo path or allowed pseudo-anchor"
    if tag.startswith("other:"):
        slug = tag[len("other:"):]
        if not slug:
            return rule, key, "other: needs a slug"
        for base in vocab.get(rule, {}):
            if norm(base) == norm(slug):
                return rule, key, "other:{} is the vocabulary tag '{}'".format(slug, base)
        return rule, key, None
    base, _, qual = tag.partition(":")
    rule_vocab = vocab.get(rule, {})
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
    try:
        with open(args.findings) as f:
            findings = json.load(f)
    except (OSError, ValueError) as e:
        print("error: {}".format(e), file=sys.stderr)
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
