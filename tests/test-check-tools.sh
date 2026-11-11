#!/usr/bin/env bash
# Test check-tools.py: a record resting only on a static-tool finding uses the rule and tag security-tools.md gives its code.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHK="$SCRIPT_DIR/references/check-tools.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { python3 "$CHK" "$@" > "$TMP/out" 2>&1; echo $?; }
# security <pre-review dir> <app_id>: a security.json with tool_finding candidates as pre-review.py writes them
security() { mkdir -p "$1/$2"; cat > "$1/$2/security.json" <<'JSON'
{"counts": {}, "candidates": [
 {"kind": "interpolation", "check": "sec-interpolation", "file": "submit.yml.erb", "line": 4, "rule": "OODT-01", "tag": "unsanitized-user-input"},
 {"kind": "tool_finding", "check": "sec-tool-finding", "rule": null, "tag": null, "tool": "shellcheck", "code": "SC2164", "file": "template/script.sh.erb", "lines": [12, 30], "artifact": false},
 {"kind": "tool_finding", "check": "sec-tool-finding", "rule": null, "tag": null, "tool": "shellcheck", "code": "SC2086", "file": "template/after.sh", "lines": [35], "artifact": false},
 {"kind": "tool_finding", "check": "sec-tool-finding", "rule": null, "tag": null, "tool": "shellcheck", "code": "SC2054", "file": "template/script.sh.erb", "lines": [112, 115], "artifact": false},
 {"kind": "tool_finding", "check": "sec-tool-finding", "rule": null, "tag": null, "tool": "shellcheck", "code": "SC2140", "file": "template/script.sh.erb", "lines": [128], "artifact": false},
 {"kind": "tool_finding", "check": "sec-tool-finding", "rule": null, "tag": null, "tool": "shellcheck", "code": "SC2154", "file": "template/script.sh.erb", "lines": [40], "artifact": false},
 {"kind": "tool_finding", "check": "sec-tool-finding", "rule": null, "tag": null, "tool": "shellcheck", "code": "SC2071", "file": "template/script.sh.erb", "lines": [50], "artifact": false},
 {"kind": "tool_finding", "check": "sec-tool-finding", "rule": null, "tag": null, "tool": "bandit", "code": "B603", "file": "template/proxy.py", "lines": [60], "artifact": false},
 {"kind": "tool_finding", "check": "sec-tool-finding", "rule": null, "tag": null, "tool": "bandit", "code": "B110", "file": "template/proxy.py", "lines": [352, 365], "artifact": false}]}
JSON
}
# finding <app_id> <rule> <defect_key> <result> <evidence> <summary>
finding() { printf '{"app_id":"%s","rule":"%s","defect_key":"%s","aspect":"security","severity":"low","result":"%s","evidence":"%s","summary":"%s"}' "$@"; }
security "$TMP/p" root

echo "Test 1: a listed hygiene code filed under an OODT rule (the schrodinger SC2164 case)"
echo "[$(finding root OODT-08 template/script.sh.erb:insecure-default WARN 'template/script.sh.erb:12,30' 'SC2164: cd without || exit')]" > "$TMP/f1.json"
check "exit 1" 1 "$(run "$TMP/f1.json" "$TMP/p")"
check "line" 1 "$(grep -cxF 'MISMATCH root template/script.sh.erb:insecure-default: WARN under OODT-08, but its only evidence is shellcheck SC2164, which security-tools.md files under QUA-03 no-error-check; re-key it as QUA-03 template/script.sh.erb:no-error-check' "$TMP/out")"
check "summary" "tools: 1 problems" "$(tail -1 "$TMP/out")"

echo "Test 2: a listed security code filed under a QUA rule (the llama SC2086 case)"
echo "[$(finding root QUA-03 template/after.sh:no-error-check FAIL 'template/after.sh:35' 'SC2086: unquoted variable')]" > "$TMP/f2.json"
check "exit 1" 1 "$(run "$TMP/f2.json" "$TMP/p")"
check "line" 1 "$(grep -cxF 'MISMATCH root template/after.sh:no-error-check: FAIL under QUA-03, but its only evidence is shellcheck SC2086, which security-tools.md files under OODT-01 unquoted-variable; re-key it as OODT-01 template/after.sh:unquoted-variable' "$TMP/out")"

