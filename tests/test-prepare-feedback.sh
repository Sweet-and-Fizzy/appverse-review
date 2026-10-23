#!/usr/bin/env bash
# Test prepare-feedback.py: which findings become Draft feedback items, at
# which level, grouped how, and what survives a re-run.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REFS="$SCRIPT_DIR/references"
PREP="$REFS/prepare-feedback.py"
CHECKS="$REFS/checks.json"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
# prep: run the script on $TMP/f.json and $TMP/m.json into $TMP/fb.json; echo its exit code.
prep() { python3 "$PREP" "$TMP/f.json" "$TMP/m.json" "$CHECKS" "$TMP/fb.json" > "$TMP/out" 2>&1; echo $?; }
# q: print a Python expression over the feedback document `d` and its `items`.
q() { python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); items = d["items"]; print(eval(sys.argv[2]))' "$TMP/fb.json" "$1" 2>&1; }
levels() { q '",".join(i["level"] for i in items)'; }
DEFAULT_META='{"apps": [{"app_id": "root", "name": "SAS"}], "not_archived": "pass", "public": "pass"}'
meta() { if [ $# -gt 0 ]; then printf '%s' "$1"; else printf '%s' "$DEFAULT_META"; fi > "$TMP/m.json"; }
finding() { # app rule key result severity evidence [aspect]
  printf '{"app_id":"%s","rule":"%s","defect_key":"%s","result":"%s","severity":"%s","evidence":"%s","summary":"summary of %s","aspect":"%s"}' \
    "$1" "$2" "$3" "$4" "$5" "$6" "$3" "${7:-quality}"; }
findings() { local IFS=,; echo "[$*]" > "$TMP/f.json"; }

echo "Test 1: levels"
meta
findings "$(finding root STR-02 manifest.yml:missing-field:software FAIL low manifest.yml:1 structure)"
check "exit 0" 0 "$(prep)"
check "gate FAIL is must" "must" "$(levels)"
findings "$(finding root OODT-01 a.sh:unsanitized-user-input WARN high a.sh:3 security)"; prep >/dev/null
check "OODT WARN high is should" "should" "$(levels)"
findings "$(finding root OODT-01 a.sh:unsanitized-user-input FAIL low a.sh:3 security)"; prep >/dev/null
check "OODT FAIL low is suggestion" "suggestion" "$(levels)"
findings "$(finding root QUA-03 a.sh:no-error-check FAIL low a.sh:3)"; prep >/dev/null
check "QUA-03 low is should (table)" "should" "$(levels)"
findings "$(finding root QUA-07 form.yml:missing-pattern WARN low form.yml:4)"; prep >/dev/null
check "QUA-07 missing-pattern low is suggestion" "suggestion" "$(levels)"
findings "$(finding root QUA-01 README.md:docs-minimal FAIL low README.md:1)"; prep >/dev/null
check "QUA-01 any tag low is should (*)" "should" "$(levels)"
findings "$(finding root QUA-06 form.yml:wrong-help-text FAIL high form.yml:9)"; prep >/dev/null
check "QUA FAIL high is should not must" "should" "$(levels)"

echo "Test 2: info findings and PASS rows produce no item"
findings "$(finding root QUA-08 a.sh:magic-number FAIL info a.sh:3)" "$(finding root QUA-03 a.sh:no-error-check PASS info a.sh:3)"; prep >/dev/null
check "no items" "0" "$(q 'len(items)')"

echo "Test 3: grouping"
findings "$(finding app1 OODT-01 app1/submit.yml.erb:unsanitized-user-input WARN low app1/submit.yml.erb:11 security)" \
  "$(finding app2 OODT-01 app2/submit.yml.erb:unsanitized-user-input WARN low app2/submit.yml.erb:11 security)"
meta '{"repo_url": "https://github.com/ubc-arc/OOD_Appverse", "apps": [{"app_id": "app1", "name": "A"}, {"app_id": "app2", "name": "B"}]}'
prep >/dev/null
check "same rule+tag in two apps is one item" "1" "$(q 'len(items)')"
check "with both locations" "app1/submit.yml.erb:11|app2/submit.yml.erb:11" "$(q '"|".join(items[0]["locations"])')"
check "group key" "suggestion:OODT-01:unsanitized-user-input" "$(q 'items[0]["group"]')"
check "multi-app app_name is the repo name" "OOD_Appverse" "$(q 'd["app_name"]')"
meta
findings "$(finding root OODT-01 a.sh:unsanitized-user-input FAIL high a.sh:3 security)" "$(finding root OODT-01 b.erb:unsanitized-user-input WARN medium b.erb:5 security)"; prep >/dev/null
check "FAIL high and WARN medium of one tag are two items" "must,should" "$(levels)"
findings "$(finding root QUA-06 form.yml:duplicate-yaml-key:help FAIL low form.yml:10)" "$(finding root QUA-06 form.yml:duplicate-yaml-key:label FAIL low form.yml:20)"; prep >/dev/null
check "qualified tags group on the base tag" "1" "$(q 'len(items)')"
check "one file, both lines" "form.yml:10,20" "$(q '"|".join(items[0]["locations"])')"
findings "$(finding root STR-04 root:other:odd-layout FAIL low README.md:1 structure)" "$(finding root STR-04 root:other:stray-binary FAIL low bin/x:1 structure)"; prep >/dev/null
check "other: slugs do not merge" "2" "$(q 'len(items)')"
check "items sort by level then severity" "must,should,suggestion" "$(findings "$(finding root QUA-07 form.yml:missing-pattern WARN low form.yml:4)" "$(finding root STR-02 manifest.yml:missing-field:software FAIL low manifest.yml:1 structure)" "$(finding root QUA-06 form.yml:wrong-help-text FAIL medium form.yml:9)"; prep >/dev/null; levels)"

echo "Test 4: portability folding"
findings "$(finding root QUA-02 root:site-specific-mixin FAIL medium 'form.yml:3; template/script.sh.erb:21')" \
  "$(finding root QUA-02 form.yml:hardcoded-cluster WARN low form.yml:3)" \
  "$(finding root QUA-02 template/script.sh.erb:hardcoded-path WARN low template/script.sh.erb:21)"; prep >/dev/null
check "mixin folds hardcoded findings on its lines" "1" "$(q 'len(items)')"
check "folded item is should" "should" "$(levels)"
check "folded item covers all three keys" "3" "$(q 'len(items[0]["defect_keys"])')"
findings "$(finding root QUA-02 template/script.sh.erb:hardcoded-path WARN low template/script.sh.erb:21)" \
  "$(finding root QUA-02 root:site-specific-mixin FAIL medium 'form.yml:3; template/script.sh.erb:21')"; prep >/dev/null
check "the mixin's own locations come first" "form.yml:3|template/script.sh.erb:21" "$(q '"|".join(items[0]["locations"])')"
findings "$(finding root QUA-02 root:site-specific-mixin FAIL medium 'form.yml:3')" \
  "$(finding root QUA-02 form.yml:hardcoded-cluster WARN low form.yml:8)"; prep >/dev/null
check "hardcoded finding on another line stays separate" "should,suggestion" "$(levels)"

echo "Test 5: evidence_locations"
el() { PYTHONPATH="$REFS" python3 -c 'import sys; from feedback_terms import evidence_locations; print(evidence_locations(sys.argv[1]))' "$1"; }
check "two files" "[('form.yml', ['3']), ('template/script.sh.erb', ['21'])]" "$(el 'form.yml:3; template/script.sh.erb:21')"
check "four lines in one file" "[('template/script.sh.erb', ['11', '12', '17', '64'])]" "$(el 'template/script.sh.erb:11,12,17,64')"
check "reviewed OK tail is cut" "[('form.yml', ['3'])]" "$(el 'form.yml:3; reviewed OK: form.yml:9')"
check "range kept as written" "[('form.yml', ['8-9', '12'])]" "$(el 'form.yml:8-9,12')"
check "no path" "[]" "$(el 'commits')"
check "quoted code after the line is not more lines" "[('template/script.sh.erb', ['64'])]" "$(el 'template/script.sh.erb:64: module load sas/9.4')"
check "a quoted value is not a line" "[('form.yml', ['47'])]" "$(el 'form.yml:47: min: 0')"
check "comma-separated files are two entries" "[('form.yml', ['3']), ('template/script.sh.erb', ['21'])]" "$(el 'form.yml:3, template/script.sh.erb:21')"
check "a line-less path is kept" "[('manifest.yml', [])]" "$(el 'manifest.yml')"

echo "Test 6: labels for findings with no file"
findings "$(finding root MNT-01 root:stale-repo WARN medium commits maintenance)"; prep >/dev/null
check "root:stale-repo gets label Stale repo" "Stale repo" "$(q '"|".join(items[0]["locations"])')"
findings "$(finding root MNT-02 releases:no-releases WARN low 'GitHub releases API: 0' maintenance)"; prep >/dev/null
check "releases:no-releases gets label Release" "Release" "$(q '"|".join(items[0]["locations"])')"
findings "$(finding root MNT-04 .github/workflows:no-ci WARN low 'none found' maintenance)"; prep >/dev/null
check ".github/workflows:no-ci gets label CI workflow" "CI workflow" "$(q '"|".join(items[0]["locations"])')"
findings "$(finding root OODT-04 network:unexpected-network-call WARN low 'n/a' security)"; prep >/dev/null
check "pathless non-pseudo finding has no label" "0" "$(q 'len(items[0]["locations"])')"

echo "Test 7: meta gates"
findings
meta '{"apps": [{"app_id": "root", "name": "SAS"}], "not_archived": "FAIL", "public": "pass"}'; prep >/dev/null
check "archived meta adds the archived must item" "must:meta:not_archived" "$(q '"|".join(i["group"] for i in items)')"
check "archived item text" "The repository is archived on GitHub; unarchive it so the catalog can list it." "$(q 'items[0]["text"]')"
echo "not json" > "$TMP/m.json"; check "unreadable meta exits 0" 0 "$(prep)"
check "unreadable meta warns" "1" "$(grep -c '^warning:' "$TMP/out")"
check "unreadable meta: app_name empty" "" "$(q 'd["app_name"]')"

echo "Test 8: merge on re-run"
meta
findings "$(finding root QUA-03 a.sh:no-error-check FAIL low a.sh:3)" "$(finding root QUA-07 form.yml:missing-pattern WARN low form.yml:4)"; prep >/dev/null
python3 - "$TMP/fb.json" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))
d["opening"] = "Thank you."
for i in d["items"]:
    i["text"] = "Fix " + i["group"]
