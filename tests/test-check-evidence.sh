#!/usr/bin/env bash
# Test check-evidence.py: every finding's evidence that cites a file:line
# names a real file under --target with the line(s) within its length.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$SCRIPT_DIR/references/check-evidence.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { python3 "$CHECK" "$@" > "$TMP/out" 2>&1; echo $?; }
rec() { # rule defect_key evidence
  printf '{"app_id":"root","rule":"%s","defect_key":"%s","aspect":"x","severity":"low","result":"WARN","summary":"s","evidence":"%s"}' "$1" "$2" "$3"; }
recs() { # rule defect_key evidence summary
  python3 -c 'import json,sys; print(json.dumps({"app_id":"root","rule":sys.argv[1],"defect_key":sys.argv[2],"aspect":"x","severity":"low","result":"WARN","summary":sys.argv[4],"evidence":sys.argv[3]}))' "$1" "$2" "$3" "$4"; }

# a fake target tree: template/script.sh.erb has 5 lines, form.yml has 3
mkdir -p "$TMP/t/template" "$TMP/t/apps/sub"
printf 'a\nb\nc\nd\ne\n' > "$TMP/t/template/script.sh.erb"
printf 'k1: v1\nk2: v2\nk3: v3\n' > "$TMP/t/form.yml"
printf 'x: 1\ny: 2\n' > "$TMP/t/apps/sub/form.yml"
printf 'Title\nBody text.\n' > "$TMP/t/README.md"

echo "Test 1: valid file:line and file:line-line pass"

printf '[%s,%s]' \
  "$(rec QUA-02 template/script.sh.erb:hardcoded-path template/script.sh.erb:3)" \
  "$(rec OODT-01 submit.yml.erb:unsanitized-input template/script.sh.erb:2-4)" \
  > "$TMP/ok.json"
check "exit 0" 0 "$(run "$TMP/ok.json" --target "$TMP/t")"
check "summary" "evidence: 2/2 valid" "$(tail -1 "$TMP/out")"

echo "Test 2: line number past EOF is BAD"
printf '[%s]' "$(rec QUA-02 template/script.sh.erb:hardcoded-path template/script.sh.erb:99)" > "$TMP/a.json"
check "exit 1" 1 "$(run "$TMP/a.json" --target "$TMP/t")"
check "reason" 1 "$(grep -cF "BAD QUA-02 template/script.sh.erb:hardcoded-path template/script.sh.erb:99 (line 99 past end of file, has 5 lines)" "$TMP/out")"

echo "Test 3: missing file is BAD"
printf '[%s]' "$(rec QUA-02 nope.yml:hardcoded-path nope.yml:1)" > "$TMP/b.json"
check "exit 1" 1 "$(run "$TMP/b.json" --target "$TMP/t")"
check "reason" 1 "$(grep -cF "BAD QUA-02 nope.yml:hardcoded-path nope.yml:1 (file not found (case-exact))" "$TMP/out")"

echo "Test 4: a non-file:line phrase is allowed as-is"
printf '[%s,%s]' \
  "$(rec MNT-02 root:no-releases 'GitHub releases API: 0')" \
  "$(rec STR-01 LICENSE:missing-license '(no file)')" \
  > "$TMP/c.json"
check "exit 0" 0 "$(run "$TMP/c.json" --target "$TMP/t")"
check "summary" "evidence: 2/2 valid" "$(tail -1 "$TMP/out")"

echo "Test 5: a pseudo-anchor with a line number is BAD when it does not exist as a real file"
printf '[%s,%s]' \
  "$(rec MNT-02 releases:no-releases releases:3)" \
  "$(rec MNT-01 commits:stale commits:1-2)" \
  > "$TMP/d.json"
check "exit 1" 1 "$(run "$TMP/d.json" --target "$TMP/t")"
check "releases reason" 1 "$(grep -cF "BAD MNT-02 releases:no-releases releases:3 (pseudo-anchor, not a file)" "$TMP/out")"
check "commits reason" 1 "$(grep -cF "BAD MNT-01 commits:stale commits:1-2 (pseudo-anchor, not a file)" "$TMP/out")"

