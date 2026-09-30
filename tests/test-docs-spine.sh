#!/usr/bin/env bash
# Structural test for the Reviewer Process + Review Rubric split (Plan B).
# Asserts the two reference docs have the spine headings, that the old
# Required/Quality bucketing is gone, that the security content moved intact,
# and that no file in the repo still points at security-rubric.md.
set -u
cd "$(dirname "$0")/.."

pass=0; fail=0
ok()   { echo "  PASS  $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail+1)); }
has()  { grep -q -F -- "$2" "$1" && ok "$3" || bad "$3"; }
lacks(){ grep -q -F -- "$2" "$1" && bad "$3" || ok "$3"; }

RUBRIC=references/review-rubric.md
PROCESS=references/review-checklist.md

echo "Test 1: files"
[ -f "$RUBRIC" ] && ok "rubric exists" || bad "rubric exists"
[ -f "$PROCESS" ] && ok "process doc exists" || bad "process doc exists"
[ -f references/security-rubric.md ] && bad "security-rubric.md removed" || ok "security-rubric.md removed"

echo "Test 2: rubric spine headings (in order)"
expected_rubric="# Appverse Review Rubric
## How to read this rubric
## Repo shapes
## Structure (gate criteria)
## Security
## Portability
## Documentation
## Code Quality
## Upkeep
## Decision rubric
## Appendix: common issues in real apps"
headings() { awk '/^```/{f=!f; next} !f' "$1" | grep -E '^#{1,2} '; }   # skip fenced code blocks
actual_rubric=$(headings "$RUBRIC")
[ "$actual_rubric" = "$expected_rubric" ] && ok "H1/H2 sequence" || { bad "H1/H2 sequence"; diff <(echo "$expected_rubric") <(echo "$actual_rubric"); }

echo "Test 3: process doc headings (in order)"
expected_process="# Appverse Reviewer Process
## Before you start
## Step 1: Gate the app
## Step 2: Open the review report
## Step 3: Verify the findings
## Step 4: Curate the feedback
## Step 5: Decide
## Appendix: Review template"
actual_process=$(headings "$PROCESS")
[ "$actual_process" = "$expected_process" ] && ok "H1/H2 sequence" || { bad "H1/H2 sequence"; diff <(echo "$expected_process") <(echo "$actual_process"); }

echo "Test 4: the two-bucket scheme is gone"
lacks "$RUBRIC"  "## Required Criteria" "rubric has no Required Criteria heading"
lacks "$RUBRIC"  "## Quality Criteria"  "rubric has no Quality Criteria heading"
lacks "$PROCESS" "## Required Criteria" "process has no Required Criteria heading"
lacks "$PROCESS" "## Quality Criteria"  "process has no Quality Criteria heading"

echo "Test 5: security content moved intact"
for code in OODT-01 OODT-02 OODT-03 OODT-04 OODT-05 OODT-06 OODT-07 OODT-08; do
  has "$RUBRIC" "| $code |" "rubric lists $code"
done
has "$RUBRIC" "### Capability baseline: Batch Connect apps" "batch-connect baseline present"
has "$RUBRIC" "### Capability baseline: Passenger apps"     "passenger baseline present"
has "$RUBRIC" "### Pattern checks (all app types)"           "pattern checks present"
has "$RUBRIC" "GHSA-2cwp-8g29-9q32"                          "advisory reference kept"

echo "Test 6: three legs and derivation present"
has "$RUBRIC" "Signals do not gate; the decision rubric does." "gate/signal separation stated"
has "$RUBRIC" "| **Accept with suggestions** |" "decision table present"
has "$RUBRIC" "Low = " "Low/High polarity stated"
for dim in Portability Documentation Upkeep; do
  has "$RUBRIC" "**$dim signal:**" "$dim derivation line"
done
lacks "$RUBRIC" "**Security signal:**" "no Security signal derivation"
lacks "$PROCESS" "Security: [Low" "process doc has no Security level"

echo "Test 7: enumerated named checks"
has "$RUBRIC" "check: icon-matches-target-os" "icon check"
has "$RUBRIC" "check: numeric-field-bounds"   "bounds check"
has "$RUBRIC" "check: hardcoded-site-paths"   "site-path check"

echo "Test 8: no referrer still points at the old file or slug"
stale=$(git grep -n -F -e "security-rubric.md" -e "appverse-security-rubric" \
  -- . ':!docs' ':!reviews' ':!tests' ':!references/review-rubric.md' || true)
[ -z "$stale" ] && ok "no stale references" || { bad "no stale references"; echo "$stale"; }

echo "Test 9: the checks manifest and the rubric agree (never skipped)"
MANIFEST=references/checks.json
manifest_ids=$(python3 -c 'import json,sys; [print(c["id"]) for c in json.load(open(sys.argv[1]))["checks"]]' "$MANIFEST" 2>/dev/null)
[ -n "$manifest_ids" ] && ok "checks.json loads" || bad "checks.json loads"
yml_ids=$(sed -n 's/^  - id: *//p' references/checks.yml)
[ "$yml_ids" = "$manifest_ids" ] && ok "checks.yml and checks.json list the same ids in order" \
  || { bad "checks.yml and checks.json list the same ids in order"; diff <(echo "$yml_ids") <(echo "$manifest_ids"); }
unknown=""
for id in $(grep -oE '`check: [A-Za-z0-9_.-]+`' "$RUBRIC" | sed 's/`check: //; s/`$//' | sort -u); do
  echo "$manifest_ids" | grep -qxF -- "$id" || unknown="$unknown $id"
done
[ -z "$unknown" ] && ok "every rubric check: id is a manifest id" || bad "every rubric check: id is a manifest id (unknown:$unknown)"
cq_section=$(awk '/^## Code Quality$/{f=1; next} /^## /{f=0} f' "$RUBRIC")
cq_ids=$(python3 -c 'import json,sys; [print(c["id"]) for c in json.load(open(sys.argv[1]))["checks"] if c["dimension"] == "code_quality"]' "$MANIFEST" 2>/dev/null)
[ -n "$cq_ids" ] && ok "manifest has code_quality checks" || bad "manifest has code_quality checks"
for id in $cq_ids; do
  echo "$cq_section" | grep -qF -- "\`check: $id\`" && ok "Code Quality names check: $id" || bad "Code Quality names check: $id"
done

cq_rows=$(echo "$cq_section" | awk '/^\| *Check *\| *Target *\|/{f=1; next} f && /^\|/{print; next} f{exit}' | grep -vE '^\|[-: |]+\|$')
[ -n "$cq_rows" ] && ok "Code Quality table found" || bad "Code Quality table found"
unmarked=$(echo "$cq_rows" | grep -vE '`check: [A-Za-z0-9_.-]+`' || true)
[ -z "$unmarked" ] && ok "every Code Quality table row carries a check: marker" \
  || { bad "every Code Quality table row carries a check: marker"; echo "$unmarked"; }

echo "Test 9b: every manifest entry has a tag field (a tag or null), each non-null tag and every tags entry is in finding-codes.md under its rule, and every suggestion check has tags"
TAGS_OUT=$(mktemp)
python3 - "$MANIFEST" references/finding-codes.md > "$TAGS_OUT" 2>&1 <<'PY'
import json, re, sys
checks = json.load(open(sys.argv[1]))["checks"]
vocab, rule = {}, None
for line in open(sys.argv[2], encoding="utf-8"):
    m = re.match(r"\*\*([A-Z]+-\d+):\*\*\s*$", line.strip())
    if m:
        rule = m.group(1)
        continue
    if line.startswith("#") or line.strip() == "---":
        rule = None
    if rule:
        vocab.setdefault(rule, set()).update(re.findall(r"`([^`]+)`", line))
for c in checks:
    if "tag" not in c:
        print("no tag field: " + c["id"])
    elif c["tag"] is not None and c["tag"] not in vocab.get(c["rule"], ()):
        print("tag {} not under {} in finding-codes.md: {}".format(c["tag"], c["rule"], c["id"]))
    # a tag with a qualifier is written `base:{name}` in finding-codes.md
    bases = {t.split(":", 1)[0] for t in vocab.get(c.get("rule"), ())}
    for t in c.get("tags") or []:
        if t not in bases:
            print("tags entry {} not under {} in finding-codes.md: {}".format(t, c["rule"], c["id"]))
    if c.get("weight") == "suggestion" and not c.get("tags"):
        print("suggestion check has no tags list: " + c["id"])
PY
tag_problems=$(cat "$TAGS_OUT"); rm -f "$TAGS_OUT"
[ -z "$tag_problems" ] && ok "manifest tags are present and in the vocabulary" \
  || { bad "manifest tags are present and in the vocabulary"; echo "$tag_problems"; }

echo "Test 10: checks.json is generated from checks.yml"
python3 references/checks-sync.py --verify > /dev/null 2>&1; rc=$?
case $rc in
  0) ok "checks-sync.py --verify" ;;
  3) echo "  SKIP  checks-sync.py --verify (PyYAML not installed)" ;;
  *) bad "checks-sync.py --verify (exit $rc; run python3 references/checks-sync.py)" ;;
