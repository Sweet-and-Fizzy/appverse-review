#!/usr/bin/env bash
# Test compare-runs.py: pairwise Jaccard of fix-item keys, and per-candidate
# verdicts (F/W/P/-, recorded and answered) across N run directories.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$SCRIPT_DIR/references/compare-runs.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { python3 "$CHECK" "$@" > "$TMP/out" 2>&1; echo $?; }
finding() { # rule defect_key result severity evidence
  printf '{"app_id":"root","rule":"%s","defect_key":"%s","aspect":"x","severity":"%s","result":"%s","summary":"s","evidence":"%s"}' \
    "$1" "$2" "$4" "$3" "$5"
}

# Three synthetic run dirs, each with pre-review/ fact files and a findings file.
mkrun() {
  local dir="$1"; shift
  mkdir -p "$dir/pre-review/root"
  cat > "$dir/pre-review/apps.json" <<'EOF'
[{"app_id": "root", "path": ".", "app_type": "batch_connect", "readme": "README.md"}]
EOF
  cat > "$dir/pre-review/root/security.json" <<'EOF'
{"candidates": [
  {"kind": "eval_exec", "file": "template/script.sh.erb", "line": 10, "text": "eval $x", "rule": "OODT-01", "note": ""},
  {"kind": "network_call", "file": "template/before.sh.erb", "line": 4, "text": "curl http://x", "rule": "OODT-04", "note": ""}
]}
EOF
  cat > "$dir/pre-review/root/template.json" <<'EOF'
{"dir": "template", "files": [], "icons": [], "absolute_paths": [
  {"file": "template/script.sh.erb", "line": 22, "text": "/scratch/foo"}
], "numeric_literals": [], "commented_code": [], "skipped_files": []}
EOF
  cat > "$dir/pre-review/root/form.json" <<'EOF'
{"file": "form.yml", "submit_file": "submit.yml.erb", "error": null, "attributes": []}
EOF
  printf '%s' "$1" > "$dir/review-app.findings.json"
}

# Run A: records eval_exec (exact line), records absolute_paths candidate via
# a range citation (20-25 covers 22). Misses the network_call candidate.
mkrun "$TMP/a" "$(printf '[%s,%s]' \
  "$(finding OODT-01 template/script.sh.erb:eval-exec FAIL high template/script.sh.erb:10)" \
  "$(finding QUA-02 template/script.sh.erb:hardcoded-path WARN medium template/script.sh.erb:20-25)")"

# Run B: records eval_exec, records network_call as a PASS citing the site,
# does NOT record the absolute_paths candidate.
mkrun "$TMP/b" "$(printf '[%s,%s]' \
  "$(finding OODT-01 template/script.sh.erb:eval-exec FAIL high template/script.sh.erb:10)" \
  "$(finding OODT-04 template/before.sh.erb:network-call PASS info 'template/before.sh.erb:4 (intentional, documented)')")"

# Run C: records only the absolute_paths candidate (exact line); misses both
# security candidates entirely.
mkrun "$TMP/c" "$(printf '[%s]' \
  "$(finding QUA-02 template/script.sh.erb:hardcoded-path FAIL medium template/script.sh.erb:22)")"

echo "Test 1: three runs, markdown output, exit 0"
out=$(run "$TMP/a" "$TMP/b" "$TMP/c")
check "exit 0" 0 "$out"

echo "Test 2: pairwise Jaccard section present with three pairs"
check "three jaccard data rows" 3 "$(grep -c '| [0-9.]* |$' "$TMP/out")"
check "jaccard header present" 1 "$(grep -c '## Pairwise Jaccard' "$TMP/out")"

echo "Test 3: per-candidate verdict table present, 3 candidates listed"
check "eval_exec candidate row" 1 "$(grep -c 'template/script.sh.erb:10' "$TMP/out")"
check "network_call candidate row" 1 "$(grep -c 'template/before.sh.erb:4' "$TMP/out")"
check "absolute_paths candidate row" 1 "$(grep -c 'template/script.sh.erb:22' "$TMP/out")"

echo "Test 4: eval_exec candidate recorded by 2 of 3 runs (a, b; not c)"
check "verdicts, recorded 2/3, answered 2/3" "| template/script.sh.erb:10 | sec-eval-exec | OODT-01 | F high | F high | - | 2/3 | 2/3 |" "$(grep -F '| template/script.sh.erb:10 |' "$TMP/out")"

