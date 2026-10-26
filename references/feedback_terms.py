#!/usr/bin/env python3
"""Words and locations of a finding, as the inclusion floor reads them.

Shared by check-feedback-floor.py, which checks that the Draft feedback
names each fix-item, and prepare-feedback.py, which labels each generated
item with the same words, so a generated item satisfies the floor by
construction.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from repo_paths import CITATION_RE, PSEUDO_ANCHORS, split_reviewed_ok  # noqa: E402


PATH_PREFIX = re.compile(
    r"^([A-Za-z0-9_./\-]+\.[A-Za-z0-9_.]+)(?::|\s|$)"  # has a file extension
    r"|^([A-Za-z0-9_./\-]+)(?=:\d)"                    # extensionless, e.g. LICENSE:1
)


STOPWORDS = {
    "no", "not", "missing", "other", "wrong", "bad", "un", "non",
    "app", "key", "value", "file",
    # File-extension fragments (erb, yml, yaml, sh, md) and bare verbs (set)
    # that show up inside a mechanism tag but, on their own, describe the
    # file's name or a generic action rather than the specific defect — a
    # mention of the file itself (e.g. "submit.yml.erb") or an unrelated
    # command (e.g. "set -x") would otherwise make rule 3's mechanism-word
    # check trivially true.
    "erb", "yml", "yaml", "sh", "md", "set",
}


# Leading words in a mechanism tag that negate or genericize what follows
# rather than naming it — "no-set-e" is about "set -e", not "no" or "set" in
# isolation. Stripped only from the front of the tag's word sequence (see
# `phrase_words`), not treated as stopwords generally: "set" still needs to
# be droppable on its own (STOPWORDS) when what's left after it isn't a
# genuine negated phrase.
NEGATION_PREFIXES = {"no", "missing", "without", "unhandled", "undocumented"}


# Pseudo-anchor -> subject words: what a fix-item with no recognizable file
# path in its evidence is "about", drawn from the defect_key's anchor (the
# part before the first ':'). Only overrides that the default rule in
# subject_words() can't produce itself — "root" has no subject word of its
# own (it falls back to the mechanism tag), and ".github/workflows" is
# better described by "ci"/"workflow" than by its own default. Every other
# entry of repo_paths.PSEUDO_ANCHORS gets a subject from the default rule,
# so this table does not need one entry per pseudo-anchor.
PSEUDO_SUBJECTS = {
    ".github/workflows": ["ci", "workflow"],
}


def evidence_path(evidence):
    m = PATH_PREFIX.match(str(evidence or "").strip())
    if not m:
        return None
    return m.group(1) if m.group(1) is not None else m.group(2)


def evidence_numbers(evidence):
    """Every integer and every 'a-b' range in the evidence string, as
    (singles, ranges) — singles is the set of individual integers found
    outside of a range plus each range's endpoints; ranges is the list of
    (a, b) string pairs, for matching a literal 'lines a-b' form. The
    cell is cut at '; reviewed OK:' first: the lines after it are PASS
    lines, so naming one does not describe the FAIL/WARN."""
    text = split_reviewed_ok(str(evidence or ""))[0]
    ranges = [(a, b) for a, b in re.findall(r"(\d+)-(\d+)", text)]
    singles = set(re.findall(r"\d+", text))
    return singles, ranges


def tag_words(defect_key):
    """The mechanism tag's own word sequence, in order, unfiltered: the part
    of defect_key after the anchor (the first ':'). If that starts with
    'other:', the words come from the remainder, hyphen-split. Otherwise, if
    it carries a ':{qualifier}', the qualifier IS the word sequence by
    definition — its words (split on hyphens, dots, AND underscores, e.g.
    'custom_num_cores.help' -> custom, num, cores, help) are used instead of
    the base tag's. With no qualifier, the tag's own words are used
    (hyphen-split). No stopword or length filtering — see `mechanism_words`
    for the filtered, distinctive-word version and `phrase_words` for the
    negation-stripped version used by the sentence-window phrase fallback."""
    key = str(defect_key or "")
    if ":" not in key:
        tag = key
    else:
        tag = key.split(":", 1)[1]
    if tag.startswith("other:"):
        words = re.split(r"[-]", tag[len("other:"):])
    elif ":" in tag:
        qualifier = tag.split(":", 1)[1]
        words = re.split(r"[-._]", qualifier)
    else:
        words = re.split(r"[-]", tag)
    return [w for w in words if w]


def anchor_words(defect_key):
    """Words that name the finding's anchor rather than its defect: the
    anchor's basename stem ("changelog" for CHANGELOG.md, "script" for
    template/script.sh.erb) and, for a pseudo-anchor, its subject words
    ("commit" for commits, "ci"/"workflow" for .github/workflows),
    normalized and with a trailing "s" stripped. A tag word among them
    only repeats the file or subject rule 2 already found, so it cannot
    describe the defect."""
    anchor = str(defect_key or "").split(":", 1)[0]
    base = anchor.split("/")[-1].lstrip(".")
    words = {base.split(".", 1)[0]} if base else set()
    if anchor in PSEUDO_SUBJECTS:
        words.update(PSEUDO_SUBJECTS[anchor])
    elif anchor in PSEUDO_ANCHORS and anchor != "root":
        words.add(default_subject(anchor))
    return {_singular(normalize(w)) for w in words if w}


def _singular(word):
    return word[:-1] if word.endswith("s") and len(word) > 1 else word


def mechanism_words(defect_key):
    """Distinctive words of the mechanism tag (see `tag_words`). Stopwords,
    NEGATION_PREFIXES (they negate what follows rather than name it:
    "undocumented" in "undocumented-hex-color" would match any
    "undocumented" in the window), bare 1-2 letter fragments and words
    that name the anchor itself (`anchor_words`) are dropped. When dropping the anchor's words is what
    empties the list ("wrong-app-changelog" on CHANGELOG.md), the tag's
    other words of three or more letters, stopwords included but not
    NEGATION_PREFIXES, stand in ("wrong", "app"): the defect is then named
    by those, never by the file name. Returns words with
    hyphens/underscores already stripped, for comparison against
    similarly-normalized prose."""
    words = tag_words(defect_key)
    named = anchor_words(defect_key)
    # Drop stopwords and bare 1-2 letter fragments (e.g. "ci" from "no-ci")
    # — too short to be a distinctive, recognizable word in prose.
    distinctive = [w for w in words if w.lower() not in STOPWORDS and len(w) > 2
                   and w.lower() not in NEGATION_PREFIXES]
    kept = [w for w in distinctive if _singular(normalize(w)) not in named]
    if distinctive and not kept:
        kept = [w for w in words if len(w) > 2 and w.lower() not in NEGATION_PREFIXES
                and _singular(normalize(w)) not in named]
    return kept


def phrase_words(defect_key):
    """The mechanism tag's own word sequence (see `tag_words`), with any
    leading run of NEGATION_PREFIXES words dropped — "no-set-e" ->
    ["set", "e"], "undocumented-hex-color" -> ["hex", "color"]. Unlike
    `mechanism_words`, nothing else is filtered: short fragments like "e"
    and words that are STOPWORDS on their own (e.g. "set") are kept,
    because it's the consecutive phrase, not any single word of it, that
    has to be distinctive. Returns [] if every word is a negation prefix
    (nothing left to form a phrase) or the tag has fewer than two words
    after stripping (a single word is already covered by
    `mechanism_words`, not by the phrase fallback)."""
    words = tag_words(defect_key)
    i = 0
    while i < len(words) and words[i].lower() in NEGATION_PREFIXES:
        i += 1
    words = words[i:]
    return words if len(words) >= 2 else []


def default_subject(anchor):
    """The default subject word for a pseudo-anchor with no PSEUDO_SUBJECTS
    override: the anchor lowercased, with any file extension and a single
    trailing "s" stripped (e.g. "commits" -> "commit", "CHANGELOG.md" ->
    "changelog", "LICENSE" -> "license"). This is what makes subject_words
    total over every entry of repo_paths.PSEUDO_ANCHORS without a table
    entry for each one."""
    base = anchor.split("/")[-1]
    if "." in base:
        base = base.rsplit(".", 1)[0]
    base = base.lower()
    if base.endswith("s") and len(base) > 1:
        base = base[:-1]
    return base


def subject_words(defect_key):
    """The subject of a pseudo-anchored fix-item (one whose evidence has no
    recognizable file path): words for the defect_key's anchor (the part
    before the first ':'). This is total over every entry of
    repo_paths.PSEUDO_ANCHORS: PSEUDO_SUBJECTS overrides the two anchors
    that need one ("root" has no subject word of its own, so it falls back
    to the finding's mechanism-tag words instead; ".github/workflows" is
    better described by "ci"/"workflow" than by its own default), and every
    other pseudo-anchor gets `default_subject(anchor)`. An anchor that is
    not in PSEUDO_ANCHORS at all (not a recognized pseudo-anchor) yields no
    subject words — nothing for rule 4 to verify beyond rule 1."""
    anchor = str(defect_key or "").split(":", 1)[0]
    if anchor not in PSEUDO_ANCHORS:
        return []
    if anchor == "root":
        return mechanism_words(defect_key)
    if anchor in PSEUDO_SUBJECTS:
        return PSEUDO_SUBJECTS[anchor]
    return [default_subject(anchor)]


def normalize(word):
    return re.sub(r"[-_]", "", word).lower()


def words_named(words, prose):
    """True if at least one of `words` appears in `prose` as a whole word,
    comparing case-insensitively with hyphens/underscores stripped from
    both sides (so "hardcoded" matches "hard-coded" and "CI" matches
    "ci"), and tolerating a plain trailing "s" symmetrically — the word is
    stripped of a trailing "s" first (so "releases" -> "release"), then
    matched against the prose allowing an optional trailing "s" there too.
    This makes plural tolerance two-way: a singular word like "release"
    matches prose written as "releases", AND a word like "releases" (as in
    the "releases" pseudo-anchor's own name, before the table maps it to
    its singular subject) matches prose written as "release". Ordinary
    English pluralization, not a stem match."""
    norm_prose = normalize(prose)
    for w in words:
        n = normalize(w)
        if n.endswith("s") and len(n) > 1:
            n = n[:-1]
        if n and re.search(r"(?<![a-z0-9])" + re.escape(n) + r"s?(?![a-z0-9])", norm_prose):
            return True
    return False


RULE_HEADER = re.compile(r"^\*\*([A-Z]+-\d+):\*\*\s*$")
BACKTICKED = re.compile(r"`([^`]+)`")


def vocabulary_tags(path):
    """{rule: [tag, ...]} from finding-codes.md: the backticked tokens on the
    lines after each `**RULE:**` header, up to the first blank line. The
    prose paragraphs that follow some tag lists quote other backticked
    things (`bash -n`, `syntax.json`), so only that first block counts, and a
    token with a space or a '.' is never a tag. A qualifier, whether the
    `:{name}` placeholder or a worked example (`missing-field:software`), is
    stripped, leaving the base tag."""
    vocab = {}
    rule = None
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = RULE_HEADER.match(line.strip())
            if m:
                rule = m.group(1)
                vocab.setdefault(rule, [])
                continue
            if rule is None:
                continue
            if not line.strip():
                rule = None
                continue
            for token in BACKTICKED.findall(line):
                if " " in token or "." in token:
                    continue
                tag = token.split(":", 1)[0]
                if tag not in vocab[rule]:
                    vocab[rule].append(tag)
    return vocab


LINE_TOKEN = re.compile(r"\d+(?:-\d+)?")


def evidence_locations(evidence):
    """[(path, [line, ...]), ...] for each file the evidence cites, in order.
    The evidence is cut at '; reviewed OK:' (those lines are PASS lines).
    Citations are read with repo_paths.CITATION_RE, the parser check-evidence
    uses, so a quoted value after the line ("form.yml:47: min: 0") is not
    taken for more lines and a comma-separated second file is kept. A range
    ("8-9") stays one token, as written. A path cited with no line
    ("manifest.yml") is kept with no lines. A file cited twice appears once,
    with its lines merged."""
    text = split_reviewed_ok(str(evidence or ""))[0]
    out = []
    index = {}

    def add(path, lines):
        if path not in index:
            index[path] = len(out)
            out.append((path, []))
        merged = out[index[path]][1]
        for line in lines:
            if line not in merged:
                merged.append(line)

    for m in CITATION_RE.finditer(text):
        add(m.group(1), LINE_TOKEN.findall(m.group(2)))
    for part in text.split(";"):
        path = evidence_path(part.strip())
        if path and path not in index:
            add(path, [])
    return out


DRAFT_HEADING_RE = re.compile(r"^##\s+Draft feedback\b", re.IGNORECASE)
JSON_FENCE_RE = re.compile(r"^```json\s*$")


def draft_section_bounds(lines):
    """(start, end) line indices of the Draft feedback section: its heading
    (outside code fences, with or without "— edit before sending") up to the
    next `## ` heading or the structured-findings ```json fence, or None.
    render-feedback.py replaces this span and fill-guard.py compares
    everything outside it, so the two agree on where the section is."""
    start = None
    in_fence = False
    for i, line in enumerate(lines):
        if line.startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence and DRAFT_HEADING_RE.match(line):
            start = i
            break
    if start is None:
        return None
    in_fence = False
    for i in range(start + 1, len(lines)):
        line = lines[i]
        if not in_fence and (JSON_FENCE_RE.match(line) or line.startswith("## ")):
            return start, i
        if line.startswith("```"):
            in_fence = not in_fence
    return start, len(lines)
