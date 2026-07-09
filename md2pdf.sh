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
trap 'rm -f "$STYLE_FILE" "$LUA_FILTER"' EXIT
cat > "$STYLE_FILE" << 'TYPST'
#set table(
  stroke: 0.5pt + luma(140),
  inset: 6pt,
)
#set table.cell(align: left)
#show table.cell.where(y: 0): set text(weight: "bold")
#show figure.where(kind: table): set block(breakable: true)
#show raw.where(block: false): set text(size: 0.78em)
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
  name="$(basename "$md")"

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
