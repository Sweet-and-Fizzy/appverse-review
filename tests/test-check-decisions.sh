#!/usr/bin/env bash
# Test check-decisions.py: decisions meet the floor their FAILs set: any structure gate FAIL, High/Critical security and upkeep; security repo-wide.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHK="$SCRIPT_DIR/references/check-decisions.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { python3 "$CHK" "$@" > "$TMP/out" 2>&1; echo $?; }

# meta <file> <recommendation> <app_id:decision>...
meta() { local out="$1" rec="$2"; shift 2
  python3 - "$out" "$rec" "$@" <<'PY'
import json, sys
out, rec, *apps = sys.argv[1:]
json.dump({"recommendation": {"decision": rec, "note": "x"},
           "apps": [{"app_id": a.split(":", 1)[0], "decision": a.split(":", 1)[1]} for a in apps]},
          open(out, "w"))
PY
}
# finding <app_id> <aspect> <severity> <result> <rule> <evidence>
finding() { printf '{"app_id":"%s","aspect":"%s","severity":"%s","result":"%s","rule":"%s","evidence":"%s","defect_key":"k","summary":"s"}' "$@"; }

echo "Test 1: a High security FAIL in one monorepo app sets Request changes for every app"
meta "$TMP/m1.json" "Request changes" "apps/a:Accept" "apps/b:Request changes"
echo "[$(finding apps/b security high FAIL OODT-02 apps/b/template/script.sh.erb:2)]" > "$TMP/f1.json"
check "exit 1" 1 "$(run "$TMP/m1.json" "$TMP/f1.json")"
check "names the clean app" 1 "$(grep -c '^MISMATCH decision apps/a: Accept, but OODT-02 high FAIL at apps/b/template/script.sh.erb:2 (applies to every app) needs at least Request changes$' "$TMP/out")"
check "the app with the finding is fine" 0 "$(grep -c 'decision apps/b' "$TMP/out")"

echo "Test 2: the same repo with both apps at Request changes passes"
meta "$TMP/m2.json" "Request changes" "apps/a:Request changes" "apps/b:Request changes"
check "exit 0" 0 "$(run "$TMP/m2.json" "$TMP/f1.json")"
check "summary" "decisions: 2 apps against 1 floor, 0 problems" "$(tail -1 "$TMP/out")"

echo "Test 3: a High structure FAIL in one app sets only that app's floor"
meta "$TMP/m3.json" "Request changes" "apps/a:Accept" "apps/b:Request changes"
echo "[$(finding apps/b structure high FAIL STR-02 appverse.yml)]" > "$TMP/f3.json"
check "exit 0" 0 "$(run "$TMP/m3.json" "$TMP/f3.json")"
meta "$TMP/m3b.json" "Request changes" "apps/a:Accept" "apps/b:Accept with suggestions"
check "the app itself below its floor: exit 1" 1 "$(run "$TMP/m3b.json" "$TMP/f3.json")"
check "names only that app" "1 0" "$(grep -c 'decision apps/b' "$TMP/out") $(grep -c 'decision apps/a' "$TMP/out")"

echo "Test 4: a High repo-level FAIL (app_id root in a monorepo) applies to every app and the recommendation"
meta "$TMP/m4.json" "Accept with suggestions" "apps/a:Accept" "apps/b:Request changes"
echo "[$(finding root structure high FAIL STR-01 LICENSE)]" > "$TMP/f4.json"
check "exit 1" 1 "$(run "$TMP/m4.json" "$TMP/f4.json")"
check "app and recommendation named" "1 1" "$(grep -c '^MISMATCH decision apps/a:' "$TMP/out") $(grep -c '^MISMATCH decision recommendation:' "$TMP/out")"

echo "Test 5: a Critical security FAIL needs Reject"
meta "$TMP/m5.json" "Request changes" "root:Request changes"
echo "[$(finding root security critical FAIL OODT-01 install.sh:3)]" > "$TMP/f5.json"
check "exit 1" 1 "$(run "$TMP/m5.json" "$TMP/f5.json")"
check "app and recommendation both need Reject" 2 "$(grep -c 'needs at least Reject$' "$TMP/out")"
check "single app: no 'every app' note" 0 "$(grep -c 'applies to every app' "$TMP/out")"

