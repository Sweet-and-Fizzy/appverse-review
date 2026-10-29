#!/usr/bin/env bash
# Test check-form.py: STR-04 and QUA-07 findings agree with the attributes form.json says OOD defines.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHK="$SCRIPT_DIR/references/check-form.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { python3 "$CHK" "$@" > "$TMP/out" 2>&1; echo $?; }
# form <pre-review dir> <app_id>: a form.json with OOD's auto_accounts and auto_qos, bc_num_hours, global_gpus and the form's own extra
form() { mkdir -p "$1/$2"; cat > "$1/$2/form.json" <<'JSON'
{"file": "form.yml", "submit_file": "submit.yml.erb", "error": null, "attributes": [
 {"name": "auto_accounts", "widget": "select", "min": null, "pattern": null, "defined": false, "ood": "auto", "in_form": true},
 {"name": "auto_qos", "widget": "select", "min": null, "pattern": null, "defined": true, "ood": "auto", "in_form": true},
 {"name": "bc_num_hours", "widget": "number_field", "min": 1, "pattern": null, "defined": true, "ood": "builtin", "in_form": true},
 {"name": "bc_queue", "widget": "text_field", "min": null, "pattern": null, "defined": false, "ood": "builtin", "in_form": true},
 {"name": "global_gpus", "widget": null, "min": null, "pattern": null, "defined": false, "ood": "global", "in_form": true},
 {"name": "extra", "widget": "text_field", "min": null, "pattern": null, "defined": true, "ood": null, "in_form": true}]}
JSON
}
# finding <app_id> <rule> <defect_key> [result]
finding() { printf '{"app_id":"%s","rule":"%s","defect_key":"%s","aspect":"x","severity":"high","result":"%s","summary":"s","evidence":"x"}' "$1" "$2" "$3" "${4:-FAIL}"; }

echo "Test 1: an undefined-variable FAIL on an OOD auto attribute (the tillicum case)"
form "$TMP/p" root; echo "[$(finding root STR-04 submit.yml.erb:undefined-variable:auto_accounts)]" > "$TMP/f1.json"
check "exit 1" 1 "$(run "$TMP/f1.json" "$TMP/p")"
check "line" 1 "$(grep -cxF 'MISMATCH root submit.yml.erb:undefined-variable:auto_accounts: FAIL, but form.json lists auto_accounts as one OOD defines (auto)' "$TMP/out")"
check "summary" "form: 1 problems" "$(tail -1 "$TMP/out")"

echo "Test 2: undefined-attribute and a global_ one, WARN too"
echo "[$(finding root STR-04 form.yml:undefined-attribute:global_gpus WARN)]" > "$TMP/f2.json"
check "exit 1" 1 "$(run "$TMP/f2.json" "$TMP/p")"
check "line" 1 "$(grep -cxF 'MISMATCH root form.yml:undefined-attribute:global_gpus: WARN, but form.json lists global_gpus as one OOD defines (global)' "$TMP/out")"

echo "Test 3: the form's own undefined attribute stays"
echo "[$(finding root STR-04 submit.yml.erb:undefined-variable:custom_x)]" > "$TMP/f3.json"
check "exit 0" 0 "$(run "$TMP/f3.json" "$TMP/p")"

echo "Test 4: a missing-pattern FAIL on an attribute OOD renders as a select"
echo "[$(finding root QUA-07 form.yml:missing-pattern:auto_qos)]" > "$TMP/f4.json"
check "exit 1" 1 "$(run "$TMP/f4.json" "$TMP/p")"
check "line" 1 "$(grep -cxF 'MISMATCH root form.yml:missing-pattern:auto_qos: FAIL, but form.json has auto_qos as a select, which takes no free text' "$TMP/out")"

echo "Test 5: a missing-pattern FAIL on an OOD number field with a floor"
echo "[$(finding root QUA-07 form.yml:missing-pattern:bc_num_hours)]" > "$TMP/f5.json"
check "exit 1" 1 "$(run "$TMP/f5.json" "$TMP/p")"
check "line" 1 "$(grep -cxF 'MISMATCH root form.yml:missing-pattern:bc_num_hours: FAIL, but form.json has bc_num_hours as a number_field with min 1' "$TMP/out")"

echo "Test 6: a missing-pattern FAIL on an OOD text field, and on the form's own text field, stays"
echo "[$(finding root QUA-07 form.yml:missing-pattern:bc_queue),$(finding root QUA-07 form.yml:missing-pattern:extra)]" > "$TMP/f6.json"
check "exit 0" 0 "$(run "$TMP/f6.json" "$TMP/p")"

echo "Test 7: a monorepo app reads its own form.json; PASS records are not judged"
form "$TMP/p" apps/a; echo "[$(finding apps/a STR-04 apps/a/submit.yml.erb:undefined-variable:auto_accounts),$(finding root STR-04 submit.yml.erb:undefined-variable:auto_qos PASS)]" > "$TMP/f7.json"
check "exit 1" 1 "$(run "$TMP/f7.json" "$TMP/p")"
check "only the app's FAIL" "1|0" "$(grep -c '^MISMATCH apps/a ' "$TMP/out")|$(grep -c '^MISMATCH root ' "$TMP/out")"

echo "Test 8: an app with no form.json is not judged"
echo "[$(finding apps/b STR-04 apps/b/submit.yml.erb:undefined-variable:auto_accounts)]" > "$TMP/f8.json"
check "exit 0" 0 "$(run "$TMP/f8.json" "$TMP/p")"

echo "Test 9: unreadable findings is exit 2"
echo "{" > "$TMP/f9.json"
check "exit 2" 2 "$(run "$TMP/f9.json" "$TMP/p")"

echo
echo "check-form: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