esac
# The verify path itself, with a stub yaml module that returns checks.json's
# data (in sync) or that data minus its last check (out of sync).
STUB=$(mktemp -d); trap 'rm -rf "$STUB"' EXIT
cat > "$STUB/yaml.py" <<'PY'
import json, os
class YAMLError(Exception):
    pass
def safe_load(f):
    data = json.load(open(os.environ["STUB_JSON"]))
    if os.environ.get("STUB_DRIFT"):
        data["checks"].pop()
    return data
PY
STUB_JSON="$MANIFEST" PYTHONPATH="$STUB" python3 references/checks-sync.py --verify > /dev/null 2>&1
[ $? -eq 0 ] && ok "verify passes when the YAML data matches checks.json" || bad "verify passes when the YAML data matches checks.json"
STUB_JSON="$MANIFEST" STUB_DRIFT=1 PYTHONPATH="$STUB" python3 references/checks-sync.py --verify > /dev/null 2>&1
[ $? -eq 1 ] && ok "verify fails (exit 1) when they differ" || bad "verify fails (exit 1) when they differ"

echo "Test 11: fix-wave sentences present and consistent (drift-catchers)"
SEC_SKILL=skills/review-security/SKILL.md
QUA_SKILL=skills/review-quality/SKILL.md
APP_SKILL=skills/review-app/SKILL.md
MERGE_SENTENCE="result\` is the worst among them (FAIL > WARN > PASS) and its \`severity\`"
has "$SEC_SKILL" "$MERGE_SENTENCE" "review-security states the record merge rule"
has "$QUA_SKILL" "$MERGE_SENTENCE" "review-quality states the record merge rule"
has "$QUA_SKILL" "anchors on the submit file (\`submit.yml.erb\`" "erb-missing-value anchors on submit.yml.erb"
has "$QUA_SKILL" "tags anchor on \`form.yml\`" "numeric-field-bounds/QUA-07 tags anchor on form.yml"
APP_ID_SENTENCE="\"root\" for a single-app repo, the normalised"
has "$APP_SKILL" "$APP_ID_SENTENCE" "review-app states apps.json app_id = finding app_id"
has "$QUA_SKILL" "$APP_ID_SENTENCE" "review-quality states apps.json app_id = finding app_id"
has references/security-tools.md "$APP_ID_SENTENCE" "security-tools.md ties app_id to apps.json"
has references/target-setup.md "Same value as \`apps.json\`'s \`app_id\`" "target-setup.md ties app_id to apps.json"
has .github/workflows/appverse-review.yaml "references/check-all.py \${{ github.workspace }}/review-\${{ steps.params.outputs.repo_slug }}.md \${{ github.workspace }}/review-\${{ steps.params.outputs.repo_slug }}.findings.json \${{ github.workspace }}/appverse-review/references/checks.json \${{ github.workspace }}/pre-review --target" "workflow prompt gives check-all.py a resolvable plugin path, report path and findings path"
has skills/review-app/SKILL.md "check-all.py" "review-app SKILL.md wrap-up step names check-all.py"
has .github/workflows/appverse-review.yaml "references/checks.json" "workflow prompt names checks.json"
has .github/workflows/appverse-review.yaml "INVALID/MISSING/MISMATCH/UNCITED/BAD" "verify step lists UNCITED and BAD"
lacks "$SEC_SKILL" "tag may be null" "security skill has no stale tag-may-be-null text"
lacks "$SEC_SKILL" "config_flag\` candidate with no tag" "security skill has no config_flag no-tag fallback"
has "$SEC_SKILL" "presence_checked: true\` is not a guard" "security skill states presence_checked is not a guard"
has references/finding-codes.md "entry-point-parse-error" "finding-codes.md lists entry-point-parse-error under STR-07"
has skills/review-structure/SKILL.md ":entry-point-parse-error\` (STR-07" "structure skill files entry-point-parse-error under STR-07"
lacks "$QUA_SKILL" "expected to fail" "review-quality has no stale check-rating expected-to-fail wording"