echo "Test 5: a PASS citing the candidate is answered, not recorded (network_call, run b)"
check "network_call P in run b, recorded 0/3, answered 1/3" "| template/before.sh.erb:4 | sec-network-call | OODT-04 | - | P | - | 0/3 | 1/3 |" "$(grep -F '| template/before.sh.erb:4 |' "$TMP/out")"

echo "Test 6: a range citation (20-25) counts for the line-22 candidate (run a, run c both record it)"
check "absolute_paths W medium / - / F medium, 2/3" "| template/script.sh.erb:22 | hardcoded-site-paths | QUA-02 | W medium | - | F medium | 2/3 | 2/3 |" "$(grep -F '| template/script.sh.erb:22 |' "$TMP/out")"

echo "Test 7: --json shape"
out_json=$(run "$TMP/a" "$TMP/b" "$TMP/c" --json)
check "json exit 0" 0 "$out_json"
check "valid json" 0 "$(python3 -c "import json,sys; json.load(open('$TMP/out'))" > /dev/null 2>&1; echo $?)"
check "json has jaccard key" 1 "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
print(1 if 'jaccard' in d else 0)
")"
check "json has candidates key" 1 "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
print(1 if 'candidates' in d else 0)
")"
check "json candidates count is 3" 3 "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
print(len(d['candidates']))
")"
check "json eval_exec recorded_by count 2" 2 "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
for c in d['candidates']:
    if c['file'] == 'template/script.sh.erb' and c['line'] == 10:
        print(c['recorded_by'])
        break
")"

echo "Test 8: runs without any fact files -> Jaccard-only output with the stated message"
mkdir -p "$TMP/nf1" "$TMP/nf2"
printf '%s' "$(printf '[%s]' "$(finding OODT-01 template/script.sh.erb:eval-exec FAIL high template/script.sh.erb:10)")" > "$TMP/nf1/review-app.findings.json"
printf '%s' "$(printf '[%s]' "$(finding OODT-01 template/script.sh.erb:eval-exec FAIL high template/script.sh.erb:10)")" > "$TMP/nf2/review-app.findings.json"
out_nf=$(run "$TMP/nf1" "$TMP/nf2")
check "exit 0 (no fact files)" 0 "$out_nf"
check "jaccard header still present" 1 "$(grep -c '## Pairwise Jaccard' "$TMP/out")"
check "unavailable message present" 1 "$(grep -c 'per-candidate.*unavailable' "$TMP/out")"
check "no per-candidate table" 0 "$(grep -c 'recorded_by\|2/3\|1/2' "$TMP/out")"

echo "Test 9: findings nested under a subdirectory (real runs bury findings/pre-review several levels deep)"
mkdir -p "$TMP/nested/sub/deeper/pre-review/root"
cp "$TMP/a/pre-review/apps.json" "$TMP/nested/sub/deeper/pre-review/apps.json"
cp "$TMP/a/pre-review/root/security.json" "$TMP/nested/sub/deeper/pre-review/root/security.json"
cp "$TMP/a/pre-review/root/template.json" "$TMP/nested/sub/deeper/pre-review/root/template.json"
cp "$TMP/a/pre-review/root/form.json" "$TMP/nested/sub/deeper/pre-review/root/form.json"
cp "$TMP/a/review-app.findings.json" "$TMP/nested/sub/deeper/review-app.findings.json"
check "nested run dir still exit 0" 0 "$(run "$TMP/nested" "$TMP/b")"

echo "Test 10: two run dirs (not three) still work, Jaccard is a single pair"
out2=$(run "$TMP/a" "$TMP/b")
check "exit 0 two runs" 0 "$out2"

echo "Test 11: unreadable/missing run dir is exit 2"
check "exit 2 missing dir" 2 "$(run "$TMP/does-not-exist" "$TMP/b")"

echo "Test 12: fewer than two run dirs is exit 2 (usage error)"
check "exit 2 one dir" 2 "$(run "$TMP/a")"

