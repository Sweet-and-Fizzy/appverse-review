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
## What a review is, and what we ask of you
## Before you start
## Step 1: Gate the app
## Step 2: Read the review page
## Step 3: Check the findings
## Step 4: Curate the feedback
## Step 5: Decide and send
## After the decision
## Who sees what, and when
## Appendix: Reading the catalog by hand"
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
has "$RUBRIC" "Portable, Complete or Well" "good end of each axis named in its level words"
lacks "$RUBRIC" "Low / Medium / High" "rubric has no Low / Medium / High scale"
lacks "$PROCESS" "Low / Medium / High" "process doc has no Low / Medium / High scale"
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
has .github/workflows/appverse-review.yaml "group: appverse-review-\${{ inputs.target_repo }}" "one review run at a time per target repo (#106)"
has .github/workflows/appverse-review.yaml "cancel-in-progress: false" "a second run for the same repo waits rather than cancelling the first"
has .github/workflows/appverse-review.yaml "INVALID/MISSING/MISMATCH/UNCITED/BAD" "verify step lists UNCITED and BAD"
lacks "$SEC_SKILL" "tag may be null" "security skill has no stale tag-may-be-null text"
lacks "$SEC_SKILL" "config_flag\` candidate with no tag" "security skill has no config_flag no-tag fallback"
has "$SEC_SKILL" "presence_checked: true\` is not a guard" "security skill states presence_checked is not a guard"
has references/finding-codes.md "entry-point-parse-error" "finding-codes.md lists entry-point-parse-error under STR-07"
has skills/review-structure/SKILL.md ":entry-point-parse-error\` (STR-07" "structure skill files entry-point-parse-error under STR-07"
lacks "$QUA_SKILL" "expected to fail" "review-quality has no stale check-rating expected-to-fail wording"
has "$QUA_SKILL" "\`set -e\` is not required" "review-quality does not require set -e (QUA-03)"
has "$QUA_SKILL" "missing \`max\` alone is not a finding" "review-quality does not require a hardcoded max (QUA-07)"
lacks "$QUA_SKILL" "without both \`min\` and \`max\`" "review-quality has no stale min-and-max candidate rule"

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
has skills/review-structure/SKILL.md "An inferred repo still has the rubric's inferred-repo check" "structure skill keeps the inferred repo's manifest.yml fields under STR-02 (metadata.json demands nothing of them)"
has skills/repair-review/SKILL.md "app has no STR-02 row left, add a STR-02 PASS row citing the file the line" "repair keeps a STR-02 row when a [metadata] MISMATCH removes the last FAIL"
has references/review-rubric.md "| \`name\` | Present" "rubric's declared-repo table lists name, which the catalog requires"
has skills/review-structure/SKILL.md "If \`<pre-review>/metadata.json\` is absent" "structure skill says what to do when the metadata fact is missing"
has skills/repair-review/SKILL.md "it comes from), the catalog knows the app type, or the field is not one" "repair handles the not-required [metadata] MISMATCH"
has .github/workflows/appverse-review.yaml 'model_id="${MODEL_ID_INPUT:-$MODEL}"' "an Anthropic run passes the tier alias (newest model) unless model_id pins one"
has .github/workflows/appverse-review.yaml 'default: "qwen"' "the on-prem gateway stays the default model"
has .github/workflows/appverse-review.yaml 'references/session-model.py" "$RUNNER_TEMP/sessions/review.json"' "the stamp step records the model the review session ran"
has skills/review-structure/SKILL.md "which is every name under" "structure skill: an attribute form.json marks as OOD's is never undefined (STR-04)"
has skills/review-quality/SKILL.md "bounds those itself, so they are never candidates" "quality skill never makes OOD's own attributes bounds candidates"
has skills/repair-review/SKILL.md "[metadata], [license], [form], [tools]," "repair prompt names [metadata] and [form] among the lines to fix"
has skills/repair-review/SKILL.md "A [form] MISMATCH line: the attribute is listed under form:, so" "repair handles a [form] MISMATCH"
has skills/review-structure/SKILL.md "\`<pre-review>/license.json\` lists the ones at the repo root, best first" "structure skill reads the license file from license.json"
has references/review-rubric.md "any name GitHub's license detection reads" "rubric accepts the license file names GitHub recognises"
has skills/repair-review/SKILL.md "[metadata], [license], [form], [tools]," "repair prompt names [metadata] and [license] among the lines to fix"
has skills/review-app/SKILL.md "\`check-license.py\`: a STR-01" "review-app section 6 describes check-license"
has skills/review-app/SKILL.md "\`check-form.py\`: no STR-04" "review-app section 6 describes check-form"
has skills/review-app/SKILL.md "\`check-tools.py\`: a FAIL or WARN record whose only evidence is a" "review-app section 6 describes check-tools"
has skills/repair-review/SKILL.md "A [tools] MISMATCH line: the record rests only on the static-tool" "repair handles a [tools] MISMATCH"
has references/security-tools.md "OODT categories a tool can surface, not where each of its findings goes" "security-tools: the code table, not the per-tool OODT mapping, decides a tool finding's rule"
has skills/review-security/SKILL.md "A shellcheck code the table does not list is never an OODT" "security skill files an unlisted shellcheck code under QUA"
has skills/review-security/SKILL.md "A tool row is the exception to the OODT classification: it takes" "security skill step 7 defers to the code table for tool rows"
has skills/repair-review/SKILL.md "another record, merge them into one record and one row." "repair merges records a [tools] re-key gives the same key"
has skills/repair-review/SKILL.md "A [license] MISMATCH line: the repo has the license files the" "repair handles a [license] MISMATCH"
has .github/workflows/appverse-review.yaml "Run the /appverse-review:repair-review skill" "the repair session runs the repair-review skill (#118)"
has .github/workflows/appverse-review.yaml '--model ${{ steps.params.outputs.repair_model_id }}' "the repair sessions run the repair model"
has .github/workflows/appverse-review.yaml 'repair_model_id="${REPAIR_MODEL_ID_INPUT:-$default_repair}"' "a dispatch can name the repair model"
has .github/workflows/appverse-review.yaml '"Read(./appverse-review/references/**/*.py)"' "the repair session cannot read the checker scripts"
has skills/repair-review/SKILL.md "Never read a skill or reference file whole." "the repair skill reads only the section a line needs"
has .github/workflows/appverse-review.yaml "read its file, \${{ github.workspace }}/appverse-review/skills/repair-review/SKILL.md," "the repair prompt names the skill file for a model that does not invoke the Skill tool"
has .github/workflows/appverse-review.yaml "run it once more, then stop whatever it says." "the repair prompt keeps its own stop rule"
has .github/workflows/appverse-review.yaml 'error|no_result) echo "::warning::the $SESSION session ended on an error' "the log step warns when a session ended on an error"
has .github/workflows/appverse-review.yaml "model_re='^[A-Za-z0-9][A-Za-z0-9._/:-]*\$'" "a model id cannot start with a dash"
has .github/workflows/appverse-review.yaml 'if [ "$model_id" = "$DEFAULT_GATEWAY_MODEL" ]; then default_repair="$DEFAULT_GATEWAY_REPAIR_MODEL"' "the default repair model follows the default review model, however it was named"
has skills/repair-review/SKILL.md "the catalog requires, or the repo is inferred and the field is one only" "repair handles the inferred-repo [metadata] MISMATCH"
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
      # manifest weight "target": a strong suggestion, worded as recommended
      # in the feedback; it never sets a decision
      has "$RUBRIC" "\`check: $id\`) | Strong suggestion |" "$id row: Strong suggestion" ;;
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
# The reviewer checklist no longer names checker internals; it tells the
# reviewer to read cited lines themselves. The skill's line above is the spine.
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

