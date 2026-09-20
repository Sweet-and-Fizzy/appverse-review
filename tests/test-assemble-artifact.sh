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
  {"app_id":"root","rule":"STR-01","defect_key":"LICENSE:missing-license","severity":"high","summary":"Missing LICENSE","evidence":"(no file)"},
  {"app_id":"root","rule":"STR-03","defect_key":"form.yml:yaml-parse-error","severity":"high","summary":"Broken YAML","evidence":"form.yml:3"},
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

# --- Test 4: indicator derivation ---
echo ""
echo "Test 4: indicator derivation"
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
check "schema_version bumped to 1.1" "1.1" "$SCHEMA"

SEC_A=$(echo "$ART4" | jget "d['apps'][0]['indicators']['security']['level']")
check "app-a security level (Medium finding)" "needs_attention" "$SEC_A"

SEC_A_SUM=$(echo "$ART4" | jget "d['apps'][0]['indicators']['security']['summary']")
check "app-a security summary mechanical" "1 Medium, 1 Low" "$SEC_A_SUM"

SEC_B=$(echo "$ART4" | jget "d['apps'][1]['indicators']['security']['level']")
check "app-b security level (no OODT findings)" "solid" "$SEC_B"

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

ANCHOR=$(echo "$ART4" | jget "d['apps'][0]['indicators']['security']['anchor']")
check "security anchor fragment" "#security" "$ANCHOR"

MAINT_ANCHOR=$(echo "$ART4" | jget "d['repo_level']['indicators']['maintenance']['anchor']")
check "maintenance anchor fragment" "#maintenance-signals" "$MAINT_ANCHOR"

# The report has no "Quality" heading any more: docs and portability each have
# their own section, so each indicator links to its own.
DOCS_ANCHOR_A=$(echo "$ART4" | jget "d['apps'][0]['indicators']['documentation']['anchor']")
check "app-a documentation anchor" "#documentation" "$DOCS_ANCHOR_A"

PORT_ANCHOR_A=$(echo "$ART4" | jget "d['apps'][0]['indicators']['portability']['anchor']")
check "app-a portability anchor" "#portability" "$PORT_ANCHOR_A"

# Monorepo: every app repeats the same headings, and pandoc de-duplicates the
# second occurrence as "-1". App index 1 must not link into app 0's section.
SEC_ANCHOR_B=$(echo "$ART4" | jget "d['apps'][1]['indicators']['security']['anchor']")
check "app-b security anchor (2nd app)" "#security-1" "$SEC_ANCHOR_B"

PORT_ANCHOR_B=$(echo "$ART4" | jget "d['apps'][1]['indicators']['portability']['anchor']")
check "app-b portability anchor (2nd app)" "#portability-1" "$PORT_ANCHOR_B"

DOCS_ANCHOR_B=$(echo "$ART4" | jget "d['apps'][1]['indicators']['documentation']['anchor']")
check "app-b documentation anchor (2nd app)" "#documentation-1" "$DOCS_ANCHOR_B"

# --- Test 5: no assessments -> no indicators (backward compatible) ---
echo ""
echo "Test 5: no assessments -> indicators omitted"
ART5=$(python3 "$ASSEMBLE" --meta "$TMP/meta.json" --findings "$TMP/findings.json" --md "r.md" --plugin-version "0.3.0" 2> "$TMP/warn5.txt")
HAS_IND=$(echo "$ART5" | jget "'indicators' in d['apps'][0] or 'indicators' in d['repo_level']")
check "no indicators without assessments" "False" "$HAS_IND"
grep -q "assessments" "$TMP/warn5.txt" && WARNED=yes || WARNED=no
check "stderr warns about missing assessments" "yes" "$WARNED"

# --- Test 6: cross-check warnings + waiver ---
echo ""
echo "Test 6: cross-check warnings and brand-new waiver"
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

# --- Test 7: security severity boundaries ---
echo ""
echo "Test 7: security severity boundaries"
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

SEC_CRIT=$(echo "$ART7" | jget "d['apps'][0]['indicators']['security']['level']")
check "Critical finding -> needs_attention" "needs_attention" "$SEC_CRIT"

SEC_CRIT_SUM=$(echo "$ART7" | jget "d['apps'][0]['indicators']['security']['summary']")
check "Critical counted in summary" "1 Critical" "$SEC_CRIT_SUM"

SEC_INFO=$(echo "$ART7" | jget "d['apps'][1]['indicators']['security']['level']")
check "Info-only finding -> some_notes" "some_notes" "$SEC_INFO"

# A high-severity STRUCTURE finding is not a security finding: the security
# level keys on the OODT- rule prefix, not on severity alone.
SEC_STR=$(echo "$ART7" | jget "d['apps'][2]['indicators']['security']['level']")
check "High STR finding leaves security solid" "solid" "$SEC_STR"

# --- Test 8: upkeep boundaries ---
echo ""
echo "Test 8: upkeep boundaries"
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
NO_SIGNALS='{"releases": false, "changelog": false, "ci": false, "multiple_contributors": false, "issues_responded": false}'
MNT01='[{"app_id":"root","rule":"MNT-01","defect_key":"(repo):stale-repo","aspect":"maintenance","severity":"medium","result":"FAIL","summary":"Last commit 14 months ago","evidence":"(git log)"}]'

