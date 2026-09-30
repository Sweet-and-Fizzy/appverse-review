#!/usr/bin/env bash
# Test check-feedback-floor.py: the Draft Feedback must name every Low+ FAIL/WARN finding.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$SCRIPT_DIR/references/check-feedback-floor.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { python3 "$CHECK" "$1" "$2" > "$TMP/out" 2>&1; echo $?; }

cat > "$TMP/findings.json" <<'EOF'
[
 {"app_id":"root","rule":"OODT-01","defect_key":"submit.yml.erb:unsanitized-input","aspect":"security","severity":"low","result":"WARN","summary":"x","evidence":"submit.yml.erb:15-19"},
 {"app_id":"root","rule":"QUA-03","defect_key":"template/script.sh.erb:no-error-handling","aspect":"quality","severity":"low","result":"FAIL","summary":"x","evidence":"template/script.sh.erb:1"},
 {"app_id":"root","rule":"QUA-05","defect_key":"template/script.sh.erb:dead-code","aspect":"quality","severity":"info","result":"WARN","summary":"x","evidence":"template/script.sh.erb:30"},
 {"app_id":"root","rule":"OODT-04","defect_key":"root:tier3","aspect":"security","severity":"medium","result":"NOT CHECKED","summary":"x","evidence":"n/a"},
 {"app_id":"root","rule":"MNT-03","defect_key":"root:changelog-wrong-app","aspect":"maintenance","severity":"low","result":"WARN","summary":"CHANGELOG describes another app","evidence":"CHANGELOG.md:11"},
 {"app_id":"root","rule":"MNT-02","defect_key":"root:no-releases","aspect":"maintenance","severity":"low","result":"WARN","summary":"0 tagged releases","evidence":"GitHub releases API: 0"},
 {"app_id":"root","rule":"QUA-02","defect_key":"form.yml:hardcoded-module-version","aspect":"quality","severity":"low","result":"FAIL","summary":"module version hardcoded","evidence":"form.yml:63"}
]
EOF

echo "Test 1: fully covered feedback passes"
cat > "$TMP/ok.md" <<'EOF'
# Appverse Review: x
## Overall recommendation
Accept with suggestions.
## Draft feedback — edit before sending
Please validate the free-text fields in submit.yml.erb; the input is unsanitized. It has no error handling, so add set -e to template/script.sh.erb.
CHANGELOG.md describes a different, wrong app; please rewrite it. Consider tagging a release.
form.yml hardcodes a module version at line 63; please make it configurable.
<!-- feedback-covers: submit.yml.erb:unsanitized-input, template/script.sh.erb:no-error-handling, root:changelog-wrong-app, root:no-releases, form.yml:hardcoded-module-version -->
EOF
check "exit 0" 0 "$(run "$TMP/findings.json" "$TMP/ok.md")"
check "reports 5/5" "feedback floor: 5/5 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 2: a Low finding missing from the coverage line fails"
sed 's/, root:no-releases//' "$TMP/ok.md" > "$TMP/missing-key.md"
check "exit 1" 1 "$(run "$TMP/findings.json" "$TMP/missing-key.md")"
check "names the finding" 1 "$(grep -c 'MISSING MNT-02 root:no-releases' "$TMP/out")"
check "reports 4/5" "feedback floor: 4/5 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 3: key listed but file never named in prose fails"
sed 's#add set -e to template/script.sh.erb.#add set -e to the job script.#' "$TMP/ok.md" > "$TMP/missing-path.md"
check "exit 1" 1 "$(run "$TMP/findings.json" "$TMP/missing-path.md")"
check "names the finding with reason" 1 "$(grep -c 'MISSING QUA-03 template/script.sh.erb:no-error-handling (file not named in feedback)' "$TMP/out")"

echo "Test 4: basename is enough"
sed 's#template/script.sh.erb\.#script.sh.erb.#' "$TMP/ok.md" > "$TMP/basename.md"
check "exit 0" 0 "$(run "$TMP/findings.json" "$TMP/basename.md")"

echo "Test 5: submitter-mode heading accepted"
sed 's/^## Draft feedback — edit before sending$/## Fix before submitting/' "$TMP/ok.md" > "$TMP/submitter.md"
check "exit 0" 0 "$(run "$TMP/findings.json" "$TMP/submitter.md")"

echo "Test 6: no feedback section is exit 2"
grep -v -e '^## Draft feedback' -e 'feedback-covers' "$TMP/ok.md" > "$TMP/nosection.md"
check "exit 2" 2 "$(run "$TMP/findings.json" "$TMP/nosection.md")"