echo "Test 13: the anchor+rule fallback is gone -- a FAIL anchored at the file with a"
echo "matching rule but NOT citing a candidate's line does not record that candidate"
mkdir -p "$TMP/d1/pre-review/root" "$TMP/d2/pre-review/root"
cat > "$TMP/d1/pre-review/apps.json" <<'EOF'
[{"app_id": "root", "path": ".", "app_type": "batch_connect", "readme": "README.md"}]
EOF
cp "$TMP/d1/pre-review/apps.json" "$TMP/d2/pre-review/apps.json"
# Two candidates in the same file at different lines.
cat > "$TMP/d1/pre-review/root/security.json" <<'EOF'
{"candidates": [
  {"kind": "eval_exec", "file": "submit.yml.erb", "line": 5, "text": "eval $x", "rule": "OODT-01", "note": ""},
  {"kind": "eval_exec", "file": "submit.yml.erb", "line": 40, "text": "eval $y", "rule": "OODT-01", "note": ""}
]}
EOF
cp "$TMP/d1/pre-review/root/security.json" "$TMP/d2/pre-review/root/security.json"
touch "$TMP/d1/pre-review/root/template.json" "$TMP/d2/pre-review/root/template.json"
echo '{}' > "$TMP/d1/pre-review/root/template.json"; echo '{}' > "$TMP/d2/pre-review/root/template.json"
echo '{"attributes": []}' > "$TMP/d1/pre-review/root/form.json"; echo '{"attributes": []}' > "$TMP/d2/pre-review/root/form.json"
# A finding anchored submit.yml.erb, rule OODT-01, evidence citing ONLY line 5
# (the first candidate). Under the old anchor+rule fallback this would have
# also recorded the line-40 candidate; it must not.
printf '%s' "$(printf '[%s]' \
  "$(finding OODT-01 submit.yml.erb:eval-exec FAIL high submit.yml.erb:5)")" > "$TMP/d1/review-app.findings.json"
printf '%s' "[]" > "$TMP/d2/review-app.findings.json"
out13=$(python3 "$CHECK" "$TMP/d1" "$TMP/d2" --json > "$TMP/out" 2>&1; echo $?)
check "exit 0" 0 "$out13"
check "first candidate (line 5) recorded 1/2" "1" "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
for c in d['candidates']:
    if c['line'] == 5:
        print(c['recorded_by'])
")"
check "second candidate (line 40) recorded 0/2" "0" "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
for c in d['candidates']:
    if c['line'] == 40:
        print(c['recorded_by'])
")"

echo "Test 14: form.json candidates are app-relative; a monorepo finding citing the"
echo "repo-relative path (app path prefix + form.yml) matches"
mkdir -p "$TMP/mono1/pre-review/apps/app-a" "$TMP/mono1/pre-review/apps/app-b"
cat > "$TMP/mono1/pre-review/apps.json" <<'EOF'
[
  {"app_id": "apps/app-a", "path": "apps/app-a", "app_type": "batch_connect", "readme": "README.md"},
  {"app_id": "apps/app-b", "path": "apps/app-b", "app_type": "batch_connect", "readme": "README.md"}
]
EOF
cat > "$TMP/mono1/pre-review/apps/app-a/form.json" <<'EOF'
{"file": "form.yml", "submit_file": "submit.yml.erb", "error": null, "attributes": [
  {"name": "num_cores", "widget": "number_field", "min": null, "max": null, "pattern": null,
   "required": false, "line": 12, "defined": true, "in_form": true,
   "interpolated_in_submit": false, "submit_lines": [], "reaches_scheduler": true}
]}
EOF
echo '{"file": "form.yml", "submit_file": "submit.yml.erb", "error": null, "attributes": []}' > "$TMP/mono1/pre-review/apps/app-b/form.json"
echo '{}' > "$TMP/mono1/pre-review/apps/app-a/template.json"
echo '{}' > "$TMP/mono1/pre-review/apps/app-b/template.json"
echo '{"candidates": []}' > "$TMP/mono1/pre-review/apps/app-a/security.json"
echo '{"candidates": []}' > "$TMP/mono1/pre-review/apps/app-b/security.json"
mkdir -p "$TMP/mono2/pre-review/apps/app-a" "$TMP/mono2/pre-review/apps/app-b"
cp "$TMP/mono1/pre-review/apps.json" "$TMP/mono2/pre-review/apps.json"
cp "$TMP/mono1/pre-review/apps/app-a/form.json" "$TMP/mono2/pre-review/apps/app-a/form.json"
cp "$TMP/mono1/pre-review/apps/app-b/form.json" "$TMP/mono2/pre-review/apps/app-b/form.json"
cp "$TMP/mono1/pre-review/apps/app-a/template.json" "$TMP/mono2/pre-review/apps/app-a/template.json"
cp "$TMP/mono1/pre-review/apps/app-b/template.json" "$TMP/mono2/pre-review/apps/app-b/template.json"
cp "$TMP/mono1/pre-review/apps/app-a/security.json" "$TMP/mono2/pre-review/apps/app-a/security.json"
cp "$TMP/mono1/pre-review/apps/app-b/security.json" "$TMP/mono2/pre-review/apps/app-b/security.json"
# The finding cites the repo-relative path "apps/app-a/form.yml:12", as
# check-rows.py's citation grammar expects.
printf '%s' "$(printf '[%s]' \
  "$(finding QUA-07 apps/app-a/form.yml:missing-min-max FAIL medium apps/app-a/form.yml:12)")" > "$TMP/mono1/review-app.findings.json"