has skills/review-maintenance/SKILL.md "Records under MNT-02 to MNT-06 are WARN at most" "maintenance skill states check-rating rejects a good-practice FAIL"

echo "Test 11c: the security-claim sentence bullet follows the rows, in both docs"
has "$SEC_SKILL" "no row in either table is FAIL or WARN" "review-security states the sentence follows the rows"
has "$SEC_SKILL" "write it when any row is FAIL or WARN" "review-security states the never-write-it-with-a-row rule"
has "$RUBRIC" "no row in either table is FAIL or WARN" "rubric states the sentence follows the rows"

echo "Test 11d: the Documentation strings check-rating and check-evidence match are the ones the docs write"
# checker <file> <python expression over the module's globals>: read a constant from a checker, not restate it
checker() { python3 -c 'import importlib.util,sys; s=importlib.util.spec_from_file_location("m",sys.argv[1]); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(eval(sys.argv[2], vars(m)))' "$1" "$2" 2>&1; }
STUB_LINE=$(checker references/check-rating.py 'STUB_LINE if STUB_RATING.search("Rating: **" + STUB_LINE) else "STUB_RATING does not match STUB_LINE"')
has "$QUA_SKILL" "$STUB_LINE" "review-quality writes check-rating's stub line"
has "$RUBRIC" "$STUB_LINE" "rubric writes check-rating's stub line"
BELOW=$(checker references/check-rating.py 'BELOW_MINIMAL if RATING_RE.search("Rating: **" + BELOW_MINIMAL) else "RATING_RE does not match BELOW_MINIMAL"')
has "$QUA_SKILL" "\`$BELOW\`" "review-quality writes check-rating's Below minimal rating word"
has "$RUBRIC" "| **$BELOW** |" "rubric's Documentation level table has check-rating's Below minimal row"
CONTENT_FORM=$(grep -o '`content: README.md:N`' "$QUA_SKILL" | head -1 | tr -d '`')
[ "$(checker references/check-evidence.py "content_citations('$CONTENT_FORM'.replace('N', '7'))")" = "[('README.md', [7], 'README.md:7')]" ] \
  && ok "review-quality's content: citation form is the one check-evidence parses" || bad "review-quality's content: citation form is the one check-evidence parses"
