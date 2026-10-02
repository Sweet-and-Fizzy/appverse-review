#!/usr/bin/env bash
# Test insert-catalog.py and check-catalog.py: the Catalog checks section is the pre-review block, written by script.
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

INS="$SCRIPT_DIR/references/insert-catalog.py"
ins() { python3 "$INS" "$@" > "$TMP/ins" 2>&1; echo $?; }

echo "Test 1: the block inserted by insert-catalog.py passes"
printf '# x\n\n## Catalog checks\n\n<!-- catalog-checks -->\n\n## Overall recommendation\n\nAccept.\n' > "$TMP/r1.md"
check "insert exit 0" 0 "$(ins "$TMP/r1.md" "$PRE")"
check "marker replaced" 0 "$(grep -c 'catalog-checks -->' "$TMP/r1.md")"
check "recommendation kept" 1 "$(grep -c '^## Overall recommendation$' "$TMP/r1.md")"
check "check exit 0" 0 "$(run "$TMP/r1.md" "$PRE")"
check "summary" "catalog: section matches catalog-checks.md (6 lines)" "$(tail -1 "$TMP/out")"

echo "Test 2: a report without the section gets one before the recommendation"
printf '# x\n\n## Review scope\n\ny\n\n## Overall recommendation\n\nAccept.\n' > "$TMP/r2.md"
check "insert exit 0" 0 "$(ins "$TMP/r2.md" "$PRE")"
check "section added before the recommendation" "## Catalog checks|## Overall recommendation" "$(grep '^## ' "$TMP/r2.md" | sed -n '2,3p' | paste -sd'|' -)"
check "check exit 0" 0 "$(run "$TMP/r2.md" "$PRE")"

echo "Test 3: inserting twice is the same as once; a title-case heading is found"
printf '# x\n\n## Catalog Checks\n\nmodel text that should go\n\n## Overall recommendation\n' > "$TMP/r3.md"
ins "$TMP/r3.md" "$PRE" >/dev/null; cp "$TMP/r3.md" "$TMP/r3a.md"; ins "$TMP/r3.md" "$PRE" >/dev/null
check "idempotent" "same" "$(cmp -s "$TMP/r3.md" "$TMP/r3a.md" && echo same || echo differs)"
check "model text replaced" 0 "$(grep -c 'model text that should go' "$TMP/r3.md")"
check "check exit 0" 0 "$(run "$TMP/r3.md" "$PRE")"

echo "Test 4: a filled-in rationale fails"
sed 's/_<reviewer fills in.*>_/_No duplicate: no other dashboard app._/' "$TMP/r1.md" > "$TMP/r4.md"
check "exit 1" 1 "$(run "$TMP/r4.md" "$PRE")"
check "names the placeholder as missing" 1 "$(grep -c '^MISSING catalog line: - \*\*Duplicate-check rationale' "$TMP/out")"

echo "Test 5: an added contradicting line fails"
awk '{print} /^- `implementation_tags`/{print "- NOT CHECKED: catalog unreachable; no duplicate exists."}' "$TMP/r1.md" > "$TMP/r5.md"
check "exit 1" 1 "$(run "$TMP/r5.md" "$PRE")"
check "names the extra line" 1 "$(grep -c '^EXTRA catalog line: - NOT CHECKED' "$TMP/out")"

echo "Test 6: a rewritten result fails"
sed 's/matches the Software entry "Dashboards"./NOT CHECKED: network fetch denied./' "$TMP/r1.md" > "$TMP/r6.md"
check "exit 1" 1 "$(run "$TMP/r6.md" "$PRE")"

echo "Test 7: no Catalog checks section is a missing section (exit 2, as check-all reads it)"
printf '# x\n\n## Overall recommendation\n\nAccept.\n' > "$TMP/r7.md"
check "exit 2" 2 "$(run "$TMP/r7.md" "$PRE")"
check "error names the section" 1 "$(grep -c "^error: report has no '## Catalog checks' section" "$TMP/out")"

echo "Test 8: no catalog-checks.md (an older pre-review run) is not checked, and insert leaves the report alone"
mkdir -p "$TMP/old"; cp "$TMP/r7.md" "$TMP/r8.md"
check "check exit 0" 0 "$(run "$TMP/r7.md" "$TMP/old")"
check "says not checked" 1 "$(grep -c '^catalog: not checked' "$TMP/out")"
check "insert exit 0" 0 "$(ins "$TMP/r8.md" "$TMP/old")"
check "report unchanged" "same" "$(cmp -s "$TMP/r7.md" "$TMP/r8.md" && echo same || echo differs)"

echo "Test 9: an unreadable report is exit 2"
check "check exit 2" 2 "$(run "$TMP/nope.md" "$PRE")"
check "insert exit 2" 2 "$(ins "$TMP/nope.md" "$PRE")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
