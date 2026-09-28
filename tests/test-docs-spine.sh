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
for dim in Security Portability Documentation Upkeep; do
  has "$RUBRIC" "**$dim signal:**" "$dim derivation line"
done

echo "Test 7: enumerated named checks"
has "$RUBRIC" "check: icon-matches-target-os" "icon check"
has "$RUBRIC" "check: numeric-field-bounds"   "bounds check"
has "$RUBRIC" "check: hardcoded-site-paths"   "site-path check"

echo "Test 8: no referrer still points at the old file or slug"
stale=$(git grep -n -F -e "security-rubric.md" -e "appverse-security-rubric" \
  -- . ':!docs' ':!reviews' ':!tests' ':!references/review-rubric.md' || true)
[ -z "$stale" ] && ok "no stale references" || { bad "no stale references"; echo "$stale"; }

echo
echo "Done: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
