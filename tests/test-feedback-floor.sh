#!/usr/bin/env bash
# Test check-feedback-floor.py: the Draft Feedback must name every Low+ FAIL/WARN finding.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$SCRIPT_DIR/references/check-feedback-floor.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { python3 "$CHECK" "$1" "$2" > "$TMP/out" 2>&1; echo $?; }

cat > "$TMP/findings.json" <<'EOF'
[
 {"app_id":"root","rule":"OODT-01","defect_key":"submit.yml.erb:unsanitized-input","aspect":"security","severity":"low","result":"WARN","summary":"x","evidence":"submit.yml.erb:15-19"},
 {"app_id":"root","rule":"QUA-03","defect_key":"template/script.sh.erb:no-error-handling","aspect":"quality","severity":"low","result":"FAIL","summary":"x","evidence":"template/script.sh.erb:1"},
 {"app_id":"root","rule":"QUA-05","defect_key":"template/script.sh.erb:dead-code","aspect":"quality","severity":"info","result":"WARN","summary":"x","evidence":"template/script.sh.erb:30"},
 {"app_id":"root","rule":"OODT-04","defect_key":"root:tier3","aspect":"security","severity":"medium","result":"NOT CHECKED","summary":"x","evidence":"n/a"},
 {"app_id":"root","rule":"MNT-03","defect_key":"root:changelog-wrong-app","aspect":"maintenance","severity":"low","result":"WARN","summary":"CHANGELOG describes another app","evidence":"CHANGELOG.md:11"},
 {"app_id":"root","rule":"MNT-02","defect_key":"root:no-releases","aspect":"maintenance","severity":"low","result":"WARN","summary":"0 tagged releases","evidence":"GitHub releases API: 0"}
]
EOF

echo "Test 1: fully covered feedback passes"
cat > "$TMP/ok.md" <<'EOF'
# Appverse Review: x
## Overall recommendation
Accept with suggestions.
## Draft feedback — edit before sending
Please validate the free-text fields in submit.yml.erb. Add set -e to template/script.sh.erb.
CHANGELOG.md describes a different app; please rewrite it. Consider tagging a release.
<!-- feedback-covers: submit.yml.erb:unsanitized-input, template/script.sh.erb:no-error-handling, root:changelog-wrong-app, root:no-releases -->
EOF
check "exit 0" 0 "$(run "$TMP/findings.json" "$TMP/ok.md")"
check "reports 4/4" "feedback floor: 4/4 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 2: a Low finding missing from the coverage line fails"
sed 's/, root:no-releases//' "$TMP/ok.md" > "$TMP/missing-key.md"
check "exit 1" 1 "$(run "$TMP/findings.json" "$TMP/missing-key.md")"
check "names the finding" 1 "$(grep -c 'MISSING MNT-02 root:no-releases' "$TMP/out")"
check "reports 3/4" "feedback floor: 3/4 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 3: key listed but file never named in prose fails"
sed 's#Add set -e to template/script.sh.erb.#Add set -e to the job script.#' "$TMP/ok.md" > "$TMP/missing-path.md"
check "exit 1" 1 "$(run "$TMP/findings.json" "$TMP/missing-path.md")"
check "names the finding with reason" 1 "$(grep -c 'MISSING QUA-03 template/script.sh.erb:no-error-handling (file not named in feedback)' "$TMP/out")"

echo "Test 4: basename is enough"
sed 's#template/script.sh.erb\.#script.sh.erb.#' "$TMP/ok.md" > "$TMP/basename.md"
check "exit 0" 0 "$(run "$TMP/findings.json" "$TMP/basename.md")"

echo "Test 5: submitter-mode heading accepted"
sed 's/^## Draft feedback — edit before sending$/## Fix before submitting/' "$TMP/ok.md" > "$TMP/submitter.md"
check "exit 0" 0 "$(run "$TMP/findings.json" "$TMP/submitter.md")"

echo "Test 6: no feedback section is exit 2"
grep -v -e '^## Draft feedback' -e 'feedback-covers' "$TMP/ok.md" > "$TMP/nosection.md"
check "exit 2" 2 "$(run "$TMP/findings.json" "$TMP/nosection.md")"

echo "Test 7: no coverage line is exit 1 with every fix-item missing"
grep -v 'feedback-covers' "$TMP/ok.md" > "$TMP/nocover.md"
check "exit 1" 1 "$(run "$TMP/findings.json" "$TMP/nocover.md")"
check "reports 0/4" "feedback floor: 0/4 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 8: no fix-items at all passes with 0/0"
echo '[{"app_id":"root","rule":"QUA-05","defect_key":"a:b","aspect":"quality","severity":"info","result":"WARN","summary":"x","evidence":"a:1"}]' > "$TMP/none.json"
check "exit 0" 0 "$(run "$TMP/none.json" "$TMP/ok.md")"
check "reports 0/0" "feedback floor: 0/0 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 9: a '##' line inside a fenced code block does not end the section"
awk '/<!-- feedback-covers:/ { print "```"; print "## a comment inside a snippet"; print "```" } { print }' "$TMP/ok.md" > "$TMP/fenced.md"
check "exit 0" 0 "$(run "$TMP/findings.json" "$TMP/fenced.md")"
check "reports 4/4" "feedback floor: 4/4 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 10: a superstring of the path does not satisfy the token-boundary match"
sed 's#template/script.sh.erb\.#template/myscript.sh.erb.#' "$TMP/ok.md" > "$TMP/superstring.md"
check "exit 1" 1 "$(run "$TMP/findings.json" "$TMP/superstring.md")"
check "names the finding with reason" 1 "$(grep -c 'MISSING QUA-03 template/script.sh.erb:no-error-handling (file not named in feedback)' "$TMP/out")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
