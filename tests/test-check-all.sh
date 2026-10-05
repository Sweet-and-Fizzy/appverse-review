#!/usr/bin/env bash
# Test check-all.py: runs floor, keys, rating, rows, evidence in order, each
# checker's problem lines prefixed with its name, then its summary line,
# exit 1 if any failed (2 if any could not run).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$SCRIPT_DIR/references/check-all.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() {
  python3 "$CHECK" "$TMP/report.md" "$TMP/findings.json" "$TMP/checks.json" "$TMP/pre-review" --target "$TMP/target" > "$TMP/out" 2>&1
  echo $?
}
count() { grep -cxF -- "$1" "$TMP/out"; }

mkdir -p "$TMP/pre-review" "$TMP/target/template"
echo '#!/bin/bash' > "$TMP/target/template/script.sh.erb"
echo '{"checks":[]}' > "$TMP/checks.json"
echo '[{"app_id":"root","name":"X","app_type":"batch_connect"}]' > "$TMP/pre-review/apps.json"

echo "Test 1: a run that fails two checkers (floor, rating) prints both blocks and exits 1"
cat > "$TMP/findings.json" <<'EOF'
[
 {"app_id":"root","rule":"QUA-03","defect_key":"template/script.sh.erb:no-set-e","aspect":"quality","severity":"low","result":"FAIL","summary":"x","evidence":"template/script.sh.erb:1"}
]
EOF
cat > "$TMP/report.md" <<'EOF'
# Appverse Review: x
## App: X (root)
### Documentation
Rating: Minimal — not supported (stub README; see QUA-01)
### Signals
| Dimension | Level |
|---|---|
| Documentation | High |
## Draft feedback — edit before sending
Nothing here.
EOF
check "exit 1" 1 "$(run)"
check "floor block: MISSING line prefixed" 1 "$(count '[floor] MISSING QUA-03 template/script.sh.erb:no-set-e (not in feedback-covers)')"
check "floor block: summary prefixed"      1 "$(count '[floor] feedback floor: 0/1 fix-items covered')"
check "keys passes, prefixed summary"      1 "$(count '[keys] finding keys: 1/1 valid')"
check "keys block: no INVALID line"        0 "$(grep -c '^\[keys\] INVALID' "$TMP/out")"
check "rating block: MISMATCH prefixed"    1 "$(count "[rating] MISMATCH Documentation rating (Minimal claimed but 'what it launches' evidence is missing; highest supported rung is none)")"
check "rating block: summary prefixed"     1 "$(count '[rating] ratings: 1 mismatch')"
check "rows passes, prefixed summary"      1 "$(count '[rows] check-rows: 1 app, 0 required rows, 0 problems')"
check "evidence passes, prefixed summary"  1 "$(count '[evidence] evidence: 1/1 valid; report rows: 0/0 valid')"
check "order: floor before keys before rating before rows before evidence" 0 "$(awk '/\[floor\]/{f=NR} /\[keys\]/{k=NR} /\[rating\]/{r=NR} /\[rows\]/{w=NR} /\[evidence\]/{e=NR} END{print !(f && f<k && k<r && r<w && w<e)}' "$TMP/out")"

echo "Test 2: a fully clean run exits 0 with no problem lines, only summaries"
cat > "$TMP/findings.json" <<'EOF'
[
 {"app_id":"root","rule":"QUA-03","defect_key":"template/script.sh.erb:no-set-e","aspect":"quality","severity":"low","result":"FAIL","summary":"x","evidence":"template/script.sh.erb:1"}
]
EOF
cat > "$TMP/report.md" <<'EOF'
# Appverse Review: x
## App: X (root)
### Documentation
Rating: Minimal
Evidence per rung:
- what it launches: README.md:1
- prerequisites: README.md:5
### Signals
| Dimension | Level |
|---|---|
| Documentation | High |
## Upkeep
| Signal | Value | Assessment |
## Review scope
**Examined:** all
## Overall recommendation
**Accept with suggestions.** One fix-item.
## Draft feedback — edit before sending
No set -e in template/script.sh.erb; please add it.
<!-- feedback-covers: template/script.sh.erb:no-set-e -->
EOF
check "exit 0" 0 "$(run)"
check "no problem-line prefixes at all" 0 "$(grep -Ec '^\[[a-z]+\] (MISSING|INVALID|MISMATCH|UNCITED|BAD)' "$TMP/out")"
check "sections passes, prefixed summary" 1 "$(count '[sections] sections: complete')"
check "all five summaries present" 5 "$(grep -Ec '^\[(floor|keys|rating|rows|evidence)\] ' "$TMP/out")"