echo "Test 14: a 0.0.0.0 bind is judged by its authentication, not the bind"
has skills/review-security/SKILL.md "The finding is a service other users can reach without authentication." "security skill: unauthenticated service is the finding"
has references/finding-codes.md "the bind alone is not exposure" "finding-codes: bind-all-interfaces defined by authentication"
has references/security-tools.md "a finding only when the service has no authentication, else PASS" "security-tools: B104 judged by authentication"
has skills/review-security/SKILL.md "the line that generates it is not evidence" "security skill: a generated password counts only where the service consumes it"
has references/finding-codes.md "counts only when the service reads it" "finding-codes: a generated password counts only when the service reads it"
has skills/review-structure/SKILL.md "catalog's app_type vocabulary" "structure skill: app_type is a vocabulary term"
lacks skills/review-structure/SKILL.md "OOD needs the exact value" "structure skill no longer asks for the exact app_type value"

grep -q 'sets_floor' references/check-decisions.py && ok "check-decisions uses sets_floor" || bad "check-decisions uses sets_floor"

levels_problems=$(PYTHONPATH=references python3 -c '
import json
from feedback_terms import vocabulary_tags
vocab = vocabulary_tags("references/finding-codes.md")
levels = json.load(open("references/checks.json")).get("feedback_levels", {}).get("should_at_low")
if not levels:
    print("no feedback_levels.should_at_low in checks.json")
else:
    for rule, tags in levels.items():
        for t in tags:
            if t != "*" and t not in vocab.get(rule, []):
                print(rule, t)
' 2>&1)
[ -z "$levels_problems" ] && ok "feedback_levels tags are finding-codes tags" \
  || { bad "feedback_levels tags are finding-codes tags"; echo "$levels_problems"; }

echo "Test: the draft feedback is built by script"
WF=.github/workflows/appverse-review.yaml
sec6=$(awk '/^## 6\. /{on=1; next} on && /^## /{exit} on' skills/review-app/SKILL.md)
echo "$sec6" | grep -q 'prepare-feedback.py' && echo "$sec6" | grep -q 'render-feedback.py' \
  && ok "skill names prepare-feedback and render-feedback in §6" || bad "skill names prepare-feedback and render-feedback in §6"
tr '\n' ' ' < skills/review-app/SKILL.md | tr -s ' ' | grep -q "or any OODT FAIL" \
  && bad "skill no longer says any OODT FAIL is Required" || ok "skill no longer says any OODT FAIL is Required"
n=$(grep -c '"$WS/appverse-review/references/render-feedback.py"' "$WF")
[ "$n" -ge 3 ] && ok "workflow runs render-feedback in checks, recheck and recheck2" \
  || bad "workflow runs render-feedback in checks, recheck and recheck2 (found $n)"
unguarded=$(grep -E '"\$WS/appverse-review/references/(prepare|render)-feedback\.py"' "$WF" | grep -vE 'review_aspects.*\|\| echo')
[ -z "$unguarded" ] && [ "$n" -ge 3 ] && ok "workflow never lets prepare/render fail a step" \
  || { bad "workflow never lets prepare/render fail a step"; echo "$unguarded"; }
first_render=$(grep -n 'references/render-feedback.py' "$WF" | head -1 | cut -d: -f1)
first_check=$(grep -n 'references/check-all.py' "$WF" | head -1 | cut -d: -f1)
[ -n "$first_render" ] && [ "$first_render" -lt "$first_check" ] && ok "review prompt runs render before check-all" \
  || bad "review prompt runs render before check-all"
has "$WF" 'review-*.feedback.json' "workflow uploads feedback.json"

echo "Test: the review's turn limit comes from the app count"
WF=.github/workflows/appverse-review.yaml
has "$WF" '--max-turns ${{ steps.params.outputs.review_turns }}' "review max-turns comes from params"
stray=$(grep -n 'inputs.max_turns' "$WF" | grep -v 'MAX_TURNS_INPUT: ${{ inputs.max_turns }}')
[ -z "$stray" ] && grep -q 'MAX_TURNS_INPUT: ${{ inputs.max_turns }}' "$WF" && ok "max_turns input never in a run block" \
  || { bad "max_turns input never in a run block"; echo "$stray"; }
has "$WF" "turns_re='^[0-9]{1,3}\$'" "params checks review_turns before writing it"

echo "Test: the guarded fill steps"
WF=.github/workflows/appverse-review.yaml
step() { awk -v n="$1" 'index($0, "      - name: " n) == 1 {on=1; print; next} on && /^      - name: /{exit} on' "$WF"; }
fill=$(step "Fill draft feedback")
gate=$(step "Check draft feedback for empty sentences")
guard=$(step "Keep or roll back the filled draft")
echo "$fill" | grep -qF "if: \"!cancelled() && inputs.review_aspects == 'all' && steps.feedback_gate.outputs.needs_fill == 'true'\"" \
  && ok "fill step runs only on full reviews when the gate says so" || bad "fill step runs only on full reviews when the gate says so"
echo "$fill" | grep -q '"Bash(' && bad "fill step cannot run Bash" \
  || { echo "$fill" | grep -q '"Bash"' && ok "fill step cannot run Bash" || bad "fill step cannot run Bash"; }
scoped=$(echo "$fill" | grep -oE '"(Edit|Write)[^"]*"' | grep -v '\.feedback\.json)"$')
[ -z "$scoped" ] && [ "$(echo "$fill" | grep -cE '"(Edit|Write)\(')" -eq 2 ] && ok "fill step edits only feedback.json" \
  || { bad "fill step edits only feedback.json"; echo "$scoped"; }
for st in "$gate" "$fill" "$guard"; do echo "$st" | grep -q 'continue-on-error: true' || nofail=1; done
[ -z "${nofail:-}" ] && [ -n "$gate" ] && [ -n "$guard" ] && ok "new steps never fail the job" || bad "new steps never fail the job"
fl=$(grep -n '      - name: Fill draft feedback' "$WF" | cut -d: -f1); pl=$(grep -n '      - name: Generate PDF and HTML from review' "$WF" | cut -d: -f1)
[ -n "$fl" ] && [ "$fl" -lt "$pl" ] && ok "fill steps sit before the PDF step" || bad "fill steps sit before the PDF step"
printf '%s\n%s\n%s\n' "$gate" "$fill" "$guard" | grep -q needs_repair && bad "the fill steps never write needs_repair" || ok "the fill steps never write needs_repair"
echo "$fill" | grep -qF 'Never present as a strength anything' && ok "fill prompt quotes the skill's praise rule" || bad "fill prompt quotes the skill's praise rule"
grep -qF 'Never present as a strength anything' skills/review-app/SKILL.md && ok "the quoted praise rule is still in the skill" || bad "the quoted praise rule is still in the skill"
echo "$guard" | grep -q 'fill-guard.py" verify' && ok "guard step runs fill-guard verify" || bad "guard step runs fill-guard verify"

echo "Test: the guard checks its own inputs"
echo "$gate" | grep -q 'snapshot_digest=' && ok "gate emits the snapshot digest" || bad "gate emits the snapshot digest"
echo "$guard" | grep -qF 'steps.feedback_gate.outputs.snapshot_digest' && ok "guard compares the digest" || bad "guard compares the digest"
echo "$gate" | grep -qF 'plugin_status=$(python3 "$WS/appverse-review/references/fill-guard.py" plugin-status' && echo "$guard" | grep -qF '[ "$pstat" = error ]' \
  && ok "guard checks the plugin checkout is unchanged since the gate" || bad "guard checks the plugin checkout is unchanged since the gate"
verify_step=$(step "Verify review outputs")
echo "$verify_step" | grep -qF 'FILL_INTEGRITY: ${{ steps.fill_guard.outputs.integrity }}' && echo "$verify_step" | grep -q '"$FILL_INTEGRITY" = fail' \
  && ok "Verify fails a run whose guard inputs were tampered with" || bad "Verify fails a run whose guard inputs were tampered with"

echo "Test: sessions are bounded by turns and kept out of the plugin checkout"
for pair in "Run Appverse review:180" "Repair review outputs:60" "Repair review outputs (second round):60" "Fill draft feedback:20"; do
  name=${pair%:*}; mins=${pair##*:}
  step "$name" | grep -qx "        timeout-minutes: $mins" && ok "$name times out at $mins minutes" || bad "$name times out at $mins minutes"
done
names=$(grep -E '^      - name: ' "$WF" | sed 's/^      - name: //')
for pair in "Run Appverse review:Keep the review session's log" "Repair review outputs:Keep the repair session's log" \
    "Repair review outputs (second round):Keep the second repair session's log" "Fill draft feedback:Keep the fill session's log"; do
  s=${pair%%:*}; k=${pair#*:}
  [ "$(echo "$names" | grep -A1 -xF "$s" | tail -1)" = "$k" ] && step "$k" | grep -qE 'run: [&*]keep_session' \
    && ok "$s is followed by the restoring log step" || bad "$s is followed by the restoring log step"
done
ro=$(step "Make the plugin checkout read-only")
ro_line=$(echo "$names" | grep -nxF "Make the plugin checkout read-only" | cut -d: -f1)
rv_line=$(echo "$names" | grep -nxF "Run Appverse review" | cut -d: -f1)
echo "$ro" | grep -q 'chmod -R a-w' && [ -n "$ro_line" ] && [ "$ro_line" -lt "$rv_line" ] \
  && ok "the plugin checkout is read-only before the review session" || bad "the plugin checkout is read-only before the review session"
keep=$(step "Keep the review session's log")
echo "$keep" | grep -qF 'core.hooksPath=/dev/null reset -q --hard "${{ github.sha }}"' && echo "$keep" | grep -qF 'clean -fdxq' \
  && ok "the log step restores the plugin checkout without running its hooks" || bad "the log step restores the plugin checkout without running its hooks"
[ "$(echo "$keep" | grep -n 'chmod -R a-w' | cut -d: -f1)" -gt "$(echo "$keep" | grep -n 'clean -fdxq' | cut -d: -f1)" ] 2>/dev/null \
  && ok "the log step makes the checkout read-only again after restoring it" || bad "the log step makes the checkout read-only again after restoring it"
echo "$keep" | grep -q '::error::.*tracked' && ok "an edited plugin file is an error" || bad "an edited plugin file is an error"
echo "$keep" | grep -q 'references/session-status.py' && echo "$keep" | grep -q 'max_turns)' && ok "the log step warns when a session ran out of turns" || bad "the log step warns when a session ran out of turns"
echo "$keep" | grep -q 'context_overflow)' && ok "the log step warns when a session passed the model's context limit (#118)" || bad "the log step warns when a session passed the model's context limit (#118)"
st=$(echo "$keep" | grep -n 'session-status.py' | cut -d: -f1); rs=$(echo "$keep" | grep -n 'reset -q --hard' | cut -d: -f1)
[ -n "$st" ] && [ -n "$rs" ] && [ "$st" -gt "$rs" ] && ok "the log step reads the session status with the plugin's own script, after the reset" || bad "the log step reads the session status with the plugin's own script, after the reset"
echo "$guard" | grep -qF '"$RUNNER_TEMP/sessions/fill.plugin-changes.txt"' \
  && ok "the guard distrusts a fill that changed the plugin checkout" || bad "the guard distrusts a fill that changed the plugin checkout"

echo "Test: the review session does not run the checkers; the workflow and the repair session do"
review=$(step "Run Appverse review")
echo "$review" | grep -q 'python3 [^ ]*check-all\.py' && bad "the review prompt never runs check-all.py" || ok "the review prompt never runs check-all.py"
echo "$review" | grep -qF '"Bash(python3 *check-*.py*)"' && ok "the review session's permissions deny the checkers" || bad "the review session's permissions deny the checkers"
echo "$review" | grep -q 'the workflow does the finish step after this' && ok "the review prompt ends the session before the skill's finish step" || bad "the review prompt ends the session before the skill's finish step"
grep -q 'A CI review stops before this step' skills/review-app/SKILL.md && ok "the skill's finish step says a CI review stops before it" || bad "the skill's finish step says a CI review stops before it"
step "Repair review outputs" | grep -q 'check-all\.py' && ok "the repair prompt still runs check-all.py" || bad "the repair prompt still runs check-all.py"
step "Repair review outputs" | grep -qF 'check-*.py' && bad "the repair session may run the checkers" || ok "the repair session may run the checkers"

echo
echo "Done: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