echo "Test 5b: a pseudo-anchor that IS also a real, case-exact file validates like any other path"
printf '[%s]' "$(rec QUA-06 README.md:readme-typo README.md:2)" > "$TMP/d1.json"
check "README.md:2 against a real 2-line README exit 0" 0 "$(run "$TMP/d1.json" --target "$TMP/t")"
check "summary" "evidence: 1/1 valid" "$(tail -1 "$TMP/out")"
printf '[%s]' "$(rec QUA-06 README.md:readme-typo README.md:99)" > "$TMP/d2.json"
check "README.md:99 past EOF is still BAD, not pseudo-anchor-BAD" 1 "$(run "$TMP/d2.json" --target "$TMP/t")"
check "reason is line-past-EOF, not pseudo-anchor" 1 "$(grep -cF "BAD QUA-06 README.md:readme-typo README.md:99 (line 99 past end of file, has 2 lines)" "$TMP/out")"
printf '[%s]' "$(rec MNT-02 releases:no-releases releases:1)" > "$TMP/d3.json"
check "releases:1 is still BAD (no real 'releases' file in target)" 1 "$(run "$TMP/d3.json" --target "$TMP/t")"
check "releases reason unchanged" 1 "$(grep -cF "BAD MNT-02 releases:no-releases releases:1 (pseudo-anchor, not a file)" "$TMP/out")"
printf '[%s]' "$(rec QUA-06 README.md:readme-typo README.md:2)" > "$TMP/d4.json"
check "without --target a pseudo-anchor citing a line stays BAD (can't tell if it's a real file)" 1 "$(run "$TMP/d4.json")"
check "format-only reason" 1 "$(grep -cF "BAD QUA-06 README.md:readme-typo README.md:2 (pseudo-anchor, not a file)" "$TMP/out")"

echo "Test 6: a monorepo subpath resolves under the target root"
printf '[%s]' "$(rec QUA-06 apps/sub/form.yml:duplicate-key apps/sub/form.yml:2)" > "$TMP/e.json"
check "exit 0" 0 "$(run "$TMP/e.json" --target "$TMP/t")"
check "summary" "evidence: 1/1 valid" "$(tail -1 "$TMP/out")"

echo "Test 7: a range whose end is past EOF is BAD"
printf '[%s]' "$(rec QUA-02 form.yml:hardcoded-path form.yml:2-10)" > "$TMP/f.json"
check "exit 1" 1 "$(run "$TMP/f.json" --target "$TMP/t")"
check "reason" 1 "$(grep -cF "BAD QUA-02 form.yml:hardcoded-path form.yml:2-10 (line 10 past end of file, has 3 lines)" "$TMP/out")"

echo "Test 8: unreadable input is exit 2"
check "exit 2" 2 "$(run "$TMP/nope.json" --target "$TMP/t")"

echo "Test 9: no --target given skips existence/line checks (format only)"
printf '[%s]' "$(rec QUA-02 anywhere.yml:hardcoded-path anywhere.yml:1)" > "$TMP/g.json"
check "exit 0 without target" 0 "$(run "$TMP/g.json")"

echo "Test 10: a --target that is not a directory is exit 2"
printf '[%s]' "$(rec QUA-02 form.yml:hardcoded-path form.yml:1)" > "$TMP/h.json"
check "nonexistent target exit 2" 2 "$(run "$TMP/h.json" --target /nonexistent)"
check "nonexistent target message" 1 "$(grep -c "^error: --target is not a directory: '/nonexistent'$" "$TMP/out")"

echo "Test 11: non-list input is exit 2, no traceback"
echo '{"findings":[]}' > "$TMP/i.json"
check "object top level exit 2" 2 "$(run "$TMP/i.json" --target "$TMP/t")"
check "no traceback" 0 "$(grep -c Traceback "$TMP/out")"

echo "Test 12: line 0 is BAD (files are 1-indexed)"
printf '[%s]' "$(rec QUA-02 form.yml:hardcoded-path form.yml:0)" > "$TMP/j.json"
check "exit 1" 1 "$(run "$TMP/j.json" --target "$TMP/t")"
check "reason" 1 "$(grep -cF "BAD QUA-02 form.yml:hardcoded-path form.yml:0 (line 0 past end of file, has 3 lines)" "$TMP/out")"

