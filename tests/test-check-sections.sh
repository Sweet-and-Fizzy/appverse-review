#!/usr/bin/env bash
# Test check-sections.py: required sections exist, decisions are stated, and the report agrees with meta.json.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHK="$SCRIPT_DIR/references/check-sections.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { python3 "$CHK" "$@" > "$TMP/out" 2>&1; echo $?; }

# mono <file> <rec paragraph> <a decision line> <b decision line>
mono() { cat > "$1" <<EOR
# Appverse Review: x
## Repo-level gate criteria
| Rule | Result | Evidence |
## Upkeep
| Signal | Value | Assessment |
## App: A (apps/a)
### Signals
$3
<!-- Accept | Accept with suggestions | Request changes | Reject -->
## App: B (apps/b)
### Signals
$4
## Review scope
**Examined:** all
## Catalog checks
x
## Overall recommendation
$2
## Draft feedback — edit before sending
y
EOR
}
meta() { python3 -c "import json,sys; a=sys.argv[3:]; json.dump({'recommendation':{'decision':sys.argv[2],'note':'x'},'apps':[{'app_id':x.split(':')[0],'decision':x.split(':')[1]} for x in a]},open(sys.argv[1],'w'))" "$@"; }

echo "Test 1: a complete monorepo report that agrees with its meta.json passes"
mono "$TMP/r1.md" "**Request changes.** The token blocks both apps." "**Per-app decision:** Request changes" "**Per-app decision:** Request changes"
meta "$TMP/m1.json" "Request changes" "apps/a:Request changes" "apps/b:request_changes"
check "exit 0" 0 "$(run "$TMP/r1.md" "$TMP/m1.json")"
check "summary" "sections: complete" "$(tail -1 "$TMP/out")"

echo "Test 2: missing sections are named"
grep -v -e '^## Upkeep' -e '^## Review scope' "$TMP/r1.md" > "$TMP/r2.md"
check "exit 1" 1 "$(run "$TMP/r2.md")"
check "both named" 2 "$(grep -c '^MISSING section: ## \(Upkeep\|Review scope\)$' "$TMP/out")"

echo "Test 3: a monorepo app with no Per-app decision line fails"
mono "$TMP/r3.md" "**Request changes.**" "**Per-app decision:** Request changes" "No decision here."
check "exit 1" 1 "$(run "$TMP/r3.md")"
check "names the app" 1 "$(grep -c '^MISSING decision: ## App: B (apps/b) has no Per-app decision line' "$TMP/out")"

echo "Test 4: the template comment's decision words do not count as a decision"
mono "$TMP/r4.md" "<!-- Accept -->" "**Per-app decision:** Accept" "**Per-app decision:** Accept"
check "exit 1" 1 "$(run "$TMP/r4.md")"
check "recommendation has no decision" 1 "$(grep -c '^MISSING decision: ## Overall recommendation does not state' "$TMP/out")"

echo "Test 5: prose that names a milder outcome in passing reads the stated decision"
mono "$TMP/r5.md" "Both apps fail gates. Ratings move it to Accept with suggestions once fixed. The recommended decision is Request changes." "**Per-app decision:** Request changes" "**Per-app decision:** Request changes"
check "exit 0 against Request changes" 0 "$(run "$TMP/r5.md" "$TMP/m1.json")"
mono "$TMP/r5b.md" "Ratings move it to Accept with suggestions once fixed, or Request changes now." "**Per-app decision:** Request changes" "**Per-app decision:** Request changes"
check "two decisions, none stated: exit 1" 1 "$(run "$TMP/r5b.md")"

echo "Test 6: report and meta.json disagreeing is a MISMATCH"
meta "$TMP/m6.json" "Accept with suggestions" "apps/a:Request changes" "apps/b:Accept"
check "exit 1" 1 "$(run "$TMP/r1.md" "$TMP/m6.json")"
check "recommendation mismatch" 1 "$(grep -c '^MISMATCH decision recommendation: the report says Request changes, meta.json says Accept with suggestions$' "$TMP/out")"
check "app mismatch names its line" 1 "$(grep -c '^MISMATCH decision apps/b: its Per-app decision line says Request changes, meta.json says Accept$' "$TMP/out")"

echo "Test 7: a single-app repo needs no Per-app line; its app decision must match the recommendation"
grep -v -e '^## App: B' -e 'Per-app' "$TMP/r1.md" > "$TMP/r7.md"
meta "$TMP/m7.json" "Request changes" "root:Accept"
check "exit 1" 1 "$(run "$TMP/r7.md" "$TMP/m7.json")"
check "names the recommendation as the app's decision" 1 "$(grep -c '^MISMATCH decision root: the Overall recommendation says Request changes, meta.json says Accept$' "$TMP/out")"
check "no Per-app MISSING" 0 "$(grep -c 'Per-app' "$TMP/out")"

echo "Test 8: real phrasings read correctly: a plain opening decision, Title-Case Per-App lines, a heading with more words, a hyphen"
mono "$TMP/r8.md" "Request changes. Any later Accept depends on the duplicate check; no reject trigger applies." "**Per-App Decision:** Request-changes" "Per-app decision — **Request changes**"
python3 -c "import sys; p=sys.argv[1]; t=open(p).read().replace('## Overall recommendation\n','## Overall recommendation (pending the duplicate check)\n'); open(p,'w').write(t)" "$TMP/r8.md"
check "exit 0" 0 "$(run "$TMP/r8.md" "$TMP/m1.json")"
check "summary" "sections: complete" "$(tail -1 "$TMP/out")"

echo "Test 9: a heading id with a trailing slash still matches its app in meta.json"
python3 - "$TMP/r1.md" "$TMP/r9.md" <<'PYR'
import sys
t = open(sys.argv[1]).read().replace("(apps/b)", "(apps/b/)")
head, tail = t.split("## App: B", 1)
open(sys.argv[2], "w").write(head + "## App: B" + tail.replace("Per-app decision:** Request changes", "Per-app decision:** Accept", 1))
PYR
check "exit 1" 1 "$(run "$TMP/r9.md" "$TMP/m1.json")"
check "the mismatch is found" 1 "$(grep -c '^MISMATCH decision apps/b: its Per-app decision line says Accept, meta.json says Request changes$' "$TMP/out")"

echo "Test 10: unreadable input is exit 2"
check "no report" 2 "$(run "$TMP/nope.md")"
printf 'x' > "$TMP/bad.json"; check "bad meta" 2 "$(run "$TMP/r1.md" "$TMP/bad.json")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