echo "Test 7: no coverage line is exit 1 with every fix-item missing"
grep -v 'feedback-covers' "$TMP/ok.md" > "$TMP/nocover.md"
check "exit 1" 1 "$(run "$TMP/findings.json" "$TMP/nocover.md")"
check "reports 0/5" "feedback floor: 0/5 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 8: no fix-items at all passes with 0/0"
echo '[{"app_id":"root","rule":"QUA-05","defect_key":"a:b","aspect":"quality","severity":"info","result":"WARN","summary":"x","evidence":"a:1"}]' > "$TMP/none.json"
check "exit 0" 0 "$(run "$TMP/none.json" "$TMP/ok.md")"
check "reports 0/0" "feedback floor: 0/0 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 9: a '##' line inside a fenced code block does not end the section"
awk '/<!-- feedback-covers:/ { print "```"; print "## a comment inside a snippet"; print "```" } { print }' "$TMP/ok.md" > "$TMP/fenced.md"
check "exit 0" 0 "$(run "$TMP/findings.json" "$TMP/fenced.md")"
check "reports 5/5" "feedback floor: 5/5 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 10: a superstring of the path does not satisfy the token-boundary match"
sed 's#template/script.sh.erb\.#template/myscript.sh.erb.#' "$TMP/ok.md" > "$TMP/superstring.md"
check "exit 1" 1 "$(run "$TMP/findings.json" "$TMP/superstring.md")"
check "names the finding with reason" 1 "$(grep -c 'MISSING QUA-03 template/script.sh.erb:no-error-handling (file not named in feedback)' "$TMP/out")"

echo "Test 11: monorepo evidence requires the full app-scoped path, not just the basename"
cat > "$TMP/monorepo.json" <<'EOF'
[
 {"app_id":"apps/a","rule":"QUA-06","defect_key":"apps/a/form.yml:duplicate-key","aspect":"quality","severity":"low","result":"FAIL","summary":"x","evidence":"apps/a/form.yml:3"},
 {"app_id":"apps/b","rule":"QUA-06","defect_key":"apps/b/form.yml:duplicate-key","aspect":"quality","severity":"low","result":"FAIL","summary":"x","evidence":"apps/b/form.yml:3"}
]
EOF
cat > "$TMP/monorepo-basename.md" <<'EOF'
# Appverse Review: x
## Overall recommendation
Accept with suggestions.
## Draft feedback — edit before sending
form.yml has a duplicate key in both apps; please fix it.
<!-- feedback-covers: apps/a/form.yml:duplicate-key, apps/b/form.yml:duplicate-key -->
EOF
check "basename alone fails for both apps" \
  "1|2" \
  "$(run "$TMP/monorepo.json" "$TMP/monorepo-basename.md")|$(grep -c '(file not named in feedback)' "$TMP/out")"
sed -e 's#form\.yml has a duplicate key in both apps; please fix it\.#apps/a/form.yml and apps/b/form.yml each have a duplicate key; please fix them.#' \
  "$TMP/monorepo-basename.md" > "$TMP/monorepo-fullpath.md"
check "full app-scoped paths pass" \
  "0|feedback floor: 2/2 fix-items covered" \
  "$(run "$TMP/monorepo.json" "$TMP/monorepo-fullpath.md")|$(tail -1 "$TMP/out")"

echo "Test 12: extensionless evidence paths (LICENSE:1, Dockerfile:5) are recognized as file paths"
cat > "$TMP/extensionless.json" <<'EOF'
[
 {"app_id":"root","rule":"STR-02","defect_key":"LICENSE:missing-license","aspect":"structure","severity":"high","result":"FAIL","summary":"x","evidence":"LICENSE:1"}
]
EOF
cat > "$TMP/no-license-word.md" <<'EOF'
# Appverse Review: x
## Overall recommendation
Request changes.
## Draft feedback — edit before sending
Please add an open-source license to the repo.
<!-- feedback-covers: LICENSE:missing-license -->
EOF
check "missing LICENSE token fails" \
  "1|(file not named in feedback)" \
  "$(run "$TMP/extensionless.json" "$TMP/no-license-word.md")|$(grep -o '(file not named in feedback)' "$TMP/out")"
sed 's#Please add an open-source license to the repo\.#The repo is missing an open-source LICENSE.#' \
  "$TMP/no-license-word.md" > "$TMP/with-license-word.md"
