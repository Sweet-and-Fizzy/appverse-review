#!/usr/bin/env bash
# Test assemble-artifact.py: routing, criteria derivation, and edge cases.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSEMBLE="$SCRIPT_DIR/references/assemble-artifact.py"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS  $name"
    pass=$((pass + 1))
  else
    echo "  FAIL  $name: expected '$expected', got '$actual'"
    fail=$((fail + 1))
  fi
}

# --- Test 1: routing and criteria ---
cat > "$TMP/meta.json" << 'EOF'
{
  "repo_url": "https://github.com/test/app",
  "sha": "abc123", "ref": "main",
  "repo_shape": "inferred_single",
  "not_archived": "pass",
  "model": "claude-sonnet-4-6",
  "recommendation": {"decision": "Request changes", "note": "Fails criteria."},
  "apps": [{"app_id": "root", "name": "Test App", "decision": "Request changes"}]
}
EOF

cat > "$TMP/findings.json" << 'EOF'
[
  {"app_id":"root","rule":"STR-01","defect_key":"LICENSE:missing-license","result":"FAIL","severity":"high","summary":"Missing LICENSE","evidence":"(no file)"},
  {"app_id":"root","rule":"STR-03","defect_key":"form.yml:yaml-parse-error","result":"FAIL","severity":"high","summary":"Broken YAML","evidence":"form.yml:3"},
  {"app_id":"root","rule":"OODT-02","defect_key":"script.sh.erb:hardcoded-credential","severity":"high","summary":"Hardcoded token","evidence":"script.sh.erb:2"},
  {"app_id":"root","rule":"MNT-03","defect_key":"CHANGELOG:no-changelog","severity":"info","summary":"No CHANGELOG","evidence":"(no file)"}
]
EOF

ARTIFACT=$(python3 "$ASSEMBLE" --meta "$TMP/meta.json" --findings "$TMP/findings.json" --md "r.md" --plugin-version "0.3.0")

echo "Test 1: routing and criteria"
# MNT-03 should be in repo_level, not apps
REPO_FINDING_COUNT=$(echo "$ARTIFACT" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['repo_level']['findings']))")
check "repo_level has 1 finding (MNT)" "1" "$REPO_FINDING_COUNT"

APP_FINDING_COUNT=$(echo "$ARTIFACT" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['apps'][0]['findings']))")
check "app has 3 findings (STR+OODT)" "3" "$APP_FINDING_COUNT"

