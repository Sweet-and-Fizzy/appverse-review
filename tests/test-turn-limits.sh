#!/usr/bin/env bash
# Test turn-limits.py: the review session's turn limit from the app count,
# and the override a manual dispatch may pass.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TL="$SCRIPT_DIR/references/turn-limits.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
apps() { python3 -c 'import json, sys; json.dump([{"app_id": "a%d" % i, "path": "p%d" % i} for i in range(int(sys.argv[1]))], open(sys.argv[2], "w"))' "$1" "$TMP/apps.json"; }
tl() { python3 "$TL" "$@" 2>"$TMP/err"; }
warned() { grep -c '^warning:' "$TMP/err"; }

echo "Test 1: from the app count"
apps 1; check "1 app is 100" 100 "$(tl "$TMP/apps.json")"
apps 5; check "5 apps is 140" 140 "$(tl "$TMP/apps.json")"
apps 7; check "7 apps hits the cap 150" 150 "$(tl "$TMP/apps.json")"
apps 50; check "50 apps is 150" 150 "$(tl "$TMP/apps.json")"
check "missing apps.json is 100" 100 "$(tl "$TMP/nope.json")"
echo "{broken" > "$TMP/bad.json"
check "malformed apps.json is 100" 100 "$(tl "$TMP/bad.json")"
check "and warns" 1 "$(warned)"
echo '{"apps": [1, 2, 3]}' > "$TMP/obj.json"
check "a JSON object is 100" 100 "$(tl "$TMP/obj.json")"
echo '[]' > "$TMP/empty.json"
check "an empty list is 100" 100 "$(tl "$TMP/empty.json")"

echo "Test 2: the override"
apps 5
check "override 120 is 120" 120 "$(tl "$TMP/apps.json" 120)"
check "override 999 is clamped to 150" 150 "$(tl "$TMP/apps.json" 999)"
check "override 0 is ignored" 140 "$(tl "$TMP/apps.json" 0)"
check "override 0 warns" 1 "$(warned)"
check "override with a newline is ignored" 140 "$(tl "$TMP/apps.json" $'150\n--x')"
check "and warns" 1 "$(warned)"
check "override with a flag is ignored" 140 "$(tl "$TMP/apps.json" '150 --x')"
check "five digits is ignored" 140 "$(tl "$TMP/apps.json" 12345)"
check "empty override is ignored" 140 "$(tl "$TMP/apps.json" '')"
check "with no warning" 0 "$(warned)"

echo "Test 3: always exits 0"
python3 "$TL" "$TMP/bad.json" 'x' >/dev/null 2>&1
check "exit 0 on bad input" 0 "$?"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