check "naming LICENSE passes" \
  "0|feedback floor: 1/1 fix-items covered" \
  "$(run "$TMP/extensionless.json" "$TMP/with-license-word.md")|$(tail -1 "$TMP/out")"

echo "Test 13: file named but neither the line nor the tag words are in the prose fails"
cat > "$TMP/version.json" <<'EOF'
[
 {"app_id":"root","rule":"QUA-02","defect_key":"form.yml:hardcoded-module-version","aspect":"quality","severity":"low","result":"FAIL","summary":"x","evidence":"form.yml:63"}
]
EOF
cat > "$TMP/no-defect-named.md" <<'EOF'
# Appverse Review: x
## Overall recommendation
Accept with suggestions.
## Draft feedback — edit before sending
Please take another look at form.yml.
<!-- feedback-covers: form.yml:hardcoded-module-version -->
EOF
check "exit 1" 1 "$(run "$TMP/version.json" "$TMP/no-defect-named.md")"
check "names the finding with the new reason" 1 \
  "$(grep -c 'MISSING QUA-02 form.yml:hardcoded-module-version (defect not described in feedback)' "$TMP/out")"

echo "Test 14: same feedback plus the tag words passes"
sed 's#Please take another look at form.yml\.#form.yml has a hardcoded module version; please take another look.#' \
  "$TMP/no-defect-named.md" > "$TMP/tag-words.md"
check "exit 0" 0 "$(run "$TMP/version.json" "$TMP/tag-words.md")"
check "reports 1/1" "feedback floor: 1/1 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 15: same feedback plus the line number instead passes"
sed 's#Please take another look at form.yml\.#Please take another look at form.yml:63.#' \
  "$TMP/no-defect-named.md" > "$TMP/line-number.md"
check "exit 0" 0 "$(run "$TMP/version.json" "$TMP/line-number.md")"
check "reports 1/1" "feedback floor: 1/1 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 15b: synonym-tolerant defect rule accepts correct prose the old word-for-word rule rejected"
cat > "$TMP/synonyms.json" <<'EOF'
[
 {"app_id":"root","rule":"QUA-03","defect_key":"template/script.sh.erb:missing-shebang","aspect":"quality","severity":"low","result":"FAIL","summary":"x","evidence":"template/script.sh.erb:1"},
 {"app_id":"root","rule":"MNT-03","defect_key":"CHANGELOG.md:wrong-app-changelog","aspect":"maintenance","severity":"low","result":"WARN","summary":"x","evidence":"CHANGELOG.md:1"}
]
EOF
cat > "$TMP/synonyms.md" <<'EOF'
# Appverse Review: x
## Overall recommendation
Accept with suggestions.
## Draft feedback — edit before sending
template/script.sh.erb has no shebang line; please add one.
CHANGELOG.md is still MATLAB's changelog; please rewrite it for this app.
<!-- feedback-covers: template/script.sh.erb:missing-shebang, CHANGELOG.md:wrong-app-changelog -->
EOF
check "exit 0" 0 "$(run "$TMP/synonyms.json" "$TMP/synonyms.md")"
check "reports 2/2" "feedback floor: 2/2 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 15c: a mechanism tag with no distinctive word after stopwords (no-ci) falls back to evidence with no line number, satisfied by file name alone"
cat > "$TMP/noci.json" <<'EOF'
[
 {"app_id":"root","rule":"MNT-04","defect_key":".github/workflows:no-ci","aspect":"maintenance","severity":"low","result":"FAIL","summary":"x","evidence":".github/workflows: absent"}
]
EOF
cat > "$TMP/noci.md" <<'EOF'
# Appverse Review: x
## Overall recommendation
Accept with suggestions.
## Draft feedback — edit before sending
Please add a .github/workflows directory with a CI configuration.
<!-- feedback-covers: .github/workflows:no-ci -->
EOF
check "exit 0" 0 "$(run "$TMP/noci.json" "$TMP/noci.md")"
check "reports 1/1" "feedback floor: 1/1 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 16: a structured-findings JSON block after the feedback section must not rescue a missing fix-item"
cat > "$TMP/with-json.md" <<'EOF'
# Appverse Review: x
## Overall recommendation
Accept with suggestions.
## Draft feedback — edit before sending
CHANGELOG.md is still MATLAB's changelog; please rewrite it for this app.
form.yml hardcodes a module version at line 63; please make it configurable.
<!-- feedback-covers: submit.yml.erb:unsanitized-input, template/script.sh.erb:no-error-handling, root:changelog-wrong-app, root:no-releases, form.yml:hardcoded-module-version -->