echo "Test 13: case-exact existence: readme.md is BAD (real file is README.md, a pseudo-anchor only in its real case), README.md is OK"
printf 'Title\nBody text.\n' > "$TMP/t/README.md"
printf '[%s]' "$(rec QUA-06 readme.md:readme-typo readme.md:2)" > "$TMP/k.json"
check "exit 1" 1 "$(run "$TMP/k.json" --target "$TMP/t")"
check "reason" 1 "$(grep -cF "BAD QUA-06 readme.md:readme-typo readme.md:2 (file not found (case-exact))" "$TMP/out")"
printf '[%s]' "$(rec QUA-06 Form.yml:case-typo Form.yml:2)" > "$TMP/k2.json"
check "different-case form.yml exit 1" 1 "$(run "$TMP/k2.json" --target "$TMP/t")"
check "different-case form.yml reason" 1 "$(grep -cF "BAD QUA-06 Form.yml:case-typo Form.yml:2 (file not found (case-exact))" "$TMP/out")"
printf '[%s]' "$(rec QUA-06 form.yml:case-typo form.yml:2)" > "$TMP/k3.json"
check "exact-case form.yml exit 0" 0 "$(run "$TMP/k3.json" --target "$TMP/t")"

echo "Test 14: trailing colon-junk after the citation is ignored; the first path:line run is validated"
printf '[%s]' "$(rec QUA-02 form.yml:hardcoded-path form.yml:2:extra)" > "$TMP/l.json"
check "exit 0" 0 "$(run "$TMP/l.json" --target "$TMP/t")"
printf '[%s]' "$(rec QUA-02 form.yml:hardcoded-path form.yml:999:x)" > "$TMP/l2.json"
check "exit 1" 1 "$(run "$TMP/l2.json" --target "$TMP/t")"
check "reason" 1 "$(grep -cF "BAD QUA-02 form.yml:hardcoded-path form.yml:999:x (line 999 past end of file, has 3 lines)" "$TMP/out")"

echo "Test 15: path hygiene: absolute or traversal paths are BAD without touching the real filesystem"
printf '[%s]' "$(rec QUA-02 hack:traversal ../x.yml:1)" > "$TMP/m.json"
check "exit 1" 1 "$(run "$TMP/m.json" --target "$TMP/t")"
check "reason" 1 "$(grep -cF "BAD QUA-02 hack:traversal ../x.yml:1 (path is not repo-relative)" "$TMP/out")"
printf '[%s]' "$(rec QUA-02 hack:absolute /etc/passwd:1)" > "$TMP/n.json"
check "exit 1" 1 "$(run "$TMP/n.json" --target "$TMP/t")"
check "reason" 1 "$(grep -cF "BAD QUA-02 hack:absolute /etc/passwd:1 (path is not repo-relative)" "$TMP/out")"

echo "Test 16: a file over 5 MB is not read for a line count; the citation passes and the summary says so"
python3 -c "
with open('$TMP/t/big.yml', 'wb') as f:
    f.write(b'x\n' * 1)
    f.seek(6 * 1024 * 1024)
    f.write(b'x\n')
"
printf '[%s]' "$(rec QUA-02 big.yml:hardcoded-path big.yml:1)" > "$TMP/o.json"
check "exit 0" 0 "$(run "$TMP/o.json" --target "$TMP/t")"
check "summary mentions the skip" 1 "$(grep -cF "evidence: 1/1 valid (1 line count not checked: file over 5 MB)" "$TMP/out")"