printf '%s' "[]" > "$TMP/mono2/review-app.findings.json"
out14=$(python3 "$CHECK" "$TMP/mono1" "$TMP/mono2" --json > "$TMP/out" 2>&1; echo $?)
check "exit 0" 0 "$out14"
check "candidate file is prefixed with the app path" "apps/app-a/form.yml" "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
for c in d['candidates']:
    if c['line'] == 12:
        print(c['file'])
")"
check "prefixed candidate recorded 1/2" "1" "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
for c in d['candidates']:
    if c['line'] == 12:
        print(c['recorded_by'])
")"

echo "Test 15: a config_flag candidate uses its own rule field (OODT-05), not a fixed table entry"
mkdir -p "$TMP/e1/pre-review/root" "$TMP/e2/pre-review/root"
cat > "$TMP/e1/pre-review/apps.json" <<'EOF'
[{"app_id": "root", "path": ".", "app_type": "batch_connect", "readme": "README.md"}]
EOF
cp "$TMP/e1/pre-review/apps.json" "$TMP/e2/pre-review/apps.json"
cat > "$TMP/e1/pre-review/root/security.json" <<'EOF'
{"candidates": [
  {"kind": "config_flag", "file": "template/script.sh.erb", "line": 8, "text": "0.0.0.0", "rule": "OODT-05", "note": ""}
]}
EOF
cp "$TMP/e1/pre-review/root/security.json" "$TMP/e2/pre-review/root/security.json"
echo '{}' > "$TMP/e1/pre-review/root/template.json"; echo '{}' > "$TMP/e2/pre-review/root/template.json"
echo '{"attributes": []}' > "$TMP/e1/pre-review/root/form.json"; echo '{"attributes": []}' > "$TMP/e2/pre-review/root/form.json"
printf '%s' "$(printf '[%s]' \
  "$(finding OODT-05 template/script.sh.erb:bind-all-interfaces FAIL high template/script.sh.erb:8)")" > "$TMP/e1/review-app.findings.json"
printf '%s' "[]" > "$TMP/e2/review-app.findings.json"
out15=$(python3 "$CHECK" "$TMP/e1" "$TMP/e2" --json > "$TMP/out" 2>&1; echo $?)
check "exit 0" 0 "$out15"
check "candidate carries its own rule OODT-05" "OODT-05" "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
for c in d['candidates']:
    if c['line'] == 8:
        print(c['rule'])
")"
check "recorded 1/2 by the OODT-05 finding citing its line" "1" "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
for c in d['candidates']:
    if c['line'] == 8:
        print(c['recorded_by'])
")"

echo "Test 16: security.json/template.json paths are already repo-relative in a monorepo"
echo "(baked in at scan time) and must NOT be prefixed again with the app path"
mkdir -p "$TMP/mono3/pre-review/apps/app-a"
cat > "$TMP/mono3/pre-review/apps.json" <<'EOF'
[{"app_id": "apps/app-a", "path": "apps/app-a", "app_type": "batch_connect", "readme": "README.md"}]
EOF
cat > "$TMP/mono3/pre-review/apps/app-a/security.json" <<'EOF'
{"candidates": [
  {"kind": "eval_exec", "file": "apps/app-a/template/script.sh.erb", "line": 9, "text": "eval $x", "rule": "OODT-01", "note": ""}
]}
EOF
echo '{}' > "$TMP/mono3/pre-review/apps/app-a/template.json"
echo '{"attributes": []}' > "$TMP/mono3/pre-review/apps/app-a/form.json"
mkdir -p "$TMP/mono4/pre-review/apps/app-a"
cp "$TMP/mono3/pre-review/apps.json" "$TMP/mono4/pre-review/apps.json"
cp "$TMP/mono3/pre-review/apps/app-a/security.json" "$TMP/mono4/pre-review/apps/app-a/security.json"
cp "$TMP/mono3/pre-review/apps/app-a/template.json" "$TMP/mono4/pre-review/apps/app-a/template.json"
cp "$TMP/mono3/pre-review/apps/app-a/form.json" "$TMP/mono4/pre-review/apps/app-a/form.json"
printf '%s' "$(printf '[%s]' \
  "$(finding OODT-01 apps/app-a/template/script.sh.erb:eval-exec FAIL high apps/app-a/template/script.sh.erb:9)")" > "$TMP/mono3/review-app.findings.json"