# Criteria derived from rules
LICENSE=$(echo "$ARTIFACT" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo_level']['criteria']['license'])")
check "license criterion is fail" "fail" "$LICENSE"

YAML=$(echo "$ARTIFACT" | python3 -c "import json,sys; print(json.load(sys.stdin)['apps'][0]['criteria']['yaml_valid'])")
check "yaml_valid criterion is fail" "fail" "$YAML"

REFS=$(echo "$ARTIFACT" | python3 -c "import json,sys; print(json.load(sys.stdin)['apps'][0]['criteria']['references'])")
check "references criterion is pass (no STR-04)" "pass" "$REFS"

# Decision normalized
DECISION=$(echo "$ARTIFACT" | python3 -c "import json,sys; print(json.load(sys.stdin)['recommendation']['decision'])")
check "decision normalized to snake_case" "request_changes" "$DECISION"

# not_archived from meta
ARCHIVED=$(echo "$ARTIFACT" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo_level']['criteria']['not_archived'])")
check "not_archived from meta" "pass" "$ARCHIVED"

# Model in run_meta
MODEL=$(echo "$ARTIFACT" | python3 -c "import json,sys; print(json.load(sys.stdin)['run_meta']['model'])")
check "model in run_meta" "claude-sonnet-4-6" "$MODEL"

# --- Test 2: archived repo ---
echo ""
echo "Test 2: archived repo"
cat > "$TMP/meta-archived.json" << 'EOF'
{
  "repo_url": "https://github.com/test/old",
  "sha": "def456", "ref": "main",
  "repo_shape": "inferred_single",
  "not_archived": "fail",
  "recommendation": {"decision": "Reject", "note": "Archived."},
  "apps": [{"app_id": "root", "name": "Old App", "decision": "Reject"}]
}
EOF

ARTIFACT2=$(python3 "$ASSEMBLE" --meta "$TMP/meta-archived.json" --md "r.md" --plugin-version "0.3.0")
ARCHIVED2=$(echo "$ARTIFACT2" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo_level']['criteria']['not_archived'])")
check "archived repo criteria is fail" "fail" "$ARCHIVED2"

# --- Test 3: empty findings ---
echo ""
echo "Test 3: empty findings"
ARTIFACT3=$(echo '[]' | python3 "$ASSEMBLE" --meta "$TMP/meta.json" --md "r.md" --plugin-version "0.3.0")
EMPTY_REPO=$(echo "$ARTIFACT3" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['repo_level']['findings']))")
check "empty findings: repo_level has 0 findings" "0" "$EMPTY_REPO"

# schema_version bump (checked against Test 1's artifact)
SCHEMA_VERSION=$(echo "$ARTIFACT" | python3 -c "import json,sys; print(json.load(sys.stdin)['schema_version'])")
check "schema_version is 1.0.1" "1.0.1" "$SCHEMA_VERSION"

# --- Test 4: result field honored ---
echo ""
echo "Test 4: result field honored"

# Case 1: PASS records only for STR-01 (license), STR-02, STR-03, STR-04, STR-07 -> every criterion pass
cat > "$TMP/meta-result1.json" << 'EOF'
{
  "repo_url": "https://github.com/test/app",
  "sha": "abc123", "ref": "main",
  "repo_shape": "inferred_single",
  "not_archived": "pass",
  "model": "claude-sonnet-4-6",
  "recommendation": {"decision": "Accept", "note": "All gates pass."},
  "apps": [{"app_id": "root", "name": "Test App", "decision": "Accept"}]
}
EOF

cat > "$TMP/findings-result1.json" << 'EOF'
[
  {"app_id":"root","rule":"STR-01","defect_key":"LICENSE:missing-license","result":"PASS","severity":"info","summary":"LICENSE present","evidence":"LICENSE"},
  {"app_id":"root","rule":"STR-02","defect_key":"manifest.yml:missing-field:name","result":"PASS","severity":"info","summary":"metadata ok","evidence":"manifest.yml"},
  {"app_id":"root","rule":"STR-03","defect_key":"form.yml:yaml-parse-error","result":"PASS","severity":"info","summary":"yaml valid","evidence":"form.yml"},
  {"app_id":"root","rule":"STR-04","defect_key":"submit.yml.erb:form-submit-mismatch","result":"PASS","severity":"info","summary":"references ok","evidence":"submit.yml.erb"},
  {"app_id":"root","rule":"STR-07","defect_key":"form.yml:missing-form","result":"PASS","severity":"info","summary":"structure ok","evidence":"form.yml"}
]
EOF

ARTIFACT_R1=$(python3 "$ASSEMBLE" --meta "$TMP/meta-result1.json" --findings "$TMP/findings-result1.json" --md "r.md" --plugin-version "0.3.0")
check "case1: license pass" "pass" "$(echo "$ARTIFACT_R1" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo_level']['criteria']['license'])")"
check "case1: metadata pass" "pass" "$(echo "$ARTIFACT_R1" | python3 -c "import json,sys; print(json.load(sys.stdin)['apps'][0]['criteria']['metadata'])")"
check "case1: yaml_valid pass" "pass" "$(echo "$ARTIFACT_R1" | python3 -c "import json,sys; print(json.load(sys.stdin)['apps'][0]['criteria']['yaml_valid'])")"
check "case1: references pass" "pass" "$(echo "$ARTIFACT_R1" | python3 -c "import json,sys; print(json.load(sys.stdin)['apps'][0]['criteria']['references'])")"
check "case1: structure pass" "pass" "$(echo "$ARTIFACT_R1" | python3 -c "import json,sys; print(json.load(sys.stdin)['apps'][0]['criteria']['structure'])")"

# Case 2: STR-03 WARN -> yaml_valid = warn; other criteria pass
cat > "$TMP/findings-result2.json" << 'EOF'
[
  {"app_id":"root","rule":"STR-03","defect_key":"form.yml:yaml-parse-error","result":"WARN","severity":"low","summary":"yaml has a warning","evidence":"form.yml"}
]
EOF
ARTIFACT_R2=$(python3 "$ASSEMBLE" --meta "$TMP/meta-result1.json" --findings "$TMP/findings-result2.json" --md "r.md" --plugin-version "0.3.0")
check "case2: yaml_valid warn" "warn" "$(echo "$ARTIFACT_R2" | python3 -c "import json,sys; print(json.load(sys.stdin)['apps'][0]['criteria']['yaml_valid'])")"
check "case2: metadata pass" "pass" "$(echo "$ARTIFACT_R2" | python3 -c "import json,sys; print(json.load(sys.stdin)['apps'][0]['criteria']['metadata'])")"
check "case2: structure pass" "pass" "$(echo "$ARTIFACT_R2" | python3 -c "import json,sys; print(json.load(sys.stdin)['apps'][0]['criteria']['structure'])")"
check "case2: references pass" "pass" "$(echo "$ARTIFACT_R2" | python3 -c "import json,sys; print(json.load(sys.stdin)['apps'][0]['criteria']['references'])")"

# Case 3: STR-04 NOT CHECKED -> references = not_checked
cat > "$TMP/findings-result3.json" << 'EOF'
[
  {"app_id":"root","rule":"STR-04","defect_key":"submit.yml.erb:form-submit-mismatch","result":"NOT CHECKED","severity":"info","summary":"not checked","evidence":"submit.yml.erb"}
]
EOF
ARTIFACT_R3=$(python3 "$ASSEMBLE" --meta "$TMP/meta-result1.json" --findings "$TMP/findings-result3.json" --md "r.md" --plugin-version "0.3.0")
check "case3: references not_checked" "not_checked" "$(echo "$ARTIFACT_R3" | python3 -c "import json,sys; print(json.load(sys.stdin)['apps'][0]['criteria']['references'])")"

# Case 4: STR-02 WARN and STR-02 FAIL both present -> metadata = fail (worst wins)
#         STR-07 PASS and STR-07 WARN -> structure = warn
cat > "$TMP/findings-result4.json" << 'EOF'
[
  {"app_id":"root","rule":"STR-02","defect_key":"manifest.yml:missing-field:name","result":"WARN","severity":"low","summary":"metadata warn","evidence":"manifest.yml"},
  {"app_id":"root","rule":"STR-02","defect_key":"manifest.yml:missing-field:description","result":"FAIL","severity":"high","summary":"metadata fail","evidence":"manifest.yml"},
  {"app_id":"root","rule":"STR-07","defect_key":"form.yml:missing-form","result":"PASS","severity":"info","summary":"structure ok","evidence":"form.yml"},
  {"app_id":"root","rule":"STR-07","defect_key":"form.yml:missing-submit","result":"WARN","severity":"low","summary":"structure warn","evidence":"form.yml"}
]
EOF
ARTIFACT_R4=$(python3 "$ASSEMBLE" --meta "$TMP/meta-result1.json" --findings "$TMP/findings-result4.json" --md "r.md" --plugin-version "0.3.0")
check "case4: metadata fail (worst wins)" "fail" "$(echo "$ARTIFACT_R4" | python3 -c "import json,sys; print(json.load(sys.stdin)['apps'][0]['criteria']['metadata'])")"
check "case4: structure warn (worst wins)" "warn" "$(echo "$ARTIFACT_R4" | python3 -c "import json,sys; print(json.load(sys.stdin)['apps'][0]['criteria']['structure'])")"

# Case 5: unrecognized result -> fail + stderr warning
cat > "$TMP/findings-result5.json" << 'EOF'
[
  {"app_id":"root","rule":"STR-01","defect_key":"LICENSE:missing-license","result":"maybe","severity":"high","summary":"Missing LICENSE","evidence":"(no file)"}
]
EOF
ARTIFACT_R5=$(python3 "$ASSEMBLE" --meta "$TMP/meta-result1.json" --findings "$TMP/findings-result5.json" --md "r.md" --plugin-version "0.3.0" 2>"$TMP/stderr5.txt")
check "case5: license fail on unrecognized result" "fail" "$(echo "$ARTIFACT_R5" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo_level']['criteria']['license'])")"
STDERR5=$(cat "$TMP/stderr5.txt")
case "$STDERR5" in
  *"unrecognized result 'maybe'"*) check "case5: stderr warns unrecognized result" "yes" "yes" ;;
  *) check "case5: stderr warns unrecognized result" "yes" "no ($STDERR5)" ;;
