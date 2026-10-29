#!/usr/bin/env bash
# Test check-license.py: STR-01 license findings agree with the pre-review's license.json.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHK="$SCRIPT_DIR/references/check-license.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { python3 "$CHK" "$@" > "$TMP/out" 2>&1; echo $?; }
# fact <dir> <file JSON>: a pre-review dir whose license.json names that file
fact() { mkdir -p "$1"; printf '{"schema": "license/1", "file": %s, "found": %s}' "$2" "$( [ "$2" = null ] && echo '[]' || echo "[$2]")" > "$1/license.json"; }
# finding <defect_key> [result] [rule]
finding() { printf '{"app_id":"root","rule":"%s","defect_key":"%s","aspect":"structure","severity":"high","result":"%s","summary":"s","evidence":"x"}' "${3:-STR-01}" "$1" "${2:-FAIL}"; }

echo "Test 1: LICENSE.txt exists and a FAIL says LICENSE is missing (the vmd case)"
fact "$TMP/p1" '"LICENSE.txt"'; echo "[$(finding LICENSE:missing-license)]" > "$TMP/f1.json"
check "exit 1" 1 "$(run "$TMP/f1.json" "$TMP/p1")"
check "line" 1 "$(grep -cxF 'MISMATCH root LICENSE:missing-license: FAIL, but license.json finds LICENSE.txt (key a FAIL for a license that is not open source on the file it reads)' "$TMP/out")"
check "summary" "license: LICENSE.txt, 1 problems" "$(tail -1 "$TMP/out")"

echo "Test 2: a FAIL keyed on the found file (not an open-source license) is fine"
echo "[$(finding LICENSE.txt:missing-license)]" > "$TMP/f2.json"
check "exit 0" 0 "$(run "$TMP/f2.json" "$TMP/p1")"
check "summary" "license: LICENSE.txt, 0 problems" "$(tail -1 "$TMP/out")"

echo "Test 3: no license file and no FAIL"
fact "$TMP/p3" null; echo "[$(finding LICENSE:missing-license PASS)]" > "$TMP/f3.json"
check "exit 1" 1 "$(run "$TMP/f3.json" "$TMP/p3")"
check "line" 1 "$(grep -cxF 'MISSING root LICENSE:missing-license (license.json finds no license file; record a STR-01 FAIL in place of any PASS with that key)' "$TMP/out")"

echo "Test 4: no license file and the FAIL is there"
check "exit 0" 0 "$(run "$TMP/f1.json" "$TMP/p3")"
check "summary" "license: none, 0 problems" "$(tail -1 "$TMP/out")"

echo "Test 5: only STR-01 FAIL records count"
echo "[$(finding LICENSE:missing-license FAIL STR-02)]" > "$TMP/f5.json"
check "an STR-02 record does not answer" 1 "$(run "$TMP/f5.json" "$TMP/p3")"
check "an STR-02 record is not a MISMATCH" 0 "$(run "$TMP/f5.json" "$TMP/p1")"

echo "Test 6: no license.json: not judged"
mkdir -p "$TMP/p6"
check "exit 0" 0 "$(run "$TMP/f1.json" "$TMP/p6")"
check "summary" "license: not judged (no license.json in $TMP/p6)" "$(tail -1 "$TMP/out")"

echo "Test 7: unreadable findings is exit 2"
echo "{" > "$TMP/f7.json"
check "exit 2" 2 "$(run "$TMP/f7.json" "$TMP/p1")"

echo "Test 8: a FAIL keyed on any file license.json found is fine (a placeholder LICENSE beside an MIT LICENSE.md)"
mkdir -p "$TMP/p8"; printf '{"schema": "license/1", "file": "LICENSE", "found": ["LICENSE", "LICENSE.md"]}' > "$TMP/p8/license.json"
echo "[$(finding LICENSE.md:missing-license)]" > "$TMP/f8.json"
check "exit 0" 0 "$(run "$TMP/f8.json" "$TMP/p8")"

echo "Test 9: the line names the record's own app_id"
printf '[{"app_id":"apps/a","rule":"STR-01","defect_key":"apps/a/LICENSE:missing-license","result":"FAIL","severity":"high","summary":"s","evidence":"x"}]' > "$TMP/f9.json"
check "exit 1" 1 "$(run "$TMP/f9.json" "$TMP/p1")"
check "app_id kept" 1 "$(grep -c '^MISMATCH apps/a apps/a/LICENSE:missing-license: FAIL' "$TMP/out")"

echo "Test 10: a license.json of the wrong shape is exit 2, not a crash"
mkdir -p "$TMP/p10"; echo '[1, 2]' > "$TMP/p10/license.json"
check "a list" 2 "$(run "$TMP/f1.json" "$TMP/p10")"
echo '{"file": 5, "found": []}' > "$TMP/p10/license.json"
check "a non-string file" 2 "$(run "$TMP/f1.json" "$TMP/p10")"
check "no traceback" 0 "$(grep -c Traceback "$TMP/out")"

echo
echo "check-license: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