echo "Test 17: every citation group and every comma item is validated, the reviewed-OK segment included"
printf '[%s]' "$(rec OODT-01 template/script.sh.erb:unsanitized-user-input 'template/script.sh.erb:2,999 x; reviewed OK: template/nope.sh:9,23')" > "$TMP/p.json"
check "exit 1" 1 "$(run "$TMP/p.json" --target "$TMP/t")"
check "comma item 999 reported" 1 "$(grep -cF "BAD OODT-01 template/script.sh.erb:unsanitized-user-input template/script.sh.erb:2,999 x; reviewed OK: template/nope.sh:9,23 (template/script.sh.erb: line 999 past end of file, has 5 lines)" "$TMP/out")"
check "reviewed-OK path reported" 1 "$(grep -cF "(template/nope.sh: file not found (case-exact))" "$TMP/out")"
check "counted as one bad finding" "evidence: 0/1 valid" "$(tail -1 "$TMP/out")"
printf '[%s]' "$(rec OODT-01 template/script.sh.erb:unsanitized-user-input 'template/script.sh.erb:2 x; reviewed OK: form.yml:1,3')" > "$TMP/p2.json"
check "all groups valid: exit 0" 0 "$(run "$TMP/p2.json" --target "$TMP/t")"
printf '[%s]' "$(rec OODT-01 template/script.sh.erb:unsanitized-user-input 'template/script.sh.erb:2 x; reviewed OK:template/nope.sh:9')" > "$TMP/p3.json"
check "no space after the reviewed-OK colon: the path is still validated" 1 "$(run "$TMP/p3.json" --target "$TMP/t")"
check "reviewed-OK path without a space reported" 1 "$(grep -cF "(template/nope.sh: file not found (case-exact))" "$TMP/out")"

echo "Test 18: a backtick-wrapped path and a ./ path are the same file"
printf '[%s,%s,%s]' \
  "$(rec QUA-02 template/script.sh.erb:hardcoded-path '`template/script.sh.erb:3`')" \
  "$(rec QUA-02 form.yml:hardcoded-path './form.yml:2 and **form.yml**:3')" \
  "$(rec QUA-02 form.yml:x '`./form.yml`:1')" > "$TMP/q.json"
check "exit 0" 0 "$(run "$TMP/q.json" --target "$TMP/t")"
check "summary" "evidence: 3/3 valid" "$(tail -1 "$TMP/out")"
printf '[%s]' "$(rec QUA-02 form.yml:hardcoded-path '`./form.yml:7`')" > "$TMP/q2.json"
check "backticked ./ path past EOF is BAD" 1 "$(run "$TMP/q2.json" --target "$TMP/t")"
check "reason" 1 "$(grep -cF '(line 7 past end of file, has 3 lines)' "$TMP/out")"

echo "Test 19: prose that looks like host:port or image:tag is not a citation"
printf '[%s]' "$(rec OODT-05 template/script.sh.erb:bind-all-interfaces 'template/script.sh.erb:3 --host 0.0.0.0:5000 image python:3 http://localhost:8080 ruby:3.1')" > "$TMP/r.json"
check "exit 0" 0 "$(run "$TMP/r.json" --target "$TMP/t")"

echo "Test 20: a backtick-quoted value in the summary must be on the cited line"
python3 -c "
with open('$TMP/t/long-README.md', 'w') as f:
    for n in range(1, 131):
        f.write('cluster line {}\n'.format(n) if n != 115 else 'cluster name: odyssey\n')
"
printf '[%s]' "$(recs QUA-02 long-README.md:cluster-name 'long-README.md:115' '`odyssey3` documented at')" > "$TMP/s1.json"
check "exit 1" 1 "$(run "$TMP/s1.json" --target "$TMP/t")"
check "reason" 1 "$(grep -cF 'BAD QUA-02 long-README.md:cluster-name long-README.md:115 (`odyssey3` is not on long-README.md:115)' "$TMP/out")"

python3 -c "
with open('$TMP/t/long-README.md', 'w') as f:
    for n in range(1, 131):
        f.write('cluster line {}\n'.format(n) if n != 115 else 'cluster name: odyssey3\n')
"
printf '[%s]' "$(recs QUA-02 long-README.md:cluster-name 'long-README.md:115' '`odyssey3` documented at')" > "$TMP/s2.json"
check "value present on the cited line: exit 0" 0 "$(run "$TMP/s2.json" --target "$TMP/t")"

echo "Test 20b: a value inside a cited range is found anywhere in the range"
python3 -c "
with open('$TMP/t/long-README.md', 'w') as f:
    for n in range(1, 131):
        f.write('cluster line {}\n'.format(n) if n != 118 else 'cluster name: odyssey3\n')