echo "Test 3: the right rule but the wrong tag, and two codes in one record (the llama SC2054 case)"
echo "[$(finding root QUA-08 template/script.sh.erb:magic-number WARN 'template/script.sh.erb:112,115; template/script.sh.erb:128' 'SC2054: comma in array element; SC2140: mixed quoting')]" > "$TMP/f3.json"
check "exit 1" 1 "$(run "$TMP/f3.json" "$TMP/p")"
check "SC2054 line" 1 "$(grep -cxF 'MISMATCH root template/script.sh.erb:magic-number: WARN under QUA-08, but its only evidence is shellcheck SC2054, which security-tools.md files under QUA-06 other:array-element-comma; re-key it as QUA-06 template/script.sh.erb:other:array-element-comma' "$TMP/out")"
check "SC2140 line" 1 "$(grep -cxF 'MISMATCH root template/script.sh.erb:magic-number: WARN under QUA-08, but its only evidence is shellcheck SC2140, which security-tools.md files under QUA-06 other:mixed-quoting; re-key it as QUA-06 template/script.sh.erb:other:mixed-quoting' "$TMP/out")"

echo "Test 4: records that follow the table, including a {var_name} tag and a bandit code"
echo "[$(finding root QUA-03 template/script.sh.erb:no-error-check WARN 'template/script.sh.erb:12' 'SC2164: cd without || exit'),$(finding root STR-04 template/script.sh.erb:undefined-variable:WORKDIR WARN 'template/script.sh.erb:40' 'SC2154: WORKDIR is referenced but not assigned'),$(finding root QUA-03 template/proxy.py:no-error-check FAIL 'template/proxy.py:352,365' 'B110: bare except: pass')]" > "$TMP/f4.json"
check "exit 0" 0 "$(run "$TMP/f4.json" "$TMP/p")"
check "summary" "tools: 0 problems" "$(tail -1 "$TMP/out")"

echo "Test 5: an unlisted shellcheck code under an OODT rule (the schrodinger SC2071 case); under a QUA rule it stands"
echo "[$(finding root OODT-08 template/script.sh.erb:insecure-default WARN 'template/script.sh.erb:50' 'SC2071: > is for string comparisons'),$(finding root QUA-06 template/script.sh.erb:other:string-comparison WARN 'template/script.sh.erb:50' 'SC2071: > is for string comparisons')]" > "$TMP/f5.json"
check "exit 1" 1 "$(run "$TMP/f5.json" "$TMP/p")"
check "line" 1 "$(grep -cxF 'MISMATCH root template/script.sh.erb:insecure-default: WARN under OODT-08, but its only evidence is shellcheck SC2071, which security-tools.md does not file under a security rule; file it under the QUA rule its defect belongs to' "$TMP/out")"
check "only that line" "tools: 1 problems" "$(tail -1 "$TMP/out")"

echo "Test 6: a record with evidence of its own beyond the tool's lines is the review's finding, corroborated"
echo "[$(finding root OODT-01 template/script.sh.erb:unsanitized-user-input FAIL 'submit.yml.erb:4; template/script.sh.erb:50' 'form value reaches the shell; shellcheck SC2071 also flags the line'),$(finding root OODT-08 template/script.sh.erb:insecure-default WARN 'template/script.sh.erb:12,31' 'SC2164 at 12, and the same cd at 31')]" > "$TMP/f6.json"
check "exit 0" 0 "$(run "$TMP/f6.json" "$TMP/p")"

echo "Test 7: an unlisted bandit code is the review's call; PASS and INFO records are not judged"
echo "[$(finding root OODT-01 template/proxy.py:command-injection FAIL 'template/proxy.py:60' 'B603: subprocess without shell'),$(finding root OODT-08 template/script.sh.erb:insecure-default PASS 'template/script.sh.erb:12' 'SC2164: cd is guarded'),$(finding root OODT-08 template/script.sh.erb:insecure-default INFO 'template/script.sh.erb:12' 'SC2164')]" > "$TMP/f7.json"
check "exit 0" 0 "$(run "$TMP/f7.json" "$TMP/p")"

