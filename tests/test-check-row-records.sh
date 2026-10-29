#!/usr/bin/env bash
# Test check-row-records.py: every FAIL or WARN row in an app's section is backed by a record of its rule,
# at its result or worse, whose evidence carries a line the row cites.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHK="$SCRIPT_DIR/references/check-row-records.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); cat "$TMP/out"; fi; }
run() { python3 "$CHK" "$@" > "$TMP/out" 2>&1; echo $?; }
count() { grep -cxF -- "$1" "$TMP/out"; }
# finding <app_id> <rule> <defect_key> <result> <evidence>
finding() { printf '{"app_id":"%s","rule":"%s","defect_key":"%s","aspect":"x","severity":"low","result":"%s","summary":"s","evidence":"%s"}' "$@"; }

P="$TMP/pre"; mkdir -p "$P"
echo '[{"app_id": "root", "path": ".", "app_type": "batch_connect"}]' > "$P/apps.json"
cat > "$TMP/r.md" <<'EOF'
# Review

## App: Llama (root)

### Security

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | FAIL | medium | unintentional | extra_slurm_args reaches the shell | submit.yml.erb:18 |
| OODT-01 | `check: sec-interpolation` | WARN | low | unintentional | auto_accounts select, controlled value | submit.yml.erb:4 |
| — | `check: sec-tool-finding` | PASS | info | — | SC2148: artefacts | template/after.sh:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | FAIL | low | bc_num_hours has no min | form.yml:19 |
| QUA-07 | `check: numeric-field-bounds` | **WARN** (low) | low | extra_llama_args has no pattern | form.yml:76 |
| QUA-02 | `check: portability-rating` | FAIL | low | Not portable; set by the hardcoded-path records | template/before.sh.erb:2 |
| QUA-08 | `check: magic-numbers` | NOT CHECKED | info | n/a | — |
EOF
SEC="$(finding root OODT-01 submit.yml.erb:unsanitized-user-input FAIL 'submit.yml.erb:4,5,18')"

echo "Test 1: a FAIL row whose record a repair removed (the llama bc_num_hours case)"
echo "[$SEC,$(finding root QUA-07 form.yml:missing-pattern WARN 'form.yml:76')]" > "$TMP/f1.json"
check "exit 1" 1 "$(run "$TMP/r.md" "$TMP/f1.json" "$P")"
check "line" 1 "$(count 'MISMATCH root QUA-07 FAIL row (`check: numeric-field-bounds`, form.yml:19): findings.json has no QUA-07 record at FAIL for this app; its QUA-07 records are WARN')"
check "summary" "row-records: 1 app, 4 FAIL/WARN rows, 1 problem" "$(tail -1 "$TMP/out")"

echo "Test 2: every row backed; a WARN row inside a FAIL record that cites its line is the merge rule, not a mismatch"
echo "[$SEC,$(finding root qua-07 form.yml:missing-min ' fail ' 'form.yml:19'),$(finding root QUA-07 form.yml:missing-pattern 'WARN (low)' 'form.yml:76')]" > "$TMP/f2.json"
check "exit 0" 0 "$(run "$TMP/r.md" "$TMP/f2.json" "$P")"
check "summary" "row-records: 1 app, 4 FAIL/WARN rows, 0 problems" "$(tail -1 "$TMP/out")"

echo "Test 3: another record of the same rule and result does not hide a removed one (the tillicum case)"
echo "[$SEC,$(finding root QUA-07 form.yml:missing-pattern FAIL 'form.yml:76')]" > "$TMP/f3.json"
check "exit 1" 1 "$(run "$TMP/r.md" "$TMP/f3.json" "$P")"
check "line" 1 "$(count 'MISMATCH root QUA-07 FAIL row (`check: numeric-field-bounds`, form.yml:19): no QUA-07 record at FAIL or worse for this app cites form.yml:19')"
check "only that row" "row-records: 1 app, 4 FAIL/WARN rows, 1 problem" "$(tail -1 "$TMP/out")"

echo "Test 4: a row whose rule has no record at all; a reviewed-OK line does not back a row"
echo "[$(finding root OODT-01 submit.yml.erb:unsanitized-user-input FAIL 'submit.yml.erb:18; reviewed OK: submit.yml.erb:4'),$(finding root QUA-07 form.yml:missing-min FAIL 'form.yml:19,76')]" > "$TMP/f4.json"
check "exit 1" 1 "$(run "$TMP/r.md" "$TMP/f4.json" "$P")"
check "reviewed OK line" 1 "$(count 'MISMATCH root OODT-01 WARN row (`check: sec-interpolation`, submit.yml.erb:4): no OODT-01 record at WARN or worse for this app cites submit.yml.erb:4')"
echo "[$(finding root QUA-07 form.yml:missing-min FAIL 'form.yml:19,76')]" > "$TMP/f4b.json"
check "exit 1" 1 "$(run "$TMP/r.md" "$TMP/f4b.json" "$P")"
check "no OODT-01 record" 1 "$(count 'MISMATCH root OODT-01 FAIL row (`check: sec-interpolation`, submit.yml.erb:18): findings.json has no OODT-01 record at FAIL for this app; it has no OODT-01 record')"