"
printf '[%s]' "$(recs QUA-02 long-README.md:cluster-name 'long-README.md:110-120' '`odyssey3` documented at')" > "$TMP/s3.json"
check "value on line 118 within a 110-120 range: exit 0" 0 "$(run "$TMP/s3.json" --target "$TMP/t")"

echo "Test 20c: codes, paths, numbers and two-letter tokens are never flagged, even absent"
printf '[%s]' "$(recs QUA-02 long-README.md:notes 'long-README.md:1' 'see `SC2164`, `form.yml`, `42`, and `ab` for details')" > "$TMP/s4.json"
check "exit 0 (no value shape matches)" 0 "$(run "$TMP/s4.json" --target "$TMP/t")"

echo "Test 20d: without --target, the value rule is not checked (nothing to read the line against)"
printf '[%s]' "$(recs QUA-02 long-README.md:cluster-name 'long-README.md:115' '`odyssey3` documented at')" > "$TMP/s5.json"
check "exit 0 without target" 0 "$(run "$TMP/s5.json")"

echo "Test 21: a report table row with a check: marker is scanned the same way (--report)"
python3 -c "
with open('$TMP/t/long-README.md', 'w') as f:
    for n in range(1, 131):
        f.write('cluster line {}\n'.format(n) if n != 115 else 'cluster name: odyssey\n')
"
printf '[]' > "$TMP/empty.json"
cat > "$TMP/report.md" <<'EOF'
## App: SAS (root)

### Portability

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | medium | `odyssey3` documented in the README configuration table | long-README.md:115 |
EOF
check "exit 1" 1 "$(run "$TMP/empty.json" --target "$TMP/t" --report "$TMP/report.md")"
check "reason" 1 "$(grep -cF '(`odyssey3` is not on long-README.md:115)' "$TMP/out")"
check "row summary line" "evidence: 0/0 valid; report rows: 0/1 valid" "$(tail -1 "$TMP/out")"

echo "Test 21b: the same report row with the correct value passes"
python3 -c "
with open('$TMP/t/long-README.md', 'w') as f:
    for n in range(1, 131):
        f.write('cluster line {}\n'.format(n) if n != 115 else 'cluster name: odyssey3\n')
"
check "exit 0" 0 "$(run "$TMP/empty.json" --target "$TMP/t" --report "$TMP/report.md")"
check "row summary line" "evidence: 0/0 valid; report rows: 1/1 valid" "$(tail -1 "$TMP/out")"

echo "Test 21c: a report row with no check: marker is not scanned"
cat > "$TMP/report2.md" <<'EOF'
## App: SAS (root)

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-05 | | WARN | low | copy-paste references `odyssey3` in the changelog | long-README.md:115 |
EOF
python3 -c "
with open('$TMP/t/long-README.md', 'w') as f:
    for n in range(1, 131):
        f.write('cluster line {}\n'.format(n) if n != 115 else 'cluster name: odyssey\n')
"
check "exit 0 (unmarked row skipped)" 0 "$(run "$TMP/empty.json" --target "$TMP/t" --report "$TMP/report2.md")"
check "row summary line" "evidence: 0/0 valid; report rows: 0/0 valid" "$(tail -1 "$TMP/out")"

echo "Test 21d: --report naming an unreadable file is exit 2"
check "exit 2" 2 "$(run "$TMP/empty.json" --target "$TMP/t" --report "$TMP/nope-report.md")"

echo "Test 22: a content: citation must cite a content line"
mkdir -p "$TMP/c"
cat > "$TMP/c/README.md" <<'MD'
# Llama WebUI

Batch Connect app that starts llama-server on a GPU node.

## Current defaults

```text
cluster: tillicum
```