echo "Test 8: a code is named as a whole token, and a record citing no candidate is not a tool record"
echo "[$(finding root OODT-08 template/script.sh.erb:insecure-default WARN 'template/script.sh.erb:12' 'see SC21640'),$(finding root OODT-08 template/x.sh:insecure-default WARN 'template/x.sh:3' 'SC2164: cd without || exit')]" > "$TMP/f8.json"
check "exit 0" 0 "$(run "$TMP/f8.json" "$TMP/p")"

echo "Test 9: a monorepo app's candidates are app-relative; the record may cite the repo path"
security "$TMP/p" rnaseq
echo "[$(finding rnaseq OODT-08 apps/rnaseq/template/script.sh.erb:insecure-default WARN 'apps/rnaseq/template/script.sh.erb:30' 'SC2164: cd without || exit')]" > "$TMP/f9.json"
check "exit 1" 1 "$(run "$TMP/f9.json" "$TMP/p")"
check "line" 1 "$(grep -c '^MISMATCH rnaseq apps/rnaseq/template/script.sh.erb:insecure-default: WARN under OODT-08, but its only evidence is shellcheck SC2164' "$TMP/out")"

echo "Test 10: an app without security.json is not judged; unreadable findings or table exit 2"
echo "[$(finding other OODT-08 template/script.sh.erb:insecure-default WARN 'template/script.sh.erb:12' 'SC2164')]" > "$TMP/f10.json"
check "no security.json: exit 0" 0 "$(run "$TMP/f10.json" "$TMP/p")"
echo '{' > "$TMP/bad.json"
check "bad findings: exit 2" 2 "$(run "$TMP/bad.json" "$TMP/p")"
printf '# no table here\n' > "$TMP/empty.md"
check "no code table: exit 2" 2 "$(run "$TMP/f1.json" "$TMP/p" --tools-doc "$TMP/empty.md")"
check "usage: exit 2" 2 "$(run "$TMP/f1.json")"

echo "Test 11: the table is read from security-tools.md itself"
check "SC2164, SC2054, B104 as the doc gives them" "QUA-03 no-error-check|QUA-06 other:array-element-comma|OODT-05 bind-all-interfaces" \
  "$(python3 -c "import importlib.util as u, sys; s=u.spec_from_file_location('ct', sys.argv[1]); m=u.module_from_spec(s); s.loader.exec_module(m); t=m.load_table(); print('|'.join(' '.join(t[c]) for c in ('SC2164','SC2054','B104')))" "$CHK")"

check "every row of the doc's table is read (a cell may hold an escaped pipe)" "$(sed -n '/^### Tool finding codes: rule and tag/,/^#/p' "$SCRIPT_DIR/references/security-tools.md" | grep -cE '^\|? *[A-Z]+[0-9]+ *\|')" \
  "$(python3 -c "import importlib.util as u, sys; s=u.spec_from_file_location('ct', sys.argv[1]); m=u.module_from_spec(s); s.loader.exec_module(m); print(len(m.load_table()))" "$CHK")"

echo "Test 12: a manual finding that mentions a code in passing on a tool line is not a tool record (only the row's leading CODE: counts)"
echo "[$(finding root OODT-01 template/after.sh:unsanitized-user-input FAIL 'template/after.sh:35' 'port interpolated unescaped into the shell; shellcheck SC2086 also flags the line'),$(finding root OODT-01 template/script.sh.erb:unsanitized-user-input FAIL 'template/script.sh.erb:50' 'value reaches the test unescaped (SC2071 too)')]" > "$TMP/f12.json"
check "exit 0" 0 "$(run "$TMP/f12.json" "$TMP/p")"
echo "[$(finding root OODT-08 template/script.sh.erb:insecure-default WARN 'template/script.sh.erb:30' 'SC2155, SC2164: cd without || exit')]" > "$TMP/f12b.json"
check "a leading code list still counts" 1 "$(run "$TMP/f12b.json" "$TMP/p")"