```json
[
 {"defect_key": "submit.yml.erb:unsanitized-input", "evidence": "template/script.sh.erb:1"},
 {"defect_key": "template/script.sh.erb:no-error-handling", "evidence": "template/script.sh.erb:1"},
 {"defect_key": "root:changelog-wrong-app", "evidence": "template/script.sh.erb:1"},
 {"defect_key": "root:no-releases", "evidence": "template/script.sh.erb:1"},
 {"defect_key": "form.yml:hardcoded-module-version", "evidence": "template/script.sh.erb:1"}
]
```
EOF
check "exit 1" 1 "$(run "$TMP/findings.json" "$TMP/with-json.md")"
check "names the finding missing from prose" 1 \
  "$(grep -c 'MISSING QUA-03 template/script.sh.erb:no-error-handling (file not named in feedback)' "$TMP/out")"

echo "Test 17: file named in one paragraph, its tag word only in a different paragraph fails"
cat > "$TMP/wrong-paragraph.md" <<'EOF'
# Appverse Review: x
## Overall recommendation
Accept with suggestions.
## Draft feedback — edit before sending
Please take another look at form.yml.

Elsewhere, something is hardcoded and should be configurable via a module version setting.
<!-- feedback-covers: form.yml:hardcoded-module-version -->
EOF
check "exit 1" 1 "$(run "$TMP/version.json" "$TMP/wrong-paragraph.md")"
check "names the finding with the new reason" 1 \
  "$(grep -c 'MISSING QUA-02 form.yml:hardcoded-module-version (defect not described in feedback)' "$TMP/out")"

echo "Test 18: mechanism_words takes the tag after the anchor; a qualifier's words are the distinctive words, an other: prefix uses its remainder"
qualifier_words="$(python3 -c "
import importlib.util
spec = importlib.util.spec_from_file_location('cff', '$CHECK')
cff = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cff)
print(','.join(cff.mechanism_words('form.yml:duplicate-yaml-key:custom_num_cores.help')))
print(','.join(cff.mechanism_words('x:other:icon-mismatch')))
")"
check "qualifier IS the distinctive part: words from custom_num_cores.help" \
  "$(printf 'custom,num,cores,help')" \
  "$(echo "$qualifier_words" | sed -n '1p')"
check "other: prefix stripped, words from icon-mismatch" \
  "$(printf 'icon,mismatch')" \
  "$(echo "$qualifier_words" | sed -n '2p')"

echo "Test 19: a qualified defect_key is covered when the prose names the qualifier's topic, distinct from the unqualified base tag"
cat > "$TMP/testing-table.json" <<'EOF'
[
 {"app_id":"root","rule":"QUA-06","defect_key":"README.md:readme-inconsistency:testing-table","aspect":"quality","severity":"low","result":"WARN","summary":"x","evidence":"README.md:182-184 vs :201"}
]
EOF
cat > "$TMP/testing-table-covered.md" <<'EOF'
# Appverse Review: x
## Overall recommendation
Accept with suggestions.
## Draft feedback — edit before sending
README.md's testing table lists Rocky only.
<!-- feedback-covers: README.md:readme-inconsistency:testing-table -->
EOF
check "exit 0" 0 "$(run "$TMP/testing-table.json" "$TMP/testing-table-covered.md")"
check "reports 1/1" "feedback floor: 1/1 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 20: the same qualified defect_key is not covered when the prose names the file but not the qualifier's topic"
cat > "$TMP/testing-table-uncovered.md" <<'EOF'
# Appverse Review: x
## Overall recommendation
Accept with suggestions.
## Draft feedback — edit before sending
README.md says Rocky.
<!-- feedback-covers: README.md:readme-inconsistency:testing-table -->
EOF
check "exit 1" 1 "$(run "$TMP/testing-table.json" "$TMP/testing-table-uncovered.md")"
check "names the finding with the new reason" 1 \
  "$(grep -c 'MISSING QUA-06 README.md:readme-inconsistency:testing-table (defect not described in feedback)' "$TMP/out")"

echo "Test 21: a covers comment placed just above the '## Draft feedback' heading (within five lines) is honored"
cat > "$TMP/above-heading.md" <<'EOF'
# Appverse Review: x
## Overall recommendation
Accept with suggestions.
<!-- feedback-covers: submit.yml.erb:unsanitized-input, template/script.sh.erb:no-error-handling, root:changelog-wrong-app, root:no-releases, form.yml:hardcoded-module-version -->