esac

# Case 6: repo level missing-readme tag with PASS -> readme_substantive = pass; with FAIL -> fail
cat > "$TMP/findings-result6a.json" << 'EOF'
[
  {"app_id":"root","rule":"STR-01","defect_key":"README.md:missing-readme","result":"PASS","severity":"info","summary":"readme present","evidence":"README.md"}
]
EOF
ARTIFACT_R6A=$(python3 "$ASSEMBLE" --meta "$TMP/meta-result1.json" --findings "$TMP/findings-result6a.json" --md "r.md" --plugin-version "0.3.0")
check "case6: readme_substantive pass" "pass" "$(echo "$ARTIFACT_R6A" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo_level']['criteria']['readme_substantive'])")"

cat > "$TMP/findings-result6b.json" << 'EOF'
[
  {"app_id":"root","rule":"STR-01","defect_key":"README.md:missing-readme","result":"FAIL","severity":"high","summary":"readme missing","evidence":"(no file)"}
]
EOF
ARTIFACT_R6B=$(python3 "$ASSEMBLE" --meta "$TMP/meta-result1.json" --findings "$TMP/findings-result6b.json" --md "r.md" --plugin-version "0.3.0")
check "case6: readme_substantive fail" "fail" "$(echo "$ARTIFACT_R6B" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo_level']['criteria']['readme_substantive'])")"

