#!/usr/bin/env python3
"""Check the Draft Feedback against the inclusion floor.

Every finding with result FAIL or WARN and severity low or above is a
fix-item, and so is a Structure gate FAIL at any severity, since it sets at
least Request changes (check-decisions.py) and the feedback must say why.
Each must be represented in the feedback section of the report:

  1. its defect_key is listed in an HTML comment
       <!-- feedback-covers: key1, key2, ... -->
     normally trailing inside the feedback section, but also recognized up
     to five lines above the '## Draft feedback' / '## Fix before
     submitting' heading itself, since a model sometimes writes it just
     above the heading instead of inside the section. If a covers comment
     appears in both places (or more than once in either), the last one
     found wins — read top to bottom, the in-section one wins over a
     pre-heading one.
  2. if its evidence starts with a file path, that path appears in the
     feedback prose as a whole token. For a root-level finding
     (app_id == "root") the path's basename also satisfies this; for a
     finding scoped to a specific app (app_id != "root", e.g. a monorepo
     subpath) only the full evidence path counts, since the basename alone
     is ambiguous across apps. A path is recognized either by a file
     extension (a dot) or, for extensionless files like LICENSE or
     Dockerfile, by evidence of the form "NAME:<digit>" — the colon must
     immediately follow the name, with no space, so "GitHub releases API: 0"
     is not mistaken for a path. For a root-level finding, an all-capitals
     basename stem of four or more characters (README for README.md,
     CHANGELOG for CHANGELOG.md), written case-exactly, also names the
     file: "the README" is how prose refers to it. A lowercase stem
     ("script", "readme") does not.
  3. when a path (or, for a pseudo-anchor, a subject — see below) was
     recognized in step 2, the sentence window around the sentence(s) that
     name it also describes the defect, not just names the file: either a
     line number parsed out of the finding's evidence (every integer, and
     every "a-b" range's endpoints, plus any ":N", "line N", or "lines N-M"
     form) appears in that window, OR at least one distinctive word of the
     mechanism tag appears there, OR a concrete value quoted in the
     evidence does (evidence_literals: a token of three or more characters
     outside the citations and the '; reviewed OK:' part that holds a
     digit, '_', '/' or '.', or two or more capitals, such as
     `bc_osc_matlab` or `MATLAB`, never the finding's own file name). A
     sentence window runs from the sentence that names the file up to, but
     not including, the first later sentence that names a *different* file
     — a sentence ends at '.' or ';' followed by whitespace, or a newline; a
     ':' does not end one, so a lead-in and its detail ("The repo is stale:
     the last commit ...") stay one sentence. A real report typically names a
     file once in a lead-in sentence and then describes several of its
     defects over the sentences that follow, and that still passes; the
     window only has to stop once the prose moves on to a different file,
     so a line number or mechanism word attached to that other file's
     mention does not count for this one.
     The mechanism tag is the part of defect_key after the
     anchor (the first ":"). If it starts with "other:", the distinctive
     words come from the remainder, hyphen-split. Otherwise, if it carries a
     ":{qualifier}", the qualifier IS the distinctive part by definition —
     its words (split on hyphens, dots, and underscores, e.g.
     "custom_num_cores.help" -> custom, num, cores, help) are used instead of
     the base tag's words. With no qualifier, the tag's own words are used
     (hyphen-split). Stopwords {no, not, missing, other, wrong, bad, un, non,
     app, key, value, file, erb, yml, yaml, sh, md, set} and bare 1-2 letter
     fragments are then dropped, and both the remaining tag words and the
     prose are compared with hyphens/underscores stripped, case-insensitive
     (so "hardcoded" matches "hard-coded"). A stopword is dropped because it
     is too generic or too easily coincidental on its own to describe a
     specific defect — "erb"/"yml"/"sh"/"md" are file-extension fragments
     that would otherwise match the file's own name, and "set" would
     otherwise match any unrelated "set -x"-style mention.

     If no single distinctive word survives that filter, rule 3 has a phrase
     fallback before giving up on the mechanism tag: the tag's own word
     sequence (unfiltered — short words and words that are only stopwords in
     isolation, like "set", are kept here), with any leading run of
     NEGATION_PREFIXES words dropped (no, missing, without, unhandled,
     undocumented — a small, general set, not specific to any one tag),
     counts as describing the defect when it appears *consecutively* in the
     sentence window, case-insensitive, with the words separated by any run
     of "-", "_", or space. So tag "no-set-e" is satisfied by prose that
     says "does not have set -e" or "no set -e", but not by an unrelated
     "remove set -x" — the phrase, not the bare word "set", has to be
     there. A longer tag also matches prose that only spells out a leading
     portion of it (down to two words): "commented-out-code" is satisfied by
     "a commented-out block". If neither a single distinctive word nor the
     phrase (nor, for a two-or-fewer-word tag with nothing left after
     negation-stripping, anything at all) can be found, rule 3 falls back to
     the line-number check alone; if the evidence also has no line number,
     rule 3 is considered satisfied (rules 1 and 2 still apply).

  4. when a finding's evidence has no recognizable file path (a
     pseudo-anchor, e.g. a repo-wide check like "0 tagged releases" with
     evidence "GitHub releases API: 0"), the finding still has a subject —
     and this is total over every anchor in repo_paths.PSEUDO_ANCHORS
     ("LICENSE", "README.md", "CHANGELOG.md", ".github/workflows",
     "releases", "issues", "contributors", "commits", "root"), not just a
     few of them: by default the subject is the anchor lowercased, with any
     file extension and a single trailing "s" stripped ("commits" ->
     "commit", "issues" -> "issue", "contributors" -> "contributor",
     "CHANGELOG.md" -> "changelog", "LICENSE" -> "license"); two anchors
     override the default because it doesn't fit them — "root" has no
     subject word of its own, so it falls back to the mechanism tag's own
     distinctive words, and ".github/workflows" uses "ci"/"workflow"
     instead of its own default. If the anchor isn't one of
     PSEUDO_ANCHORS at all, there is nothing to verify and rule 1 alone
     governs, as before. But if it IS one of PSEUDO_ANCHORS and still
     yields no subject word (a "root" finding with no distinctive
     mechanism-tag word), that is a real gap, not a pass: the finding is
     MISSING with reason "no subject for pseudo-anchor {anchor}" — a
     pseudo-anchored fix-item never passes on its covers-line key alone,
     regardless of why its table lookup came up empty. Otherwise the
     subject is treated like a file name: some paragraph must name it as a
     whole word (or the finding is MISSING with reason "subject not named
     in feedback"). Rule 3 then applies as for a file, in the sentence
     window around the sentence naming the subject: a distinctive
     mechanism-tag word, the tag's phrase, a line number, or (since a
     pseudo-anchor's evidence holds counts and dates rather than line
     numbers) an integer of two or more digits from the evidence must be
     there. So "Please commit a LICENSE file" names the subject of
     `commits:stale-repo` but does not describe it; "the repo is stale" or
     "the last commit was 2023-04-11" does. A tag with no distinctive word
     and no phrase once the subject is set aside (`no-releases`, `no-ci`,
     `no-changelog`) has nothing beyond its subject to look for, and stays
     subject-only.

     In both rules, a tag word that only names the anchor is not a
     distinctive word: the anchor's basename stem and a pseudo-anchor's
     subject (`changelog` for CHANGELOG.md, `readme` for README.md,
     `commit` for commits) are dropped from the mechanism words, so
     "Thanks for adding CHANGELOG.md" does not describe
     `CHANGELOG.md:wrong-app-changelog`.

     Known limit: when a qualified and an unqualified finding share the same
     base tag and anchor (e.g. "README.md:readme-inconsistency" and
     "README.md:readme-inconsistency:testing-table"), the floor checks each
     independently against the qualifier's own words. If the feedback prose
     mentions the qualifier's topic without actually describing the mismatch
     (e.g. naming "testing table" without saying what's inconsistent about
     it), rule 3 can still pass on the topic word alone — the floor verifies
     the defect is *named*, not that the description is complete.

     Known limit: a sentence window (rule 3) stops at the first later
     sentence naming a *different* file, and "different file" is detected
     by a generic filename-shaped-token pattern (FILENAME_TOKEN), not a
     real filesystem check. A hostname or a log/library filename mentioned
     in passing (e.g. "output.log", "llama.cpp", "osc.github.io") matches
     that pattern too and will cut a window short even though it is not
     actually a different tracked file. This is accepted for now — it
     narrows some legitimate windows but does not create a false pass.

    python3 references/check-feedback-floor.py review-<slug>.findings.json review-<slug>.md

Exit 0 when every fix-item is covered, 1 when any is missing, 2 when an
input cannot be read, 3 (a malformed report) when the report has no
feedback section.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from report_parse import MALFORMED, is_gate_finding, positional_args  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from repo_paths import CITATION_RE, PSEUDO_ANCHORS, split_reviewed_ok  # noqa: E402

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
# ':' does not end a sentence: "The repo is stale: the last commit ..." is
# one sentence, its lead-in and its detail.
SENTENCE_END = re.compile(r"(?<=[.;])\s+|\n")
# A filename-shaped token anywhere in a sentence: a path/word segment with a
# file extension (e.g. "form.yml", "template/script.sh.erb"). Used to detect
# whether a sentence is about a *different* file than the one whose window
# is being built, so that file's line numbers or mechanism words don't leak
# in from a neighboring sentence about something else. The stem must be at
# least two characters and the extension must be letter-led, so ordinary
# prose abbreviations and version numbers ("e.g.", "i.e.", "3.1.", "v2.0.")
# are not mistaken for filenames.
FILENAME_TOKEN = re.compile(
    r"(?<![A-Za-z0-9_./\-])"
    r"((?:[A-Za-z0-9_\-]+/)*[A-Za-z0-9_\-]{2,}(?:\.[A-Za-z][A-Za-z0-9]{0,5})+)"
    r"(?![A-Za-z0-9_/\-])"
)
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


PREHEADING_LOOKBACK = 5
# An all-capitals basename stem (README, CHANGELOG, CONTRIBUTING) is how
# prose names such a file ("the README"), so it names the file too.
UPPER_STEM = re.compile(r"^[A-Z][A-Z0-9_]{3,}$")


def feedback_section(report_text):
    """The Draft Feedback / Fix before submitting section, ending at the
    next '## ' heading OR the structured-findings ```json block, whichever
    comes first — the JSON block is machine-readable data, not prose the
    reviewer wrote, and must never satisfy the inclusion floor.

    Returns (preheading, body): `body` is the section's own text as before;
    `preheading` is the up-to-five lines immediately before the heading
    line, joined as text. A model sometimes writes the
    '<!-- feedback-covers: ... -->' comment just above '## Draft feedback'
    instead of inside it (observed 2026-09-29); `preheading` lets main()
    also look there without treating that text as prose the floor checks
    for file/defect mentions."""
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
    preheading = "\n".join(lines[max(0, start - 1 - PREHEADING_LOOKBACK):start - 1])
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
    return preheading, "\n".join(body)


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


def named_in(candidate, text, ci=False):
    """True if `candidate` appears in `text` as a whole token. File paths
    (ci=False) use `token_in_prose`'s exact, path-aware boundaries. A
    pseudo-anchor's subject words (ci=True) are plain words, not paths, so
    they use `words_named`'s case-insensitive, hyphen/underscore-stripped
    match instead (so a subject word "ci" matches prose "CI", and
    "workflow" matches "workflows")."""
    return words_named([candidate], text) if ci else token_in_prose(candidate, text)


def paragraphs(prose):
    return [p for p in re.split(r"\n\s*\n", prose) if p.strip()]


def paragraph_naming(candidates, prose, ci=False):
    """The paragraph(s) in which any of `candidates` appears as a whole
    token. `ci` selects case-insensitive, hyphen/underscore-stripped
    matching for pseudo-anchor subject words instead of file-path
    matching (see `named_in`)."""
    return [p for p in paragraphs(prose) if any(named_in(c, p, ci) for c in candidates)]


def sentences(paragraph):
    """`paragraph` split into sentences: a sentence ends at '.' or ';'
    followed by whitespace, or at a newline."""
    return [s for s in SENTENCE_END.split(paragraph) if s.strip()]


def names_other_file(sentence, candidates):
    """True if `sentence` contains a filename-shaped token that is none of
    `candidates` — i.e. the sentence is about some other file. A token is
    also accepted as matching a candidate if their basenames agree, so
    that a later sentence using the short form "script.sh.erb" for a
    non-root app's full evidence path "apps/x/template/script.sh.erb" is
    not mistaken for a different file."""
    for tok in FILENAME_TOKEN.findall(sentence):
        if any(
            token_in_prose(c, tok) or tok == c or os.path.basename(tok) == os.path.basename(c)
            for c in candidates
        ):
            continue
        return True
    return False


def sentence_windows(paragraph, candidates, ci=False):
    """Each sentence in `paragraph` that names one of `candidates` as a whole
    token, plus every sentence after it up to, but not including, the first
    later sentence that names a *different* file. A real report typically
    names a file once in a lead-in sentence and then describes several of
    its defects over the sentences that follow, so the window has to run
    that far to be useful — it just has to stop before the prose moves on
    to another file. Rule 3 is checked against these windows rather than
    the whole paragraph, so a description of a *different* file's defect
    does not count for this one — the description has to sit with the
    file, from its lead-in up to wherever the paragraph turns to something
    else. `ci` is as in `paragraph_naming`."""
    ss = sentences(paragraph)
    windows = []
    for i, s in enumerate(ss):
        if not any(named_in(c, s, ci) for c in candidates):
            continue
        end = i + 1
        while end < len(ss) and not names_other_file(ss[end], candidates):
            end += 1
        windows.append(" ".join(ss[i:end]))
    return windows


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


def names_only_anchor(defect_key):
    """True when the tag's only distinctive words name its anchor
    ("missing-license" on LICENSE, "no-changelog" on CHANGELOG.md): nothing
    beyond the file or subject is left to describe, so naming it (rule 2)
    is all rule 3 can ask."""
    words = tag_words(defect_key)
    distinctive = [w for w in words if w.lower() not in STOPWORDS and len(w) > 2]
    return bool(distinctive) and not mechanism_words(defect_key) and not phrase_words(defect_key)


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


def phrase_named(defect_key, prose):
    """True if the mechanism tag's negation-stripped word sequence (or a
    prefix of it, down to 2 words) appears *consecutively* in `prose`,
    case-insensitive, with the words separated by any run of '-', '_', or
    space. This is rule 3's phrase fallback: after the single
    distinctive-word check (`word_named`) fails, a tag like "no-set-e" is
    still satisfied by prose that says "does not have set -e" or "no set
    -e", but not by an unrelated mention of "set" alone (e.g. "set -x") —
    the phrase, not the bare word, is what has to be there. Trying
    shrinking prefixes (full sequence first, then one word shorter, down to
    2) lets a longer tag still match prose that only spells out its first
    two words (e.g. "commented-out-code" matched by "a commented-out
    block").

    A phrase word of one character (after the first word) is read as a
    shell flag, so it matches only in flag form: the separator before it
    must end in a hyphen ('[ _]*-'), so "set -e" and "set-e" match but
    "set e" (as in "users can set e (environment) variables") does not.
    The flag may lead a cluster of further flag letters ('-e[a-z]*'), so
    "set -euo pipefail" matches too. Words of two or more characters keep
    the '[-_ ]*' separator."""
    words = phrase_words(defect_key)
    for end in range(len(words), 1, -1):
        pattern = r"\b" + re.escape(words[0])
        for w in words[1:end]:
            if len(w) == 1:
                # a shell flag, alone or leading a cluster: -e, -euo
                pattern += r"[ _]*-" + re.escape(w) + r"[a-z]*"
            else:
                pattern += r"[-_ ]*" + re.escape(w)
        pattern += r"\b"
        if re.search(pattern, prose, re.IGNORECASE):
            return True
    return False


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


def word_named(defect_key, prose):
    """True if at least one distinctive mechanism-tag word appears in
    `prose`, comparing with hyphens/underscores stripped from both sides."""
    return words_named(mechanism_words(defect_key), prose)


LITERAL_TOKEN = re.compile(r"[A-Za-z0-9_$./-]+")


def evidence_literals(evidence, candidates):
    """Concrete values quoted in the evidence (outside its '; reviewed OK:'
    part and its file:line citations): tokens of three or more characters
    that read as a value rather than an English word, because they hold a
    digit, '_', or '.' (`bc_osc_matlab`, `2018a`). A '/'-joined token also
    gives its parts. Tokens that are purely digits (line numbers have
    their own rule) or name the finding's own file are left out, so the
    file name never describes its own defect. A CamelCase word or
    all-caps acronym alone (`GitHub`, `MATLAB`) does not qualify: those
    show up incidentally in evidence sources like "GitHub API" and would
    otherwise let generic prose ("...on GitHub...") pass for a
    description."""
    text = CITATION_RE.sub(" ", split_reviewed_ok(str(evidence or ""))[0])
    names = {c.lower() for c in candidates} | {os.path.basename(c).lower() for c in candidates}
    out = []
    for tok in LITERAL_TOKEN.findall(text):
        tok = tok.strip("./-")
        for t in [tok] + (tok.split("/") if "/" in tok else []):
            if (len(t) >= 3 and not t.isdigit() and t.lower() not in names
                    and re.search(r"[0-9_/.]", t)):
                out.append(t)
    return out


def literal_named(literals, prose):
    """True if any evidence literal appears in prose as a whole token,
    case-insensitive."""
    return any(re.search(r"(?<![A-Za-z0-9_])" + re.escape(t) + r"(?![A-Za-z0-9_])", prose, re.I)
               for t in literals)


def number_named(evidence, prose):
    """True if an integer of two or more digits from the evidence (outside
    its '; reviewed OK:' part) appears in prose as a whole number: a
    pseudo-anchor's evidence holds counts and dates ("last commit
    2023-04-11", "400 days"), not line numbers, so naming one describes
    the defect."""
    singles, _ = evidence_numbers(evidence)
    return any(re.search(r"(?<!\d)" + re.escape(n) + r"(?!\d)", prose) for n in singles if len(n) >= 2)


def defect_named(candidates, evidence, defect_key, named_paragraphs, words=None, ci=False, counts=False):
    """True if the defect is described in the sentence window(s) around
    where `candidates` (the file path, or a pseudo-anchor's subject words)
    is named — not merely somewhere in the same paragraph. Each paragraph
    that names a candidate contributes one window per naming sentence.

    `words` are the distinctive words to look for in the window; by default
    the finding's mechanism-tag words (rule 3). A pseudo-anchor's caller
    passes its subject words instead, with `ci=True` (see `named_in`). The
    mechanism tag's phrase fallback (`phrase_named`) only applies on the
    default (mechanism-word) path, not when a caller supplies its own
    `words` — a pseudo-anchor's subject is checked as plain words, not as
    a negation-strippable phrase. `counts` (a pseudo-anchor) also accepts
    an evidence number named in the window (`number_named`)."""
    use_mechanism_words = words is None
    if words is None:
        words = mechanism_words(defect_key)
    singles, ranges = evidence_numbers(evidence)
    phrase = phrase_words(defect_key) if use_mechanism_words else []
    literals = evidence_literals(evidence, candidates)
    if not words and not phrase and not singles and not ranges and not literals:
        # No distinctive word, no phrase, and no line number to check
        # against — rule 3 has nothing to verify; satisfied (rules 1 and 2
        # still apply).
        return True
    for p in named_paragraphs:
        for window in sentence_windows(p, candidates, ci):
            if line_named(candidates, evidence, window):
                return True
            if counts and number_named(evidence, window):
                return True
            if literals and literal_named(literals, window):
                return True
            if words and words_named(words, window):
                return True
            if phrase and phrase_named(defect_key, window):
                return True
    return False


def main(argv):
    argv = positional_args(argv, ["findings.json", "report.md"], description=(__doc__ or "").split("\n\n")[0])
    if isinstance(argv, int):
        return argv
    try:
        with open(argv[1]) as f:
            findings = json.load(f)
        with open(argv[2]) as f:
            report = f.read()
    except (OSError, ValueError) as e:
        print("error: {}".format(e), file=sys.stderr)
        return 2
    parsed = feedback_section(report)
    if parsed is None:
        print("error: no '## Draft feedback' or '## Fix before submitting' section", file=sys.stderr)
        return MALFORMED
    preheading, section = parsed
    # A covers comment may sit just above the heading (preheading) or inside
    # the section; if both are present, or either has more than one, the
    # last one wins.
    matches = list(COVERS.finditer(preheading)) + list(COVERS.finditer(section))
    covered = set()
    if matches:
        covered = {k.strip() for k in matches[-1].group(1).split(",") if k.strip()}
    prose = strip_fences(COVERS.sub("", section))

    fix_items = [
        f for f in findings
        if str(f.get("result", "")).upper() in FIX_RESULTS
        and (str(f.get("severity", "")).lower() in FIX_SEVERITIES
             or (str(f.get("result", "")).upper() == "FAIL" and is_gate_finding(f)))
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
            stem = os.path.basename(path).split(".", 1)[0]
            if f.get("app_id") == "root" and stem != os.path.basename(path) and UPPER_STEM.match(stem):
                candidates += (stem,)  # "the README" names README.md
            named_paragraphs = paragraph_naming(candidates, prose)
            if not named_paragraphs:
                missing.append((f, "file not named in feedback"))
                continue
            if names_only_anchor(key):
                continue
            if not defect_named(candidates, f.get("evidence"), f.get("defect_key", ""), named_paragraphs):
                missing.append((f, "defect not described in feedback"))
        else:
            # Pseudo-anchor: evidence has no recognizable file path. The
            # finding still has a subject — the anchor's own words — and a
            # covers-line key alone must not be enough to pass it.
            anchor = key.split(":", 1)[0]
            subject = subject_words(key)
            if not subject:
                if anchor in PSEUDO_ANCHORS:
                    # A recognized pseudo-anchor (e.g. "root" with no
                    # distinctive mechanism-tag word) still must not pass on
                    # its covers key alone: subject_words() being total over
                    # PSEUDO_ANCHORS means this is a real gap, not a case
                    # with nothing to verify.
                    missing.append((f, "no subject for pseudo-anchor {}".format(anchor)))
                # An anchor outside PSEUDO_ANCHORS (evidence just happens to
                # have no recognizable path, but isn't one of the known
                # repo-wide checks) has no subject to verify — nothing
                # beyond rule 1 to check, as before.
                continue
            candidates = tuple(subject)
            named_paragraphs = paragraph_naming(candidates, prose, ci=True)
            if not named_paragraphs:
                missing.append((f, "subject not named in feedback"))
                continue
            if not mechanism_words(key) and not phrase_words(key):
                continue  # nothing beyond the subject names the defect (no-releases, no-ci)
            if not defect_named(candidates, f.get("evidence"), key, named_paragraphs, ci=True, counts=True):
                missing.append((f, "defect not described in feedback"))
    for f, reason in missing:
        print("MISSING {} {} ({})".format(f.get("rule", "?"), f.get("defect_key", "?"), reason))
    print("feedback floor: {}/{} fix-items covered".format(len(fix_items) - len(missing), len(fix_items)))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
