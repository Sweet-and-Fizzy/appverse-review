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

# Evaluate a path expression against the JSON on stdin (bound to `d`). A missing
# key prints a marker instead of raising, so one absent field shows up as a FAIL
# line rather than aborting the whole run under `set -e`.
jget() {
  python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(eval(sys.argv[1], {"d": d}))
except (KeyError, IndexError, TypeError) as e:
    print("<missing: {}>".format(e))
except ValueError:
    print("<invalid json>")
' "$1"
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

ARTIFACT=$(python3 "$ASSEMBLE" --meta "$TMP/meta.json" --findings "$TMP/findings.json" --md "r.md" --plugin-version "0.3.0" 2> "$TMP/warn1.txt")

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

ARTIFACT2=$(python3 "$ASSEMBLE" --meta "$TMP/meta-archived.json" --md "r.md" --plugin-version "0.3.0" 2> "$TMP/warn2.txt")
ARCHIVED2=$(echo "$ARTIFACT2" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo_level']['criteria']['not_archived'])")
check "archived repo criteria is fail" "fail" "$ARCHIVED2"

# --- Test 3: empty findings ---
echo ""
echo "Test 3: empty findings"
ARTIFACT3=$(echo '[]' | python3 "$ASSEMBLE" --meta "$TMP/meta.json" --md "r.md" --plugin-version "0.3.0" 2> "$TMP/warn3.txt")
EMPTY_REPO=$(echo "$ARTIFACT3" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['repo_level']['findings']))")
check "empty findings: repo_level has 0 findings" "0" "$EMPTY_REPO"

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

# Case 4b: STR-06 FAIL -> structure = fail; STR-06 NOT CHECKED -> structure = not_checked
cat > "$TMP/findings-result4b.json" << 'EOF'
[
  {"app_id":"root","rule":"STR-06","defect_key":"template/script.sh.erb:bash-syntax-error","result":"FAIL","severity":"high","summary":"bash -n failed","evidence":"template/script.sh.erb:3"}
]
EOF
ARTIFACT_R4B=$(python3 "$ASSEMBLE" --meta "$TMP/meta-result1.json" --findings "$TMP/findings-result4b.json" --md "r.md" --plugin-version "0.3.0")
check "case4b: STR-06 FAIL makes structure fail" "fail" "$(echo "$ARTIFACT_R4B" | python3 -c "import json,sys; print(json.load(sys.stdin)['apps'][0]['criteria']['structure'])")"
cat > "$TMP/findings-result4c.json" << 'EOF'
[
  {"app_id":"root","rule":"STR-06","defect_key":"template/script.sh.erb:bash-syntax-error","result":"NOT CHECKED","severity":"info","summary":"syntax check did not run","evidence":"template/script.sh.erb:1"}
]
EOF
ARTIFACT_R4C=$(python3 "$ASSEMBLE" --meta "$TMP/meta-result1.json" --findings "$TMP/findings-result4c.json" --md "r.md" --plugin-version "0.3.0")
check "case4c: STR-06 NOT CHECKED makes structure not_checked" "not_checked" "$(echo "$ARTIFACT_R4C" | python3 -c "import json,sys; print(json.load(sys.stdin)['apps'][0]['criteria']['structure'])")"

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

# --- Test 5: indicator derivation ---
echo ""
echo "Test 5: indicator derivation"
cat > "$TMP/meta-ind.json" << 'EOF'
{
  "repo_url": "https://github.com/test/mono",
  "sha": "abc789", "ref": "main",
  "repo_shape": "declared_monorepo",
  "not_archived": "pass",
  "model": "claude-sonnet-4-6",
  "recommendation": {"decision": "Accept with suggestions", "note": "Minor issues."},
  "maintenance_assessment": {
    "active_within_12mo": true,
    "waiver_brand_new": false,
    "signals": {"releases": true, "changelog": false, "ci": true, "multiple_contributors": true, "issues_responded": null},
    "summary": "Active, 3 releases, CI green"
  },
  "apps": [
    {"app_id": "app-a", "name": "App A", "decision": "Request changes",
     "assessments": {"documentation": "adequate", "documentation_summary": "README covers install and config",
                     "portability": "portable", "portability_summary": "All site values in form.yml"}},
    {"app_id": "app-b", "name": "App B", "decision": "Accept",
     "assessments": {"documentation": "strong", "documentation_summary": "Full README with troubleshooting",
                     "portability": "partially_portable", "portability_summary": "One hardcoded module version"}}
  ]
}
EOF

cat > "$TMP/findings-ind.json" << 'EOF'
[
  {"app_id":"app-a","rule":"OODT-05","defect_key":"template/script.sh.erb:bind-all-interfaces","aspect":"security","severity":"medium","result":"FAIL","summary":"Bound to 0.0.0.0","evidence":"template/script.sh.erb:24"},
  {"app_id":"app-a","rule":"OODT-08","defect_key":"Gemfile.lock:known-cve","aspect":"security","severity":"low","result":"WARN","summary":"Old excon","evidence":"Gemfile.lock:9"},
  {"app_id":"app-b","rule":"QUA-03","defect_key":"template/run.sh.erb:no-set-e","aspect":"quality","severity":"low","result":"WARN","summary":"No error handling","evidence":"template/run.sh.erb:1"},
  {"app_id":"root","rule":"MNT-03","defect_key":"CHANGELOG:no-changelog","aspect":"maintenance","severity":"info","result":"WARN","summary":"No CHANGELOG","evidence":"(no file)"}
]
EOF

ART4=$(python3 "$ASSEMBLE" --meta "$TMP/meta-ind.json" --findings "$TMP/findings-ind.json" --md "r.md" --plugin-version "0.3.0" 2> "$TMP/warn4.txt")

SCHEMA=$(echo "$ART4" | jget "d['schema_version']")
check "schema_version is 1.3" "1.3" "$SCHEMA"

NO_SEC=$(echo "$ART4" | jget "'security' in d['apps'][0]['indicators']")
check "no security indicator (schema 1.2)" "False" "$NO_SEC"

PORT_A=$(echo "$ART4" | jget "d['apps'][0]['indicators']['portability']['level']")
check "app-a portability solid (portable)" "solid" "$PORT_A"

DOCS_A=$(echo "$ART4" | jget "d['apps'][0]['indicators']['documentation']['level']")
check "app-a documentation some_notes (adequate)" "some_notes" "$DOCS_A"

DOCS_B=$(echo "$ART4" | jget "d['apps'][1]['indicators']['documentation']['level']")
check "app-b documentation solid (strong)" "solid" "$DOCS_B"

PORT_B=$(echo "$ART4" | jget "d['apps'][1]['indicators']['portability']['level']")
check "app-b portability some_notes (partial)" "some_notes" "$PORT_B"

MAINT=$(echo "$ART4" | jget "d['repo_level']['indicators']['maintenance']['level']")
check "maintenance solid (active + 3 signals)" "solid" "$MAINT"

ANCHOR=$(echo "$ART4" | jget "d['apps'][0]['indicators']['portability']['anchor']")
check "portability anchor fragment" "#portability" "$ANCHOR"

MAINT_ANCHOR=$(echo "$ART4" | jget "d['repo_level']['indicators']['maintenance']['anchor']")
check "maintenance anchor fragment" "#upkeep" "$MAINT_ANCHOR"

# The report has no "Quality" heading any more: docs and portability each have
# their own section, so each indicator links to its own.
DOCS_ANCHOR_A=$(echo "$ART4" | jget "d['apps'][0]['indicators']['documentation']['anchor']")
check "app-a documentation anchor" "#documentation" "$DOCS_ANCHOR_A"

PORT_ANCHOR_A=$(echo "$ART4" | jget "d['apps'][0]['indicators']['portability']['anchor']")
check "app-a portability anchor" "#portability" "$PORT_ANCHOR_A"

# Monorepo: every app repeats the same headings, and pandoc de-duplicates the
# second occurrence as "-1". App index 1 must not link into app 0's section.
PORT_ANCHOR_B=$(echo "$ART4" | jget "d['apps'][1]['indicators']['portability']['anchor']")
check "app-b portability anchor (2nd app)" "#portability-1" "$PORT_ANCHOR_B"

DOCS_ANCHOR_B=$(echo "$ART4" | jget "d['apps'][1]['indicators']['documentation']['anchor']")
check "app-b documentation anchor (2nd app)" "#documentation-1" "$DOCS_ANCHOR_B"

# --- Test 6: no assessments -> no indicators (backward compatible) ---
echo ""
echo "Test 6: no assessments -> indicators omitted"
ART5=$(python3 "$ASSEMBLE" --meta "$TMP/meta.json" --findings "$TMP/findings.json" --md "r.md" --plugin-version "0.3.0" 2> "$TMP/warn5.txt")
HAS_IND=$(echo "$ART5" | jget "'indicators' in d['apps'][0] or 'indicators' in d['repo_level']")
check "no indicators without assessments" "False" "$HAS_IND"
grep -q "assessments" "$TMP/warn5.txt" && WARNED=yes || WARNED=no
check "stderr warns about missing assessments" "yes" "$WARNED"

# --- Test 7: cross-check warnings + waiver ---
echo ""
echo "Test 7: cross-check warnings and brand-new waiver"
cat > "$TMP/meta-x.json" << 'EOF'
{
  "repo_url": "https://github.com/test/newapp",
  "sha": "fff000", "ref": "main",
  "repo_shape": "inferred_single",
  "not_archived": "pass",
  "recommendation": {"decision": "Accept", "note": "Fine."},
  "maintenance_assessment": {
    "active_within_12mo": false,
    "waiver_brand_new": true,
    "signals": {"releases": false, "changelog": false, "ci": false, "multiple_contributors": false, "issues_responded": null},
    "summary": "Brand-new app, history waived"
  },
  "apps": [
    {"app_id": "root", "name": "New App", "decision": "Accept",
     "assessments": {"documentation": "strong", "documentation_summary": "Good README",
                     "portability": "portable", "portability_summary": "Clean"}}
  ]
}
EOF
cat > "$TMP/findings-x.json" << 'EOF'
[
  {"app_id":"root","rule":"QUA-01","defect_key":"README.md:docs-minimal","aspect":"quality","severity":"medium","result":"FAIL","summary":"Docs below threshold","evidence":"README.md:1"}
]
EOF
ART6=$(python3 "$ASSEMBLE" --meta "$TMP/meta-x.json" --findings "$TMP/findings-x.json" --md "r.md" --plugin-version "0.3.0" 2> "$TMP/warn6.txt")
WAIVED=$(echo "$ART6" | jget "d['repo_level']['indicators']['maintenance']['level']")
check "waived brand-new app lands some_notes" "some_notes" "$WAIVED"
# The fixture's own summary never says "waiver"; a deployer reading the chip must
# still be told why an inactive repo is not flagged.
WAIVED_SUM=$(echo "$ART6" | jget "'waiver' in d['repo_level']['indicators']['maintenance']['summary'].lower()")
check "waiver named in maintenance summary" "True" "$WAIVED_SUM"
grep -q "QUA-01" "$TMP/warn6.txt" && XWARN=yes || XWARN=no
check "cross-check warns on QUA-01 vs strong docs" "yes" "$XWARN"
# Since row-per-check reporting, a clean check is a QUA-01 record with result
# PASS. That is agreement with a strong grade, not a contradiction.
cat > "$TMP/findings-x-pass.json" << 'EOF'
[
  {"app_id":"root","rule":"QUA-01","defect_key":"README.md:docs-minimal","aspect":"quality","severity":"info","result":"PASS","summary":"README covers all four deployment questions","evidence":"README.md:1"}
]
EOF
python3 "$ASSEMBLE" --meta "$TMP/meta-x.json" --findings "$TMP/findings-x-pass.json" --md "r.md" --plugin-version "0.3.0" > /dev/null 2> "$TMP/warn6b.txt"
grep -q "QUA-01" "$TMP/warn6b.txt" && XPASSWARN=yes || XPASSWARN=no
check "QUA-01 with result PASS beside strong docs does not warn" "no" "$XPASSWARN"

# --- Test 8: OODT findings of varying severity stay in findings, untouched ---
echo ""
echo "Test 8: OODT findings of varying severity stay in findings, untouched"
cat > "$TMP/meta-sev.json" << 'EOF'
{
  "repo_url": "https://github.com/test/sev",
  "sha": "5e5e5e", "ref": "main",
  "repo_shape": "declared_monorepo",
  "not_archived": "pass",
  "recommendation": {"decision": "Request changes", "note": "See findings."},
  "maintenance_assessment": {
    "active_within_12mo": true,
    "waiver_brand_new": false,
    "signals": {"releases": true, "changelog": true, "ci": false, "multiple_contributors": false, "issues_responded": true},
    "summary": "Active"
  },
  "apps": [
    {"app_id": "app-crit", "name": "Crit", "decision": "Request changes",
     "assessments": {"documentation": "strong", "documentation_summary": "ok",
                     "portability": "portable", "portability_summary": "ok"}},
    {"app_id": "app-info", "name": "Info", "decision": "Accept",
     "assessments": {"documentation": "strong", "documentation_summary": "ok",
                     "portability": "portable", "portability_summary": "ok"}},
    {"app_id": "app-str", "name": "Str", "decision": "Request changes",
     "assessments": {"documentation": "strong", "documentation_summary": "ok",
                     "portability": "portable", "portability_summary": "ok"}}
  ]
}
EOF
cat > "$TMP/findings-sev.json" << 'EOF'
[
  {"app_id":"app-crit","rule":"OODT-01","defect_key":"template/script.sh.erb:eval-exec","aspect":"security","severity":"critical","result":"FAIL","summary":"eval of form input","evidence":"template/script.sh.erb:12"},
  {"app_id":"app-info","rule":"OODT-03","defect_key":"template/after.sh.erb:permissive-file-mode","aspect":"security","severity":"info","result":"WARN","summary":"0644 on a scratch file","evidence":"template/after.sh.erb:4"},
  {"app_id":"app-str","rule":"STR-03","defect_key":"form.yml:yaml-parse-error","aspect":"structure","severity":"high","result":"FAIL","summary":"Broken YAML","evidence":"form.yml:3"}
]
EOF
ART7=$(python3 "$ASSEMBLE" --meta "$TMP/meta-sev.json" --findings "$TMP/findings-sev.json" --md "r.md" --plugin-version "0.3.0" 2> "$TMP/warn7.txt")

CRIT_FINDING=$(echo "$ART7" | jget "d['apps'][0]['findings'][0]['rule']")
check "Critical OODT finding stays in app-crit's findings" "OODT-01" "$CRIT_FINDING"

INFO_FINDING=$(echo "$ART7" | jget "d['apps'][1]['findings'][0]['rule']")
check "Info OODT finding stays in app-info's findings" "OODT-03" "$INFO_FINDING"

NO_SEC_CRIT=$(echo "$ART7" | jget "'security' in d['apps'][0]['indicators']")
check "no security indicator regardless of OODT severity" "False" "$NO_SEC_CRIT"

# A high-severity STRUCTURE finding is not an OODT finding, and there is no
# security indicator to key on the OODT- rule prefix any more.
SEC_STR=$(echo "$ART7" | jget "d['apps'][2]['findings'][0]['rule']")
check "High STR finding stays in app-str's findings" "STR-03" "$SEC_STR"

# --- Test 9: upkeep boundaries ---
echo ""
echo "Test 9: upkeep boundaries"
# maint_level <active> <waiver> <signals-json> <findings-json> -> level on stdout,
# assembler stderr in $TMP/warn8.txt
maint_level() {
  cat > "$TMP/meta-m.json" << EOF
{
  "repo_url": "https://github.com/test/maint",
  "sha": "aaa111", "ref": "main",
  "repo_shape": "inferred_single",
  "not_archived": "pass",
  "recommendation": {"decision": "Accept", "note": "n/a"},
  "maintenance_assessment": {
    "active_within_12mo": $1,
    "waiver_brand_new": $2,
    "signals": $3,
    "summary": "fixture"
  },
  "apps": [
    {"app_id": "root", "name": "Maint",
     "assessments": {"documentation": "strong", "documentation_summary": "ok",
                     "portability": "portable", "portability_summary": "ok"}}
  ]
}
EOF
  echo "$4" > "$TMP/findings-m.json"
  python3 "$ASSEMBLE" --meta "$TMP/meta-m.json" --findings "$TMP/findings-m.json" --md "r.md" --plugin-version "0.3.0" 2> "$TMP/warn8.txt" \
    | jget "d['repo_level']['indicators']['maintenance']['level']"
}
ONE_SIGNAL_NO_ISSUES='{"releases": true, "changelog": false, "ci": false, "multiple_contributors": false, "issues_responded": false}'
ONE_SIGNAL_NULL_ISSUES='{"releases": true, "changelog": false, "ci": false, "multiple_contributors": false, "issues_responded": null}'
TWO_SIGNALS_NULL_ISSUES='{"releases": true, "changelog": true, "ci": false, "multiple_contributors": false, "issues_responded": null}'
NO_SIGNALS='{"releases": false, "changelog": false, "ci": false, "multiple_contributors": false, "issues_responded": false}'
MNT01='[{"app_id":"root","rule":"MNT-01","defect_key":"(repo):stale-repo","aspect":"maintenance","severity":"medium","result":"FAIL","summary":"Last commit 14 months ago","evidence":"(git log)"}]'
MNT01_PASS='[{"app_id":"root","rule":"MNT-01","defect_key":"(repo):stale-repo","aspect":"maintenance","severity":"medium","result":"PASS","summary":"Last commit 2 months ago","evidence":"(git log)"}]'

check "active + 1 signal -> some_notes" "some_notes" "$(maint_level true false "$ONE_SIGNAL_NO_ISSUES" '[]')"
# No open issues is no evidence of responsiveness either way: null is neutral,
# so a quiet repo still needs two of the other four signals to reach solid.
check "null issues_responded is neutral: 1 signal + null -> some_notes" "some_notes" "$(maint_level true false "$ONE_SIGNAL_NULL_ISSUES" '[]')"
check "null issues_responded is neutral: 2 signals + null -> solid" "solid" "$(maint_level true false "$TWO_SIGNALS_NULL_ISSUES" '[]')"
check "inactive, no waiver -> needs_attention" "needs_attention" "$(maint_level false false "$NO_SIGNALS" '[]')"

check "MNT-01 wins over brand-new waiver" "needs_attention" "$(maint_level false true "$NO_SIGNALS" "$MNT01")"
grep -qi "waiver" "$TMP/warn8.txt" && CONFLICT=yes || CONFLICT=no
check "MNT-01 + waiver contradiction warns on stderr" "yes" "$CONFLICT"
# A PASS-result MNT-01 record says the gate was confirmed, not that the repo is stale.
check "MNT-01 with result PASS does not force needs_attention" "solid" "$(maint_level true false "$TWO_SIGNALS_NULL_ISSUES" "$MNT01_PASS")"
# The block is optional: a null signals block must not crash the assembler.
check "null signals block -> some_notes, no crash" "some_notes" "$(maint_level true false 'null' '[]')"

# --- Test 10: report-vs-artifact signal cross-check ---
echo ""
echo "Test 10: reported signals cross-check"
# The report states Low/Medium/High (LLM-derived); the artifact level is computed.
# with_reported <out> <app-a security> <maintenance> adds the report's stated
# levels to the Test 5 fixture. Everything except the two arguments agrees with
# the computed levels (Low=solid, Medium=some_notes, High=needs_attention). The
# security key is stale: schema 1.2 has no security indicator, so it has nothing
# to compare against and is ignored, whatever value it carries. An optional
# fifth argument overrides app-a's reported portability.
with_reported() {
  python3 -c '
import json, sys
m = json.load(open(sys.argv[1]))
m["apps"][0]["reported_signals"] = {"security": sys.argv[3], "portability": sys.argv[5] if len(sys.argv) > 5 else "Low", "documentation": "Medium"}
m["apps"][1]["reported_signals"] = {"security": "Low", "portability": "Medium", "documentation": "Low"}
m["maintenance_assessment"]["reported_signal"] = sys.argv[4]
json.dump(m, open(sys.argv[2], "w"))
' "$TMP/meta-ind.json" "$@"
}

with_reported "$TMP/meta-agree.json" "High" "Low"
python3 "$ASSEMBLE" --meta "$TMP/meta-agree.json" --findings "$TMP/findings-ind.json" --md "r.md" --plugin-version "0.3.0" > "$TMP/art9a.json" 2> "$TMP/warn9a.txt"
[ -s "$TMP/warn9a.txt" ] && QUIET=no || QUIET=yes
check "agreeing reported signals: stderr silent" "yes" "$QUIET"
LEAKED=$(jget "'reported_signals' in d['apps'][0]" < "$TMP/art9a.json")
check "reported_signals not copied into artifact" "False" "$LEAKED"

with_reported "$TMP/meta-sec.json" "Low" "Low"
python3 "$ASSEMBLE" --meta "$TMP/meta-sec.json" --findings "$TMP/findings-ind.json" --md "r.md" --plugin-version "0.3.0" > /dev/null 2> "$TMP/warn9b.txt"
[ -s "$TMP/warn9b.txt" ] && SECQUIET=no || SECQUIET=yes
check "reported_signals.security is ignored: no warning even though it disagrees" "yes" "$SECQUIET"

with_reported "$TMP/meta-mnt.json" "High" "High"
python3 "$ASSEMBLE" --meta "$TMP/meta-mnt.json" --findings "$TMP/findings-ind.json" --md "r.md" --plugin-version "0.3.0" > /dev/null 2> "$TMP/warn9c.txt"
grep -qi "maintenance" "$TMP/warn9c.txt" && MNTWARN=yes || MNTWARN=no
check "report says High, computed solid: warns for maintenance" "yes" "$MNTWARN"

with_reported "$TMP/meta-port.json" "Low" "Low" "High"
python3 "$ASSEMBLE" --meta "$TMP/meta-port.json" --findings "$TMP/findings-ind.json" --md "r.md" --plugin-version "0.3.0" > /dev/null 2> "$TMP/warn9d.txt"
grep "report states" "$TMP/warn9d.txt" | grep -q "app-a" && grep "report states" "$TMP/warn9d.txt" | grep -q "portability" && PORTWARN=yes || PORTWARN=no
check "app-a report says portability High, computed solid: warns naming app-a and portability" "yes" "$PORTWARN"
check "only that one axis and app warns" "1" "$(grep -c "report states" "$TMP/warn9d.txt")"

# --- Test 11: grades are LLM-written strings ---
echo ""
echo "Test 11: grade normalization and unknown grades"
cat > "$TMP/meta-grade.json" << 'EOF'
{
  "repo_url": "https://github.com/test/grade",
  "sha": "9a9a9a", "ref": "main",
  "repo_shape": "inferred_single",
  "not_archived": "pass",
  "recommendation": {"decision": "Accept", "note": "n/a"},
  "apps": [
    {"app_id": "root", "name": "Grade",
     "assessments": {"documentation": "excellent", "documentation_summary": "ok",
                     "portability": "Partially portable", "portability_summary": "ok"}}
  ]
}
EOF
ART10=$(python3 "$ASSEMBLE" --meta "$TMP/meta-grade.json" --md "r.md" --plugin-version "0.3.0" 2> "$TMP/warn10.txt")

PORT_NORM=$(echo "$ART10" | jget "d['apps'][0]['indicators']['portability']['level']")
check "'Partially portable' normalizes -> some_notes" "some_notes" "$PORT_NORM"

DOCS_UNKNOWN=$(echo "$ART10" | jget "'documentation' in d['apps'][0]['indicators']")
check "unknown grade: documentation indicator omitted" "False" "$DOCS_UNKNOWN"
grep -q "excellent" "$TMP/warn10.txt" && GRADEWARN=yes || GRADEWARN=no
check "unknown grade named on stderr" "yes" "$GRADEWARN"

# --- Test 12: no finding is lost ---
echo ""
echo "Test 12: findings whose app_id matches no app"
# In a monorepo the apps are subpaths, so a repo-wide structure finding carries
# app_id "root" and matches none of them. It belongs at repo level; it must not
# vanish between findings.json and the artifact.
cat > "$TMP/findings-orphan.json" << 'EOF'
[
  {"app_id":"app-a","rule":"OODT-08","defect_key":"Gemfile.lock:known-cve","aspect":"security","severity":"low","result":"WARN","summary":"Old excon","evidence":"Gemfile.lock:9"},
  {"app_id":"root","rule":"STR-04","defect_key":"app-templates/:other:missing-shared-path-dir","aspect":"structure","severity":"medium","result":"FAIL","summary":"shared_paths entry does not exist","evidence":"appverse.yml:43"},
  {"app_id":"root","rule":"MNT-03","defect_key":"CHANGELOG:no-changelog","aspect":"maintenance","severity":"info","result":"WARN","summary":"No CHANGELOG","evidence":"(no file)"}
]
EOF
ART11=$(python3 "$ASSEMBLE" --meta "$TMP/meta-ind.json" --findings "$TMP/findings-orphan.json" --md "r.md" --plugin-version "0.3.0" 2> "$TMP/warn11.txt")

TOTAL_OUT=$(echo "$ART11" | jget "len(d['repo_level']['findings']) + sum(len(a['findings']) for a in d['apps'])")
check "3 findings in, 3 findings out" "3" "$TOTAL_OUT"

ORPHAN_RULES=$(echo "$ART11" | jget "sorted(f['rule'] for f in d['repo_level']['findings'])")
check "repo-wide 'root' findings land at repo level" "['MNT-03', 'STR-04']" "$ORPHAN_RULES"

APP_A_RULES=$(echo "$ART11" | jget "[f['rule'] for f in d['apps'][0]['findings']]")
check "matched finding stays with its app" "['OODT-08']" "$APP_A_RULES"

# "root" in a monorepo is the normal home of a repo-wide finding, not a mistake;
# warning on it would fire on every monorepo and teach people to ignore stderr.
grep -q "'root'" "$TMP/warn11.txt" && ROOTWARN=yes || ROOTWARN=no
check "repo-wide 'root' findings do not warn" "no" "$ROOTWARN"

# Any other unmatched app_id is a spelling mismatch between findings.json and
# meta.apps. Routing those findings elsewhere would leave their real app with a
# clean findings and all-pass criteria it did not earn, so the assembler
# refuses instead: a red run beats a confident wrong artifact.
cat > "$TMP/findings-typo.json" << 'EOF'
[
  {"app_id":"app-a/","rule":"OODT-02","defect_key":"script.sh.erb:hardcoded-credential","aspect":"security","severity":"high","result":"FAIL","summary":"Hardcoded token","evidence":"script.sh.erb:2"}
]
EOF
if python3 "$ASSEMBLE" --meta "$TMP/meta-ind.json" --findings "$TMP/findings-typo.json" --md "r.md" --plugin-version "0.3.0" > "$TMP/art-typo.json" 2> "$TMP/warn-typo.txt"; then TYPO_RC=0; else TYPO_RC=$?; fi
check "unmatched non-root app_id: exit status non-zero" "1" "$TYPO_RC"
grep -q "app-a/" "$TMP/warn-typo.txt" && TYPOWARN=yes || TYPOWARN=no
check "unmatched non-root app_id named on stderr" "yes" "$TYPOWARN"
check "unmatched non-root app_id: no artifact written" "0" "$(wc -c < "$TMP/art-typo.json" | tr -d ' ')"

# --- Test 13: report paths are filenames ---
echo ""
echo "Test 13: report paths"
# CI passes absolute runner paths; a consumer finds the reports beside the
# artifact, so only the filename means anything outside the run.
ART12=$(python3 "$ASSEMBLE" --meta "$TMP/meta-ind.json" --findings "$TMP/findings-ind.json" \
  --md "/home/runner/work/x/review-o-r.md" --pdf "/home/runner/work/x/review-o-r.pdf" --html "sub/dir/review-o-r.html" \
  --plugin-version "0.3.0" 2> "$TMP/warn12.txt")
check "report_md is a filename" "review-o-r.md" "$(echo "$ART12" | jget "d['artifacts']['report_md']")"
check "report_pdf is a filename" "review-o-r.pdf" "$(echo "$ART12" | jget "d['artifacts']['report_pdf']")"
check "report_html is a filename" "review-o-r.html" "$(echo "$ART12" | jget "d['artifacts']['report_html']")"
ART12B=$(python3 "$ASSEMBLE" --meta "$TMP/meta-ind.json" --findings "$TMP/findings-ind.json" --md "r.md" --plugin-version "0.3.0" 2> /dev/null)
check "omitted report path stays empty" "" "$(echo "$ART12B" | jget "d['artifacts']['report_pdf']")"

# --- Test 14: indicators honor the finding's result ---
echo ""
echo "Test 14: indicators honor the finding's result"
# The security skill reports tier 3 as NOT CHECKED, and the structure skill
# emits PASS records for confirmed gates. Neither is a defect, so neither may
# move a level; only FAIL and WARN records do.
cat > "$TMP/findings-result.json" << 'EOF'
[
  {"app_id":"app-a","rule":"OODT-01","defect_key":"template/script.sh.erb:eval-exec","aspect":"security","severity":"medium","result":"NOT CHECKED","summary":"Tier 3 requires a running app","evidence":"(not run)"},
  {"app_id":"app-b","rule":"OODT-02","defect_key":"script.sh.erb:hardcoded-credential","aspect":"security","severity":"high","result":"PASS","summary":"No credentials in templates","evidence":"template/"},
  {"app_id":"app-b","rule":"OODT-08","defect_key":"Gemfile.lock:known-cve","aspect":"security","severity":"low","result":"WARN","summary":"Old excon","evidence":"Gemfile.lock:9"}
]
EOF
ART14=$(python3 "$ASSEMBLE" --meta "$TMP/meta-ind.json" --findings "$TMP/findings-result.json" --md "r.md" --plugin-version "0.3.0" 2> "$TMP/warn14.txt")
check "NOT CHECKED OODT record is still present in findings" "OODT-01" "$(echo "$ART14" | jget "d['apps'][0]['findings'][0]['rule']")"
check "NOT CHECKED result is preserved" "NOT CHECKED" "$(echo "$ART14" | jget "d['apps'][0]['findings'][0]['result']")"
check "PASS and WARN OODT records both still present" "['OODT-02', 'OODT-08']" "$(echo "$ART14" | jget "[f['rule'] for f in d['apps'][1]['findings']]")"

# --- Test 15: optional inputs with the wrong shape ---
echo ""
echo "Test 15: optional inputs with the wrong shape"
# reported_signals is optional; a list where an object was expected must not
# take the whole run down with it.
python3 - "$TMP/meta-ind.json" "$TMP/meta-badshape.json" << 'EOF'
import json, sys
m = json.load(open(sys.argv[1]))
m["apps"][0]["reported_signals"] = ["Low", "Medium", "High"]
m["maintenance_assessment"]["signals"] = None
json.dump(m, open(sys.argv[2], "w"))
EOF
if python3 "$ASSEMBLE" --meta "$TMP/meta-badshape.json" --findings "$TMP/findings-ind.json" --md "r.md" --plugin-version "0.3.0" > "$TMP/art15.json" 2> "$TMP/warn15.txt"; then RC15=0; else RC15=$?; fi
check "list-shaped reported_signals + null signals: exit 0" "0" "$RC15"
check "…and the indicators are still derived" "solid" "$(jget "d['apps'][0]['indicators']['portability']['level']" < "$TMP/art15.json")"
grep -qi "reported_signals" "$TMP/warn15.txt" && SHAPEWARN=yes || SHAPEWARN=no
check "…and the bad shape is named on stderr" "yes" "$SHAPEWARN"

# --- Test 17: per-app upkeep in a declared monorepo (schema 1.3) ---
echo ""
echo "Test 17: per-app upkeep"
# Each app's own activity sets its upkeep; the repo's stays. An app without a
# maintenance_assessment has no maintenance indicator, and the level links to
# the app's Signals block.
cat > "$TMP/meta-upkeep.json" << 'EOF'
{
  "repo_url": "https://github.com/test/mono",
  "sha": "abc789", "ref": "main",
  "repo_shape": "declared_monorepo",
  "not_archived": "pass",
  "model": "claude-sonnet-4-6",
  "recommendation": {"decision": "Accept", "note": "Fine."},
  "maintenance_assessment": {
    "active_within_12mo": true, "waiver_brand_new": false,
    "signals": {"releases": true, "changelog": true, "ci": true, "multiple_contributors": true, "issues_responded": null},
    "summary": "Active, releases, CI"
  },
  "apps": [
    {"app_id": "busy", "name": "Busy", "decision": "Accept",
     "assessments": {"documentation": "strong", "portability": "portable"},
     "reported_signals": {"maintenance": "Low"},
     "maintenance_assessment": {"active_within_12mo": true,
       "signals": {"releases": true, "changelog": false, "ci": true, "multiple_contributors": true, "issues_responded": null},
       "summary": "Changed last month; two contributors"}},
    {"app_id": "quiet", "name": "Quiet", "decision": "Accept",
     "assessments": {"documentation": "strong", "portability": "portable"},
     "reported_signals": {"maintenance": "Low"},
     "maintenance_assessment": {"active_within_12mo": false,
       "signals": {"releases": true, "changelog": false, "ci": true, "multiple_contributors": false, "issues_responded": null},
       "summary": "Last change 2023-02"}},
    {"app_id": "older", "name": "Older", "decision": "Accept",
     "assessments": {"documentation": "strong", "portability": "portable"}}
  ]
}
EOF
echo '[]' > "$TMP/findings-upkeep.json"
ART17=$(python3 "$ASSEMBLE" --meta "$TMP/meta-upkeep.json" --findings "$TMP/findings-upkeep.json" --md "r.md" --plugin-version "0.3.0" 2> "$TMP/warn17.txt")
check "busy app: its own upkeep is solid" "solid" "$(echo "$ART17" | jget "d['apps'][0]['indicators']['maintenance']['level']")"
check "busy app: links to its Signals block" "#signals" "$(echo "$ART17" | jget "d['apps'][0]['indicators']['maintenance']['anchor']")"
check "quiet app: inactive needs attention" "needs_attention" "$(echo "$ART17" | jget "d['apps'][1]['indicators']['maintenance']['level']")"
check "quiet app: second app's Signals anchor" "#signals-1" "$(echo "$ART17" | jget "d['apps'][1]['indicators']['maintenance']['anchor']")"
check "app without its own assessment: no maintenance indicator" "False" "$(echo "$ART17" | jget "'maintenance' in d['apps'][2]['indicators']")"
check "repo upkeep unchanged" "solid" "$(echo "$ART17" | jget "d['repo_level']['indicators']['maintenance']['level']")"
check "a reported per-app level that disagrees warns" "1" "$(grep -c "app 'quiet': report states maintenance signal 'Low'" "$TMP/warn17.txt")"

# --- Test 17b: a per-app upkeep block must be well-typed, monorepo-only, no waiver ---
echo ""
echo "Test 17b: per-app upkeep input checks"
python3 - "$TMP" << 'PY'
import json, sys
tmp = sys.argv[1]
m = json.load(open(tmp + "/meta-upkeep.json"))
m["apps"][1]["maintenance_assessment"]["active_within_12mo"] = "false"
m["apps"][0]["maintenance_assessment"]["waiver_brand_new"] = True
json.dump(m, open(tmp + "/meta-upkeep-bad.json", "w"))
m2 = json.load(open(tmp + "/meta-upkeep.json"))
m2["repo_shape"] = "declared_single"
json.dump(m2, open(tmp + "/meta-upkeep-single.json", "w"))
PY
ART17B=$(python3 "$ASSEMBLE" --meta "$TMP/meta-upkeep-bad.json" --findings "$TMP/findings-upkeep.json" --md "r.md" --plugin-version "0.3.0" 2> "$TMP/warn17b.txt")
check "string 'false' is refused, not read as active" "False" "$(echo "$ART17B" | jget "'maintenance' in d['apps'][1]['indicators']")"
check "the refusal warns" "1" "$(grep -c "app 'quiet': maintenance_assessment active_within_12mo is not true or false" "$TMP/warn17b.txt")"
check "a per-app waiver is ignored" "solid" "$(echo "$ART17B" | jget "d['apps'][0]['indicators']['maintenance']['level']")"
check "the ignored waiver warns" "1" "$(grep -c "the brand-new waiver does not apply per app" "$TMP/warn17b.txt")"
ART17C=$(python3 "$ASSEMBLE" --meta "$TMP/meta-upkeep-single.json" --findings "$TMP/findings-upkeep.json" --md "r.md" --plugin-version "0.3.0" 2> "$TMP/warn17c.txt")
check "outside a declared monorepo there is no per-app upkeep" "False" "$(echo "$ART17C" | jget "'maintenance' in d['apps'][0]['indicators']")"

# --- Test 16: malformed findings.json ---
echo ""
echo "Test 16: malformed findings.json"
# A findings file that will not parse used to become "no findings", and the
# artifact then claimed clean findings for every app.
printf '[{"app_id": "app-a", "rule": "OODT-01"' > "$TMP/findings-broken.json"
if python3 "$ASSEMBLE" --meta "$TMP/meta-ind.json" --findings "$TMP/findings-broken.json" --md "r.md" --plugin-version "0.3.0" > "$TMP/art16.json" 2> "$TMP/warn16.txt"; then RC16=0; else RC16=$?; fi
check "malformed findings: exit status non-zero" "1" "$RC16"
check "malformed findings: no artifact written" "0" "$(wc -c < "$TMP/art16.json" | tr -d ' ')"
if python3 "$ASSEMBLE" --meta "$TMP/meta-ind.json" --findings "$TMP/does-not-exist.json" --md "r.md" --plugin-version "0.3.0" > /dev/null 2> "$TMP/warn16b.txt"; then RC16B=0; else RC16B=$?; fi
check "findings path given but missing: exit status non-zero" "1" "$RC16B"

echo ""
echo "Done: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