## Draft feedback — edit before sending
Please validate the free-text fields in submit.yml.erb; the input is unsanitized. It has no error handling, so add set -e to template/script.sh.erb.
CHANGELOG.md describes a different, wrong app; please rewrite it. Consider tagging a release.
form.yml hardcodes a module version at line 63; please make it configurable.
EOF
check "exit 0" 0 "$(run "$TMP/findings.json" "$TMP/above-heading.md")"
check "reports 5/5" "feedback floor: 5/5 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 22: a covers comment far above the heading (more than five lines) is still ignored"
cat > "$TMP/far-above.md" <<'EOF'
# Appverse Review: x
<!-- feedback-covers: submit.yml.erb:unsanitized-input, template/script.sh.erb:no-error-handling, root:changelog-wrong-app, root:no-releases, form.yml:hardcoded-module-version -->
## Overall recommendation
Accept with suggestions.
Line filler one.
Line filler two.

## Draft feedback — edit before sending
Please validate the free-text fields in submit.yml.erb; the input is unsanitized. It has no error handling, so add set -e to template/script.sh.erb.
CHANGELOG.md describes a different, wrong app; please rewrite it. Consider tagging a release.
form.yml hardcodes a module version at line 63; please make it configurable.
EOF
check "exit 1" 1 "$(run "$TMP/findings.json" "$TMP/far-above.md")"
check "reports 0/5" "feedback floor: 0/5 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 23: a covers comment above the heading AND another inside the section: the in-section one wins"
cat > "$TMP/combined.md" <<'EOF'
# Appverse Review: x
## Overall recommendation
Accept with suggestions.
<!-- feedback-covers: root:no-releases -->

## Draft feedback — edit before sending
Please validate the free-text fields in submit.yml.erb; the input is unsanitized. It has no error handling, so add set -e to template/script.sh.erb.
CHANGELOG.md describes a different, wrong app; please rewrite it. Consider tagging a release.
form.yml hardcodes a module version at line 63; please make it configurable.
<!-- feedback-covers: submit.yml.erb:unsanitized-input, template/script.sh.erb:no-error-handling, root:changelog-wrong-app, root:no-releases, form.yml:hardcoded-module-version -->
EOF
check "exit 0 (in-section list, not just the pre-heading one, is used)" 0 "$(run "$TMP/findings.json" "$TMP/combined.md")"
check "reports 5/5" "feedback floor: 5/5 fix-items covered" "$(tail -1 "$TMP/out")"
sed 's/, root:no-releases -->/ -->/; s/, root:no-releases,/,/' "$TMP/combined.md" > "$TMP/combined-partial.md"
check "exit 1 when the in-section list drops a key the pre-heading one had" 1 "$(run "$TMP/findings.json" "$TMP/combined-partial.md")"
check "names the finding dropped from the in-section list" 1 "$(grep -c 'MISSING MNT-02 root:no-releases' "$TMP/out")"

echo "Test 24: a line after '; reviewed OK:' is a PASS line: naming it does not describe the FAIL"
cat > "$TMP/rok.json" <<'EOF'
[
 {"app_id":"root","rule":"QUA-08","defect_key":"template/script.sh.erb:magic-number","aspect":"quality","severity":"low","result":"WARN","summary":"x","evidence":"template/script.sh.erb:22; reviewed OK: template/script.sh.erb:9,23"}
]
EOF
cat > "$TMP/rok.md" <<'EOF'
# Appverse Review: x
## Overall recommendation
Accept with suggestions.
## Draft feedback — edit before sending
Please look at template/script.sh.erb line 9.
<!-- feedback-covers: template/script.sh.erb:magic-number -->
EOF
check "PASS line named: exit 1" 1 "$(run "$TMP/rok.json" "$TMP/rok.md")"
check "reason" 1 "$(grep -c 'MISSING QUA-08 template/script.sh.erb:magic-number (defect not described in feedback)' "$TMP/out")"
sed 's/line 9\./line 22./' "$TMP/rok.md" > "$TMP/rok2.md"
check "FAIL line named: exit 0" 0 "$(run "$TMP/rok.json" "$TMP/rok2.md")"

echo "Test 25: a line number in a sentence about another file does not describe this file's defect"
cat > "$TMP/t25.json" <<'EOF'
[{"app_id":"root","rule":"OODT-08","defect_key":"template/script.sh.erb:debug-tracing-enabled","result":"WARN","severity":"low","evidence":"template/script.sh.erb:19,44,54"},
 {"app_id":"root","rule":"QUA-06","defect_key":"form.yml:duplicate-yaml-key:custom_num_cores.help","result":"WARN","severity":"low","evidence":"form.yml:44,45"}]
