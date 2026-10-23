#!/usr/bin/env bash
# Test render-feedback.py: the Draft feedback section built from
# feedback.json, and that what it renders satisfies check-feedback-floor.py
# even when the model wrote no sentences.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REFS="$SCRIPT_DIR/references"
RENDER="$REFS/render-feedback.py"
PREP="$REFS/prepare-feedback.py"
FLOOR="$REFS/check-feedback-floor.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
render() { env -u GITHUB_ACTIONS python3 "$RENDER" "$TMP/r.md" "$TMP/fb.json" > "$TMP/out" 2>&1; echo $?; }
report() { printf '# Appverse Review: fasrc/ood-sas\n\n## Overall recommendation\n\nRequest changes.\n\n%s' "$1" > "$TMP/r.md"; }
section() { awk '/^## Draft feedback/{on=1} on && /^## / && !/^## Draft feedback/{exit} on' "$TMP/r.md"; }

cat > "$TMP/fb.json" <<'EOF'
{"app_name": "SAS", "opening": "Thank you for submitting SAS to Appverse. The README covers every rung.",
 "items": [
  {"group": "must:STR-02:missing-field", "level": "must", "locations": ["manifest.yml:1"], "defect_keys": ["manifest.yml:missing-field:software"], "summaries": ["manifest.yml lacks software"], "text": "Add the software field."},
  {"group": "should:QUA-03:no-error-check", "level": "should", "locations": ["template/script.sh.erb:17,22", "template/before.sh.erb:4"], "defect_keys": ["template/script.sh.erb:no-error-check", "template/before.sh.erb:no-error-check"], "summaries": ["a", "b"], "text": "Check the cd and mkdir."},
  {"group": "should:QUA-07:zero-minimum", "level": "should", "locations": ["form.yml:47"], "defect_keys": ["form.yml:zero-minimum"], "summaries": ["Cores allow zero."], "text": ""}
 ]}
EOF

echo "Test 1: section placement"
report '## Draft feedback — edit before sending

Old model-written draft.
'
check "exit 0" 0 "$(render)"
check "full heading body is replaced" "0" "$(grep -c 'Old model-written draft' "$TMP/r.md")"
check "one Draft feedback heading" "1" "$(grep -c '^## Draft feedback' "$TMP/r.md")"
report '## Draft feedback

Old.

## Appendix

kept
'
render >/dev/null
check "plain heading is replaced, not duplicated" "1" "$(grep -c '^## Draft feedback' "$TMP/r.md")"
check "plain heading becomes the full heading" "1" "$(grep -c '^## Draft feedback — edit before sending$' "$TMP/r.md")"
check "the next section is kept" "kept" "$(tail -1 "$TMP/r.md")"
report ''
render >/dev/null
check "missing heading appends at end" "## Draft feedback — edit before sending" "$(grep '^## Draft' "$TMP/r.md")"
report '## Draft feedback

Old.

```json
[{"x": 1}]
```
'
render >/dev/null
check "json fence after section is preserved" '[{"x": 1}]' "$(grep -A1 '^```json' "$TMP/r.md" | tail -1)"

echo "Test 2: layout"
report '## Draft feedback
'
render >/dev/null
check "opening first" "Thank you for submitting SAS to Appverse. The README covers every rung." "$(section | sed -n 3p)"
check "numbering runs across levels" "1.|2.|3." "$(section | grep -oE '^[0-9]+\.' | paste -sd'|' -)"
check "labels in order, empty level has no label" "**Must fix**|**Should fix**" "$(section | grep -E '^\*\*' | paste -sd'|' -)"
check "no blank line between items" "3." "$(section | grep -A1 '^2\. ' | tail -1 | cut -c1-2)"
check "item shape" '2. `template/script.sh.erb:17,22`, `template/before.sh.erb:4` Check the cd and mkdir.' "$(section | grep '^2\. ')"
check "empty text falls back to summaries with marker" '3. `form.yml:47` Cores allow zero. <!-- feedback-missing -->' "$(section | grep '^3\. ')"
check "generated marker" "1" "$(section | grep -c '^<!-- feedback-generated -->$')"
check "covers lists every defect key" "<!-- feedback-covers: manifest.yml:missing-field:software, template/script.sh.erb:no-error-check, template/before.sh.erb:no-error-check, form.yml:zero-minimum -->" "$(section | grep 'feedback-covers')"
check "warning printed for missing text" "1" "$(grep -c '^warning: feedback-missing for should:QUA-07:zero-minimum' "$TMP/out")"
cp "$TMP/r.md" "$TMP/once.md"; render >/dev/null
check "rendering twice is identical" "same" "$(cmp -s "$TMP/once.md" "$TMP/r.md" && echo same || echo differs)"
GITHUB_ACTIONS=true python3 "$RENDER" "$TMP/r.md" "$TMP/fb.json" > "$TMP/out" 2>&1
check "GITHUB_ACTIONS adds ::warning::" "1" "$(grep -c '^::warning::Draft feedback: 1 item' "$TMP/out")"

