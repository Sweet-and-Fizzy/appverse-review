#!/usr/bin/env python3
"""Check the Draft Feedback against the inclusion floor.

Every finding with result FAIL or WARN and severity low or above is a
fix-item and must be represented in the feedback section of the report:

  1. its defect_key is listed in a trailing HTML comment
       <!-- feedback-covers: key1, key2, ... -->
  2. if its evidence starts with a file path, that path appears in the
     feedback prose as a whole token. For a root-level finding
     (app_id == "root") the path's basename also satisfies this; for a
     finding scoped to a specific app (app_id != "root", e.g. a monorepo
     subpath) only the full evidence path counts, since the basename alone
     is ambiguous across apps. A path is recognized either by a file
     extension (a dot) or, for extensionless files like LICENSE or
     Dockerfile, by evidence of the form "NAME:<digit>" — the colon must
     immediately follow the name, with no space, so "GitHub releases API: 0"
     is not mistaken for a path.
  3. when a path was recognized in step 2, the paragraph(s) that name the
     file also describe the defect, not just the file: either a line number
     parsed out of the finding's evidence (every integer, and every "a-b"
     range's endpoints, plus any ":N", "line N", or "lines N-M" form) appears
     in that paragraph, OR at least one distinctive word of the mechanism tag
     appears there. The mechanism tag is the part of defect_key after the
     anchor (the first ":"); if it starts with "other:" the distinctive words
     come from the remainder, otherwise any trailing ":{qualifier}" is
     dropped first. The tag is split on hyphens into words, stopwords {no,
     not, missing, other, wrong, bad, un, non, app, key, value, file} and
     bare 1-2 letter fragments are dropped, and both the remaining tag words
     and the prose are compared with hyphens/underscores stripped,
     case-insensitive (so "hardcoded" matches "hard-coded"). If no
     distinctive word survives the filter (e.g. tag "no-ci" — "no" is a
     stopword, "ci" is too short), rule 3 falls back to the line-number
     check alone; if the evidence also has no line number, rule 3 is
     considered satisfied (rules 1 and 2 still apply).

    python3 references/check-feedback-floor.py review-<slug>.findings.json review-<slug>.md

Exit 0 when every fix-item is covered, 1 when any is missing, 2 when an
input cannot be read or the report has no feedback section.
"""
import json
import os
import re
import sys

FIX_SEVERITIES = {"critical", "high", "medium", "low"}
FIX_RESULTS = {"FAIL", "WARN"}
SECTION_HEADINGS = (
    re.compile(r"^##\s+Draft feedback", re.IGNORECASE),
    re.compile(r"^##\s+Fix before submitting", re.IGNORECASE),
)
JSON_FENCE = re.compile(r"^```json\s*$")
COVERS = re.compile(r"<!--\s*feedback-covers:\s*(.*?)\s*-->", re.DOTALL)
PATH_PREFIX = re.compile(
    r"^([A-Za-z0-9_./\-]+\.[A-Za-z0-9_.]+)(?::|\s|$)"  # has a file extension
    r"|^([A-Za-z0-9_./\-]+)(?=:\d)"                    # extensionless, e.g. LICENSE:1
)
STOPWORDS = {
    "no", "not", "missing", "other", "wrong", "bad", "un", "non",
    "app", "key", "value", "file",
}


def feedback_section(report_text):
    """The Draft Feedback / Fix before submitting section, ending at the
    next '## ' heading OR the structured-findings ```json block, whichever
    comes first — the JSON block is machine-readable data, not prose the
    reviewer wrote, and must never satisfy the inclusion floor."""
    lines = report_text.splitlines()
    start = None
    in_fence = False
    for i, line in enumerate(lines):
        if line.startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence and any(h.match(line) for h in SECTION_HEADINGS):
            start = i + 1
            break
    if start is None:
        return None
    body = []
    in_fence = False
    for line in lines[start:]:
        if not in_fence and JSON_FENCE.match(line):
            break
        if line.startswith("```"):
            in_fence = not in_fence
            body.append(line)
            continue
        if not in_fence and line.startswith("## "):
            break
        body.append(line)
    return "\n".join(body)


def strip_fences(text):
    """Remove fenced code blocks (```...```) from text, keeping the
    surrounding prose intact. A fix-item must be described in what the
    reviewer wrote, not in an embedded code sample."""
    out = []
    in_fence = False
    for line in text.splitlines():
        if line.startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence:
            out.append(line)
    return "\n".join(out)


def evidence_path(evidence):
    m = PATH_PREFIX.match(str(evidence or "").strip())
    if not m:
        return None
    return m.group(1) if m.group(1) is not None else m.group(2)


def token_in_prose(candidate, prose):
    # '.' is excluded from the boundary class: paths routinely end a
    # sentence ("...in submit.yml.erb.") and '.' is also a valid path
    # character, so treating it as non-boundary would reject that case.
    pattern = r"(?<![A-Za-z0-9_/-])" + re.escape(candidate) + r"(?![A-Za-z0-9_/-])"
    return re.search(pattern, prose) is not None


def paragraphs(prose):
    return [p for p in re.split(r"\n\s*\n", prose) if p.strip()]


