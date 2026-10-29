#!/usr/bin/env bash
# Test check-form.py: STR-04 and QUA-07 findings agree with the attributes form.json says OOD builds.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHK="$SCRIPT_DIR/references/check-form.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { python3 "$CHK" "$@" > "$TMP/out" 2>&1; echo $?; }
# form <pre-review dir> <app_id>: a form.json as scan_form writes it
form() { mkdir -p "$1/$2"; cat > "$1/$2/form.json" <<'JSON'
{"file": "form.yml", "submit_file": "submit.yml.erb", "error": null, "attributes": [
 {"name": "auto_qos", "widget": "select", "min": null, "line": 5, "defined": true, "ood": "auto", "in_form": true},
 {"name": "bc_num_hours", "widget": "number_field", "min": 1, "line": 19, "defined": true, "ood": "builtin", "in_form": true},
 {"name": "extra", "widget": "text_field", "min": null, "line": 90, "defined": true, "ood": null, "in_form": true},
 {"name": "not_in_form", "widget": "select", "min": null, "line": 95, "defined": true, "ood": "auto", "in_form": false},
 {"name": "auto_accounts", "widget": "select", "min": null, "line": 101, "defined": false, "ood": "auto", "in_form": true},
 {"name": "global_gpus", "widget": null, "min": null, "line": 102, "defined": false, "ood": "global", "in_form": true},
 {"name": "custom_x", "widget": "text_field", "min": null, "line": 103, "defined": false, "ood": null, "in_form": true}]}
JSON
}
# finding <app_id> <rule> <defect_key> [result] [evidence]
finding() { printf '{"app_id":"%s","rule":"%s","defect_key":"%s","aspect":"x","severity":"low","result":"%s","summary":"s","evidence":"%s"}' "$1" "$2" "$3" "${4:-FAIL}" "${5:-x}"; }

echo "Test 1: an undefined-variable FAIL on an OOD auto attribute in form: (the tillicum case)"
form "$TMP/p" root; echo "[$(finding root STR-04 submit.yml.erb:undefined-variable:auto_accounts)]" > "$TMP/f1.json"
check "exit 1" 1 "$(run "$TMP/f1.json" "$TMP/p")"
check "line" 1 "$(grep -cxF 'MISMATCH root submit.yml.erb:undefined-variable:auto_accounts: FAIL, but form.json lists auto_accounts under form:, so OOD builds it (an auto attribute)' "$TMP/out")"
check "summary" "form: 1 problems" "$(tail -1 "$TMP/out")"

echo "Test 2: undefined-attribute WARNs on a global_ attribute and on the form's own attribute in form: with no attributes: block"
echo "[$(finding root STR-04 form.yml:undefined-attribute:global_gpus WARN),$(finding root STR-04 submit.yml.erb:undefined-variable:custom_x)]" > "$TMP/f2.json"
check "exit 1" 1 "$(run "$TMP/f2.json" "$TMP/p")"
check "global line" 1 "$(grep -cxF 'MISMATCH root form.yml:undefined-attribute:global_gpus: WARN, but form.json lists global_gpus under form:, so OOD builds it (a global attribute)' "$TMP/out")"
check "own line" 1 "$(grep -cxF 'MISMATCH root submit.yml.erb:undefined-variable:custom_x: FAIL, but form.json lists custom_x under form:, so OOD builds it (a text_field)' "$TMP/out")"

echo "Test 3: an attribute declared but not in form: is never built, so its undefined FAIL stays; so does one form.json does not list"
echo "[$(finding root STR-04 submit.yml.erb:undefined-variable:not_in_form),$(finding root STR-04 submit.yml.erb:undefined-variable:nowhere)]" > "$TMP/f3.json"
check "exit 0" 0 "$(run "$TMP/f3.json" "$TMP/p")"

echo "Test 4: a QUA-07 record keyed with the attribute as a suffix"
echo "[$(finding root QUA-07 form.yml:missing-pattern:auto_qos)]" > "$TMP/f4.json"
check "exit 1" 1 "$(run "$TMP/f4.json" "$TMP/p")"
check "line" 1 "$(grep -cxF 'MISMATCH root form.yml:missing-pattern:auto_qos: FAIL, but auto_qos is an attribute OOD defines and bounds itself (numeric-field-bounds does not judge it); remove the record' "$TMP/out")"

echo "Test 5: a QUA-07 record with the fixed tag names its attributes by the lines it cites (the abaqus case)"
echo "[$(finding root QUA-07 form.yml:missing-min FAIL form.yml:19)]" > "$TMP/f5.json"
check "exit 1" 1 "$(run "$TMP/f5.json" "$TMP/p")"
check "line" 1 "$(grep -cxF 'MISMATCH root form.yml:missing-min: FAIL, but bc_num_hours is an attribute OOD defines and bounds itself (numeric-field-bounds does not judge it); remove the record' "$TMP/out")"

echo "Test 6: one record over OOD's and the form's own attributes keeps the form's (the tillicum shared row)"
echo "[$(finding root QUA-07 form.yml:missing-pattern FAIL 'form.yml:5,19,90')]" > "$TMP/f6.json"
check "exit 1" 1 "$(run "$TMP/f6.json" "$TMP/p")"
check "line" 1 "$(grep -cxF 'MISMATCH root form.yml:missing-pattern: FAIL, but auto_qos, bc_num_hours are attributes OOD defines and bounds itself (numeric-field-bounds does not judge them); drop them from the record and its row and keep extra' "$TMP/out")"

echo "Test 7: QUA-07 records on the form's own attributes, zero-minimum and missing-required stay"
echo "[$(finding root QUA-07 form.yml:missing-pattern FAIL form.yml:90),$(finding root QUA-07 form.yml:zero-minimum FAIL form.yml:19),$(finding root QUA-07 form.yml:missing-required FAIL form.yml:19)]" > "$TMP/f7.json"
check "exit 0" 0 "$(run "$TMP/f7.json" "$TMP/p")"

echo "Test 8: a monorepo app reads its own form.json and its app-prefixed citations; PASS records are not judged"
form "$TMP/p" apps/a
echo "[$(finding apps/a QUA-07 apps/a/form.yml:missing-min FAIL apps/a/form.yml:19),$(finding root STR-04 submit.yml.erb:undefined-variable:auto_qos PASS)]" > "$TMP/f8.json"
check "exit 1" 1 "$(run "$TMP/f8.json" "$TMP/p")"
check "only the app's FAIL" "1|0" "$(grep -c '^MISMATCH apps/a ' "$TMP/out")|$(grep -c '^MISMATCH root ' "$TMP/out")"

echo "Test 9: an app with no form.json is not judged"
echo "[$(finding apps/b STR-04 apps/b/submit.yml.erb:undefined-variable:auto_accounts)]" > "$TMP/f9.json"
check "exit 0" 0 "$(run "$TMP/f9.json" "$TMP/p")"

echo "Test 10: unreadable findings is exit 2"
echo "{" > "$TMP/f10.json"
check "exit 2" 2 "$(run "$TMP/f10.json" "$TMP/p")"

echo
echo "check-form: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