echo "Test 3: degraded input"
echo "{broken" > "$TMP/fb.json"; report '## Draft feedback
'
check "unreadable feedback.json exits 0" 0 "$(render)"
check "default opening from the title" "Thank you for submitting ood-sas to Appverse." "$(section | sed -n 3p)"
echo '{"app_name": "", "opening": "", "items": [{"group": "must:meta:public", "level": "must", "locations": [], "defect_keys": [], "summaries": [], "text": "The repository is not public; make it public so the catalog can read it."}]}' > "$TMP/fb.json"
render >/dev/null
check "meta-gate item has no location" "1. The repository is not public; make it public so the catalog can read it." "$(section | grep '^1\. ')"
check "missing report exits 2" 2 "$(python3 "$RENDER" "$TMP/nope.md" "$TMP/fb.json" >/dev/null 2>&1; echo $?)"

echo "Test 3b: model text cannot break the layout"
cat > "$TMP/fb.json" <<'EOF'
{"app_name": "SAS", "opening": "Thanks.\n\nGreat README.",
 "items": [
  {"group": "should:QUA-03:no-error-check", "level": "should", "locations": ["a.sh:3"], "defect_keys": ["a.sh:no-error-check"], "summaries": ["x"], "text": "Add set -e.\n\n## Oops\n\n1. stray"},
  {"group": "suggestion:QUA-07:missing-pattern", "level": "suggestion", "locations": ["form.yml:4"], "defect_keys": ["form.yml:missing-pattern"], "summaries": ["No pattern.", "No pattern.", "Free text\nunchecked"], "text": ""}
 ]}
EOF
report '## Draft feedback
'
render >/dev/null
check "a newline in text adds no heading" "1" "$(grep -c '^## ' "$TMP/r.md" | xargs -I{} expr {} - 1)"
check "text is one line" '1. `a.sh:3` Add set -e. ## Oops 1. stray' "$(section | grep '^1\. ')"
check "covers stays in the section" "1" "$(section | grep -c 'feedback-covers')"
check "opening is one line" "Thanks. Great README." "$(section | sed -n 3p)"
check "fallback summaries are de-duplicated, joined as sentences" '2. `form.yml:4` No pattern. Free text unchecked. <!-- feedback-missing -->' "$(section | grep '^2\. ')"

echo "Test 4: floor passes on every fallback"
# Every vocabulary tag, as a WARN low fix-item with no sentence written,
# rendered by prepare + render, must pass check-feedback-floor.py. MNT tags
# take their usual pseudo-anchor; root:no-ci is left out because the floor
# rejects it whatever the prose says (it normally anchors at .github/workflows).
PYTHONPATH="$REFS" python3 - "$REFS/finding-codes.md" "$TMP" <<'EOF'
import json, sys
from feedback_terms import vocabulary_tags
vocab = vocabulary_tags(sys.argv[1])
tmp = sys.argv[2]
MNT = {"stale-repo": "root", "no-releases": "releases", "no-changelog": "CHANGELOG.md",
       "no-ci": ".github/workflows", "single-contributor": "contributors", "unresponsive-issues": "issues"}
def finding(rule, key, evidence, summary):
    aspect = {"OODT": "security", "STR": "structure", "QUA": "quality", "MNT": "maintenance"}[rule.split("-")[0]]
    return {"app_id": "root", "rule": rule, "defect_key": key, "result": "WARN", "severity": "low",
            "evidence": evidence, "summary": summary, "aspect": aspect}
single, grouped = [], []
for rule, tags in vocab.items():
    for tag in tags:
        words = tag.replace("-", " ")
        if rule.startswith("MNT"):
            single.append(finding(rule, "{}:{}".format(MNT[tag], tag), "not found", words))
            continue
        single.append(finding(rule, "form.yml:" + tag, "form.yml:7", words))
        grouped.append(finding(rule, "form.yml:" + tag, "form.yml:7", words))
        grouped.append(finding(rule, "template/script.sh.erb:" + tag, "template/script.sh.erb:9", words))
json.dump(single, open(tmp + "/single.json", "w"))
json.dump(grouped, open(tmp + "/grouped.json", "w"))
json.dump([finding("QUA-05", "README.md:template-placeholder", "README.md", "template placeholder left in")], open(tmp + "/lineless-ok.json", "w"))
json.dump([finding("QUA-05", "README.md:template-placeholder", "README.md", "x")], open(tmp + "/lineless-bad.json", "w"))
print(len(single), len(grouped))
EOF
echo '{"apps": [{"app_id": "root", "name": "X"}]}' > "$TMP/m.json"
floor_case() { # findings-file
  rm -f "$TMP/fb.json"; printf '# Appverse Review: o/r\n\n## Draft feedback\n' > "$TMP/r.md"
  python3 "$PREP" "$1" "$TMP/m.json" "$REFS/checks.json" "$TMP/fb.json" >/dev/null 2>&1
  env -u GITHUB_ACTIONS python3 "$RENDER" "$TMP/r.md" "$TMP/fb.json" >/dev/null 2>&1
  python3 "$FLOOR" "$1" "$TMP/r.md" > "$TMP/floor.out" 2>&1; echo $?; }
check "every tag alone passes the floor" 0 "$(floor_case "$TMP/single.json")"; grep MISSING "$TMP/floor.out"
check "every tag grouped across two files passes the floor" 0 "$(floor_case "$TMP/grouped.json")"; grep MISSING "$TMP/floor.out"
check "a line-less file finding passes when its summary names the defect" 0 "$(floor_case "$TMP/lineless-ok.json")"
check "a line-less file finding with a bare summary fails (documented limit)" 1 "$(floor_case "$TMP/lineless-bad.json")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