echo "Test 5: a row with no citation is backed by rule and rank alone; a FAIL (gate) result is FAIL"
cat > "$TMP/r5.md" <<'EOF'
## App: Llama (root)

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-01 | — | FAIL (gate) | high | No license file | — |
| QUA-03 | `check: error-handling` | WARN | low | no set -e | — |
EOF
echo "[$(finding root STR-01 LICENSE:missing-license FAIL 'LICENSE'),$(finding root QUA-03 template/script.sh.erb:no-set-e FAIL 'template/script.sh.erb:1')]" > "$TMP/f5.json"
check "exit 0" 0 "$(run "$TMP/r5.md" "$TMP/f5.json" "$P")"
check "both rows judged" "row-records: 1 app, 2 FAIL/WARN rows, 0 problems" "$(tail -1 "$TMP/out")"
echo "[$(finding root QUA-03 template/script.sh.erb:no-set-e FAIL 'template/script.sh.erb:1')]" > "$TMP/f5b.json"
check "the gate row without a record" 1 "$(run "$TMP/r5.md" "$TMP/f5b.json" "$P")"
check "named by its summary when it cites nothing" 1 "$(count 'MISMATCH root STR-01 FAIL row (No license file): findings.json has no STR-01 record at FAIL for this app; it has no STR-01 record')"

echo "Test 6: a monorepo row is backed by its own app's record (repo or app paths) or a repo-level one, never another app's"
mkdir -p "$TMP/pm"
echo '[{"app_id": "a", "path": "apps/a", "app_type": "batch_connect"}, {"app_id": "b", "path": "apps/b", "app_type": "batch_connect"}]' > "$TMP/pm/apps.json"
cat > "$TMP/rm.md" <<'EOF'
## App: A (a)

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | maintainer.name missing | manifest.yml |
| QUA-03 | `check: error-handling` | FAIL | low | no set -e | template/script.sh.erb:1 |

## App: B (apps/b)

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-03 | `check: error-handling` | FAIL | low | no set -e | apps/b/template/script.sh.erb:1 |
EOF
echo "[$(finding root STR-02 root:missing-field:maintainer.name FAIL 'manifest.yml'),$(finding a QUA-03 apps/a/template/script.sh.erb:no-set-e FAIL 'apps/a/template/script.sh.erb:1')]" > "$TMP/f6.json"
check "exit 1" 1 "$(run "$TMP/rm.md" "$TMP/f6.json" "$TMP/pm")"
check "only b's row" 1 "$(grep -c '^MISMATCH ' "$TMP/out")"
check "b, found by its path" 1 "$(grep -c '^MISMATCH b QUA-03 FAIL row' "$TMP/out")"

echo "Test 7: a row with no rule code, a row outside an app section, and a table with no Rule column are not judged"
cat > "$TMP/r7.md" <<'EOF'
## Summary

| Rule | Result | Summary |
|---|---|---|
| STR-01 | FAIL | LICENSE missing |

## App: Llama (root)

| Check | Result | Evidence |
|---|---|---|
| `check: documentation-rating` | FAIL | README.md:1 |

| Rule | Check | Result | Summary | Evidence |
|---|---|---|---|---|
| — | `check: sec-tool-finding` | FAIL | SC2086 | template/after.sh:35 |
EOF
check "exit 0" 0 "$(run "$TMP/r7.md" "$TMP/f1.json" "$P")"
check "no rows judged" "row-records: 1 app, 0 FAIL/WARN rows, 0 problems" "$(tail -1 "$TMP/out")"

echo "Test 8: unreadable inputs exit 2; malformed records and apps are skipped, never a traceback"
echo '{' > "$TMP/bad.json"
check "bad findings" 2 "$(run "$TMP/r.md" "$TMP/bad.json" "$P")"
check "missing report" 2 "$(run "$TMP/nope.md" "$TMP/f1.json" "$P")"
check "usage" 2 "$(run "$TMP/r.md" "$TMP/f1.json")"
echo '[{"app_id": ["root"], "rule": "QUA-07", "result": "FAIL"}, {"app_id": "root", "rule": 7, "result": "FAIL"}, {"app_id": "root", "rule": "QUA-07", "result": "FAIL", "evidence": ["form.yml:19"]}, "x", null]' > "$TMP/f8.json"
check "malformed records: the rows are unbacked" 1 "$(run "$TMP/r.md" "$TMP/f8.json" "$P")"
check "no traceback" 0 "$(grep -c Traceback "$TMP/out")"
mkdir -p "$TMP/badapps"; echo '[{"app_id": "root", "path": 5}]' > "$TMP/badapps/apps.json"
check "an app with a non-string path: judged by section id" 1 "$(run "$TMP/r.md" "$TMP/f1.json" "$TMP/badapps")"
check "no traceback either" 0 "$(grep -c Traceback "$TMP/out")"

echo "Test 9: without apps.json, a section's own id names its app"
mkdir -p "$TMP/noapps"
check "exit 1" 1 "$(run "$TMP/r.md" "$TMP/f1.json" "$TMP/noapps")"
check "still judged" 1 "$(grep -c '^MISMATCH root QUA-07 FAIL row' "$TMP/out")"

echo; echo "check-row-records: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