echo "Test 13: SC2046 is filed like SC2086 (the schrodinger SC2046 case)"
python3 - "$TMP/p/root/security.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
d["candidates"].append({"kind": "tool_finding", "check": "sec-tool-finding", "rule": None, "tag": None, "tool": "shellcheck", "code": "SC2046", "file": "template/script.sh.erb", "lines": [18], "artifact": False})
json.dump(d, open(sys.argv[1], "w"))
PY
echo "[$(finding root OODT-08 template/script.sh.erb:insecure-default WARN 'template/script.sh.erb:18' 'SC2046: quote to prevent word splitting')]" > "$TMP/f13.json"
check "exit 1" 1 "$(run "$TMP/f13.json" "$TMP/p")"
check "line" 1 "$(grep -cxF 'MISMATCH root template/script.sh.erb:insecure-default: WARN under OODT-08, but its only evidence is shellcheck SC2046, which security-tools.md files under OODT-01 unquoted-variable; re-key it as OODT-01 template/script.sh.erb:unquoted-variable' "$TMP/out")"

echo "Test 14: a single-app repo matches paths exactly; rule case and spacing do not matter"
echo "[$(finding root OODT-08 vendor/template/script.sh.erb:insecure-default WARN 'vendor/template/script.sh.erb:12' 'SC2164: cd without || exit'),$(finding root ' qua-03 ' template/script.sh.erb:no-error-check WARN 'template/script.sh.erb:12' 'SC2164: cd without || exit')]" > "$TMP/f14.json"
check "exit 0" 0 "$(run "$TMP/f14.json" "$TMP/p")"
echo "[$(finding root 'oodt-08' template/script.sh.erb:insecure-default WARN 'template/script.sh.erb:50' 'SC2071: string comparison')]" > "$TMP/f14b.json"
check "a lower-case OODT rule is still an OODT rule" 1 "$(run "$TMP/f14b.json" "$TMP/p")"

echo "Test 15: malformed records and candidates are skipped, never a traceback"
echo '[{"app_id":"root","rule":"OODT-08","defect_key":"template/script.sh.erb:x","result":"WARN","evidence":"template/script.sh.erb:12","summary":["SC2164: cd"]},{"app_id":["root"],"rule":"OODT-08","defect_key":"a:b","result":"WARN","evidence":"a:1","summary":"SC2164: cd"},{"app_id":"root","rule":"OODT-08","defect_key":"a:b","result":"WARN","evidence":["template/script.sh.erb:12"],"summary":"SC2164: cd"}]' > "$TMP/f15.json"
check "bad records: exit 0" 0 "$(run "$TMP/f15.json" "$TMP/p")"
check "no traceback" 0 "$(grep -c Traceback "$TMP/out")"
mkdir -p "$TMP/q/root"; printf '{"candidates": [{"kind": "tool_finding", "tool": "shellcheck", "code": 2164, "file": "template/script.sh.erb", "lines": [12]}, {"kind": "tool_finding", "tool": "shellcheck", "code": "SC2164", "file": "template/script.sh.erb", "lines": 12}, {"kind": "tool_finding", "tool": "shellcheck", "code": "SC2164", "file": null, "lines": [12]}]}' > "$TMP/q/root/security.json"
check "bad candidates: exit 0" 0 "$(run "$TMP/f1.json" "$TMP/q")"
check "no traceback either" 0 "$(grep -c Traceback "$TMP/out")"

echo "Test 16: the table tolerates a row without its leading pipe and refuses a code row it cannot read"
sed -n '/^### Tool finding codes: rule and tag/,$p' "$SCRIPT_DIR/references/security-tools.md" | sed 's/^| SC2164 |/SC2164 |/' > "$TMP/nopipe.md"
check "a row without its leading pipe is read" 1 "$(run "$TMP/f1.json" "$TMP/p" --tools-doc "$TMP/nopipe.md")"
check "and filed as the table says" 1 "$(grep -c 'files under QUA-03 no-error-check' "$TMP/out")"
sed -n '/^### Tool finding codes: rule and tag/,$p' "$SCRIPT_DIR/references/security-tools.md" | sed 's/^| SC2164 | \(.*\) | QUA-03 |/| SC2164 | \1 | QUA03 |/' > "$TMP/badrow.md"
check "a code row with no readable rule: exit 2" 2 "$(run "$TMP/f1.json" "$TMP/p" --tools-doc "$TMP/badrow.md")"

echo; echo "check-tools: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
