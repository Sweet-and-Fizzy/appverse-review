#!/usr/bin/env bash
# Test check-catalog.py: the report's Catalog checks section carries the pre-review block.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHK="$SCRIPT_DIR/references/check-catalog.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { python3 "$CHK" "$@" > "$TMP/out" 2>&1; echo $?; }

PRE="$TMP/pre"; mkdir -p "$PRE"
cat > "$PRE/catalog-checks.md" <<'EOF'
Read from the catalog's public API: 2 published apps (1 page), 3 Software entries, 3 app types, 3 implementation tags.

- Duplicate check — No published app implements "Dashboards".
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- `software` — matches the Software entry "Dashboards".
- `app_type` — "dashboard" is in the app-type vocabulary.
- `implementation_tags` — all in the vocabulary: "passenger".
EOF
report() { { echo "# Appverse Review: x"; echo; echo "## Catalog checks"; echo; cat; echo; echo "## Overall recommendation"; echo; echo "Accept."; } > "$1"; }

echo "Test 1: the block pasted verbatim passes"
report "$TMP/r1.md" < "$PRE/catalog-checks.md"
check "exit 0" 0 "$(run "$TMP/r1.md" "$PRE")"
check "summary" "catalog: 6/6 lines of catalog-checks.md present" "$(tail -1 "$TMP/out")"

echo "Test 2: re-wrapped whitespace still matches"
sed 's/  */ /g' "$PRE/catalog-checks.md" | report "$TMP/r2.md"
check "exit 0" 0 "$(run "$TMP/r2.md" "$PRE")"

echo "Test 3: a filled-in rationale fails"
sed 's/_<reviewer fills in.*>_/_No duplicate: no other dashboard app._/' "$PRE/catalog-checks.md" | report "$TMP/r3.md"
check "exit 1" 1 "$(run "$TMP/r3.md" "$PRE")"
check "names the placeholder" 1 "$(grep -c '^MISSING catalog line: - \*\*Duplicate-check rationale' "$TMP/out")"

echo "Test 4: a rewritten result fails"
sed 's/matches the Software entry "Dashboards"./NOT CHECKED: network fetch denied./' "$PRE/catalog-checks.md" | report "$TMP/r4.md"
check "exit 1" 1 "$(run "$TMP/r4.md" "$PRE")"
check "one missing line" 1 "$(grep -c '^MISSING' "$TMP/out")"

echo "Test 5: no Catalog checks section is a missing section (exit 2, as check-all reads it)"
printf '# x\n\n## Overall recommendation\n\nAccept.\n' > "$TMP/r5.md"
check "exit 2" 2 "$(run "$TMP/r5.md" "$PRE")"
check "error names the section" 1 "$(grep -c "^error: report has no '## Catalog checks' section" "$TMP/out")"

echo "Test 6: no catalog-checks.md (an older pre-review run) is not checked"
mkdir -p "$TMP/old"
check "exit 0" 0 "$(run "$TMP/r5.md" "$TMP/old")"
check "says not checked" 1 "$(grep -c '^catalog: not checked' "$TMP/out")"

echo "Test 7: an unreadable report is exit 2"
check "exit 2" 2 "$(run "$TMP/nope.md" "$PRE")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
