#!/usr/bin/env bash
# Test compare-runs.py: pairwise Jaccard of fix-item keys, and per-candidate
# recall across N run directories.
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

echo "Test 3: per-candidate recall table present, 3 candidates listed"
check "eval_exec candidate row" 1 "$(grep -c 'template/script.sh.erb:10' "$TMP/out")"
check "network_call candidate row" 1 "$(grep -c 'template/before.sh.erb:4' "$TMP/out")"
check "absolute_paths candidate row" 1 "$(grep -c 'template/script.sh.erb:22' "$TMP/out")"

echo "Test 4: eval_exec candidate recorded by 2 of 3 runs (a, b; not c)"
check "2/3 recorded" 1 "$(grep 'template/script.sh.erb:10' "$TMP/out" | grep -c '2/3')"

echo "Test 5: a PASS citing the candidate counts as recorded (network_call, run b)"
check "network_call 1/3 recorded" 1 "$(grep 'template/before.sh.erb:4' "$TMP/out" | grep -c '1/3')"

echo "Test 6: a range citation (20-25) counts for the line-22 candidate (run a, run c both record it)"
check "absolute_paths 2/3 recorded" 1 "$(grep 'template/script.sh.erb:22' "$TMP/out" | grep -c '2/3')"

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

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