Needs Apptainer and one GPU on the compute node.
Contact: someone@example.edu
MD
printf '[%s]' "$(rec QUA-01 README.md:docs-minimal 'content: README.md:5')" > "$TMP/g1.json"
check "a heading: exit 1" 1 "$(run "$TMP/g1.json" --target "$TMP/c")"
check "a heading: reason" "BAD QUA-01 README.md:docs-minimal content: README.md:5 (README.md:5 is a heading, not content)" "$(head -1 "$TMP/out")"
printf '[%s]' "$(rec QUA-01 README.md:docs-minimal 'content: README.md:8')" > "$TMP/g2.json"
check "inside a fence: exit 1" 1 "$(run "$TMP/g2.json" --target "$TMP/c")"
check "inside a fence: reason" "BAD QUA-01 README.md:docs-minimal content: README.md:8 (README.md:8 is inside a code fence, not content)" "$(head -1 "$TMP/out")"
printf '[%s]' "$(rec QUA-01 README.md:docs-minimal 'content: README.md:12')" > "$TMP/g3.json"
check "a contact line: exit 1" 1 "$(run "$TMP/g3.json" --target "$TMP/c")"
check "a contact line: reason" "BAD QUA-01 README.md:docs-minimal content: README.md:12 (README.md:12 is a contact line, not content)" "$(head -1 "$TMP/out")"
printf '[%s,%s]' "$(rec QUA-01 README.md:docs-minimal 'prerequisites: content: README.md:11')" "$(rec QUA-01 README.md:docs-minimal 'content:README.md:3')" > "$TMP/g4.json"
check "content lines (spaced and unspaced): exit 0" 0 "$(run "$TMP/g4.json" --target "$TMP/c")"
check "summary" "evidence: 2/2 valid" "$(tail -1 "$TMP/out")"
printf '[%s]' "$(rec QUA-01 README.md:docs-minimal 'content: README.md:11-12')" > "$TMP/g5.json"
check "a range: every line must be content: exit 1" 1 "$(run "$TMP/g5.json" --target "$TMP/c")"
printf '[%s]' "$(rec QUA-01 README.md:docs-minimal 'content: README.md:40')" > "$TMP/g6.json"
check "past EOF is the existence reason, once" "BAD QUA-01 README.md:docs-minimal content: README.md:40 (line 40 past end of file, has 12 lines)|evidence: 0/1 valid" "$(run "$TMP/g6.json" --target "$TMP/c" > /dev/null; paste -sd'|' "$TMP/out")"
printf '[%s]' "$(rec QUA-01 README.md:docs-minimal 'README.md:5')" > "$TMP/g7.json"
check "a plain citation of a heading is still fine (the rule is only for content:): exit 0" 0 "$(run "$TMP/g7.json" --target "$TMP/c")"
printf '[%s]' "$(rec QUA-01 README.md:docs-minimal 'content: README.md:5')" > "$TMP/g8.json"
check "without --target a README.md line stays the pseudo-anchor BAD, never a content reason" "BAD QUA-01 README.md:docs-minimal content: README.md:5 (pseudo-anchor, not a file)" "$(run "$TMP/g8.json" > /dev/null; head -1 "$TMP/out")"

echo "Test 22b: --report checks content: citations in the Documentation evidence lines"
cat > "$TMP/g.md" <<'MD'
## App: Llama (root)

### Documentation
- Rating: **Minimal** — x
- Evidence per rung:
  - what it launches: "Batch Connect app" (intro), README.md:3
  - prerequisites: content: README.md:11
  - installation: none
MD
check "a content line in the evidence block: exit 0" 0 "$(run "$TMP/empty.json" --target "$TMP/c" --report "$TMP/g.md")"
check "summary counts it" "evidence: 0/0 valid; report rows: 0/0 valid; content citations: 1/1 valid" "$(tail -1 "$TMP/out")"
sed 's/content: README.md:11/content: README.md:5/' "$TMP/g.md" > "$TMP/g2.md"
check "a heading in the evidence block: exit 1" 1 "$(run "$TMP/empty.json" --target "$TMP/c" --report "$TMP/g2.md")"
check "reason" "BAD report:content content content: README.md:5 (README.md:5 is a heading, not content)" "$(head -1 "$TMP/out")"
sed 's/  - prerequisites: content: README.md:11/  - prerequisites: "Requirements", README.md:5/' "$TMP/g.md" > "$TMP/g3.md"
check "a report with no content: citation keeps the old summary: exit 0" "0|evidence: 0/0 valid; report rows: 0/0 valid" "$(run "$TMP/empty.json" --target "$TMP/c" --report "$TMP/g3.md")|$(tail -1 "$TMP/out")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