EOF
cat > "$TMP/t25.md" <<'EOF'
## Draft feedback
<!-- feedback-covers: template/script.sh.erb:debug-tracing-enabled, form.yml:duplicate-yaml-key:custom_num_cores.help -->
The script template/script.sh.erb needs a shebang. In form.yml the duplicate help keys on lines 44/45 should be merged.
EOF
check "exit 1" 1 "$(run "$TMP/t25.json" "$TMP/t25.md")"
check "OODT-08 missing" 1 "$(grep -cF 'MISSING OODT-08 template/script.sh.erb:debug-tracing-enabled (defect not described in feedback)' "$TMP/out")"
check "QUA-06 covered" 0 "$(grep -cF 'MISSING QUA-06' "$TMP/out")"

echo "Test 26: file in one sentence, line in the next: still covered"
cat > "$TMP/t26.md" <<'EOF'
## Draft feedback
<!-- feedback-covers: template/script.sh.erb:debug-tracing-enabled, form.yml:duplicate-yaml-key:custom_num_cores.help -->
template/script.sh.erb turns on tracing. Lines 19, 44 and 54 each run set -x; drop them before release. form.yml has duplicate help keys at lines 44/45.
EOF
check "exit 0" 0 "$(run "$TMP/t25.json" "$TMP/t26.md")"

echo "Test 27: a pseudo-anchor fix-item needs its subject in the prose, not only its covers key"
cat > "$TMP/t27.json" <<'EOF'
[{"app_id":"root","rule":"MNT-02","defect_key":"releases:no-releases","result":"WARN","severity":"low","evidence":"releases"}]
EOF
printf '## Draft feedback\n<!-- feedback-covers: releases:no-releases -->\nThe README is fine.\n' > "$TMP/t27a.md"
check "exit 1" 1 "$(run "$TMP/t27.json" "$TMP/t27a.md")"
check "reason" 1 "$(grep -cF 'MISSING MNT-02 releases:no-releases (subject not named in feedback)' "$TMP/out")"
printf '## Draft feedback\n<!-- feedback-covers: releases:no-releases -->\nThere are no tagged releases yet; tag one when the next change lands.\n' > "$TMP/t27b.md"
check "subject named: exit 0" 0 "$(run "$TMP/t27.json" "$TMP/t27b.md")"

echo "Test 28: a file named once in a lead-in, with several of its defects described over the following sentences, still passes (the window runs until a different file is named, not just one sentence)"
cat > "$TMP/t28.json" <<'EOF'
[{"app_id":"root","rule":"OODT-08","defect_key":"template/script.sh.erb:debug-tracing-enabled","result":"WARN","severity":"low","evidence":"template/script.sh.erb:19,44,54"},
 {"app_id":"root","rule":"QUA-02","defect_key":"form.yml:hardcoded-module-version","result":"FAIL","severity":"low","evidence":"form.yml:63"}]
EOF
cat > "$TMP/t28.md" <<'EOF'
## Draft feedback
<!-- feedback-covers: template/script.sh.erb:debug-tracing-enabled, form.yml:hardcoded-module-version -->
template/script.sh.erb enables debug tracing. This shows up at lines 19, 44 and 54, and should be removed. It also lacks a shebang line, e.g. the standard interpreter directive. See the OOD packaging guidance for v2.0. form.yml separately hardcodes a module version at line 63.
EOF
check "exit 0" 0 "$(run "$TMP/t28.json" "$TMP/t28.md")"
check "reports 2/2" "feedback floor: 2/2 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 29: Must-not — a pseudo-anchor item whose prose says the singular form, with no line number, passes (plural tolerance is symmetric)"
cat > "$TMP/t29.json" <<'EOF'
[{"app_id":"root","rule":"MNT-02","defect_key":"releases:no-releases","result":"WARN","severity":"low","evidence":"releases"}]
EOF
printf '## Draft feedback\n<!-- feedback-covers: releases:no-releases -->\nThere is no tagged release yet.\n' > "$TMP/t29.md"
check "singular release passes: exit 0" 0 "$(run "$TMP/t29.json" "$TMP/t29.md")"
check "reports 1/1" "feedback floor: 1/1 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 30: a pseudo-anchor whose defect_key anchor is 'root' falls back to its mechanism-tag words as the subject"
cat > "$TMP/t30.json" <<'EOF'
[{"app_id":"root","rule":"MNT-02","defect_key":"root:no-releases","result":"WARN","severity":"low","evidence":"GitHub releases API: 0"}]
EOF
printf '## Draft feedback\n<!-- feedback-covers: root:no-releases -->\nThe README looks fine.\n' > "$TMP/t30a.md"
check "no subject named: exit 1" 1 "$(run "$TMP/t30.json" "$TMP/t30a.md")"
check "reason" 1 "$(grep -cF 'MISSING MNT-02 root:no-releases (subject not named in feedback)' "$TMP/out")"
printf '## Draft feedback\n<!-- feedback-covers: root:no-releases -->\nConsider tagging a release.\n' > "$TMP/t30b.md"
check "mechanism word as subject: exit 0" 0 "$(run "$TMP/t30.json" "$TMP/t30b.md")"