has "$RUBRIC" "\`$CONTENT_FORM\`" "rubric writes the same content: citation form"

echo "Test 11e: search other headings' content before rating a rung none"
has "$QUA_SKILL" "read the README for a line that delivers the rung under" "review-quality states the search-before-none rule"
has "$RUBRIC" "other headings' content (configuration met by a line under Environment" "rubric states the search-before-none rule"
has skills/review-structure/SKILL.md "readme-not-substantive" "review-structure records STR-01 readme-not-substantive, the record check-rating falls back to"
STUB_N=$(checker references/pre-review.py 'STUB_CONTENT_CHARS')
has "$RUBRIC" "fewer than $STUB_N characters of content" "rubric states pre-review's stub threshold"
has skills/review-structure/SKILL.md "fewer than $STUB_N characters of content" "review-structure states pre-review's stub threshold"

echo "Test 12: every code_quality check's manifest weight matches its rubric row"
WEIGHTS_OUT=$(mktemp)
python3 - "$MANIFEST" > "$WEIGHTS_OUT" 2>&1 <<'PY'
import json, sys
checks = json.load(open(sys.argv[1]))["checks"]
for c in checks:
    if c["dimension"] == "code_quality":
        print(c["id"], c.get("weight", ""))
PY
while read -r id weight; do
  [ -n "$id" ] || continue
  case "$weight" in
    target)
      has "$RUBRIC" "\`check: $id\`) | Target for inclusion |" "$id row: Target for inclusion" ;;
    suggestion)
      has "$RUBRIC" "\`check: $id\`) | Suggestion |" "$id row: Suggestion" ;;
    *) bad "$id has a recognised manifest weight (got '$weight')" ;;
  esac
