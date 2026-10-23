#!/usr/bin/env bash
# Test fill-guard.py: whether a fill session's changes are kept or rolled
# back, and the Draft feedback section bounds the guard and renderer share.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REFS="$SCRIPT_DIR/references"
FG="$REFS/fill-guard.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }

R="$TMP/review.md"; F="$TMP/review.findings.json"; M="$TMP/review.meta.json"; FB="$TMP/review.feedback.json"
B="$TMP/before.txt"; A="$TMP/after.txt"; SNAP="$TMP/snap"
fb() { printf '{"app_name": "X", "opening": "%s", "items": [{"group": "should:QUA-03:no-error-check", "text": "%s", "defect_keys": ["a.sh:no-error-check"]}, {"group": "suggestion:QUA-07:missing-pattern", "text": "%s", "defect_keys": ["form.yml:missing-pattern"]}]}' "$1" "$2" "$3" > "$FB"; }
report() { printf '# Appverse Review: o/r\n\n## Overall recommendation\n\nAccept.\n\n## Draft feedback — edit before sending\n\n%s\n\n<!-- feedback-generated -->\n<!-- feedback-covers: a.sh:no-error-check -->\n\n```json\n[]\n```\n' "$1" > "$R"; }
setup() { # a snapshot with the opening and first text filled, the second empty
  rm -rf "$SNAP"; report "Thanks. 1. a"; echo '[{"k": 1}]' > "$F"; echo '{"m": 1}' > "$M"; fb "Thanks." "Fix a." ""
  printf '[floor] feedback floor: 2/2 fix-items covered\n' > "$B"; cp "$B" "$A"
  python3 "$FG" snapshot "$SNAP" "$R" "$F" "$M" "$FB" >/dev/null 2>&1; }
verify() { python3 "$FG" verify "$SNAP" "$R" "$F" "$M" "$FB" "$B" "$A" > "$TMP/out" 2>&1; echo $?; }
filled() { fb "Thanks." "Fix a." "Add a pattern."; report "Thanks. 1. a 2. b"; }

echo "Test 1: needs-fill"
nf() { python3 "$FG" needs-fill "$1" 2>/dev/null; }
fb "Thanks." "Fix a." ""; check "true on an empty text" true "$(nf "$FB")"
fb "" "Fix a." "Fix b."; check "true on an empty opening" true "$(nf "$FB")"
fb "Thanks." "Fix a." "Fix b."; check "false when all filled" false "$(nf "$FB")"
check "needs-fill on a missing file is false" false "$(nf "$TMP/nope.json")"
echo "{broken" > "$TMP/bad.json"; check "false on malformed JSON" false "$(nf "$TMP/bad.json")"

echo "Test 2: kept"
setup; filled
check "a filled sentence is kept" 0 "$(verify)"
check "says kept" "fill-guard: kept" "$(tail -1 "$TMP/out")"
setup; filled; printf '[floor] error: pre-review dir missing\n[floor] error: pre-review dir missing\n' > "$B"; cp "$B" "$A"
check "same error lines before and after is not a regression" 0 "$(verify)"
setup; filled; printf '[keys] INVALID x\n' > "$B"; printf '[keys] INVALID x\n[floor] feedback floor: 2/2\n' > "$A"
check "a problem line that was already there is not a regression" 0 "$(verify)"

echo "Test 3: restored"
restored_all() { # every file back to its snapshot
  [ "$(cat "$F")" = '[{"k": 1}]' ] && [ "$(cat "$M")" = '{"m": 1}' ] && grep -q '"text": "Fix a."' "$FB" && grep -q 'Thanks. 1. a$' "$R" && echo yes || echo no; }
setup; filled; echo '[{"k": 2}]' > "$F"
check "an edited findings.json restores" 1 "$(verify)"
check "and restores all four files" yes "$(restored_all)"
setup; filled; echo '{"m": 2}' > "$M"
check "an edited meta.json restores" 1 "$(verify)"
setup; filled; sed -i.bak 's/^Accept\.$/Reject./' "$R"
check "a report edit outside the section restores" 1 "$(verify)"
setup; filled; printf '\n## Draft feedback\n\nagain\n' >> "$R"
check "a second Draft feedback heading restores" 1 "$(verify)"
setup; filled; sed -i.bak '/feedback-generated/d' "$R"
check "a missing feedback-generated marker restores" 1 "$(verify)"
setup; filled; printf '[floor] MISSING QUA-03 a.sh:no-error-check (defect not described in feedback)\n' >> "$A"
check "a new problem line restores" 1 "$(verify)"
setup; fb "Thanks." "" ""; report "Thanks. 1. fallback 2. fallback"
check "malformed feedback after fill restores" 1 "$(verify)"
check "and the snapshot feedback is back" yes "$(grep -q '"text": "Fix a."' "$FB" && echo yes || echo no)"
setup; fb "Thanks." "" "Add a pattern."; report "Thanks. 1. fallback 2. b"
check "a blanked sentence restores" 1 "$(verify)"
setup; fb "Thanks." "Fix a." ""; report "Thanks. 1. a 2. fallback"
check "no newly filled sentence restores" 1 "$(verify)"
setup; fb "Different." "Fix a." "Add a pattern."
check "a changed opening restores" 1 "$(verify)"

echo "Test 4: absent files"
rm -rf "$SNAP"; report "Thanks. 1. a"; echo '[{"k": 1}]' > "$F"; rm -f "$M"; fb "Thanks." "Fix a." ""
printf '' > "$B"; cp "$B" "$A"
python3 "$FG" snapshot "$SNAP" "$R" "$F" "$M" "$FB" >/dev/null 2>&1
filled; echo '{"new": 1}' > "$M"
check "an absent meta.json that now exists restores" 1 "$(verify)"
check "and is removed on restore" no "$([ -e "$M" ] && echo yes || echo no)"

echo "Test 5: draft_section_bounds"
sb() { PYTHONPATH="$REFS" python3 -c 'import sys; from feedback_terms import draft_section_bounds; print(draft_section_bounds(open(sys.argv[1]).read().splitlines()))' "$1"; }
printf 'a\n## Draft feedback\nx\n## Next\ny\n' > "$TMP/s1.md"; check "section with a following heading" "(1, 3)" "$(sb "$TMP/s1.md")"
printf 'a\n## Draft feedback\nx\n```json\n[]\n```\n' > "$TMP/s2.md"; check "section ending at a json fence" "(1, 3)" "$(sb "$TMP/s2.md")"
printf 'a\n## Other\n' > "$TMP/s3.md"; check "no section is None" "None" "$(sb "$TMP/s3.md")"
printf '```\n## Draft feedback\n```\n## Draft feedback\nx\n' > "$TMP/s4.md"; check "a heading inside a code fence is ignored" "(3, 5)" "$(sb "$TMP/s4.md")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