printf '%s' "[]" > "$TMP/mono4/review-app.findings.json"
out16=$(python3 "$CHECK" "$TMP/mono3" "$TMP/mono4" --json > "$TMP/out" 2>&1; echo $?)
check "exit 0" 0 "$out16"
check "candidate file is NOT double-prefixed" "apps/app-a/template/script.sh.erb" "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
for c in d['candidates']:
    if c['line'] == 9:
        print(c['file'])
")"
check "recorded 1/2 (the finding cites the already-repo-relative path)" "1" "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
for c in d['candidates']:
    if c['line'] == 9:
        print(c['recorded_by'])
")"

echo "Test 17: compare-runs uses the shared parser: every group, a backticked path and a ./ path"
check "groups from the semicolon-joined evidence" "[('template/script.sh.erb', [22]), ('template/script.sh.erb', [9, 23])]" "$(python3 -c "
import sys
sys.path.insert(0, '$SCRIPT_DIR/references')
from repo_paths import parse_citations
print(parse_citations('template/script.sh.erb:22; reviewed OK: template/script.sh.erb:9,23'))
")"
mkdir -p "$TMP/bt"; cp -R "$TMP/a/pre-review" "$TMP/bt/"
printf '%s' "$(printf '[%s,%s]' \
  "$(finding OODT-01 template/script.sh.erb:eval-exec FAIL high '`template/script.sh.erb:10`')" \
  "$(finding OODT-04 template/before.sh.erb:network-call WARN low './template/before.sh.erb:4')")" > "$TMP/bt/review-app.findings.json"
run "$TMP/bt" "$TMP/c" --json > /dev/null
check "backticked path recorded" "F high" "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
for c in d['candidates']:
    if c['line'] == 10: print(c['verdicts']['bt']['result'], c['verdicts']['bt']['severity'])
")"
check "./ path recorded" "W low" "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
for c in d['candidates']:
    if c['line'] == 4: print(c['verdicts']['bt']['result'], c['verdicts']['bt']['severity'])
")"

echo "Test 18: end-to-end -- the lines after '; reviewed OK:' are PASS (answered, not"
echo "recorded); the leading citation takes the record's WARN"
mkdir -p "$TMP/sc1/pre-review/root" "$TMP/sc2/pre-review/root"
cat > "$TMP/sc1/pre-review/apps.json" <<'EOF'
[{"app_id": "root", "path": ".", "app_type": "batch_connect", "readme": "README.md"}]
EOF
cp "$TMP/sc1/pre-review/apps.json" "$TMP/sc2/pre-review/apps.json"
cat > "$TMP/sc1/pre-review/root/template.json" <<'EOF'
{"dir": "template", "files": [], "icons": [], "absolute_paths": [], "numeric_literals": [
  {"file": "template/script.sh.erb", "line": 9, "value": "9000"},
  {"file": "template/script.sh.erb", "line": 22, "value": "22000"},
  {"file": "template/script.sh.erb", "line": 23, "value": "23000"}
], "commented_code": [], "skipped_files": []}
EOF
cp "$TMP/sc1/pre-review/root/template.json" "$TMP/sc2/pre-review/root/template.json"
echo '{"candidates": []}' > "$TMP/sc1/pre-review/root/security.json"
echo '{"candidates": []}' > "$TMP/sc2/pre-review/root/security.json"
echo '{"attributes": []}' > "$TMP/sc1/pre-review/root/form.json"
echo '{"attributes": []}' > "$TMP/sc2/pre-review/root/form.json"
printf '%s' "$(printf '[%s]' \
  "$(finding QUA-08 'template/script.sh.erb:magic-number' WARN medium 'template/script.sh.erb:22; reviewed OK: template/script.sh.erb:9,23')")" > "$TMP/sc1/review-app.findings.json"
printf '%s' "[]" > "$TMP/sc2/review-app.findings.json"
out18=$(python3 "$CHECK" "$TMP/sc1" "$TMP/sc2" --json > "$TMP/out" 2>&1; echo $?)
check "exit 0" 0 "$out18"
check "line 22 recorded 1/2" "1" "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
for c in d['candidates']:
    if c['line'] == 22: print(c['recorded_by'])