done < "$WEIGHTS_OUT"
rm -f "$WEIGHTS_OUT"

echo "Test 13: checker-emitted strings and scanner constants the docs write"
CLAIM=$(checker references/check-rating.py 'SECURITY_CLAIM_SENTENCE')
has "$SEC_SKILL" "\"$CLAIM\"" "review-security writes check-rating's security sentence"
has "$APP_SKILL" "\"$CLAIM\"" "review-app writes check-rating's security sentence"
has "$RUBRIC" "\"${CLAIM%.}\"" "rubric writes check-rating's security sentence"
VERDICT=$(checker references/check-evidence.py 'VALUE_VERDICT')
has "$APP_SKILL" "\`$VERDICT\` line" "review-app names check-evidence's cited-value verdict"
has references/review-checklist.md "\`$VERDICT\`" "reviewer checklist names check-evidence's cited-value verdict"
TOOLS=references/security-tools.md
for code in $(checker references/pre-review.py '" ".join(ARTIFACT_CODES)'); do
  grep -qE "^\| $code \|.*\| (in|on) [^|]*\|\$" "$TOOLS" && ok "security-tools code table marks $code as an artefact" \
    || bad "security-tools code table marks $code as an artefact"
done
for var in $(checker references/pre-review.py '" ".join(OOD_CONTRACT_VARS)'); do
  grep -E "^\| SC2154 \|" "$TOOLS" | grep -qF "\`$var\`" && ok "SC2154 row names contract variable $var" \
    || bad "SC2154 row names contract variable $var"
done
no_codes=$(grep -E '^\| (SC|B)[0-9]+ \|.*\| no \|$' "$TOOLS" | sed 's/^| \([A-Z0-9]*\) .*/\1/')
arte=" $(checker references/pre-review.py '" ".join(ARTIFACT_CODES)') "
stray=""
for code in $no_codes; do case "$arte" in *" $code "*) stray="$stray $code";; esac; done
[ -z "$stray" ] && ok "no code the table calls not-an-artefact is in ARTIFACT_CODES" || bad "no code the table calls not-an-artefact is in ARTIFACT_CODES (got:$stray)"

echo
echo "Done: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