d["items"][0]["level"] = "must"
d["items"][0]["locations"] = ["elsewhere.txt:1"]
json.dump(d, open(sys.argv[1], "w"))
EOF
prep >/dev/null
check "merge keeps opening" "Thank you." "$(q 'd["opening"]')"
check "merge keeps text when group and keys unchanged" "Fix should:QUA-03:no-error-check" "$(q 'items[0]["text"]')"
check "merge discards edited regenerated fields" "should|a.sh:3" "$(q 'items[0]["level"] + "|" + "|".join(items[0]["locations"])')"
findings "$(finding root QUA-03 a.sh:no-error-check FAIL low a.sh:3)" "$(finding root QUA-03 b.sh:no-error-check FAIL low b.sh:2)" "$(finding root QUA-07 form.yml:missing-pattern WARN low form.yml:4)"; prep >/dev/null
check "merge clears text when defect_keys change" "" "$(q 'items[0]["text"]')"
check "an unchanged group keeps its text" "Fix suggestion:QUA-07:missing-pattern" "$(q 'items[1]["text"]')"
findings "$(finding root QUA-03 a.sh:no-error-check FAIL low a.sh:3)" "$(finding root QUA-07 form.yml:missing-pattern WARN medium form.yml:4)"; prep >/dev/null
check "merge clears text on level change" "" "$(q 'items[1]["text"]')"
echo '{"opening": 5, "items": [{"group": "should:QUA-03:no-error-check", "defect_keys": ["a.sh:no-error-check"], "text": ["x"]}]}' > "$TMP/fb.json"
check "non-string fields: exit 0" 0 "$(prep)"
check "non-string text is treated as empty" "" "$(q 'items[0]["text"]')"
check "non-string opening is treated as empty" "" "$(q 'd["opening"]')"
echo "{broken" > "$TMP/fb.json"
check "malformed feedback.json exits 0" 0 "$(prep)"
check "malformed feedback.json warns" "1" "$(grep -c '^warning:' "$TMP/out")"
check "and is rebuilt" "2" "$(q 'len(items)')"

