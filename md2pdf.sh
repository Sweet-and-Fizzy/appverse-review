#!/usr/bin/env bash
#
# md2pdf.sh — Convert markdown review files to PDF using pandoc + typst.
#
# Usage:
#   ./md2pdf.sh [file.md ...]        Convert specific files
#   ./md2pdf.sh notes/review-*.md    Convert all review files
#   ./md2pdf.sh                      Convert all notes/review-*.md by default
#
# Output: PDFs are written next to each input file (same dir, .pdf extension).

set -euo pipefail

# --- requirements check ---
for cmd in pandoc typst; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd is required but not found. Install it first." >&2
    echo "  brew install $cmd" >&2
    exit 1
  fi
done

# --- defaults (pick a font available on the current OS) ---
if fc-list "Helvetica" 2>/dev/null | grep -qi helvetica; then
  FONT="Helvetica"
elif fc-list "DejaVu Sans" 2>/dev/null | grep -qi dejavu; then
  FONT="DejaVu Sans"
else
  FONT=""
fi
FONTSIZE="10pt"
MARGIN="0.75in"

# --- lua filter (auto-size table columns based on content) ---
LUA_FILTER="$(mktemp "${TMPDIR:-/tmp}/auto-columns.XXXXXX.lua")"
cat > "$LUA_FILTER" << 'LUA'
function Table(tbl)
  for i, colspec in ipairs(tbl.colspecs) do
    tbl.colspecs[i] = {colspec[1]}
  end
  return tbl
end
LUA

# --- typst style header (lined tables, left-aligned text, bold headers) ---
STYLE_FILE="$(mktemp "${TMPDIR:-/tmp}/review-style.XXXXXX.typ")"

# --- HTML style (self-contained, stable anchors for deep-linking) ---
HTML_CSS="$(mktemp "${TMPDIR:-/tmp}/review-style.XXXXXX.css")"
trap 'rm -f "$STYLE_FILE" "$LUA_FILTER" "$HTML_CSS"' EXIT
cat > "$HTML_CSS" << 'CSS'
body { max-width: 52em; margin: 2em auto; padding: 0 1em;
       font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
                    Helvetica, Arial, sans-serif; font-size: 15px;
       line-height: 1.6; color: #1a1a1a; }
h1 { border-bottom: 2px solid #ddd; padding-bottom: 0.3em; }
h2 { border-bottom: 1px solid #eee; padding-bottom: 0.2em; margin-top: 1.8em; }
h3 { margin-top: 1.4em; }
table { border-collapse: collapse; width: 100%; margin: 1em 0; }
th, td { border: 1px solid #ddd; padding: 6px 10px; text-align: left; }
th { background: #f6f8fa; font-weight: 600; }
tr:nth-child(even) { background: #fafbfc; }
code { background: #f0f0f0; padding: 0.15em 0.35em; border-radius: 3px;
       font-size: 0.9em; }
pre { background: #f6f8fa; padding: 1em; border-radius: 4px; overflow-x: auto; }
blockquote { border-left: 3px solid #ddd; margin-left: 0; padding-left: 1em;
             color: #555; }
a { color: #0b5cad; }
#TOC { background: #f9f9f9; border: 1px solid #eee; padding: 1em;
       border-radius: 4px; margin-bottom: 2em; }
#TOC ul { list-style: none; padding-left: 1.2em; }
#TOC > ul { padding-left: 0; }
CSS
cat > "$STYLE_FILE" << 'TYPST'
#set table(
  stroke: 0.5pt + luma(140),
  inset: 6pt,
)
#set table.cell(align: left)
#show table.cell.where(y: 0): set text(weight: "bold")
#show figure.where(kind: table): set block(breakable: true)
#show raw.where(block: false): set text(size: 0.78em)
// Links are clickable but render in body colour by default; make them look
// like links so a reader knows to click.
#show link: it => underline(text(fill: rgb("#0b5cad"), it))
TYPST

# --- collect input files ---
if [[ $# -eq 0 ]]; then
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  files=("$script_dir"/notes/review-*.md)
  if [[ ${#files[@]} -eq 0 || ! -e "${files[0]}" ]]; then
    echo "No review files found in $script_dir/notes/" >&2
    exit 1
  fi
else
  files=("$@")
fi

# --- convert ---
ok=0
fail=0

for md in "${files[@]}"; do
  if [[ ! -f "$md" ]]; then
    echo "SKIP: $md (not a file)"
    fail=$((fail + 1))
    continue
  fi

  pdf="${md%.md}.pdf"
  html="${md%.md}.html"
  name="$(basename "$md")"

  # --- HTML (stable anchors for deep-linking) ---
  if pandoc "$md" \
    --standalone \
    --toc \
    --css="$HTML_CSS" \
    --self-contained \
    --metadata title="" \
    -o "$html" 2>&1; then
    echo "  OK  $name -> $(basename "$html")"
  else
    echo "WARN  $name -> HTML failed (non-fatal)"
  fi

  # --- PDF ---
  font_args=()
  [[ -n "$FONT" ]] && font_args+=(-V "mainfont=$FONT")

  if pandoc "$md" \
    --pdf-engine=typst \
    --lua-filter="$LUA_FILTER" \
    --include-in-header="$STYLE_FILE" \
    "${font_args[@]}" \
    -V fontsize="$FONTSIZE" \
    -V margin-top="$MARGIN" \
    -V margin-bottom="$MARGIN" \
    -V margin-left="$MARGIN" \
    -V margin-right="$MARGIN" \
    -o "$pdf" 2>&1; then
    echo "  OK  $name -> $(basename "$pdf")"
    ok=$((ok + 1))
  else
    echo "FAIL  $name"
    fail=$((fail + 1))
  fi
done

echo ""
echo "Done: $ok converted, $fail failed."