# Case 7: meta-sourced gates (not_archived, public) go through the same enum
cat > "$TMP/meta-result7a.json" << 'EOF'
{
  "repo_url": "https://github.com/test/app",
  "sha": "abc123", "ref": "main",
  "repo_shape": "inferred_single",
  "not_archived": "WARN",
  "model": "claude-sonnet-4-6",
  "recommendation": {"decision": "Accept", "note": "All gates pass."},
  "apps": [{"app_id": "root", "name": "Test App", "decision": "Accept"}]
}
EOF
ARTIFACT_R7A=$(python3 "$ASSEMBLE" --meta "$TMP/meta-result7a.json" --md "r.md" --plugin-version "0.3.0")
check "case7a: not_archived WARN -> warn" "warn" "$(echo "$ARTIFACT_R7A" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo_level']['criteria']['not_archived'])")"

cat > "$TMP/meta-result7b.json" << 'EOF'
{
  "repo_url": "https://github.com/test/app",
  "sha": "abc123", "ref": "main",
  "repo_shape": "inferred_single",
  "not_archived": "maybe",
  "model": "claude-sonnet-4-6",
  "recommendation": {"decision": "Accept", "note": "All gates pass."},
  "apps": [{"app_id": "root", "name": "Test App", "decision": "Accept"}]
}
EOF
ARTIFACT_R7B=$(python3 "$ASSEMBLE" --meta "$TMP/meta-result7b.json" --md "r.md" --plugin-version "0.3.0" 2>"$TMP/stderr7b.txt")
check "case7b: not_archived maybe -> fail" "fail" "$(echo "$ARTIFACT_R7B" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo_level']['criteria']['not_archived'])")"
STDERR7B=$(cat "$TMP/stderr7b.txt")
case "$STDERR7B" in
  *"unrecognized"*) check "case7b: stderr warns unrecognized" "yes" "yes" ;;
  *) check "case7b: stderr warns unrecognized" "yes" "no ($STDERR7B)" ;;
esac

cat > "$TMP/meta-result7c.json" << 'EOF'
{
  "repo_url": "https://github.com/test/app",
  "sha": "abc123", "ref": "main",
  "repo_shape": "inferred_single",
  "not_archived": "pass",
  "public": "pass",
  "model": "claude-sonnet-4-6",
  "recommendation": {"decision": "Accept", "note": "All gates pass."},
  "apps": [{"app_id": "root", "name": "Test App", "decision": "Accept"}]
}
EOF
ARTIFACT_R7C=$(python3 "$ASSEMBLE" --meta "$TMP/meta-result7c.json" --md "r.md" --plugin-version "0.3.0")
check "case7c: public pass -> pass" "pass" "$(echo "$ARTIFACT_R7C" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo_level']['criteria']['public'])")"

ARTIFACT_R7D=$(python3 "$ASSEMBLE" --meta "$TMP/meta-result1.json" --md "r.md" --plugin-version "0.3.0")
check "case7d: no public in meta -> no public key" "False" "$(echo "$ARTIFACT_R7D" | python3 -c "import json,sys; print('public' in json.load(sys.stdin)['repo_level']['criteria'])")"

# Case 8: regression probes -- lower-case and padded result values resolve correctly
cat > "$TMP/findings-result8a.json" << 'EOF'
[
  {"app_id":"root","rule":"STR-01","defect_key":"LICENSE:missing-license","result":"pass","severity":"info","summary":"lower-case pass","evidence":"LICENSE"}
]
EOF
ARTIFACT_R8A=$(python3 "$ASSEMBLE" --meta "$TMP/meta-result1.json" --findings "$TMP/findings-result8a.json" --md "r.md" --plugin-version "0.3.0")
check "case8a: lower-case 'pass' resolves to pass" "pass" "$(echo "$ARTIFACT_R8A" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo_level']['criteria']['license'])")"

cat > "$TMP/findings-result8b.json" << 'EOF'
[
  {"app_id":"root","rule":"STR-01","defect_key":"LICENSE:missing-license","result":"  FAIL  ","severity":"high","summary":"padded FAIL","evidence":"(no file)"}
]
EOF
ARTIFACT_R8B=$(python3 "$ASSEMBLE" --meta "$TMP/meta-result1.json" --findings "$TMP/findings-result8b.json" --md "r.md" --plugin-version "0.3.0")
check "case8b: padded '  FAIL  ' resolves to fail" "fail" "$(echo "$ARTIFACT_R8B" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo_level']['criteria']['license'])")"

echo ""
echo "Done: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