echo "Test 31: the '.github/workflows' pseudo-anchor's subject words are 'ci' and 'workflow'"
cat > "$TMP/t31.json" <<'EOF'
[{"app_id":"root","rule":"MNT-04","defect_key":".github/workflows:no-ci","result":"FAIL","severity":"low","evidence":".github/workflows: absent"}]
EOF
printf '## Draft feedback\n<!-- feedback-covers: .github/workflows:no-ci -->\nThere is no test suite mentioned.\n' > "$TMP/t31a.md"
check "no subject named: exit 1" 1 "$(run "$TMP/t31.json" "$TMP/t31a.md")"
check "reason" 1 "$(grep -cF 'MISSING MNT-04 .github/workflows:no-ci (subject not named in feedback)' "$TMP/out")"
printf '## Draft feedback\n<!-- feedback-covers: .github/workflows:no-ci -->\nPlease add a CI configuration.\n' > "$TMP/t31b.md"
check "ci word passes: exit 0" 0 "$(run "$TMP/t31.json" "$TMP/t31b.md")"

echo "Test 32: a monorepo app's short-form filename in a later sentence (matching the evidence path's basename) is not mistaken for a different file, so the window still runs through it"
cat > "$TMP/t32.json" <<'EOF'
[{"app_id":"apps/x","rule":"OODT-08","defect_key":"apps/x/template/script.sh.erb:debug-tracing-enabled","result":"WARN","severity":"low","evidence":"apps/x/template/script.sh.erb:19,44,54"}]
EOF
cat > "$TMP/t32.md" <<'EOF'
## Draft feedback
<!-- feedback-covers: apps/x/template/script.sh.erb:debug-tracing-enabled -->
apps/x/template/script.sh.erb enables debug tracing at lines 19, 44 and 54. script.sh.erb should have this removed before release.
EOF
check "exit 0" 0 "$(run "$TMP/t32.json" "$TMP/t32.md")"
check "reports 1/1" "feedback floor: 1/1 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 33: subject_words is total over every entry of repo_paths.PSEUDO_ANCHORS — each yields a non-empty subject for an ordinary (non-'root') tag"
anchors_empty="$(python3 -c "
import importlib.util
spec = importlib.util.spec_from_file_location('cff', '$CHECK')
cff = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cff)
empty = [a for a in sorted(cff.PSEUDO_ANCHORS) if a != 'root' and not cff.subject_words(a + ':some-tag')]
print(','.join(empty))
")"
check "no pseudo-anchor (other than root) yields an empty subject" "" "$anchors_empty"

echo "Test 34: a pseudo-anchor fix-item outside the four originally-tabled anchors (commits, issues) is MISSING, not a silent pass, when only the covers key names it"
cat > "$TMP/t34.json" <<'EOF'
[{"app_id":"root","rule":"MNT-01","defect_key":"commits:stale-repo","result":"FAIL","severity":"high","evidence":"last commit 400 days ago"},
 {"app_id":"root","rule":"MNT-05","defect_key":"issues:unresponsive-issues","result":"WARN","severity":"low","evidence":"3 open issues, no response"}]
EOF
printf '## Draft feedback\n<!-- feedback-covers: commits:stale-repo, issues:unresponsive-issues -->\nThe README is fine.\n' > "$TMP/t34a.md"
check "exit 1" 1 "$(run "$TMP/t34.json" "$TMP/t34a.md")"
check "reports 0/2" "feedback floor: 0/2 fix-items covered" "$(tail -1 "$TMP/out")"
check "commits reason" 1 "$(grep -cF 'MISSING MNT-01 commits:stale-repo (subject not named in feedback)' "$TMP/out")"
check "issues reason" 1 "$(grep -cF 'MISSING MNT-05 issues:unresponsive-issues (subject not named in feedback)' "$TMP/out")"
printf '## Draft feedback\n<!-- feedback-covers: commits:stale-repo, issues:unresponsive-issues -->\nThe last commit was over a year ago. There are open issues with no maintainer response.\n' > "$TMP/t34b.md"
check "subjects named: exit 0" 0 "$(run "$TMP/t34.json" "$TMP/t34b.md")"