echo "Test 6: Medium, WARN and PASS records set no floor; a harsher decision is fine"
meta "$TMP/m6.json" "Reject" "root:Reject"
echo "[$(finding root security medium FAIL OODT-05 a:1),$(finding root security high WARN OODT-05 a:2),$(finding root security high PASS OODT-02 a:3)]" > "$TMP/f6.json"
check "exit 0" 0 "$(run "$TMP/m6.json" "$TMP/f6.json")"
check "no floors" "decisions: 1 app against 0 floors, 0 problems" "$(tail -1 "$TMP/out")"

echo "Test 7: snake_case decisions are read; a missing decision is left to check-meta"
meta "$TMP/m7.json" "request_changes" "apps/a:accept_with_suggestions" "apps/b:"
check "exit 1" 1 "$(run "$TMP/m7.json" "$TMP/f1.json")"
check "only apps/a named" "1 0" "$(grep -c 'decision apps/a' "$TMP/out") $(grep -c 'decision apps/b' "$TMP/out")"

echo "Test 8: a record without an aspect is security by its OODT rule code"
meta "$TMP/m8.json" "Request changes" "apps/a:Accept" "apps/b:Request changes"
echo '[{"app_id":"apps/b","rule":"OODT-02","severity":"high","result":"FAIL","evidence":"apps/b/x.sh:2"}]' > "$TMP/f8.json"
check "exit 1" 1 "$(run "$TMP/m8.json" "$TMP/f8.json")"
check "applies to the other app" 1 "$(grep -c '^MISMATCH decision apps/a: Accept, but OODT-02 high FAIL at apps/b/x.sh:2 (applies to every app)' "$TMP/out")"

echo "Test 9: an app with a repo-wide High floor and its own Critical floor is held to the Critical one"
meta "$TMP/m9.json" "Reject" "apps/a:Accept" "apps/b:Reject"
echo "[$(finding apps/a security high FAIL OODT-05 apps/a/x.sh:1),$(finding apps/a structure critical FAIL STR-03 apps/a/y.sh:4)]" > "$TMP/f9.json"
check "exit 1" 1 "$(run "$TMP/m9.json" "$TMP/f9.json")"
check "names the Critical floor in one line" 1 "$(grep -c '^MISMATCH decision apps/a: Accept, but STR-03 critical FAIL at apps/a/y.sh:4 needs at least Reject$' "$TMP/out")"
check "only one line for that app" 1 "$(grep -c 'decision apps/a' "$TMP/out")"

echo "Test 10: documentation and code-quality FAILs set no floor, even at High (below-target is Accept with suggestions)"
meta "$TMP/m10.json" "Accept with suggestions" "root:Accept with suggestions"
echo "[$(finding root quality high FAIL QUA-01 README.md),$(finding root maintenance high FAIL MNT-03 CHANGELOG)]" > "$TMP/f10.json"
check "exit 0" 0 "$(run "$TMP/m10.json" "$TMP/f10.json")"
check "no floors" "decisions: 1 app against 0 floors, 0 problems" "$(tail -1 "$TMP/out")"

echo "Test 11: result and severity are read case-insensitively; MNT-01 sets a floor"
meta "$TMP/m11.json" "Accept" "root:Accept"
echo '[{"app_id":"root","aspect":"security","rule":"OODT-02","severity":"High ","result":"Fail","evidence":"a:1"}]' > "$TMP/f11.json"
check "Fail/High : exit 1" 1 "$(run "$TMP/m11.json" "$TMP/f11.json")"
echo "[$(finding root maintenance high FAIL MNT-01 .git)]" > "$TMP/f11b.json"
check "MNT-01 High: exit 1" 1 "$(run "$TMP/m11.json" "$TMP/f11b.json")"