echo "Test 3: a run neither checker can even open (missing pre-review dir) exits 2"
rm -rf "$TMP/pre-review-missing"
python3 "$CHECK" "$TMP/report.md" "$TMP/findings.json" "$TMP/checks.json" "$TMP/pre-review-missing" --target "$TMP/target" > "$TMP/out2" 2>&1
rc2=$?
check "exit 2" 2 "$rc2"
check "rows block: error prefixed" 1 "$(grep -c '^\[rows\] error: ' "$TMP/out2")"
check "evidence still runs without the missing pre-review dir" 1 "$(grep -c '^\[evidence\] evidence: 1/1 valid; report rows: 0/0 valid$' "$TMP/out2")"

echo "Test 4: a report missing a section a checker needs is exit 1 (malformed report), not 2"
cp "$TMP/report.md" "$TMP/good.md"
awk '/^### Documentation/{skip=1} /^### Signals/{skip=0} !skip' "$TMP/good.md" > "$TMP/report.md"
check "exit 1" 1 "$(run)"
check "rating block says so" 1 "$(count "[rating] MISSING section: ## App: X (root) has no '### Documentation' section")"
grep -v -e '^## Draft feedback' "$TMP/good.md" > "$TMP/report.md"
check "no feedback section: exit 1" 1 "$(run)"
check "floor block says so" 1 "$(count "[floor] MISSING section: no '## Draft feedback' or '## Fix before submitting' section")"
cp "$TMP/good.md" "$TMP/report.md"

echo "Test 5: a checker that crashes (a traceback) is exit 2, could not run, never a finding"
mkdir -p "$TMP/refs"
cp "$CHECK" "$TMP/refs/check-all.py"
for s in check-feedback-floor check-keys check-rating check-rows check-evidence; do
  printf 'print("%s: ok")\n' "$s" > "$TMP/refs/$s.py"
done
printf 'print("keys: partial")\nraise TypeError("unhashable type: list")\n' > "$TMP/refs/check-keys.py"
python3 "$TMP/refs/check-all.py" "$TMP/report.md" "$TMP/findings.json" "$TMP/checks.json" "$TMP/pre-review" --target "$TMP/target" > "$TMP/out" 2>&1
check "exit 2" 2 "$?"
check "crash line" 1 "$(count '[keys] crashed: TypeError: unhashable type: list')"
check "the other checkers still ran" 4 "$(grep -Ec '^\[(floor|rating|rows|evidence)\] check-' "$TMP/out")"
printf 'import sys\nprint("rows: odd")\nsys.exit(4)\n' > "$TMP/refs/check-rows.py"
python3 "$TMP/refs/check-all.py" "$TMP/report.md" "$TMP/findings.json" "$TMP/checks.json" "$TMP/pre-review" --target "$TMP/target" > "$TMP/out" 2>&1
check "an exit code outside 0-3 is exit 2" 2 "$?"
check "its crash line" 1 "$(count '[rows] crashed: rows: odd')"

echo "Test 6: with a meta.json beside the report, a decision below its security floor is a [decisions] MISMATCH"
cat > "$TMP/findings.json" <<'EOF'
[
 {"app_id":"root","rule":"OODT-02","defect_key":"template/script.sh.erb:hardcoded-credential","aspect":"security","severity":"high","result":"FAIL","summary":"x","evidence":"template/script.sh.erb:1"}
]
EOF
echo '{"recommendation":{"decision":"Accept","note":"x"},"not_archived":"pass","public":"pass","apps":[{"app_id":"root","decision":"Accept"}]}' > "$TMP/report.meta.json"
check "exit 1" 1 "$(run)"
check "decisions block: MISMATCH prefixed" 1 "$(grep -c '^\[decisions\] MISMATCH decision root: Accept, but OODT-02 high FAIL at template/script.sh.erb:1 needs at least Request changes$' "$TMP/out")"
rm -f "$TMP/report.meta.json"
run >/dev/null
check "no meta.json: decisions not checked" 1 "$(count '[decisions] decisions: not checked (no meta.json beside the report)')"

echo
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
