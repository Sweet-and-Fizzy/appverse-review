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

# --- defaults ---
FONT="Helvetica"
FONTSIZE="10pt"
MARGIN="0.75in"

# --- typst style header (lined tables, left-aligned text, bold headers) ---
STYLE_FILE="$(mktemp "${TMPDIR:-/tmp}/review-style.XXXXXX.typ")"
trap 'rm -f "$STYLE_FILE"' EXIT
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
    ((fail++)) || true
    continue
  fi

  pdf="${md%.md}.pdf"
  name="$(basename "$md")"

  if pandoc "$md" \
    --pdf-engine=typst \
    --include-in-header="$STYLE_FILE" \
    -V mainfont="$FONT" \
    -V fontsize="$FONTSIZE" \
    -V margin-top="$MARGIN" \
    -V margin-bottom="$MARGIN" \
    -V margin-left="$MARGIN" \
    -V margin-right="$MARGIN" \
    -o "$pdf" 2>&1; then
    echo "  OK  $name -> $(basename "$pdf")"
    ((ok++))
  else
    echo "FAIL  $name"
    ((fail++)) || true
  fi
done

echo ""
echo "Done: $ok converted, $fail failed."