def paragraph_naming(candidates, prose):
    """The paragraph(s) in which any of `candidates` appears as a whole token."""
    return [p for p in paragraphs(prose) if any(token_in_prose(c, p) for c in candidates)]


def evidence_numbers(evidence):
    """Every integer and every 'a-b' range in the evidence string, as
    (singles, ranges) — singles is the set of individual integers found
    outside of a range plus each range's endpoints; ranges is the list of
    (a, b) string pairs, for matching a literal 'lines a-b' form."""
    text = str(evidence or "")
    ranges = [(a, b) for a, b in re.findall(r"(\d+)-(\d+)", text)]
    singles = set(re.findall(r"\d+", text))
    return singles, ranges


def line_named(candidates, evidence, prose):
    """True if `prose` names a line number drawn from `evidence`: a bare
    integer as ':N', 'line N', or 'lines N' anywhere, a range as
    'lines a-b', or a range endpoint via any of the same forms."""
    singles, ranges = evidence_numbers(evidence)
    patterns = []
    for n in singles:
        patterns.append(r"(?i)\blines?\s+" + re.escape(n) + r"(?!\d)")
        for c in candidates:
            patterns.append(re.escape(c) + r":" + re.escape(n) + r"(?!\d)")
    for a, b in ranges:
        patterns.append(r"(?i)\blines?\s+" + re.escape(a) + r"-" + re.escape(b) + r"(?!\d)")
    return any(re.search(pat, prose) for pat in patterns)


def mechanism_words(defect_key):
    """Distinctive words of the mechanism tag: the part of defect_key after
    the anchor (the first ':'). If that starts with 'other:', the words come
    from the remainder; otherwise a trailing ':{qualifier}' is dropped. The
    tag is split on hyphens, and stopwords are dropped. Returns words with
    hyphens/underscores already stripped, for comparison against
    similarly-normalized prose."""
    key = str(defect_key or "")
    if ":" not in key:
        tag = key
    else:
        tag = key.split(":", 1)[1]
    if tag.startswith("other:"):
        tag = tag[len("other:"):]
    else:
        tag = tag.split(":", 1)[0]  # drop a trailing {qualifier}
    words = [w for w in re.split(r"[-_]", tag) if w]
    # Drop stopwords and bare 1-2 letter fragments (e.g. "ci" from "no-ci")
    # — too short to be a distinctive, recognizable word in prose.
    return [w for w in words if w.lower() not in STOPWORDS and len(w) > 2]


def normalize(word):
    return re.sub(r"[-_]", "", word).lower()


def word_named(defect_key, prose):
    """True if at least one distinctive mechanism-tag word appears in
    `prose`, comparing with hyphens/underscores stripped from both sides."""
    norm_prose = normalize(prose)
    for w in mechanism_words(defect_key):
        n = normalize(w)
        if n and re.search(r"(?<![a-z0-9])" + re.escape(n) + r"(?![a-z0-9])", norm_prose):
            return True
    return False


def defect_named(candidates, evidence, defect_key, named_paragraphs):
    words = mechanism_words(defect_key)
    singles, ranges = evidence_numbers(evidence)
    if not words and not singles and not ranges:
        # No distinctive tag word and no line number to check against —
        # rule 3 has nothing to verify; satisfied (rules 1 and 2 still apply).
        return True
    for p in named_paragraphs:
        if line_named(candidates, evidence, p):
            return True
        if words and word_named(defect_key, p):
            return True
    return False


def main(argv):
    if len(argv) != 3:
        print("usage: check-feedback-floor.py <findings.json> <report.md>", file=sys.stderr)
        return 2
    try:
        with open(argv[1]) as f:
            findings = json.load(f)
        with open(argv[2]) as f:
            report = f.read()
    except (OSError, ValueError) as e:
        print("error: {}".format(e), file=sys.stderr)
        return 2
    section = feedback_section(report)
    if section is None:
        print("error: no '## Draft feedback' or '## Fix before submitting' section", file=sys.stderr)
        return 2
    m = COVERS.search(section)
    covered = set()
    if m:
        covered = {k.strip() for k in m.group(1).split(",") if k.strip()}
    prose = strip_fences(COVERS.sub("", section))

    fix_items = [
        f for f in findings
        if str(f.get("result", "")).upper() in FIX_RESULTS
        and str(f.get("severity", "")).lower() in FIX_SEVERITIES
    ]
    missing = []
    for f in fix_items:
        key = f.get("defect_key", "")
        if key not in covered:
            missing.append((f, "not in feedback-covers"))
            continue
        path = evidence_path(f.get("evidence"))
        if path:
            candidates = (path, os.path.basename(path)) if f.get("app_id") == "root" else (path,)
            named_paragraphs = paragraph_naming(candidates, prose)
            if not named_paragraphs:
                missing.append((f, "file not named in feedback"))
                continue
            if not defect_named(candidates, f.get("evidence"), f.get("defect_key", ""), named_paragraphs):
                missing.append((f, "defect not described in feedback"))
    for f, reason in missing:
        print("MISSING {} {} ({})".format(f.get("rule", "?"), f.get("defect_key", "?"), reason))
    print("feedback floor: {}/{} fix-items covered".format(len(fix_items) - len(missing), len(fix_items)))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