echo "Test 12: a failed public or archive gate in meta.json sets Request changes for every app"
python3 -c "import json; json.dump({'recommendation':{'decision':'Accept'},'public':'fail','not_archived':'pass','apps':[{'app_id':'apps/a','decision':'Accept'},{'app_id':'apps/b','decision':'Request changes'}]},open('$TMP/m12.json','w'))"
echo '[]' > "$TMP/f12.json"
check "exit 1" 1 "$(run "$TMP/m12.json" "$TMP/f12.json")"
check "names the gate for the app" 1 "$(grep -c '^MISMATCH decision apps/a: Accept, but the public gate FAIL in meta.json' "$TMP/out")"

echo "Test 13: a monorepo recommendation is at least its strictest Per-app decision"
meta "$TMP/m13.json" "Accept" "apps/a:Accept" "apps/b:Reject"
check "exit 1" 1 "$(run "$TMP/m13.json" "$TMP/f12.json")"
check "names the roll-up" 1 "$(grep -c "^MISMATCH decision recommendation: Accept, but apps/b's Per-app decision (the recommendation rolls them up) needs at least Reject$" "$TMP/out")"

echo "Test 14: unreadable input is exit 2"
check "missing meta" 2 "$(run "$TMP/nope.json" "$TMP/f1.json")"
echo '{"not": "a list"}' > "$TMP/bad.json"
check "findings not a list" 2 "$(run "$TMP/m1.json" "$TMP/bad.json")"

echo "Test 15: a structure gate FAIL sets Request changes at any severity (review-rubric.md: every Structure row is a gate)"
meta "$TMP/m15.json" "Accept" "root:Accept"
for sev in medium low info; do
  echo "[$(finding root structure $sev FAIL STR-01 LICENSE)]" > "$TMP/f15.json"
  check "$sev: exit 1" 1 "$(run "$TMP/m15.json" "$TMP/f15.json")"
  check "$sev: app needs Request changes" 1 "$(grep -c "^MISMATCH decision root: Accept, but STR-01 $sev FAIL at LICENSE needs at least Request changes$" "$TMP/out")"
done
meta "$TMP/m15b.json" "Request changes" "root:Request changes"
check "Request changes meets it" 0 "$(run "$TMP/m15b.json" "$TMP/f15.json")"

echo "Test 16: a Low gate FAIL in one monorepo app sets only that app's floor; at repo level, every app's"
meta "$TMP/m16.json" "Request changes" "apps/a:Accept" "apps/b:Request changes"
echo "[$(finding apps/b structure low FAIL STR-06 apps/b/template/script.sh.erb:9)]" > "$TMP/f16.json"
check "own app only: exit 0" 0 "$(run "$TMP/m16.json" "$TMP/f16.json")"
echo "[$(finding root structure low FAIL STR-01 LICENSE)]" > "$TMP/f16b.json"
check "repo level: exit 1" 1 "$(run "$TMP/m16.json" "$TMP/f16b.json")"
check "repo level: names the other app" 1 "$(grep -c '^MISMATCH decision apps/a: Accept, but STR-01 low FAIL at LICENSE (applies to every app) needs at least Request changes$' "$TMP/out")"

echo "Test 17: a Critical gate FAIL still needs Reject; a gate WARN or a Low security or upkeep FAIL sets no floor"
meta "$TMP/m17.json" "Request changes" "root:Request changes"
echo "[$(finding root structure critical FAIL STR-01 LICENSE)]" > "$TMP/f17.json"
check "critical gate: exit 1" 1 "$(run "$TMP/m17.json" "$TMP/f17.json")"
check "critical gate: needs Reject" 1 "$(grep -c 'needs at least Reject$' "$TMP/out")"
meta "$TMP/m17b.json" "Accept" "root:Accept"
echo "[$(finding root structure medium WARN STR-01 LICENSE),$(finding root security low FAIL OODT-05 a:1),$(finding root maintenance low FAIL MNT-01 repo)]" > "$TMP/f17b.json"
check "WARN gate, Low security, Low MNT-01: exit 0" 0 "$(run "$TMP/m17b.json" "$TMP/f17b.json")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
