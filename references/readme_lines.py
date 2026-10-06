"""README line classification shared by pre-review.py (the readme facts) and
check-evidence.py (which checks that a cited README line is content). One
implementation, so the two cannot disagree about what a content line is.
"""
import os
import re


class PlaceholdersMissing(Exception):
    pass


PLACEHOLDERS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "readme-placeholders.txt")


CONTACT_LINE = re.compile(r"^[\s>*_+-]*contact\b", re.I)


def _read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def load_placeholders(path=PLACEHOLDERS_FILE):
    """The placeholder phrases. Raises PlaceholdersMissing when the file
    cannot be read: without it every template README would read as real
    content, so the stub fact would be wrong, not merely incomplete."""
    try:
        lines = _read(path).splitlines()
    except (OSError, ValueError) as e:
        reason = getattr(e, "strerror", None) or e
        raise PlaceholdersMissing("cannot read placeholder list %s (%s)" % (path, reason))
    return [l.strip() for l in lines if l.strip() and not l.startswith("# ")]


def _markdown_lines(lines):
    """Per line: (in_fence, in_comment). A fence marker line counts as in the
    fence; a line that opens or closes an HTML comment counts as comment only
    when nothing but the comment is on it."""
    out, fence, comment = [], None, False
    for line in lines:
        s = line.strip()
        m = re.match(r"^ {0,3}(`{3,}|~{3,})", line)
        if fence is None and not comment and m:
            fence = m.group(1)[0] * len(m.group(1))
            out.append((True, False))
            continue
        if fence is not None:
            if s.startswith(fence) and not s.strip(fence[0]):
                fence = None
            out.append((True, False))
            continue
        if comment:
            if "-->" in s:
                comment = False
            out.append((False, True))
            continue
        if s.startswith("<!--"):
            closed = "-->" in s[4:]
            comment = not closed
            after = s[4:].split("-->", 1)[1].strip() if closed else ""
            out.append((False, not after))
            continue
        out.append((False, False))
    return out


def _readme_parse(text, placeholders):
    """The parse scan_readme and readme_line_kinds share: (lines, flags,
    headings, heading_lines, underlines, table_rules, placeholder_rows,
    phrase_of)."""
    lines = text.splitlines()
    flags = _markdown_lines(lines)
    low_phrases = [(p, p.lower()) for p in placeholders]

    def phrase_of(line):
        low = line.lower()
        return next((p for p, lp in low_phrases if lp in low), None)

    headings, underlines = [], set()
    for i, line in enumerate(lines):
        fence, comment = flags[i]
        if fence or comment:
            continue
        m = re.match(r"^ {0,3}(#{1,6})(?:\s+(.*?))?\s*$", line)
        if m:
            text_ = re.sub(r"\s+#+\s*$", "", m.group(2) or "").strip()
            headings.append({"level": len(m.group(1)), "text": text_, "line": i + 1})
            continue
        # setext: a === or --- line under a paragraph line
        m = re.match(r"^ {0,3}(=+|-+)\s*$", line)
        prev = lines[i - 1] if i else ""
        if m and prev.strip() and not any(flags[i - 1]) and i not in underlines \
                and not (headings and headings[-1]["line"] == i) \
                and not re.match(r"^ {0,3}([-*+] |\d+[.)] |>|\|)", prev):
            headings.append({"level": 1 if m.group(1)[0] == "=" else 2, "text": prev.strip(), "line": i})
            underlines.add(i + 1)
    heading_lines = {h["line"] for h in headings}
    # a table's header row and |---| rule are structure, not section content
    rule = re.compile(r"^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$")
    table_rules = set()
    for i, line in enumerate(lines):
        if i and "|" in line and rule.match(line) and "|" in lines[i - 1] and not flags[i][0]:
            table_rules |= {i, i + 1}

    # A placeholder phrase is matched per paragraph, not per line: a wrapped
    # template paragraph's continuation line (previous line non-blank, this
    # line not itself a heading, list item, blockquote or fence start) may
    # carry none of the phrase text (the phrase was wrapped onto the line
    # before) but is still part of the same placeholder sentence, so it
    # inherits its paragraph's first line's match.
    def _unit_start(n):
        return (not lines[n].strip() or n in heading_lines or n in underlines
                or flags[n][0] or flags[n][1]
                or re.match(r"^ {0,3}(?:[-*+] |\d+[.)] |>|\||#{1,6}(?:\s|$)|`{3,}|~{3,})", lines[n]))

    placeholder_rows = []
    paragraph_phrase = None
    for i, line in enumerate(lines):
        if flags[i][0]:
            continue
        continues = i and not _unit_start(i) and not _unit_start(i - 1)
        p = phrase_of(line) if not continues else (phrase_of(line) or paragraph_phrase)
        # a phrase ending in ':' introduces what follows (the author's own
        # text in a filled-in README), so it marks only its own line
        paragraph_phrase = p if not _unit_start(i) and not (p or "").endswith(":") else None
        if p:
            placeholder_rows.append({"line": i + 1, "text": line.strip(), "phrase": p})
    return lines, flags, headings, heading_lines, underlines, table_rules, placeholder_rows, phrase_of


def readme_line_kinds(text, placeholders, parsed=None):
    """One kind per README line (index 0 is line 1): heading (ATX, setext
    text or underline), fence (inside a code fence, markers included),
    comment (an HTML comment line), blank, placeholder (a readme.json
    placeholder line), contact (contains '@' or starts with Contact), badge
    (starts with '![' or '[!['), table-header and table-rule (a table's
    header row and its |---| row), else content. check-evidence.py reads this for a `content: README.md:N`
    citation, so the stub count and that check use one definition."""
    lines, flags, _h, heading_lines, underlines, table_rules, placeholder_rows, _p = \
        parsed or _readme_parse(text, placeholders)
    placeholder_lines = {r["line"] for r in placeholder_rows}
    kinds = []
    for i, line in enumerate(lines):
        n, s = i + 1, line.strip()
        if flags[i][0]:
            kinds.append("fence")
        elif n in heading_lines or n in underlines:
            kinds.append("heading")
        elif flags[i][1]:
            kinds.append("comment")
        elif not s:
            kinds.append("blank")
        elif n in placeholder_lines:
            kinds.append("placeholder")
        elif "@" in s or CONTACT_LINE.match(s):
            kinds.append("contact")
        elif s.startswith("![") or s.startswith("[!["):
            kinds.append("badge")
        elif n in table_rules:
            kinds.append("table-rule" if n + 1 not in table_rules else "table-header")
        else:
            kinds.append("content")
    return kinds
