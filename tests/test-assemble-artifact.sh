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
  {"app_id":"root","rule":"STR-01","defect_key":"LICENSE:missing-license","severity":"high","summary":"Missing LICENSE","evidence":"(no file)"},
  {"app_id":"root","rule":"STR-03","defect_key":"form.yml:yaml-parse-error","severity":"high","summary":"Broken YAML","evidence":"form.yml:3"},
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

echo ""
echo "Done: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