echo "Test 35: a 'root' pseudo-anchor whose mechanism tag has no distinctive word is MISSING with 'no subject for pseudo-anchor root', not a silent pass"
cat > "$TMP/t35.json" <<'EOF'
[{"app_id":"root","rule":"MNT-04","defect_key":"root:no-ci","result":"FAIL","severity":"low","evidence":"n/a"}]
EOF
printf '## Draft feedback\n<!-- feedback-covers: root:no-ci -->\nEverything else looks fine.\n' > "$TMP/t35.md"
check "exit 1" 1 "$(run "$TMP/t35.json" "$TMP/t35.md")"
check "reason" 1 "$(grep -cF 'MISSING MNT-04 root:no-ci (no subject for pseudo-anchor root)' "$TMP/out")"

echo "Test 36: a mechanism word that is only a file-extension fragment (erb) does not trivially satisfy rule 3 via the file name itself"
cat > "$TMP/t36.json" <<'EOF'
[{"app_id":"root","rule":"QUA-10","defect_key":"submit.yml.erb:erb-missing-value-unhandled","result":"WARN","severity":"low","evidence":"submit.yml.erb:6,7"}]
EOF
printf '## Draft feedback\n<!-- feedback-covers: submit.yml.erb:erb-missing-value-unhandled -->\nPlease tidy submit.yml.erb.\n' > "$TMP/t36.md"
check "exit 1" 1 "$(run "$TMP/t36.json" "$TMP/t36.md")"
check "reason" 1 "$(grep -cF 'MISSING QUA-10 submit.yml.erb:erb-missing-value-unhandled (defect not described in feedback)' "$TMP/out")"

echo "Test 37: a mechanism word that is only a bare verb (set, from no-set-e) does not trivially satisfy rule 3 via an unrelated command"
cat > "$TMP/t37.json" <<'EOF'
[{"app_id":"root","rule":"QUA-03","defect_key":"template/script.sh.erb:no-set-e","result":"FAIL","severity":"low","evidence":"template/script.sh.erb:1"}]
EOF
printf '## Draft feedback\n<!-- feedback-covers: template/script.sh.erb:no-set-e -->\nIn template/script.sh.erb, remove set -x on line 19.\n' > "$TMP/t37.md"
check "exit 1" 1 "$(run "$TMP/t37.json" "$TMP/t37.md")"
check "reason" 1 "$(grep -cF 'MISSING QUA-03 template/script.sh.erb:no-set-e (defect not described in feedback)' "$TMP/out")"

echo "Test 38: rule 3's phrase fallback — a negation-stripped mechanism-tag phrase ('set -e', from tag 'no-set-e') found consecutively in the window describes the defect, even though 'set' alone is a stopword"
printf '## Draft feedback\n<!-- feedback-covers: template/script.sh.erb:no-set-e -->\ntemplate/script.sh.erb does not have set -e.\n' > "$TMP/t38.md"
check "phrase in window: exit 0" 0 "$(run "$TMP/t37.json" "$TMP/t38.md")"
check "reports 1/1" "feedback floor: 1/1 fix-items covered" "$(tail -1 "$TMP/out")"

echo "Test 39: the phrase fallback also matches a leading prefix of a longer tag's word sequence ('commented-out', from tag 'commented-out-code', matched by prose that never says 'code')"
cat > "$TMP/t39.json" <<'EOF'
[{"app_id":"root","rule":"QUA-09","defect_key":"template/script.sh.erb:commented-out-code","result":"WARN","severity":"low","evidence":"template/script.sh.erb:34-95"}]
EOF
printf '## Draft feedback\n<!-- feedback-covers: template/script.sh.erb:commented-out-code -->\ntemplate/script.sh.erb has a commented-out block that should be removed.\n' > "$TMP/t39.md"
check "prefix phrase in window: exit 0" 0 "$(run "$TMP/t39.json" "$TMP/t39.md")"
check "reports 1/1" "feedback floor: 1/1 fix-items covered" "$(tail -1 "$TMP/out")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