echo "Test 8a: each item's text sits on the line after its unique group"
meta
findings "$(finding root QUA-03 a.sh:no-error-check FAIL low a.sh:3)" "$(finding root QUA-07 form.yml:missing-pattern WARN low form.yml:4)"
rm -f "$TMP/fb.json"; prep >/dev/null
check "text follows group in the file" '"text": ""|"text": ""' "$(grep -A1 '"group": ' "$TMP/fb.json" | grep -v '"group"' | grep -v '^--' | sed 's/^ *//; s/,$//' | paste -sd'|' -)"

echo "Test 8b: degraded findings and feedback shapes"
meta
echo '[{"app_id":"root","rule":"QUA-03","defect_key":null,"result":"FAIL","severity":"low","evidence":"a.sh:3"},{"app_id":"root","rule":"QUA-03","defect_key":null,"result":"FAIL","severity":"low","evidence":"b.sh:4"}]' > "$TMP/f.json"
prep >/dev/null
check "null defect_key with an existing feedback.json exits 0" 0 "$(prep)"
echo '{"items": {"not": "a list"}}' > "$TMP/fb.json"
prep >/dev/null
check "wrong-shaped feedback.json warns" "1" "$(grep -c '^warning:' "$TMP/out")"
echo '["a list"]' > "$TMP/fb.json"
prep >/dev/null
check "non-object feedback.json warns" "1" "$(grep -c '^warning:' "$TMP/out")"

echo "Test 9: findings that cannot be read exit 2"
echo "nope" > "$TMP/f.json"
check "exit 2" 2 "$(prep)"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