")"
check "line 9 PASS, recorded 0, answered 1" "P 0 1" "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
for c in d['candidates']:
    if c['line'] == 9: print(c['verdicts']['sc1']['result'], c['recorded_by'], c['answered_by'])
")"
check "line 23 PASS (comma list in the reviewed-OK group)" "P 0 1" "$(python3 -c "
import json
d = json.load(open('$TMP/out'))
for c in d['candidates']:
    if c['line'] == 23: print(c['verdicts']['sc1']['result'], c['recorded_by'], c['answered_by'])
")"

echo "Test 19: two runs, run A FAILs a candidate and run B PASSes it: F/P, recorded 1/2, answered 2/2"
mkdir -p "$TMP/fa" "$TMP/fb"; cp -R "$TMP/a/pre-review" "$TMP/fa/"; cp -R "$TMP/a/pre-review" "$TMP/fb/"
printf '%s' "$(printf '[%s]' "$(finding OODT-01 template/script.sh.erb:eval-exec FAIL high template/script.sh.erb:10)")" > "$TMP/fa/review-app.findings.json"
printf '%s' "$(printf '[%s]' "$(finding OODT-01 template/script.sh.erb:eval-exec PASS info template/script.sh.erb:10)")" > "$TMP/fb/review-app.findings.json"
check "exit 0" 0 "$(run "$TMP/fa" "$TMP/fb")"
check "row" "| template/script.sh.erb:10 | sec-eval-exec | OODT-01 | F high | P | 1/2 | 2/2 |" "$(grep -F '| template/script.sh.erb:10 |' "$TMP/out")"

echo "Test 20: the report's rows are read per check: a QUA-10 row citing the line does not"
echo "answer the OODT-01 candidate there; a NOT CHECKED row answers nothing; reviewed OK is PASS"
mkdir -p "$TMP/ra/pre-review/root" "$TMP/rb"
echo '[{"app_id": "root", "path": ".", "app_type": "batch_connect", "readme": "README.md"}]' > "$TMP/ra/pre-review/apps.json"
cat > "$TMP/ra/pre-review/root/security.json" <<'EOF'
{"candidates": [
  {"kind": "interpolation", "file": "submit.yml.erb", "line": 17, "text": "<%= x %>", "rule": "OODT-01", "note": ""},
  {"kind": "interpolation", "file": "submit.yml.erb", "line": 18, "text": "<%= y %>", "rule": "OODT-01", "note": ""},
  {"kind": "interpolation", "file": "submit.yml.erb", "line": 19, "text": "<%= z %>", "rule": "OODT-01", "note": ""}
]}
EOF
cp -R "$TMP/ra/pre-review" "$TMP/rb/"
echo '[]' > "$TMP/ra/review-app.findings.json"; echo '[]' > "$TMP/rb/review-app.findings.json"
cat > "$TMP/ra/review-app.md" <<'EOF'
## App: X (root)

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| QUA-10 | `check: erb-missing-value` | FAIL | medium | — | no default | submit.yml.erb:17 |
| OODT-01 | `check: sec-interpolation` | NOT CHECKED | — | — | too dynamic | submit.yml.erb:17 |
| OODT-01 | `check: sec-interpolation` | WARN | **low** | unintentional | free text | `submit.yml.erb:18`; reviewed OK: submit.yml.erb:19 |
EOF
cat > "$TMP/rb/review-app.md" <<'EOF'
## App: X (root)

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | FAIL | high | unintentional | `echo x | sh` | submit.yml.erb:17 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | quoted | submit.yml.erb:18-19 |
EOF
check "exit 0" 0 "$(run "$TMP/ra" "$TMP/rb")"
check "line 17: ra has only a QUA-10 row and a NOT CHECKED row" "| submit.yml.erb:17 | sec-interpolation | OODT-01 | - | F high | 1/2 | 1/2 |" "$(grep -F '| submit.yml.erb:17 |' "$TMP/out")"
check "line 18: W low / P" "| submit.yml.erb:18 | sec-interpolation | OODT-01 | W low | P | 1/2 | 2/2 |" "$(grep -F '| submit.yml.erb:18 |' "$TMP/out")"
check "line 19: reviewed OK is P" "| submit.yml.erb:19 | sec-interpolation | OODT-01 | P | P | 0/2 | 2/2 |" "$(grep -F '| submit.yml.erb:19 |' "$TMP/out")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