check "active + 1 signal -> some_notes" "some_notes" "$(maint_level true false "$ONE_SIGNAL_NO_ISSUES" '[]')"
check "null issues_responded counts as a signal -> solid" "solid" "$(maint_level true false "$ONE_SIGNAL_NULL_ISSUES" '[]')"
check "inactive, no waiver -> needs_attention" "needs_attention" "$(maint_level false false "$NO_SIGNALS" '[]')"

check "MNT-01 wins over brand-new waiver" "needs_attention" "$(maint_level false true "$NO_SIGNALS" "$MNT01")"
grep -qi "waiver" "$TMP/warn8.txt" && CONFLICT=yes || CONFLICT=no
check "MNT-01 + waiver contradiction warns on stderr" "yes" "$CONFLICT"

# --- Test 9: report-vs-artifact signal cross-check ---
echo ""
echo "Test 9: reported signals cross-check"
# The report states Low/Medium/High (LLM-derived); the artifact level is computed.
# with_reported <out> <app-a security> <maintenance> adds the report's stated
# levels to the Test 4 fixture. Everything except the two arguments agrees with
# the computed levels (Low=solid, Medium=some_notes, High=needs_attention).
with_reported() {
  python3 -c '
import json, sys
m = json.load(open(sys.argv[1]))
m["apps"][0]["reported_signals"] = {"security": sys.argv[3], "portability": "Low", "documentation": "Medium"}
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
grep "app-a" "$TMP/warn9b.txt" | grep -qi "security" && SECWARN=yes || SECWARN=no
check "report says Low, computed needs_attention: warns for app-a security" "yes" "$SECWARN"
grep -qi "portability\|documentation\|app-b" "$TMP/warn9b.txt" && OVERWARN=yes || OVERWARN=no
check "only the disagreeing axis warns" "no" "$OVERWARN"

with_reported "$TMP/meta-mnt.json" "High" "High"
python3 "$ASSEMBLE" --meta "$TMP/meta-mnt.json" --findings "$TMP/findings-ind.json" --md "r.md" --plugin-version "0.3.0" > /dev/null 2> "$TMP/warn9c.txt"
grep -qi "maintenance" "$TMP/warn9c.txt" && MNTWARN=yes || MNTWARN=no
check "report says High, computed solid: warns for maintenance" "yes" "$MNTWARN"

# --- Test 10: grades are LLM-written strings ---
echo ""
echo "Test 10: grade normalization and unknown grades"
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

# --- Test 11: no finding is lost ---
echo ""
echo "Test 11: findings whose app_id matches no app"
# In a monorepo the apps are subpaths, so a repo-wide structure finding carries
# app_id "root" and matches none of them. It belongs at repo level; it must not
# vanish between findings.json and the artifact.
cat > "$TMP/findings-orphan.json" << 'EOF'
[
  {"app_id":"app-a","rule":"OODT-08","defect_key":"Gemfile.lock:known-cve","aspect":"security","severity":"low","result":"WARN","summary":"Old excon","evidence":"Gemfile.lock:9"},
  {"app_id":"root","rule":"STR-04","defect_key":"app-templates/:other:missing-shared-path-dir","aspect":"structure","severity":"medium","result":"FAIL","summary":"shared_paths entry does not exist","evidence":"appverse.yml:43"},
  {"app_id":"apps/typo","rule":"QUA-03","defect_key":"template/run.sh.erb:no-set-e","aspect":"quality","severity":"low","result":"WARN","summary":"No error handling","evidence":"template/run.sh.erb:1"},
  {"app_id":"root","rule":"MNT-03","defect_key":"CHANGELOG:no-changelog","aspect":"maintenance","severity":"info","result":"WARN","summary":"No CHANGELOG","evidence":"(no file)"}
]
EOF
ART11=$(python3 "$ASSEMBLE" --meta "$TMP/meta-ind.json" --findings "$TMP/findings-orphan.json" --md "r.md" --plugin-version "0.3.0" 2> "$TMP/warn11.txt")

TOTAL_OUT=$(echo "$ART11" | jget "len(d['repo_level']['findings']) + sum(len(a['findings']) for a in d['apps'])")
check "4 findings in, 4 findings out" "4" "$TOTAL_OUT"

ORPHAN_RULES=$(echo "$ART11" | jget "sorted(f['rule'] for f in d['repo_level']['findings'])")
check "unmatched findings land at repo level" "['MNT-03', 'QUA-03', 'STR-04']" "$ORPHAN_RULES"

APP_A_RULES=$(echo "$ART11" | jget "[f['rule'] for f in d['apps'][0]['findings']]")
check "matched finding stays with its app" "['OODT-08']" "$APP_A_RULES"

grep -q "apps/typo" "$TMP/warn11.txt" && ORPHANWARN=yes || ORPHANWARN=no
check "unmatched app_id named on stderr" "yes" "$ORPHANWARN"
# "root" in a monorepo is the normal home of a repo-wide finding, not a mistake;
# warning on it would fire on every monorepo and teach people to ignore stderr.
grep -q "'root'" "$TMP/warn11.txt" && ROOTWARN=yes || ROOTWARN=no
check "repo-wide 'root' findings do not warn" "no" "$ROOTWARN"

# --- Test 12: report paths are filenames ---
echo ""
echo "Test 12: report paths"
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

echo ""
echo "Done: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
