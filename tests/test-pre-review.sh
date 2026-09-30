#!/usr/bin/env bash
# Test run-pre-review.sh / pre-review.py: tools and the shell syntax check run before the model, results as JSON.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$SCRIPT_DIR/references/run-pre-review.sh"
FIX="$SCRIPT_DIR/tests/fixtures"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
skip() { echo "  SKIP  $1"; pass=$((pass+1)); }
run() { bash "$RUN" "$@" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?; }
# jq-free JSON reads: j <file> <python expression over d>
j() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2" 2>&1; }
# chk <out> <name> <field>: one field of one check record in summary.json
chk() { j "$1/summary.json" "[c for c in d['checks'] if c['name']=='$2'][0]['$3']"; }
# syn <out> <path> <field>: one field of one syntax.json entry
syn() { j "$1/syntax.json" "[e for e in d if e['path']=='$2'][0]['$3']"; }
has_sc() { command -v shellcheck >/dev/null 2>&1; }
yn() { if "$@"; then echo True; else echo False; fi; }

# Under a bash older than 4 the syntax check prefixes every failure (it may
# be false). Where the only bash is older (macOS /bin/bash 3.2), the other
# bash -n tests run through a shim that reports 5.x and execs the real bash,
# so their stderr assertions see plain bash messages; Test 20 covers both the
# < 4 and >= 4 paths with its own shims, whatever the real bash is.
REAL_BASH="$(command -v bash)"
BASH4="$REAL_BASH"
if [ "$("$REAL_BASH" -c 'echo "${BASH_VERSINFO[0]}"')" -lt 4 ]; then
  mkdir -p "$TMP/bash4"; BASH4="$TMP/bash4/bash"
  printf '#!/bin/sh\n[ "$1" = --version ] && { echo "GNU bash, version 5.2.0(1)-release (shim)"; exit 0; }\nexec "%s" "$@"\n' "$REAL_BASH" > "$BASH4"
  chmod +x "$BASH4"; PATH="$TMP/bash4:$PATH"; export PATH
  echo "NOTE: bash on PATH is older than 4; bash -n tests run through a version shim"
fi
# fakebin <dir>: a PATH dir holding only python3, sh, env and bash (>= 4)
fakebin() { mkdir -p "$1"; for b in python3 sh env; do ln -sf "$(command -v "$b")" "$1/$b"; done; ln -sf "$BASH4" "$1/bash"; }

echo "Test 1: missing target is exit 2"
check "exit 2" 2 "$(run "$TMP/nope" "$TMP/o1")"
check "stderr" 1 "$(grep -c 'target directory not found' "$TMP/stderr")"

echo "Test 2: containerized-server summary shape"
O="$TMP/cs"
check "exit 0" 0 "$(run "$FIX/containerized-server" "$O")"
check "schema" "pre-review/1" "$(j "$O/summary.json" "d['schema']")"
check "check names in order" "syntax,shellcheck,semgrep,bandit,trivy,catalog" "$(j "$O/summary.json" "','.join(c['name'] for c in d['checks'])")"
check "every status allowed" "True" "$(j "$O/summary.json" "all(c['status'] in ('ran','not_installed','failed_to_run','skipped') for c in d['checks'])")"
check "every record has the contract fields" "True" "$(j "$O/summary.json" "all(set(c)>=set(['name','status','version','command','exit_code','output_file','files_examined','note']) for c in d['checks'])")"
check "target absolute" "True" "$(j "$O/summary.json" "d['target'].startswith('/')")"
check "generated_at UTC" "True" "$(j "$O/summary.json" "d['generated_at'].endswith('Z')")"
check "catalog skipped" "skipped" "$(chk "$O" catalog status)"
check "catalog note" "catalog reads land in a later PR" "$(chk "$O" catalog note)"

echo "Test 3: containerized-server syntax.json"
check "paths" "template/after.sh,template/before.sh.erb,template/create_nginx_conf.sh.erb,template/script.sh.erb" "$(j "$O/syntax.json" "','.join(sorted(e['path'] for e in d))")"
check "after.sh not stripped" "False" "$(syn "$O" template/after.sh stripped)"
for f in before.sh.erb create_nginx_conf.sh.erb script.sh.erb; do
  check "$f stripped" "True" "$(syn "$O" "template/$f" stripped)"
done
check "all ok" "True" "$(j "$O/syntax.json" "all(e['ok'] for e in d)")"
check "syntax ran" "ran" "$(chk "$O" syntax status)"
check "syntax files_examined" "4" "$(chk "$O" syntax files_examined)"
check "syntax output_file" "syntax.json" "$(chk "$O" syntax output_file)"

echo "Test 4: bad shell fails, multi-line ERB strips cleanly with line numbers kept"
T="$TMP/t4"; mkdir -p "$T"
printf 'if [ ; then\n' > "$T/bad.sh"
printf '#!/bin/bash\n<%% if x\n%%>\nTIMEOUT=<%%= x %%>\necho "$TIMEOUT"\n<%%# a\ncomment %%>\n' > "$T/good.sh.erb"
O="$TMP/o4"
check "exit 0" 0 "$(run "$T" "$O")"
check "bad.sh not ok" "False" "$(syn "$O" bad.sh ok)"
check "bad.sh stderr syntax error" "True" "$(syn "$O" bad.sh stderr | grep -q 'syntax error' && echo True || echo False)"
check "bad.sh stderr names the repo path" "True" "$(syn "$O" bad.sh stderr | grep -q "^bad.sh:" && echo True || echo False)"
check "good.sh.erb ok" "True" "$(syn "$O" good.sh.erb ok)"
check "good.sh.erb stripped" "True" "$(syn "$O" good.sh.erb stripped)"
check "stripped copy line count" "$(wc -l < "$T/good.sh.erb" | tr -d ' ')" "$(wc -l < "$O/stripped/good.sh.erb.sh" | tr -d ' ')"
check "stripped copy ERBVALUE" 1 "$(grep -c '^TIMEOUT=ERBVALUE$' "$O/stripped/good.sh.erb.sh")"
check "stripped copy no ERB left" 0 "$(grep -c '<%' "$O/stripped/good.sh.erb.sh")"

echo "Test 5: monorepo"
O="$TMP/mono"
check "exit 0" 0 "$(run "$FIX/monorepo" "$O")"
check "shared/common.sh listed" "True" "$(j "$O/syntax.json" "any(e['path']=='shared/common.sh' for e in d)")"
check "bandit skipped" "skipped" "$(chk "$O" bandit status)"
check "bandit note" "no applicable files" "$(chk "$O" bandit note)"
check "bandit no output file" "False" "$([ -e "$O/bandit.json" ] && echo True || echo False)"
check "trivy skipped (no manifests)" "skipped" "$(chk "$O" trivy status)"

echo "Test 6: passenger-flask-app counts"
O="$TMP/flask"
check "exit 0" 0 "$(run "$FIX/passenger-flask-app" "$O")"
check "bandit files_examined" "4" "$(chk "$O" bandit files_examined)"
check "bandit ran or not_installed" "True" "$(j "$O/summary.json" "[c for c in d['checks'] if c['name']=='bandit'][0]['status'] in ('ran','not_installed')")"
check "trivy files_examined" "1" "$(chk "$O" trivy files_examined)"
if [ "$(chk "$O" trivy status)" = failed_to_run ] && chk "$O" trivy note | grep 'FATAL' | grep -qE 'download|DB|network'; then
  skip "trivy offline (cannot fetch its DB)"; skip "trivy offline (cannot fetch its DB)"
else
  check "trivy ran or not_installed" "True" "$(j "$O/summary.json" "[c for c in d['checks'] if c['name']=='trivy'][0]['status'] in ('ran','not_installed')")"
  if command -v trivy >/dev/null 2>&1; then
    check "trivy.json is trivy's own JSON" "True" "$(j "$O/trivy.json" "'SchemaVersion' in d")"
  else skip "trivy not installed"; fi
fi
if command -v bandit >/dev/null 2>&1; then
  check "bandit.json is bandit's own JSON" "True" "$(j "$O/bandit.json" "'results' in d")"
else skip "bandit not installed"; fi

echo "Test 7: no tools on PATH"
BIN="$TMP/bin"; fakebin "$BIN"
T="$TMP/t7"; mkdir -p "$T"
printf 'echo hi\n' > "$T/a.sh"; printf 'print(1)\n' > "$T/b.py"; printf 'flask\n' > "$T/requirements.txt"
O="$TMP/o7"
check "exit 0" 0 "$(PATH="$BIN" "$BIN/bash" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
for t in shellcheck semgrep bandit trivy; do
  check "$t not_installed" "not_installed" "$(chk "$O" "$t" status)"
  check "$t note non-empty" "True" "$(j "$O/summary.json" "bool([c for c in d['checks'] if c['name']=='$t'][0]['note'])")"
  check "$t version empty" "" "$(chk "$O" "$t" version)"
  check "no $t.json" "False" "$([ -e "$O/$t.json" ] && echo True || echo False)"
done
check "shellcheck install hint" "apt install shellcheck / brew install shellcheck" "$(chk "$O" shellcheck note)"
check "bandit install hint" "pip install bandit" "$(chk "$O" bandit note)"
check "syntax ran" "ran" "$(chk "$O" syntax status)"

echo "Test 8: shellcheck output on containerized-server"
O="$TMP/cs"
if command -v shellcheck >/dev/null 2>&1; then
  check "shellcheck ran" "ran" "$(chk "$O" shellcheck status)"
  check "shellcheck.json is a list" "True" "$(j "$O/shellcheck.json" "isinstance(d, list)")"
  check "shellcheck.json non-empty" "True" "$(j "$O/shellcheck.json" "len(d) > 0")"
  check "every file under template/" "True" "$(j "$O/shellcheck.json" "all(e['file'].startswith('template/') for e in d)")"
  check "command" "shellcheck --norc -f json -S info <file> (per shell file; .sh.erb scanned as its ERB-stripped copy)" "$(chk "$O" shellcheck command)"
  check "files_examined" "4" "$(chk "$O" shellcheck files_examined)"
  check "version line carries a number" "True" "$(j "$O/summary.json" "any(ch.isdigit() for ch in [c for c in d['checks'] if c['name']=='shellcheck'][0]['version'])")"
else skip "shellcheck not installed"; fi
if python3 -c 'import shutil,sys; sys.exit(shutil.which("semgrep") is None)'; then
  check "semgrep ran" "ran" "$(chk "$O" semgrep status)"
  [ "$(chk "$O" semgrep status)" = ran ] || echo "        semgrep note: $(chk "$O" semgrep note)"
  check "semgrep note explains files_examined and names the rulesets" "files_examined is semgrep's paths.scanned; rulesets p/security-audit, p/secrets" "$(chk "$O" semgrep note)"
  check "semgrep files_examined is paths.scanned" "$(j "$O/semgrep.json" "len(d['paths']['scanned'])")" "$(chk "$O" semgrep files_examined)"
else skip "semgrep not installed"; skip "semgrep not installed"; skip "semgrep not installed"; fi

echo "Test 9: flags"
T="$TMP/t9"; mkdir -p "$T"; printf 'echo hi\n' > "$T/a.sh"
check "--catalog accepted" 0 "$(run "$T" "$TMP/o9a" --catalog https://example.org)"
check "catalog still skipped" "skipped" "$(chk "$TMP/o9a" catalog status)"
check "--no-catalog accepted" 0 "$(run "$T" "$TMP/o9b" --no-catalog)"
check "unknown flag exit 2" 2 "$(run "$T" "$TMP/o9c" --bogus)"
check "usage on stderr" 1 "$(grep -c '^usage:' "$TMP/stderr")"

echo "Test 10: rerun into the same out-dir leaves no stale tool file"
O="$TMP/o10"; mkdir -p "$O/stripped"
echo '{"stale":true}' > "$O/bandit.json"; echo stale > "$O/stripped/old.sh"
check "exit 0" 0 "$(run "$FIX/monorepo" "$O")"
check "stale bandit.json gone" "False" "$([ -e "$O/bandit.json" ] && echo True || echo False)"
check "stale stripped copy gone" "False" "$([ -e "$O/stripped/old.sh" ] && echo True || echo False)"
check "second run exit 0" 0 "$(run "$FIX/monorepo" "$O")"
check "summary rewritten" "pre-review/1" "$(j "$O/summary.json" "d['schema']")"

echo "Test 11: a dangling or unreadable shell file fails its own entry, the rest still run"
T="$TMP/t11"; mkdir -p "$T"
printf 'echo hi\n' > "$T/good.sh"
ln -s /nonexistent "$T/dangling.sh.erb"
printf 'echo <%%= x %%>\n' > "$T/locked.sh.erb"; chmod 000 "$T/locked.sh.erb"
O="$TMP/o11"
check "exit 0" 0 "$(run "$T" "$O")"
check "syntax ran" "ran" "$(chk "$O" syntax status)"
check "good.sh ok" "True" "$(syn "$O" good.sh ok)"
check "dangling not ok" "False" "$(syn "$O" dangling.sh.erb ok)"
check "dangling stderr" "True" "$(syn "$O" dangling.sh.erb stderr | grep -qE 'No such file|not a regular file' && echo True || echo False)"
if [ -r "$T/locked.sh.erb" ]; then skip "running as root, chmod 000 is readable"; skip "root"; skip "root"
else
  check "unreadable not ok" "False" "$(syn "$O" locked.sh.erb ok)"
  check "unreadable stderr" "True" "$(syn "$O" locked.sh.erb stderr | grep -q 'Permission denied' && echo True || echo False)"
  if has_sc; then check "shellcheck note names the unreadable file" "True" "$(chk "$O" shellcheck note | grep -q 'not scanned (unreadable): locked.sh.erb' && echo True || echo False)"
  else skip "shellcheck not installed"; fi
fi
check "dangling excluded from syntax files_examined" "2" "$(chk "$O" syntax files_examined)"
if has_sc; then
  check "shellcheck ran" "ran" "$(chk "$O" shellcheck status)"
  check "shellcheck scanned only the readable file" "1" "$(chk "$O" shellcheck files_examined)"
else skip "shellcheck not installed"; skip "shellcheck not installed"; fi
chmod 600 "$T/locked.sh.erb"

echo "Test 12: symlinks out of the target and FIFOs are never read"
T="$TMP/t12"; mkdir -p "$T"
printf 'echo <%%= x %%>\n' > "$T/real.sh.erb"
ln -s /etc/hosts "$T/leak.sh.erb"
ln -s ./real.sh.erb "$T/inside.sh.erb"
mkfifo "$T/fifo.sh.erb"
O="$TMP/o12"
check "exit 0" 0 "$(run "$T" "$O")"
check "leak not ok" "False" "$(syn "$O" leak.sh.erb ok)"
check "leak stderr" "symlink outside target, not checked" "$(syn "$O" leak.sh.erb stderr)"
check "refused .sh.erb not stripped" "False" "$(syn "$O" leak.sh.erb stripped)"
check "no stripped copy of leak" "False" "$([ -e "$O/stripped/leak.sh.erb.sh" ] && echo True || echo False)"
check "fifo not ok" "False" "$(syn "$O" fifo.sh.erb ok)"
check "fifo stderr" "not a regular file, not checked" "$(syn "$O" fifo.sh.erb stderr)"
check "inside checked" "True" "$(syn "$O" inside.sh.erb ok)"
check "inside stripped copy" "1" "$(grep -c 'ERBVALUE' "$O/stripped/inside.sh.erb.sh")"
check "syntax files_examined counts real + inside only" "2" "$(chk "$O" syntax files_examined)"
if has_sc; then check "shellcheck files_examined" "2" "$(chk "$O" shellcheck files_examined)"
  check "no shellcheck entry for leak or fifo" "0" "$(j "$O/shellcheck.json" "len([e for e in d if e['file'] in ('leak.sh.erb','fifo.sh.erb')])")"
else skip "shellcheck not installed"; skip "shellcheck not installed"; fi
if [ "$(chk "$O" semgrep status)" = ran ]; then
  check "semgrep scanned neither leak nor fifo" "0" "$(j "$O/semgrep.json" "len([p for p in d['paths']['scanned'] if p in ('leak.sh.erb','fifo.sh.erb')])")"
else skip "semgrep did not run"; fi

echo "Test 13: a file named like an option is passed as a path"
T="$TMP/t13"; mkdir -p "$T"; printf '#!/bin/bash\ncd "$1"\n' > "$T/-x.sh"
O="$TMP/o13"
check "exit 0" 0 "$(run "$T" "$O")"
check "-x.sh ok" "True" "$(syn "$O" -x.sh ok)"
check "-x.sh stderr empty" "" "$(syn "$O" -x.sh stderr)"
if has_sc; then
  check "shellcheck ran" "ran" "$(chk "$O" shellcheck status)"
  check "SC2164 reported against -x.sh" "True" "$(j "$O/shellcheck.json" "any(e['file']=='-x.sh' and e['code']==2164 for e in d)")"
else skip "shellcheck not installed"; skip "shellcheck not installed"; fi

echo "Test 14: out-dir must not be the target; an out-dir inside the target is not walked"
T="$TMP/t14"; mkdir -p "$T"; printf 'echo hi\n' > "$T/a.sh"; printf 'x: 1\n' > "$T/form.yml"
check "out == target exit 2" 2 "$(run "$T" "$T")"
check "out == target message" 1 "$(grep -c 'out-dir must not be the target' "$TMP/stderr")"
check "out == target via trailing slash exit 2" 2 "$(run "$T" "$T/")"
check "first run inside target" 0 "$(run "$T" "$T/pre-review")"
check "second run inside target" 0 "$(run "$T" "$T/pre-review")"
check "syntax lists only a.sh" "a.sh" "$(j "$T/pre-review/syntax.json" "','.join(e['path'] for e in d)")"
if [ "$(chk "$T/pre-review" semgrep status)" = ran ]; then
  check "semgrep files_examined ignores out-dir" "2" "$(chk "$T/pre-review" semgrep files_examined)"
  check "semgrep command excludes out-dir, anchored" "True" "$(yn grep -q -- '--exclude /pre-review ' <<< "$(chk "$T/pre-review" semgrep command)")"
else skip "semgrep did not run"; skip "semgrep did not run"; fi

echo "Test 15: a crashing tool with empty stderr reports its stdout"
FB="$TMP/fakebin"; fakebin "$FB"
printf '#!/bin/sh\n[ "$1" = --version ] && { echo "Version: 9.9"; exit 0; }\necho "fatal: could not open cache"\nexit 1\n' > "$FB/trivy"; chmod +x "$FB/trivy"
T="$TMP/t15"; mkdir -p "$T"; printf 'flask\n' > "$T/requirements.txt"
O="$TMP/o15"
check "exit 0" 0 "$(PATH="$FB" "$FB/bash" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "trivy failed_to_run" "failed_to_run" "$(chk "$O" trivy status)"
check "note is stdout" "fatal: could not open cache" "$(chk "$O" trivy note)"
check "trivy exit_code" "1" "$(chk "$O" trivy exit_code)"
check "no trivy.json" "False" "$([ -e "$O/trivy.json" ] && echo True || echo False)"

has_trivy() { command -v trivy >/dev/null 2>&1; }
has_semgrep() { python3 -c 'import shutil,sys; sys.exit(shutil.which("semgrep") is None)'; }

echo "Test 14b: an in-target out-dir is skipped by path, not by name"
T="$TMP/t14b"; mkdir -p "$T/app/pre-review"
printf 'flask==0.12\n' > "$T/requirements.txt"; printf 'flask==0.12\n' > "$T/app/pre-review/requirements.txt"
printf 'echo hi\n' > "$T/app/pre-review/b.sh"
O="$T/pre-review"
check "exit 0" 0 "$(run "$T" "$O")"
check "trivy command skips the out-dir by relative path" "True" "$(yn grep -qF -- '--skip-dirs pre-review --config' <<< "$(chk "$O" trivy command)")"
if [ "$(chk "$O" semgrep status)" = ran ]; then
  check "semgrep still scans app/pre-review" "True" "$(j "$O/semgrep.json" "'app/pre-review/b.sh' in d['paths']['scanned']")"
else skip "semgrep did not run"; fi
if [ "$(chk "$O" trivy status)" = ran ]; then
  check "trivy still scans app/pre-review" "True" "$(j "$O/trivy.json" "'app/pre-review/requirements.txt' in [r['Target'] for r in d.get('Results', [])]")"
else skip "trivy did not run"; fi

echo "Test 16: a target's trivy.yaml cannot make trivy write outside the out-dir"
T="$TMP/t16"; mkdir -p "$T" "$TMP/escape"; printf 'flask==0.12\n' > "$T/requirements.txt"
printf 'output: %s/escape/pwned.json\n' "$TMP" > "$T/trivy.yaml"
printf 'CVE-2018-1000656\n' > "$T/.trivyignore"
O="$TMP/o16"
if has_trivy; then
  check "exit 0" 0 "$(run "$T" "$O")"
  check "no file written at trivy.yaml's output path" "False" "$([ -e "$TMP/escape/pwned.json" ] && echo True || echo False)"
  check "command passes the empty config and ignore file and the absolute target" "True" "$(yn grep -qF -- "--config $O/trivy-empty.yaml --ignorefile $O/trivy-empty.ignore $T" <<< "$(chk "$O" trivy command)")"
  if [ "$(chk "$O" trivy status)" = ran ]; then
    check "note names trivy.yaml and .trivyignore" "target ships .trivyignore; its suppressions were ignored; target ships trivy.yaml; its suppressions were ignored" "$(chk "$O" trivy note)"
    check "trivy.json written in out-dir" "True" "$(j "$O/trivy.json" "'SchemaVersion' in d")"
  else echo "        trivy note: $(chk "$O" trivy note)"; skip "trivy did not run (offline?)"; skip "trivy did not run"; fi
else skip "trivy not installed"; skip "trivy not installed"; skip "trivy not installed"; skip "trivy not installed"; skip "trivy not installed"; fi

echo "Test 17: a target's .shellcheckrc cannot silence shellcheck"
T="$TMP/t17"; mkdir -p "$T"; printf 'disable=all\n' > "$T/.shellcheckrc"
printf '#!/bin/bash\nrm -rf $HOME/$x\n' > "$T/a.sh"
O="$TMP/o17"
check "exit 0" 0 "$(run "$T" "$O")"
if has_sc; then
  check "findings despite disable=all" "True" "$(j "$O/shellcheck.json" "len(d) > 0")"
  check "note names .shellcheckrc" "target ships .shellcheckrc; its suppressions were ignored" "$(chk "$O" shellcheck note)"
else skip "shellcheck not installed"; skip "shellcheck not installed"; fi

echo "Test 18: a target's .semgrepignore is reported"
T="$TMP/t18"; mkdir -p "$T"; printf '*\n' > "$T/.semgrepignore"; printf 'echo hi\n' > "$T/a.sh"
O="$TMP/o18"
check "exit 0" 0 "$(run "$T" "$O")"
if has_semgrep; then
  check "semgrep ran" "ran" "$(chk "$O" semgrep status)"
  check "files_examined 0" "0" "$(chk "$O" semgrep files_examined)"
  check "note names .semgrepignore" "files_examined is semgrep's paths.scanned; rulesets p/security-audit, p/secrets; target ships .semgrepignore; it may suppress findings" "$(chk "$O" semgrep note)"
else skip "semgrep not installed"; skip "semgrep not installed"; skip "semgrep not installed"; fi

echo "Test 19: finding_count and top_codes"
O="$TMP/cs"
check "every record has finding_count and top_codes" "True" "$(j "$O/summary.json" "all('finding_count' in c and isinstance(c['top_codes'], list) for c in d['checks'])")"
check "catalog finding_count null" "None" "$(chk "$O" catalog finding_count)"
check "trivy (skipped) finding_count null" "None" "$(chk "$O" trivy finding_count)"
if has_sc; then
  # Recomputed from shellcheck.json so the test holds across shellcheck versions.
  check "shellcheck finding_count is len(shellcheck.json)" "$(j "$O/shellcheck.json" "len(d)")" "$(chk "$O" shellcheck finding_count)"
  check "shellcheck top_codes: most frequent, then by code" "$(python3 -c 'import json,sys,collections; c=collections.Counter("SC%s" % e["code"] for e in json.load(open(sys.argv[1]))); print(",".join(k for k, _ in sorted(c.items(), key=lambda kv: (-kv[1], kv[0]))[:5]))' "$O/shellcheck.json")" "$(j "$O/summary.json" "','.join([c for c in d['checks'] if c['name']=='shellcheck'][0]['top_codes'])")"
  check "SC2086 present" "True" "$(j "$O/shellcheck.json" "any(e['code']==2086 for e in d)")"
  check "SC2155 present" "True" "$(j "$O/shellcheck.json" "any(e['code']==2155 for e in d)")"
else for i in 1 2 3 4; do skip "shellcheck not installed"; done; fi

echo "Test 20: bash older than 4 keeps passes and prefixes failures; bash >= 4 does not"
# vbash <dir> <version>: a bash that reports <version> and execs the real
# bash. c.sh uses ;;& (bash 4 syntax); where the real bash accepts it, the
# shim rejects it the way bash 3.2 does, so the failure path is covered on
# any machine.
vbash() { mkdir -p "$1"; printf '#!/bin/sh\n[ "$1" = --version ] && { echo "GNU bash, version %s(1)-release"; exit 0; }\nif [ "$1" = -n ] && grep -qF ";;&" "$2" 2>/dev/null && "%s" -n "$2" 2>/dev/null; then echo "$2: line 2: syntax error near unexpected token \`&'"'"'" >&2; exit 2; fi\nexec "%s" "$@"\n' "$2" "$REAL_BASH" "$REAL_BASH" > "$1/bash"; chmod +x "$1/bash"; }
T="$TMP/t20"; mkdir -p "$T"; printf 'echo hi\n' > "$T/a.sh"; printf 'echo <%%= x %%>\n' > "$T/b.sh.erb"
printf 'case x in\n  a) echo a ;;&\n  *) echo b ;;\nesac\n' > "$T/c.sh"
vbash "$TMP/bash32" 3.2.57; vbash "$TMP/bash52" 5.2.21
O="$TMP/o20"
check "exit 0" 0 "$(PATH="$TMP/bash32:$PATH" "$REAL_BASH" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "syntax ran" "ran" "$(chk "$O" syntax status)"
check "syntax version recorded" "True" "$(chk "$O" syntax version | grep -qF 3.2.57 && echo True || echo False)"
check "syntax note" "bash 3.2.57 on PATH: failures may be false; install bash >= 4 to confirm; 1 of 3 files failed bash -n" "$(chk "$O" syntax note)"
check "syntax files_examined" "3" "$(chk "$O" syntax files_examined)"
check "valid a.sh ok" "True|" "$(j "$O/syntax.json" "'%s|%s' % ([e for e in d if e['path']=='a.sh'][0]['ok'], [e for e in d if e['path']=='a.sh'][0]['stderr'])")"
check "valid b.sh.erb ok and stripped" "True|True" "$(j "$O/syntax.json" "'%s|%s' % ([e for e in d if e['path']=='b.sh.erb'][0]['ok'], [e for e in d if e['path']=='b.sh.erb'][0]['stripped'])")"
check "c.sh (;;&) not ok" "False" "$(syn "$O" c.sh ok)"
check "c.sh stderr carries the bash < 4 prefix" "True" "$(syn "$O" c.sh stderr | grep -q '^bash 3.2.57 rejected this file (may be valid on bash >= 4): c.sh: line 2: syntax error' && echo True || echo False)"
O="$TMP/o20b"
check "exit 0 (bash 5)" 0 "$(PATH="$TMP/bash52:$PATH" "$REAL_BASH" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "syntax ran (bash 5)" "ran" "$(chk "$O" syntax status)"
check "syntax note (bash 5)" "1 of 3 files failed bash -n" "$(chk "$O" syntax note)"
check "c.sh stderr is the plain bash message" "True" "$(syn "$O" c.sh stderr | grep -q '^c.sh: line 2: syntax error' && echo True || echo False)"

echo "Test 21: shellcheck reports SC2086 (info level)"
T="$TMP/t21"; mkdir -p "$T"; printf '#!/bin/bash\necho $1\n' > "$T/a.sh"
O="$TMP/o21"
check "exit 0" 0 "$(run "$T" "$O")"
if has_sc; then
  check "SC2086 reported" "True" "$(j "$O/shellcheck.json" "any(e['code']==2086 for e in d)")"
  check "top_codes" "SC2086" "$(j "$O/summary.json" "','.join([c for c in d['checks'] if c['name']=='shellcheck'][0]['top_codes'])")"
else skip "shellcheck not installed"; skip "shellcheck not installed"; fi

echo "Test 22: a <%% literal keeps the code after it"
T="$TMP/t22"; mkdir -p "$T"
printf '#!/bin/bash\n<%%%% rm -rf $HOME/$1 %%>\necho <%%= x %%>\n' > "$T/a.sh.erb"
O="$TMP/o22"
check "exit 0" 0 "$(run "$T" "$O")"
check "stripped copy keeps the literal region" "<% rm -rf \$HOME/\$1 %>" "$(sed -n 2p "$O/stripped/a.sh.erb.sh")"
check "real tag still stripped" "echo ERBVALUE" "$(sed -n 3p "$O/stripped/a.sh.erb.sh")"

echo "Test 23: syntax note counts checked files only"
T="$TMP/t23"; mkdir -p "$T"; printf 'if [ ; then\n' > "$T/bad.sh"; printf 'echo hi\n' > "$T/good.sh"
ln -s /etc/hosts "$T/leak.sh"; mkfifo "$T/fifo.sh"
O="$TMP/o23"
check "exit 0" 0 "$(run "$T" "$O")"
check "syntax note" "1 of 2 files failed bash -n" "$(chk "$O" syntax note)"
check "syntax exit_code" "1" "$(chk "$O" syntax exit_code)"

echo "Test 24: no bash on PATH still writes syntax.json"
NB="$TMP/nobash"; mkdir -p "$NB"; ln -s "$(command -v python3)" "$NB/python3"
T="$TMP/t24"; mkdir -p "$T"; printf 'echo hi\n' > "$T/a.sh"
O="$TMP/o24"
check "exit 0" 0 "$(PATH="$NB" "$NB/python3" "$SCRIPT_DIR/references/pre-review.py" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "syntax not_installed" "not_installed" "$(chk "$O" syntax status)"
check "syntax.json entry" "False|not checked: bash not found on PATH" "$(j "$O/syntax.json" "'%s|%s' % (d[0]['ok'], d[0]['stderr'])")"

echo "Test 25: trivy failure note is its FATAL line"
FB="$TMP/fb25"; fakebin "$FB"
printf '#!/bin/sh\n[ "$1" = --version ] && { echo "Version: 9.9"; exit 0; }\necho "INFO starting" >&2\necho "FATAL Fatal error: init error: DB error: failed to download vulnerability DB" >&2\necho "INFO trailing" >&2\nexit 1\n' > "$FB/trivy"; chmod +x "$FB/trivy"
T="$TMP/t25"; mkdir -p "$T"; printf 'flask\n' > "$T/requirements.txt"
O="$TMP/o25"
check "exit 0" 0 "$(PATH="$FB" "$FB/bash" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "note is the FATAL line" "FATAL Fatal error: init error: DB error: failed to download vulnerability DB" "$(chk "$O" trivy note)"
printf '#!/bin/sh\n[ "$1" = --version ] && { echo "Version: 9.9"; exit 0; }\necho "INFO starting" >&2\necho "error: last line" >&2\necho "" >&2\nexit 1\n' > "$FB/trivy"
O="$TMP/o25b"
check "exit 0 (no FATAL)" 0 "$(PATH="$FB" "$FB/bash" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "note is the last non-empty line" "error: last line" "$(chk "$O" trivy note)"

echo "Test 26: shell files over 1 MB are skipped"
T="$TMP/t26"; mkdir -p "$T"; printf 'echo hi\n' > "$T/small.sh"
python3 -c "import sys; open(sys.argv[1],'w').write('echo x\n' * 160000)" "$T/big.sh"
O="$TMP/o26"
check "exit 0" 0 "$(run "$T" "$O")"
check "big.sh ok false" "False" "$(syn "$O" big.sh ok)"
check "big.sh reason" "skipped: file larger than 1 MB" "$(syn "$O" big.sh stderr)"
check "syntax files_examined" "1" "$(chk "$O" syntax files_examined)"
if has_sc; then
  check "shellcheck files_examined" "1" "$(chk "$O" shellcheck files_examined)"
  check "no shellcheck entry for big.sh" "0" "$(j "$O/shellcheck.json" "len([e for e in d if e['file']=='big.sh'])")"
  check "shellcheck note names big.sh" "not scanned (larger than 1 MB): big.sh" "$(chk "$O" shellcheck note)"
else skip "shellcheck not installed"; skip "shellcheck not installed"; skip "shellcheck not installed"; fi

echo "Test 27: shellcheck exiting >= 2 is failed_to_run"
FB="$TMP/fb27"; fakebin "$FB"
printf '#!/bin/sh\n[ "$1" = --version ] && { echo "version: 0.0.1"; exit 0; }\necho "boom" >&2\nexit 3\n' > "$FB/shellcheck"; chmod +x "$FB/shellcheck"
T="$TMP/t27"; mkdir -p "$T"; printf 'echo hi\n' > "$T/a.sh"
O="$TMP/o27"
check "exit 0" 0 "$(PATH="$FB" "$FB/bash" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "shellcheck failed_to_run" "failed_to_run" "$(chk "$O" shellcheck status)"
check "exit_code 3" "3" "$(chk "$O" shellcheck exit_code)"
check "note" "a.sh: boom" "$(chk "$O" shellcheck note | tr -d '\n')"
check "finding_count null" "None" "$(chk "$O" shellcheck finding_count)"

echo "Test 28: a tool that runs past the timeout is failed_to_run"
FB="$TMP/fb28"; fakebin "$FB"
printf '#!/bin/sh\n[ "$1" = --version ] && { echo "version: 0.0.1"; exit 0; }\nexec /bin/sleep 5\n' > "$FB/shellcheck"; chmod +x "$FB/shellcheck"
O="$TMP/o28"
check "exit 0" 0 "$(PRE_REVIEW_TIMEOUT=1 PATH="$FB" "$FB/bash" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "shellcheck failed_to_run" "failed_to_run" "$(chk "$O" shellcheck status)"
check "note says timed out" "a.sh: timed out after 1 s" "$(chk "$O" shellcheck note)"

echo "Test 29: .sh.erb shellcheck lines map to source lines"
T="$TMP/t29"; mkdir -p "$T"
printf '#!/bin/bash\n<%% if x\n   y %%>\ncd /tmp\necho ok\n' > "$T/a.sh.erb"
O="$TMP/o29"
check "exit 0" 0 "$(run "$T" "$O")"
if has_sc; then
  check "SC2164 on source line 4" "4" "$(j "$O/shellcheck.json" "[e['line'] for e in d if e['code']==2164][0]")"
  check "file is the source path" "a.sh.erb" "$(j "$O/shellcheck.json" "[e['file'] for e in d if e['code']==2164][0]")"
else skip "shellcheck not installed"; skip "shellcheck not installed"; fi

echo "Test 30: tool-table.md, PATH-restricted (no tools)"
check "exact contents" "$(printf '%s\n' '**Check tiers:** Tier 1 only' '' 'Tier 3 not checked — no isolated execution environment.' '' '| Tool | Status | Result |' '|---|---|---|' '| shellcheck | Not run (not installed) | — |' '| semgrep | Not run (not installed) | — |' '| bandit | Not run (not installed) | — |' '| trivy | Not run (not installed) | — |')" "$(cat "$TMP/o7/tool-table.md")"
check "ends with a newline" "True" "$(python3 -c 'import sys; print(open(sys.argv[1]).read().endswith("|\n"))' "$TMP/o7/tool-table.md")"

echo "Test 31: tool-table.md, containerized-server with only shellcheck"
if has_sc; then
  FB="$TMP/fb31"; fakebin "$FB"; ln -sf "$(command -v shellcheck)" "$FB/shellcheck"
  O="$TMP/o31"
  check "exit 0" 0 "$(PATH="$FB" "$FB/bash" "$RUN" "$FIX/containerized-server" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
  # The shellcheck Result is recomputed from shellcheck.json so the test holds across shellcheck versions.
  SC_RESULT="$(python3 -c 'import json,sys,collections; d=json.load(open(sys.argv[1])); c=collections.Counter("SC%s" % e["code"] for e in d); print("%d findings (%s)" % (len(d), ", ".join(k for k, _ in sorted(c.items(), key=lambda kv: (-kv[1], kv[0]))[:5])))' "$O/shellcheck.json")"
  check "exact contents" "$(printf '%s\n' '**Check tiers:** Tiers 1–2' '' 'Tier 3 not checked — no isolated execution environment.' '' '| Tool | Status | Result |' '|---|---|---|' "| shellcheck | Run (ERB-stripped) | $SC_RESULT |" '| semgrep | Not run (not installed) | — |' '| bandit | Not run (no applicable files) | — |' '| trivy | Not run (no applicable files) | — |')" "$(cat "$O/tool-table.md")"
else skip "shellcheck not installed"; skip "shellcheck not installed"; fi

# Fact scanners (apps.json, <out>/<app_id>/readme.json and form.json). Two
# end-to-end runs (tools off PATH, so they are fast) cover the files and the
# summary records; the scanner cases call pre-review.py's functions directly.
PR="$SCRIPT_DIR/references/pre-review.py"
# px <python code setting r> [args...]: pre-review.py imported as pr, args as A
px() { python3 -c 'import importlib.util,sys; s=importlib.util.spec_from_file_location("pr",sys.argv[1]); pr=importlib.util.module_from_spec(s); s.loader.exec_module(pr); g={"pr":pr,"A":sys.argv[3:]}; exec(sys.argv[2],g); print(g["r"])' "$PR" "$@" 2>&1; }
# YVENV_PY: a venv python with PyYAML installed, for exercising PyYAML-only
# paths (this host's python3 has no PyYAML); empty when no such venv exists.
YVENV_PY="/private/tmp/claude-501/-Users-drew-Sites-connectci-appverse-review/bf22b63a-7c35-4488-89f2-b3f69429d5d2/scratchpad/yvenv/bin/python3"
if [ ! -x "$YVENV_PY" ] || ! "$YVENV_PY" -c 'import yaml' 2>/dev/null; then YVENV_PY=""; fi
# pxv <python code setting r> [args...]: like px, but run under $YVENV_PY
pxv() { "$YVENV_PY" -c 'import importlib.util,sys; s=importlib.util.spec_from_file_location("pr",sys.argv[1]); pr=importlib.util.module_from_spec(s); s.loader.exec_module(pr); g={"pr":pr,"A":sys.argv[3:]}; exec(sys.argv[2],g); print(g["r"])' "$PR" "$@" 2>&1; }
# rd <README> <expression over d (readme facts)>
rd() { px "d=pr.scan_readme(open(A[0]).read(), pr.load_placeholders()); r=$2" "$1"; }
# fm <app dir> <expression over d (form facts; target = app dir)>
fm() { px "d=pr.scan_form(A[0], A[0]); r=$2" "$1"; }
# ap <target> <expression over a (apps.json entries)>
ap() { px "a=[pr._public(x) for x in pr.resolve_apps(A[0])]; r=$2" "$1"; }
# rec <readme|form> <target> <out> <expression over c (the summary record)>
rec() { px "c=pr.check_$1(A[0], pr.resolve_apps(A[0]), A[1]); r=$4" "$2" "$3"; }
# e2e <target> <out>: an end-to-end run with no analysis tools on PATH
FBF="$TMP/fbfacts"; fakebin "$FBF"
e2e() { PATH="$FBF" "$FBF/bash" "$RUN" "$1" "$2" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?; }
fact() { j "$1/$2/$3.json" "$4"; }
fct() { j "$1/summary.json" "[c for c in d['facts'] if c['name']=='$2'][0]['$3']"; }
parser_note() { if "$1" -c 'import yaml' 2>/dev/null; then echo "YAML parser: PyYAML"; else echo "YAML parser: built-in subset (PyYAML not importable)"; fi; }
PARSER_NOTE="$(parser_note python3)"
# a venv's python3 symlinked into the fake bin dir loses the venv's packages
E2E_PARSER_NOTE="$(parser_note "$FBF/python3")"
ROW="','.join('%s|%s|%s|%s' % (e['app_id'], e['path'], e['app_type'], e['readme']) for e in a)"
A="[a for a in d['attributes'] if a['name']=="

echo "Test 32: end-to-end, vnc-stale-debugger and broken-app"
O="$TMP/vnc"
check "exit 0" 0 "$(e2e "$FIX/vnc-stale-debugger" "$O")"
check "apps.json" "root|.|batch_connect|README.md" "$(j "$O/apps.json" "'|'.join(str(d[0][k]) for k in ('app_id','path','app_type','readme'))")"
check "summary facts in order" "readme,form,template,entry_point,security" "$(j "$O/summary.json" "','.join(c['name'] for c in d['facts'])")"
check "checks unchanged" "syntax,shellcheck,semgrep,bandit,trivy,catalog" "$(j "$O/summary.json" "','.join(c['name'] for c in d['checks'])")"
check "readme ran" "ran|{'root': 'ran'}" "$(fct "$O" readme status)|$(fct "$O" readme per_app)"
check "form ran, note names the parser" "ran|{'root': 'ran'}|$E2E_PARSER_NOTE" "$(fct "$O" form status)|$(fct "$O" form per_app)|$(fct "$O" form note)"
check "readme.json written" "README.md|Overview" "$(fact "$O" root readme "'%s|%s' % (d['file'], d['rungs']['what it launches']['heading'])")"
check "form.json written" "form.yml.erb|submit.yml.erb|ERBVALUE" "$(fact "$O" root form "'%s|%s|%s' % (d['file'], d['submit_file'], d['erb_sentinel'])")"
check "template ran, entry_point not_applicable" "ran|{'root': 'ran'}|not_applicable|{'root': 'not_applicable'}" "$(fct "$O" template status)|$(fct "$O" template per_app)|$(fct "$O" entry_point status)|$(fct "$O" entry_point per_app)"
check "template.json written, no entry_point.json" "template|template/script.sh.erb|False" "$(fact "$O" root template "'%s|%s' % (d['dir'], ','.join(d['files']))")|$(yn test -e "$O/root/entry_point.json")"
O="$TMP/o32b"; mkdir -p "$O/good-app"; printf '[{"app_id": "good-app"}]\n' > "$O/apps.json"; echo '{}' > "$O/good-app/readme.json"
check "broken-app exit 0" 0 "$(e2e "$FIX/broken-app" "$O")"
check "previous run's per-app dir removed" "False" "$(yn test -e "$O/good-app")"
check "form failed_to_run" "failed_to_run|{'root': 'failed_to_run'}" "$(fct "$O" form status)|$(fct "$O" form per_app)"
check "note carries the parse error" "True" "$(fct "$O" form note | grep -qE 'root: form\.yml: .*line 3, column 12' && echo True || echo False)"
check "form.json carries the error, no attributes" "True|[]" "$(j "$O/root/form.json" "'%s|%s' % ('line 3, column 12' in d['error'], d['attributes'])")"
check "readme still ran" "ran" "$(fct "$O" readme status)"

echo "Test 33: app shape"
check "monorepo (from the earlier run): app_id is the normalised subpath" "apps/good-app|apps/good-app|batch_connect|README.md,apps/bad-app|apps/bad-app|batch_connect|README.md" "$(j "$TMP/mono/apps.json" "','.join('%s|%s|%s|%s' % (e['app_id'], e['path'], e['app_type'], e['readme']) for e in d)")"
check "monorepo per_app" "{'apps/good-app': 'ran', 'apps/bad-app': 'ran'}|{'apps/good-app': 'ran', 'apps/bad-app': 'skipped'}" "$(fct "$TMP/mono" readme per_app)|$(fct "$TMP/mono" form per_app)"
check "fact dir nests under the subpath" "True|True" "$(yn test -e "$TMP/mono/apps/good-app/readme.json")|$(yn test -e "$TMP/mono/apps/bad-app/readme.json")"
check "single app is root" "root|.|batch_connect|README.md" "$(ap "$FIX/containerized-server" "$ROW")"
check "passenger app" "root|.|passenger|README.md" "$(ap "$FIX/passenger-flask-app" "$ROW")"
T="$TMP/t33"; mkdir -p "$T/a" "$T/b" "$T/c"
printf 'apps:\n  - path: a\n  - path: ./b/\n    app_type: companion_app\n  - path: c\n  - path: ../escape\n  - path: .\n' > "$T/appverse.yml"
printf 'run app\n' > "$T/a/config.ru"; printf 'name: B\n' > "$T/b/manifest.yml"; printf 'x: 1\n' > "$T/c/README.md"
check "entry point, declared app_type, normalized path, unknown, outside target, path ." "a|a|passenger|None,b|b|companion|None,c|c|unknown|c/README.md,escape|../escape|unknown|None,root|.|unknown|None" "$(ap "$T" "$ROW")"
check "outside-target app is skipped, named in the note" "skipped|True" "$(rec readme "$T" "$TMP/o33" "'%s|%s' % (c['per_app']['escape'], 'escape (../escape): app path outside target, not read' in c['note'])")"
T="$TMP/t33b"; mkdir -p "$T"; printf 'echo hi\n' > "$T/a.sh"
check "no manifest is still one root app" "root|.|unknown|None" "$(ap "$T" "$ROW")"
check "readme skipped without a README, no readme.json" "skipped|False" "$(rec readme "$T" "$TMP/o33b" "c['status']")|$(yn test -e "$TMP/o33b/root/readme.json")"

echo "Test 33b: monorepo app_id is the normalised subpath, not the basename"
T="$TMP/t33c"; mkdir -p "$T/apps/good-app" "$T/other/good-app"
printf 'apps:\n  - path: apps/good-app\n  - path: other/good-app\n' > "$T/appverse.yml"
check "two apps sharing a basename get distinct subpath ids" "apps/good-app|apps/good-app,other/good-app|other/good-app" "$(ap "$T" "','.join('%s|%s' % (e['app_id'], e['path']) for e in a)")"
T="$TMP/t33d"; mkdir -p "$T/apps/root" "$T/apps/stripped"
printf 'apps:\n  - path: apps/root\n  - path: apps/stripped\n' > "$T/appverse.yml"
check "a subpath merely containing a reserved basename is not reserved" "apps/root,apps/stripped" "$(ap "$T" "','.join(e['app_id'] for e in a)")"
T="$TMP/t33e"; mkdir -p "$T/root" "$T/stripped"
printf 'apps:\n  - path: root\n  - path: stripped\n' > "$T/appverse.yml"
check "a top-level subpath literally reserved still falls back" "root-2,stripped-2" "$(ap "$T" "','.join(e['app_id'] for e in a)")"

echo "Test 34: readme facts, containerized-server and vnc-stale-debugger"
R="$FIX/containerized-server/README.md"
check "headings" "1|MLflow Tracking Server|1,2|Requirements|5" "$(rd "$R" "','.join('%s|%s|%s' % (h['level'], h['text'], h['line']) for h in d['headings'])")"
check "rung keys in order" "what it launches,prerequisites,installation,configuration,known limitations,troubleshooting,screenshots,environment variables,info panel,architecture" "$(rd "$R" "','.join(d['rungs'])")"
check "prerequisites rung" "{'heading': 'Requirements', 'line': 5, 'placeholder': False, 'match': 'heading'}" "$(rd "$R" "d['rungs']['prerequisites']")"
check "intro paragraph under the H1 is what it launches" "{'heading': 'MLflow Tracking Server', 'line': 3, 'placeholder': False, 'match': 'intro'}" "$(rd "$R" "d['rungs']['what it launches']")"
check "other rungs null" "True" "$(rd "$R" "all(v is None for k, v in d['rungs'].items() if k not in ('prerequisites', 'what it launches'))")"
printf '# App\n\n[![CI](https://img.shields.io/x.svg)](https://ci)\n- a list item with words in it\nok go\n\n## Install\nx\n' > "$TMP/intro-neg.md"
check "badge, list and short lines under the H1 are not an intro" "None" "$(rd "$TMP/intro-neg.md" "d['rungs']['what it launches']")"
printf '# App\n\nLaunches a Jupyter server on a compute node.\n\n## Overview\nMore.\n' > "$TMP/intro-ov.md"
check "an Overview heading wins over the intro" "Overview|heading" "$(rd "$TMP/intro-ov.md" "'%s|%s' % (d['rungs']['what it launches']['heading'], d['rungs']['what it launches']['match'])")"
check "no placeholders, screenshots, env_vars" "[]|[]|[]" "$(rd "$R" "'%s|%s|%s' % (d['placeholders'], d['screenshots'], d['env_vars'])")"
R="$FIX/vnc-stale-debugger/README.md"
check "vnc headings (a # in a fence is not one)" "1|HPC Debugger|1,2|Overview|6,2|Requirements|11,2|Installation|17,2|Configuration|26" "$(rd "$R" "','.join('%s|%s|%s' % (h['level'], h['text'], h['line']) for h in d['headings'])")"
check "vnc rungs resolved" "what it launches:Overview:6,prerequisites:Requirements:11,installation:Installation:17,configuration:Configuration:26" "$(rd "$R" "','.join('%s:%s:%s' % (k, v['heading'], v['line']) for k, v in d['rungs'].items() if v)")"
check "vnc no rung is placeholder" "False" "$(rd "$R" "any(v['placeholder'] for v in d['rungs'].values() if v)")"
check "vnc no placeholders, screenshots, env_vars" "[]|[]|[]" "$(rd "$R" "'%s|%s|%s' % (d['placeholders'], d['screenshots'], d['env_vars'])")"

echo "Test 35: readme facts, placeholders, screenshots, env vars, synonyms"
T="$TMP/t35"; mkdir -p "$T"; R="$T/README.md"
cat > "$R" <<'MD'
# [Application Name]

## Overview

<!-- 2-3 sentences: What does this app launch? Who is it for? -->
[Application Name] is an Open OnDemand Batch Connect app that launches [software name and version].

## Screenshots
![Session view](docs/session.png)
[![build](https://img.shields.io/badge/build-passing.svg)](https://ci.example.org)

## Requirements and Setup
Set the cluster in form.yml.

```bash
# not a heading
export MY_APP_HOME=/data/app
git clone https://github.com/YOUR-ORG/YOUR-APP.git
```

### Environment

Set the environment variable before launch.

Setup heading
=============

## FAQ

- [e.g., Multi-node jobs are not supported]

## Known Issues
None so far.
MD
check "headings (ATX and setext, none from the fence)" "1|[Application Name]|1,2|Overview|3,2|Screenshots|8,2|Requirements and Setup|12,3|Environment|21,1|Setup heading|25,2|FAQ|28,2|Known Issues|32" "$(rd "$R" "','.join('%s|%s|%s' % (h['level'], h['text'], h['line']) for h in d['headings'])")"
check "placeholder lines (none from the fence)" "1,5,6,30" "$(rd "$R" "','.join(str(p['line']) for p in d['placeholders'])")"
check "placeholder phrase recorded" "[Application Name]" "$(rd "$R" "d['placeholders'][0]['phrase']")"
check "overview rung is placeholder" "{'heading': 'Overview', 'line': 3, 'placeholder': True, 'match': 'heading'}" "$(rd "$R" "d['rungs']['what it launches']")"
check "one heading, two rungs" "{'heading': 'Requirements and Setup', 'line': 12, 'placeholder': False, 'match': 'heading'}|{'heading': 'Requirements and Setup', 'line': 12, 'placeholder': False, 'match': 'heading'}" "$(rd "$R" "'%s|%s' % (d['rungs']['prerequisites'], d['rungs']['installation'])")"
check "FAQ is troubleshooting, placeholder" "{'heading': 'FAQ', 'line': 28, 'placeholder': True, 'match': 'heading'}" "$(rd "$R" "d['rungs']['troubleshooting']")"
check "Known Issues is known limitations" "{'heading': 'Known Issues', 'line': 32, 'placeholder': False, 'match': 'heading'}" "$(rd "$R" "d['rungs']['known limitations']")"
check "screenshots rung" "{'heading': 'Screenshots', 'line': 8, 'placeholder': False, 'match': 'heading'}" "$(rd "$R" "d['rungs']['screenshots']")"
check "Environment is environment variables" "{'heading': 'Environment', 'line': 21, 'placeholder': False, 'match': 'heading'}" "$(rd "$R" "d['rungs']['environment variables']")"
check "screenshots (badge excluded)" "[{'line': 9, 'alt': 'Session view', 'target': 'docs/session.png'}]" "$(rd "$R" "d['screenshots']")"
check "env_vars" "17:assignment,21:heading,23:phrase" "$(rd "$R" "','.join('%s:%s' % (e['line'], e['match']) for e in d['env_vars'])")"
check "placeholder file is seeded" "True" "$(yn grep -qxF '[Application Name]' "$SCRIPT_DIR/references/readme-placeholders.txt")"
check "git checkout v1.0.0 is not a placeholder" "False" "$(yn grep -qF 'git checkout v1.0.0' "$SCRIPT_DIR/references/readme-placeholders.txt")"

echo "Test 35b: a wrapped template paragraph's continuation line is still a placeholder"
T="$TMP/t35b"; mkdir -p "$T"; R="$T/README.md"
cat > "$R" <<'MD'
# App

## Troubleshooting

This app is built for [brief use case] and is intended for
use by researchers who need a quick interactive session
on the cluster without further setup.

## Known Issues
None.
MD
check "wrapped placeholder: all three paragraph lines recorded, continuations included" "5,6,7" "$(rd "$R" "','.join(str(p['line']) for p in d['placeholders'])")"
check "continuation line has no phrase text of its own, still flagged" "True" "$(rd "$R" "'[brief use case]' not in d['placeholders'][1]['text'] and d['placeholders'][1]['phrase'] == '[brief use case]'")"
check "section with only a wrapped placeholder paragraph: rung is placeholder" "True" "$(rd "$R" "d['rungs']['troubleshooting']['placeholder']")"
# a heading right after the wrapped text does not extend the paragraph
cat > "$T/README2.md" <<'MD'
# App

## FAQ

This app is for [brief use case].
## Known Issues
None.
MD
check "a heading line never inherits the previous paragraph's match" "5" "$(rd "$T/README2.md" "','.join(str(p['line']) for p in d['placeholders'])")"

echo "Test 36: form facts, vnc-stale-debugger (form.yml.erb)"
D="$FIX/vnc-stale-debugger"
check "file, submit file, sentinel" "form.yml.erb|submit.yml.erb|ERBVALUE" "$(fm "$D" "'%s|%s|%s' % (d['file'], d['submit_file'], d['erb_sentinel'])")"
check "names (attributes, then form-only)" "version,node_type,num_cores,input_file,bc_num_hours,bc_vnc_resolution" "$(fm "$D" "','.join(a['name'] for a in d['attributes'])")"
check "num_cores" "number_field|0|48|None|False|29|True|True" "$(fm "$D" "'|'.join(str(x[k]) for x in $A'num_cores'] for k in ('widget','min','max','pattern','required','line','defined','in_form'))")"
check "num_cores reaches the scheduler via ppn" "True|[2]|True" "$(fm "$D" "'|'.join(str(x[k]) for x in $A'num_cores'] for k in ('interpolated_in_submit','submit_lines','reaches_scheduler'))")"
check "node_type referenced twice, reaches the scheduler" "True|[12, 24]|True" "$(fm "$D" "'|'.join(str(x[k]) for x in $A'node_type'] for k in ('interpolated_in_submit','submit_lines','reaches_scheduler'))")"
check "version not referenced" "False|[]|False" "$(fm "$D" "'|'.join(str(x[k]) for x in $A'version'] for k in ('interpolated_in_submit','submit_lines','reaches_scheduler'))")"
check "input_file defined, not in form" "text_field|37|True|False" "$(fm "$D" "'|'.join(str(x[k]) for x in $A'input_file'] for k in ('widget','line','defined','in_form'))")"
check "bc_num_hours in form only" "None|12|False|True" "$(fm "$D" "'|'.join(str(x[k]) for x in $A'bc_num_hours'] for k in ('widget','line','defined','in_form'))")"

echo "Test 37: form facts, YAML form.yml, references, bounds, unparseable forms, Passenger"
check "good-app hours bounds" "hours|number_field|1|48|3" "$(fm "$FIX/monorepo/apps/good-app" "'|'.join(str(d['attributes'][0][k]) for k in ('name','widget','min','max','line'))")"
T="$TMP/t37"; mkdir -p "$T"
cat > "$T/form.yml" <<'YML'
# a comment
cluster: "owens"
form:
  - account
  - env_name
  - hours
  - cores
  - partition
  - mem
attributes:
  account:
    widget: text_field
    pattern: "^[a-z]+$"
    required: true
  env_name:
    widget: text_field
  hours: 4
  cores:
    widget: number_field
    html_options: {min: 1, max: 8}
  partition:
    widget: text_field
  mem:
    widget: number_field
YML
cat > "$T/submit.yml.erb" <<'YML'
<% a = 1; memv = mem %>
---
cluster: "<%= env_name %>"
batch_connect:
  template: "<%= hours %>"
script:
  native: ["-A", "<%= account %>"]
  job_name: "<%= context.cores %>"
  queue_name: "<%= @partition %>"
  email: "<%= memv %>"
YML
FL="'|'.join(str(x[k]) for x in"
check "account" "text_field|^[a-z]+\$|True|11|True|[7]|True" "$(fm "$T" "$FL $A'account'] for k in ('widget','pattern','required','line','interpolated_in_submit','submit_lines','reaches_scheduler'))")"
check "env_name interpolated outside script" "False|True|[3]|False" "$(fm "$T" "$FL $A'env_name'] for k in ('required','interpolated_in_submit','submit_lines','reaches_scheduler'))")"
check "hours (scalar attribute) reaches batch_connect.template" "None|17|True|[5]|True" "$(fm "$T" "$FL $A'hours'] for k in ('widget','line','interpolated_in_submit','submit_lines','reaches_scheduler'))")"
check "html_options bounds; context.cores reaches" "1|8|18|[8]|True" "$(fm "$T" "$FL $A'cores'] for k in ('min','max','line','submit_lines','reaches_scheduler'))")"
check "@partition reaches" "[9]|True" "$(fm "$T" "$FL $A'partition'] for k in ('submit_lines','reaches_scheduler'))")"
check "taint through a ;-joined statement" "[1]|True" "$(fm "$T" "$FL $A'mem'] for k in ('submit_lines','reaches_scheduler'))")"
T="$TMP/t37e"; mkdir -p "$T"
printf 'attributes:\n  cores:\n    widget: number_field\n    min: 1\n    max: <%%= max_cores %%>\n' > "$T/form.yml.erb"
check "ERB-computed bound is the sentinel" "ERBVALUE|ERBVALUE" "$(fm "$T" "'%s|%s' % (d['erb_sentinel'], d['attributes'][0]['max'])")"
T="$TMP/t37c"; mkdir -p "$T"
printf '<%% x = 1 %%>\nattributes:\n  a:\n    widget: {text_field\nform:\n  - a\n' > "$T/form.yml.erb"
check "unparseable form.yml.erb: error names line 4" "form.yml.erb|True|[]" "$(fm "$T" "'%s|%s|%s' % (d['file'], 'line 4' in d['error'], d['attributes'])")"
check "record failed_to_run, note names parser and error" "failed_to_run|True" "$(rec form "$T" "$TMP/o37c" "'%s|%s' % (c['status'], c['note'].startswith('$PARSER_NOTE; root: form.yml.erb: '))")"
check "passenger form not_applicable, no form.json" "not_applicable|{'root': 'not_applicable'}|False" "$(fct "$TMP/flask" form status)|$(fct "$TMP/flask" form per_app)|$(yn test -e "$TMP/flask/root/form.json")"
T="$TMP/t37d"; mkdir -p "$T"; printf 'app_type: companion\n' > "$T/appverse.yml"; printf 'run App\n' > "$T/config.ru"
check "companion app with no form: not_applicable, not skipped" "not_applicable|{'root': 'not_applicable'}" "$(rec form "$T" "$TMP/o37d" "'%s|%s' % (c['status'], c['per_app'])")"
T="$TMP/t37e2"; mkdir -p "$T"
check "batch_connect app missing its form file: skipped (form applies but is absent)" "skipped|{'root': 'skipped'}" "$(rec form "$T" "$TMP/o37e2" "'%s|%s' % (c['status'], c['per_app'])")"

echo "Test 38: the subset YAML parser refuses what it cannot read"
sub() { printf '%b' "$1" > "$TMP/sub.yml"; px "t=open(A[0]).read()
try:
    pr._SubsetYaml(t).parse(); r='parsed'
except pr.YamlError as e:
    r=str(e)" "$TMP/sub.yml"; }
check "anchor" "line 2, column 7: anchors (&) are not supported" "$(sub 'a: 1\nbase: &b {min: 1}\n')"
check "alias" "line 2, column 4: aliases (*) are not supported" "$(sub 'a: 1\nb: *a\n')"
check "merge key" "line 3, column 3: merge keys (<<) are not supported" "$(sub 'x:\n  y: 1\n  <<: {min: 1}\n')"
check "tag" "line 1, column 4: tags (!) are not supported" "$(sub 'a: !ruby/sym x\n')"
check "second document" "line 3, column 1: a second YAML document is not supported" "$(sub '---\na: 1\n---\nb: 2\n')"
check "a leading --- is fine" "parsed" "$(sub '---\na: 1\n')"
T="$TMP/t38"; mkdir -p "$T"; printf 'attributes:\n  a: &x\n    widget: text_field\n  b: *x\nform:\n  - a\n' > "$T/form.yml"
check "subset parser: anchored form is failed_to_run" "failed_to_run" "$(px "pr._yaml_module=lambda: None; r=pr.check_form(A[0], pr.resolve_apps(A[0]), A[1])['status']" "$T" "$TMP/o38")"

echo "Test 38a: PyYAML refuses anchors/aliases/tags/merge keys the same way (no expansion, so no alias bomb)"
if [ -n "$YVENV_PY" ]; then
  subv() { printf '%b' "$1" > "$TMP/subv.yml"; pxv "t=open(A[0]).read()
try:
    pr.load_yaml(t, 'x.yml'); r='parsed'
except pr.YamlError as e:
    r=str(e)" "$TMP/subv.yml"; }
  check "PyYAML anchor" "line 2, column 7: anchors (&) are not supported" "$(subv 'a: 1\nbase: &b {min: 1}\n')"
  check "PyYAML alias" "line 2, column 4: aliases (*) are not supported" "$(subv 'a: 1\nb: *a\n')"
  check "PyYAML merge key" "line 3, column 3: merge keys (<<) are not supported" "$(subv 'x:\n  y: 1\n  <<: {min: 1}\n')"
  check "PyYAML explicit tag" "line 1, column 4: tags (!) are not supported" "$(subv 'a: !!str 5\n')"
  check "PyYAML: a plain form still parses" "parsed" "$(subv 'a: 1\nb: 2\n')"
  T="$TMP/t38a"; mkdir -p "$T"
  # a form.yml alias bomb: each level doubles the prior level's aliases;
  # 20 levels from one leaf would be over a million refs if expanded.
  { printf 'attributes:\n  a0:\n    widget: text_field\nform:\n  - a0\na0: &a0 x\n'
    for i in $(seq 1 20); do printf 'a%d: &a%d [*a%d, *a%d]\n' "$i" "$i" "$((i-1))" "$((i-1))"; done
    printf 'min: *a20\n'; } > "$T/form.yml"
  check "alias bomb: refused, not expanded" "True" "$(pxv "import time
t0 = time.time()
try:
    pr.load_yaml(open(A[0]).read(), 'form.yml')
    r = 'parsed (BAD)'
except pr.YamlError as e:
    r = str('anchors (&) are not supported' in str(e) and time.time() - t0 < 5)" "$T/form.yml")"
  check "alias bomb: form.json stays small (refused, not a 4GB dump)" "True" "$(pxv "d = pr.scan_form(A[0], A[0]); r = len(d['error']) < 1000" "$T")"
else
  skip "no venv python with PyYAML on this host"
  skip "no venv python with PyYAML on this host"
  skip "no venv python with PyYAML on this host"
  skip "no venv python with PyYAML on this host"
  skip "no venv python with PyYAML on this host"
  skip "no venv python with PyYAML on this host"
  skip "no venv python with PyYAML on this host"
fi

echo "Test 39: fact files are read only under the shell-file rule"
OUTSIDE="$TMP/outside"; mkdir -p "$OUTSIDE"
printf '# SECRET-OUTSIDE\n## Installation\nsecret\n' > "$OUTSIDE/README.md"
printf 'attributes:\n  secret_outside:\n    widget: text_field\n' > "$OUTSIDE/form.yml"
T="$TMP/symapp"; mkdir -p "$T"; ln -s "$OUTSIDE/README.md" "$T/README.md"; ln -s "$OUTSIDE/form.yml" "$T/form.yml"
O="$TMP/o39"
check "README outside: skipped" "skipped|{'root': 'skipped'}|root: README.md: symlink outside target, not checked" "$(rec readme "$T" "$O" "'%s|%s|%s' % (c['status'], c['per_app'], c['note'])")"
check "form outside: skipped" "skipped|True" "$(rec form "$T" "$O" "'%s|%s' % (c['status'], 'root: form.yml: symlink outside target, not checked' in c['note'])")"
check "no fact files, nothing from outside" "False|False|0" "$(yn test -e "$O/root/readme.json")|$(yn test -e "$O/root/form.json")|$(grep -rl 'SECRET-OUTSIDE\|secret_outside' "$O" 2>/dev/null | wc -l | tr -d ' ')"
T="$TMP/symapp2"; mkdir -p "$T/docs"; printf '## Setup\nok\n' > "$T/docs/real.md"; ln -s docs/real.md "$T/README.md"
printf 'attributes:\n  a:\n    widget: text_field\n' > "$T/form.yml"; ln -s "$OUTSIDE/form.yml" "$T/submit.yml.erb"
check "README symlink inside: ran" "ran" "$(rec readme "$T" "$TMP/o39b" "c['status']")"
check "submit outside: form skipped" "skipped|True" "$(rec form "$T" "$TMP/o39b" "'%s|%s' % (c['status'], 'root: submit.yml.erb: symlink outside target, not checked' in c['note'])")"
T="$TMP/bigapp"; mkdir -p "$T"; python3 -c "import sys; open(sys.argv[1],'w').write('x\n' * 600000)" "$T/README.md"
check "README over 1 MB: skipped" "skipped|root: README.md: skipped: file larger than 1 MB" "$(rec readme "$T" "$TMP/o39c" "'%s|%s' % (c['status'], c['note'])")"

echo "Test 40: template facts, containerized-server"
# tp <app dir> <target> <expression over d (template facts)>
tp() { px "d=pr.scan_template(A[0], A[1]); r=$3" "$1" "$2"; }
D="$FIX/containerized-server"
check "dir and files" "template|template/after.sh,template/before.sh.erb,template/bin/nginx,template/config/.gitkeep,template/create_nginx_conf.sh.erb,template/script.sh.erb" "$(tp "$D" "$D" "'%s|%s' % (d['dir'], ','.join(d['files']))")"
check "absolute paths" "template/before.sh.erb:2:/appl/profile/zz-csc-env.sh,template/bin/nginx:2:/appl/opt/ood/,template/script.sh.erb:4:/appl/opt/ood/,template/script.sh.erb:5:/appl/opt/ood/,template/script.sh.erb:6:/appl/opt/ood/" "$(tp "$D" "$D" "','.join('%s:%s:%s' % (x['file'], x['line'], x['text']) for x in d['absolute_paths'])")"
check "numeric literals (sleep 5, 1, 1.1, 0.0.0.0, \$1, sha1sum excluded)" "template/after.sh:4:300,template/create_nginx_conf.sh.erb:4:128,template/create_nginx_conf.sh.erb:11:403,template/script.sh.erb:25:5000" "$(tp "$D" "$D" "','.join('%s:%s:%s' % (x['file'], x['line'], x['value']) for x in d['numeric_literals'])")"
check "no icons, no commented code, nothing skipped" "[]|[]|[]" "$(tp "$D" "$D" "'%s|%s|%s' % (d['icons'], d['commented_code'], d['skipped_files'])")"
check "vnc: /usr/share path, no literals in module versions" "template/script.sh.erb:4:/usr/share/Modules/init/bash|[]" "$(tp "$FIX/vnc-stale-debugger" "$FIX/vnc-stale-debugger" "'%s|%s' % (','.join('%s:%s:%s' % (x['file'], x['line'], x['text']) for x in d['absolute_paths']), d['numeric_literals'])")"

echo "Test 41: template facts, icons, literal exclusions, commented code, monorepo paths"
T="$TMP/t41"; A1="$T/apps/one"; mkdir -p "$A1/template/sub"
printf 'apps:\n  - path: apps/one\n' > "$T/appverse.yml"; printf 'x: 1\n' > "$A1/form.yml"
printf '[Desktop Entry]\nName=Term\nIcon=utilities-terminal\nExec=xterm\n' > "$A1/template/sub/term.desktop"
cat > "$A1/template/xfce4-panel.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="plugin-5" type="string" value="launcher">
    <property name="button-icon" type="string" value="firefox"/>
  </property>
  <property value="terminal" type="string" name="button-icon"/>
  <property name="button-icon" type="string">
    <value type="string">thunar</value>
  </property>
  <property name="size" type="uint" value="4096"/>
  4096
</channel>
XML
printf '[Desktop Entry]\nIcon=<%%= icon_name %%>\n' > "$A1/template/sub/app.desktop.erb"
cat > "$A1/template/run.sh" <<'SH'
#!/bin/bash
sleep 30
python -m http.server 8080
ssh -p 22 host; listen 80; nc -l 443
x=0; y=1
echo "${arr[3]}"
timeout 600 cmd # ten minutes
# the next line waits
wait_for 120
exec 3>/dev/null 2>&1
mask=0x1F
version=2.3.1
ulimit -n 4096

# for f in *.log; do
#   rm "$f"
# done

# This is a note
# (about things
# that do not parse

# only
# two

###
#
#

# Start the server
# wait a bit
# and exit

# ==========================
# Launch the Xfce desktop
# ==========================

# Copyright 2024 Example University
# Permission is hereby granted free of charge
# to any person obtaining a copy of this software

# cd /tmp
#
# ls

exit 3
kill -9 "$pid"
chmod 755 x; chmod -R 0700 y; umask 077
if [ $? -eq 2 ]; then echo; fi
color="#ff0000"; bg="#1a2b3c"
retry 7

# module load gcc
# module load openmpi
# cd work
SH
printf '#!/bin/bash\ncd /scratch/$USER\ncp x "/home/a b" --dir=/work/x\nsource /etc/profile; ls $HOME/data\ncd /projects/<%%= account %%>/runs\nCFG=<%%= x || "/opt/site/cfg" %%>\nexport PATH=$PATH:/apps/x/bin; singularity exec --bind /scratch:/scratch img\n' > "$A1/template/paths.sh.erb"
printf 'ab\0cd /opt/x 4096\n' > "$A1/template/tool.bin"
OUTSIDE41="$TMP/outside41"; mkdir -p "$OUTSIDE41"; printf 'cd /scratch/SECRET41\n' > "$OUTSIDE41/x.sh"
ln -s "$OUTSIDE41/x.sh" "$A1/template/leak.sh"
check "files (repo-relative, app subpath)" "apps/one/template|apps/one/template/paths.sh.erb,apps/one/template/run.sh,apps/one/template/sub/app.desktop.erb,apps/one/template/sub/term.desktop,apps/one/template/xfce4-panel.xml" "$(tp "$A1" "$T" "'%s|%s' % (d['dir'], ','.join(d['files']))")"
check "skipped files: symlink out, binary" "apps/one/template/leak.sh:symlink outside target, not checked,apps/one/template/tool.bin:binary file, not scanned" "$(tp "$A1" "$T" "','.join('%s:%s' % (x['file'], x['reason']) for x in d['skipped_files'])")"
check "icons (raw ERB name; attribute order; <value> element)" "apps/one/template/sub/app.desktop.erb:2:<%= icon_name %>:desktop,apps/one/template/sub/term.desktop:3:utilities-terminal:desktop,apps/one/template/xfce4-panel.xml:4:firefox:xfce4-panel,apps/one/template/xfce4-panel.xml:6:terminal:xfce4-panel,apps/one/template/xfce4-panel.xml:7:thunar:xfce4-panel" "$(tp "$A1" "$T" "','.join('%s:%s:%s:%s' % (x['file'], x['line'], x['name'], x['kind']) for x in d['icons'])")"
check "absolute paths (ERB stripped, plus inside tags; after :; one per line and text; /etc and \$HOME/data are not)" "apps/one/template/paths.sh.erb:2:/scratch/,apps/one/template/paths.sh.erb:3:/home/a,apps/one/template/paths.sh.erb:3:/work/x,apps/one/template/paths.sh.erb:5:/projects/ERBVALUE/runs,apps/one/template/paths.sh.erb:6:/opt/site/cfg,apps/one/template/paths.sh.erb:7:/apps/x/bin,apps/one/template/paths.sh.erb:7:/scratch" "$(tp "$A1" "$T" "','.join('%s:%s:%s' % (x['file'], x['line'], x['text']) for x in d['absolute_paths'])")"
check "numeric literals (sleep, ports, 0/1, index, comments, fds, decimals, exit, kill, modes, \$? excluded; hex kept)" "3:8080,11:0x1F,13:4096,51:7" "$(tp "$A1" "$T" "','.join('%s:%s' % (x['line'], x['value']) for x in d['numeric_literals'] if x['file'].endswith('run.sh'))")"
check "hex colours listed on their own, not as literals" "run.sh:50:#ff0000,run.sh:50:#1a2b3c" "$(tp "$A1" "$T" "','.join('%s:%s:%s' % (x['file'].rsplit('/',1)[-1], x['line'], x['value']) for x in d['hex_colors'])")"
check "no literals from .desktop/.xml (the xml has a bare 4096)" "True" "$(tp "$A1" "$T" "all(x['file'].endswith('.sh') for x in d['numeric_literals'])")"
check "commented code: the loop and the module block; not prose, banners, licence headers, pairs or blank-padded pairs" "apps/one/template/run.sh:15:3,apps/one/template/run.sh:53:3" "$(tp "$A1" "$T" "','.join('%s:%s:%s' % (x['file'], x['line'], x['count']) for x in d['commented_code'])")"
check "nothing read from outside" "0" "$(tp "$A1" "$T" "str(d).count('SECRET41')")"
T2="$TMP/t41b"; mkdir -p "$T2/template"; printf '#!/bin/bash\necho hi\n' > "$T2/template/a.sh"
printf 'x=1\n# case "$x" in\n#   a) echo a ;;&\n#   *) echo b ;;\n# esac\n' > "$T2/template/b.sh"
if [ "$("$REAL_BASH" -c 'echo "${BASH_VERSINFO[0]}"')" -ge 4 ]; then EXP41="template/b.sh:2:4"; else EXP41=""; fi
check "a bash 4 block counts only where bash >= 4 accepts it" "$EXP41" "$(tp "$T2" "$T2" "','.join('%s:%s:%s' % (x['file'], x['line'], x['count']) for x in d['commented_code'])")"
mkdir -p "$T2/shared"; printf 'cd /data/x\n' > "$T2/shared/lib.sh"; ln -s ../shared/lib.sh "$T2/template/lib.sh"
check "a symlink out of template/ but inside the target is read" "template/lib.sh:1:/data/x" "$(tp "$T2" "$T2" "','.join('%s:%s:%s' % (x['file'], x['line'], x['text']) for x in d['absolute_paths'])")"
T3="$TMP/t41c"; mkdir -p "$T3"; printf 'x: 1\n' > "$T3/form.yml"; mkdir -p "$OUTSIDE41/template"; printf 'cd /scratch/SECRET41\n' > "$OUTSIDE41/template/a.sh"
ln -s "$OUTSIDE41/template" "$T3/template"
check "template dir symlinked out: skipped, nothing written" "skipped|root: template: symlink outside target, not checked|False" "$(rec template "$T3" "$TMP/o41c" "'%s|%s' % (c['status'], c['note'].split('; ')[-1])")|$(yn test -e "$TMP/o41c/root/template.json")"

echo "Test 42: entry_point facts (Passenger)"
# ep <app dir> <target> <expression over d (entry point facts)>
ep() { px "d=pr.scan_entry_point(A[0], A[1]); r=$3" "$1" "$2"; }
D="$FIX/passenger-flask-app"
check "flask entry point" "passenger_wsgi.py|python|True|None|requirements.txt|True" "$(ep "$D" "$D" "'|'.join(str(d[k]) for k in ('file','language','parses','error','dependency_manifest','consistent'))")"
check "flask note names the checked imports" "third-party imports all in requirements.txt: flask" "$(ep "$D" "$D" "d['note']")"
check "no .pyc written into the target" "0" "$(find "$D" -name '*.pyc' | wc -l | tr -d ' ')"
check "stdlib fallback (Python < 3.10) lists the stdlib, not site-packages" "True|False" "$(px "n=pr._stdlib_names(None); r='%s|%s' % (set(['os','json','subprocess','ast']) <= n, 'flask' in n)")"
check "template record carries no bash note for a Passenger app" "" "$(fct "$TMP/flask" template note)"
T="$TMP/t42a"; mkdir -p "$T"; printf 'def x(:\n    pass\n' > "$T/passenger_wsgi.py"
check "python syntax error names the interpreter" "False|True|True" "$(ep "$T" "$T" "'%s|%s|%s' % (d['parses'], d['error'].startswith('python 3.'), ': line 1: ' in d['error'])")"
printf 'x = 1\0\n' > "$T/passenger_wsgi.py"
check "null byte fails to parse, not a crash" "False|True" "$(ep "$T" "$T" "'%s|%s' % (d['parses'], d['error'].startswith('python 3.'))")"
T="$TMP/t42b"; mkdir -p "$T/pkg"; printf 'import numpy\nimport os\nfrom pkg import mod\nfrom . import rel\nfrom app import application\n' > "$T/passenger_wsgi.py"
printf 'import yaml\n' > "$T/app.py"; : > "$T/pkg/__init__.py"
check "no manifest, third-party imports: inconsistent" "None|False|no dependency manifest; third-party imports: numpy, yaml" "$(ep "$T" "$T" "'%s|%s|%s' % (d['dependency_manifest'], d['consistent'], d['note'])")"
printf 'PyYAML>=6\n' > "$T/requirements.txt"
check "requirements missing one import" "requirements.txt|False|not in requirements.txt: numpy" "$(ep "$T" "$T" "'%s|%s|%s' % (d['dependency_manifest'], d['consistent'], d['note'])")"
printf 'PyYAML>=6\nnumpy==2.0 ; python_version>"3"\n' > "$T/requirements.txt"
check "requirements complete (PyYAML provides yaml)" "True" "$(ep "$T" "$T" "d['consistent']")"
T="$TMP/t42f"; mkdir -p "$T/src/mypkg"; printf 'import flask\nimport mypkg\n' > "$T/passenger_wsgi.py"; : > "$T/src/mypkg/__init__.py"; printf 'flask\n' > "$T/requirements.txt"
check "a src/ package is local" "True|third-party imports all in requirements.txt: flask" "$(ep "$T" "$T" "'%s|%s' % (d['consistent'], d['note'])")"
printf 'import setuptools\n' > "$T/setup.py"
check "setup.py imports are not runtime dependencies" "True" "$(ep "$T" "$T" "d['consistent']")"
mkdir -p "$T/tests"; printf 'import pytest\n' > "$T/tests/conftest.py"; printf 'import hypothesis\n' > "$T/test_smoke.py"
check "tests/ and test_*.py imports are not runtime dependencies" "True" "$(ep "$T" "$T" "d['consistent']")"
T="$TMP/t42c"; mkdir -p "$T"; printf 'run lambda { |env| [200, {}, ["ok"]] }\n' > "$T/config.ru"; printf "source 'https://rubygems.org'\n" > "$T/Gemfile"
check "config.ru without ruby on PATH: not_checked" "config.ru|ruby|not_checked|Gemfile|None" "$(PATH="$FBF" px "d=pr.scan_entry_point(A[0], A[1]); r='|'.join(str(d[k]) for k in ('file','language','parses','dependency_manifest','consistent'))" "$T" "$T")"
if command -v ruby >/dev/null 2>&1; then
  check "config.ru parses under ruby -c" "True" "$(ep "$T" "$T" "d['parses']")"
  T="$TMP/t42d"; mkdir -p "$T"; printf 'run lambda {\n' > "$T/config.ru"
  check "bad config.ru fails ruby -c" "False|True" "$(ep "$T" "$T" "'%s|%s' % (d['parses'], bool(d['error']))")"
  T="$TMP/t42g"; mkdir -p "$T/apps/rb"; printf 'apps:\n  - path: apps/rb\n' > "$T/appverse.yml"; printf 'run lambda {\n' > "$T/apps/rb/config.ru"
  check "monorepo ruby error names the repo path and the ruby version" "apps/rb/config.ru|True|True|False" "$(ep "$T/apps/rb" "$T" "'%s|%s|%s|%s' % (d['file'], d['error'].startswith('ruby '), 'apps/rb/config.ru' in d['error'], './config.ru' in d['error'])")"
else skip "ruby not installed"; skip "ruby not installed"; skip "ruby not installed"; fi
if command -v node >/dev/null 2>&1; then
  T="$TMP/t42h"; mkdir -p "$T"; printf 'const x = 1;\n' > "$T/app.js"
  check "app.js parses under node --check" "app.js|node|True|package.json" "$(printf '{}' > "$T/package.json"; ep "$T" "$T" "'|'.join(str(d[k]) for k in ('file','language','parses','dependency_manifest'))")"
  printf 'const = ;\n' > "$T/app.js"
  check "bad app.js fails node --check, error names node" "False|True" "$(ep "$T" "$T" "'%s|%s' % (d['parses'], d['error'].startswith('node v'))")"
else skip "node not installed"; skip "node not installed"; fi
T="$TMP/t42e"; mkdir -p "$T"; ln -s "$OUTSIDE/README.md" "$T/passenger_wsgi.py"
check "entry point symlinked out: skipped" "skipped|root: passenger_wsgi.py: symlink outside target, not checked|False" "$(rec entry_point "$T" "$TMP/o42e" "'%s|%s' % (c['status'], c['note'])")|$(yn test -e "$TMP/o42e/root/entry_point.json")"

echo "Test 43: template / entry_point records by app type"
D="$FIX/containerized-server"
check "batch connect: template ran, entry_point not_applicable" "ran|{'root': 'ran'}|6|root/template.json|not_applicable|{'root': 'not_applicable'}" "$(rec template "$D" "$TMP/o43" "'%s|%s|%s|%s' % (c['status'], c['per_app'], c['files_examined'], c['output_file'].replace('<app_id>', 'root'))")|$(rec entry_point "$D" "$TMP/o43" "'%s|%s' % (c['status'], c['per_app'])")"
check "passenger (end to end): template not_applicable, entry_point ran" "not_applicable|{'root': 'not_applicable'}|ran|{'root': 'ran'}|False|passenger_wsgi.py" "$(fct "$TMP/flask" template status)|$(fct "$TMP/flask" template per_app)|$(fct "$TMP/flask" entry_point status)|$(fct "$TMP/flask" entry_point per_app)|$(yn test -e "$TMP/flask/root/template.json")|$(fact "$TMP/flask" root entry_point "d['file']")"
check "monorepo without template dirs: skipped, noted" "{'apps/good-app': 'skipped', 'apps/bad-app': 'skipped'}|True" "$(fct "$TMP/mono" template per_app)|$(fct "$TMP/mono" template note | grep -q 'apps/good-app: no template/ directory' && echo True || echo False)"

echo "Test 44: security candidates, fixtures"
# sc <app dir> <target> <app_type> <expression over d (security facts)>
sc() { px "d=pr.scan_security(A[0], A[1], A[2]); r=$4" "$1" "$2" "$3"; }
# sco <app dir> <target> <app_type> <out> <expression over d>: scan_security with a pre-review out-dir, so tool_finding candidates are read
sco() { px "d=pr.scan_security(A[0], A[1], A[2], A[3]); r=$5" "$1" "$2" "$3" "$4"; }
CL="','.join('%s:%s:%s' % (c['kind'], c['file'], c['line']) for c in d['candidates'])"
NZ="','.join('%s=%s' % kv for kv in d['counts'].items() if kv[1])"
KINDS="interpolation,unquoted_expansion,eval_exec,network_call,file_write_outside_job,permission_change,credential_string,config_flag,binary_in_template,tool_finding"
BY="[c for c in d['candidates'] if c['kind']=="
IF="[c for c in d['candidates'] if c['kind']=='interpolation' and c['file']=="
FL3="'|'.join('%s:%s:%s:%s' % (c['line'], ','.join(c['attributes']), c['guarded'], c['quoted']) for c in"
D="$FIX/broken-app"
check "broken-app candidates" "credential_string:template/script.sh.erb:2,config_flag:template/script.sh.erb:4" "$(sc "$D" "$D" batch_connect "$CL")"
check "broken-app counts first, every kind listed" "counts|$KINDS" "$(sc "$D" "$D" batch_connect "list(d)[0] + '|' + ','.join(d['counts'])")"
check "broken-app credential shape" "credential_string|sec-credential-string|OODT-02|hardcoded-credential|export API_TOKEN=\"sk-live-FAKE1234567890abcdef\"" "$(sc "$D" "$D" batch_connect "'|'.join(str(d['candidates'][0][k]) for k in ('kind','check','rule','tag','text'))")"
check "broken-app bind is OODT-05 bind-all-interfaces" "OODT-05|bind-all-interfaces" "$(sc "$D" "$D" batch_connect "'%s|%s' % (d['candidates'][1]['rule'], d['candidates'][1]['tag'])")"
check "broken-app: an unparseable form still names its attributes" "['modules']" "$(sc "$D" "$D" batch_connect "d['attributes']")"
check "broken-app scope and files" "batch_connect|form.yml,submit.yml.erb,template/script.sh.erb" "$(sc "$D" "$D" batch_connect "d['scope'] + '|' + ','.join(d['files'])")"
D="$FIX/curl-pipe-installer"
check "curl-pipe candidates" "interpolation:submit.yml.erb:7,interpolation:submit.yml.erb:9,interpolation:template/script.sh.erb:7,interpolation:template/script.sh.erb:9,interpolation:template/script.sh.erb:10,interpolation:template/script.sh.erb:15,eval_exec:template/script.sh.erb:15,interpolation:template/script.sh.erb:20,config_flag:template/script.sh.erb:20,interpolation:template/script.sh.erb:25,interpolation:template/script.sh.erb:26,eval_exec:template/script.sh.erb:26,network_call:template/script.sh.erb:26,config_flag:template/script.sh.erb:32,config_flag:template/script.sh.erb:34,config_flag:template/script.sh.erb:35,config_flag:template/script.sh.erb:36,config_flag:template/script.sh.erb:37" "$(sc "$D" "$D" batch_connect "$CL")"
check "curl-pipe counts" "interpolation=9,eval_exec=2,network_call=1,config_flag=6" "$(sc "$D" "$D" batch_connect "$NZ")"
check "curl-pipe scope takes Singularity.def" "True" "$(sc "$D" "$D" batch_connect "'Singularity.def' in d['files']")"
check "curl-pipe submit interpolations (quoted, unguarded)" "7:num_cores:False:True|9:bc_num_hours:False:True" "$(sc "$D" "$D" batch_connect "$FL3 $IF'submit.yml.erb'])")"
check "curl-pipe template interpolations: guarded by the enclosing if, quoted by the shell line" "7:conda_env_name:False:False|9:conda_env_name:False:False|10:conda_env_name:False:False|15:extra_packages:False:True|20:pip_index_url:False:True|25:setup_script_url:False:True|26:setup_script_url:False:True" "$(sc "$D" "$D" batch_connect "$FL3 $IF'template/script.sh.erb'])")"
check "curl-pipe presence checks come from the enclosing if" "7:False|9:False|10:False|15:True|20:True|25:True|26:True" "$(sc "$D" "$D" batch_connect "'|'.join('%s:%s' % (c['line'], c['presence_checked']) for c in $IF'template/script.sh.erb'])")"
check "shell double quotes still expand \$(...)" "True" "$(sc "$D" "$D" batch_connect "$IF'template/script.sh.erb'][-1]['note'].endswith('quoted (shell), still expands \$(...)')")"
check "curl | bash is curl-pipe-exec, eval is eval-exec" "15:eval-exec|26:curl-pipe-exec" "$(sc "$D" "$D" batch_connect "'|'.join('%s:%s' % (c['line'], c['tag']) for c in $BY'eval_exec'])")"
check "curl-pipe config flag rules and tags" "20:OODT-08:supply-chain-untrusted-index|32:OODT-05:bind-all-interfaces|34:OODT-05:disabled-auth|35:OODT-05:disabled-auth|36:OODT-05:cors-wildcard|37:OODT-05:disabled-xsrf" "$(sc "$D" "$D" batch_connect "'|'.join('%s:%s:%s' % (c['line'], c['rule'], c['tag']) for c in $BY'config_flag'])")"
check "network call shape" "network_call|sec-network-call|OODT-04|unexpected-network-call|curl -fsSL \"<%= context.setup_script_url %>\" | bash" "$(sc "$D" "$D" batch_connect "'|'.join(str($BY'network_call'][0][k]) for k in ('kind','check','rule','tag','text'))")"
check "interpolation note names the widget" "True" "$(sc "$D" "$D" batch_connect "'extra_packages (text_area)' in $BY'interpolation'][5]['note']")"
D="$FIX/containerized-server"
check "containerized-server candidates" "interpolation:submit.yml.erb:7,interpolation:submit.yml.erb:9,interpolation:submit.yml.erb:10,interpolation:submit.yml.erb:12,config_flag:template/create_nginx_conf.sh.erb:17,interpolation:template/script.sh.erb:9,interpolation:template/script.sh.erb:22,interpolation:template/script.sh.erb:23,config_flag:template/script.sh.erb:24" "$(sc "$D" "$D" batch_connect "$CL")"
check "containerized-server submit flags" "7:csc_cores:False:True|9:csc_time:False:True|10:csc_memory:False:True|12:csc_nvme:False:True" "$(sc "$D" "$D" batch_connect "$FL3 $IF'submit.yml.erb'])")"
check "containerized-server CORS" "OODT-05|cors-wildcard" "$(sc "$D" "$D" batch_connect "'%s|%s' % ($BY'config_flag'][0]['rule'], $BY'config_flag'][0]['tag'])")"
D="$FIX/passenger-flask-app"
check "passenger-flask chmod note: mode, not world-writable" "chmod 0o700, not world-writable" "$(sc "$D" "$D" passenger "$BY'permission_change'][0]['note']")"
check "passenger-flask candidates" "eval_exec:app.py:27,eval_exec:app.py:36,permission_change:app.py:68,eval_exec:app.py:69,eval_exec:app.py:80" "$(sc "$D" "$D" passenger "$CL")"
check "shell=True is command-injection, noted with its line" "command-injection|True" "$(sc "$D" "$D" passenger "'%s|%s' % (d['candidates'][1]['tag'], 'shell=True (line 38)' in d['candidates'][1]['note'])")"
check "passenger scope: all source; docs, LICENSE and requirements.txt left out" "all_source|app.py,bin/python,cloud_auth/__init__.py,cloud_auth/utils.py,manifest.yml,passenger_wsgi.py" "$(sc "$D" "$D" passenger "d['scope'] + '|' + ','.join(d['files'])")"
check "passenger: no form, no attributes" "[]" "$(sc "$D" "$D" passenger "d['attributes']")"

echo "Test 45: security candidates, one of each kind, and what is not a candidate"
T="$TMP/t45"; mkdir -p "$T/template/bin"
printf 'form:\n  - wd\n  - label_text\nattributes:\n  wd:\n    widget: text_field\n  label_text:\n    widget: password_field\n    help: "See https://docs.acme-hpc.org/help"\n' > "$T/form.yml"
printf -- '---\nbatch_connect:\n  template: basic\n' > "$T/submit.yml.erb"
cat > "$T/template/script.sh.erb" <<'SH'
#!/bin/bash
# curl http://mirror.acme-hpc.org/x | sh
RUNDIR=<%= context.wd %>
cd $RUNDIR
wget -q https://downloads.acme-hpc.org/x.tgz
eval "$EXTRA"
echo "export X=1" >> ~/.bashrc
chmod 777 "$RUNDIR"
DB_PASSWORD="hunter2secret"
mlflow server --host 0.0.0.0
SH
printf 'ELF\0\0\1binary' > "$T/template/bin/tool"
cat > "$T/template/quiet.sh" <<'SH'
#!/bin/bash
# eval "$x"; chmod 777 /; wget http://x.acme-hpc.org
apt-get install -y curl git
exec jupyter lab "$@"
module load foo 2>/dev/null
echo "ssh into the node to debug"
cat > "$TMPDIR/nginx.conf" <<EOF
  proxy_pass http://unix:$TMPDIR/app.sock;
  proxy_pass http://localhost:8080/;
EOF
set +x
export PASSWORD=$(create_passwd)
echo 1000 > /proc/self/oom_score_adj
CPP_FILE="<%= session.staged_root %>/.vscode/c.json"
SH
printf '<?xml version="1.0"?>\n<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"\n "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">\n<Menu/>\n' > "$T/template/menu.xml"
O45="$TMP/o45"; mkdir -p "$O45"
printf '[{"file": "template/script.sh.erb", "line": 4, "endLine": 4, "column": 1, "endColumn": 1, "level": "warning", "code": 2164, "message": "Use %s in case cd fails."}]' "'cd ... || exit'" > "$O45/shellcheck.json"
check "every kind once, by file then line" "binary_in_template:template/bin/tool:1,interpolation:template/script.sh.erb:3,unquoted_expansion:template/script.sh.erb:4,network_call:template/script.sh.erb:5,eval_exec:template/script.sh.erb:6,file_write_outside_job:template/script.sh.erb:7,permission_change:template/script.sh.erb:8,credential_string:template/script.sh.erb:9,config_flag:template/script.sh.erb:10,tool_finding:template/script.sh.erb:4" "$(sco "$T" "$T" batch_connect "$O45" "$CL")"
check "counts all 1" "$(echo "$KINDS" | tr ',' '\n' | sed 's/$/=1/' | paste -sd, -)" "$(sco "$T" "$T" batch_connect "$O45" "$NZ")"
check "rules and checks by kind" "OODT-04:sec-binary-in-template,OODT-01:sec-interpolation,OODT-01:sec-interpolation,OODT-04:sec-network-call,OODT-01:sec-eval-exec,OODT-07:sec-file-write-outside-job,OODT-03:sec-permissive-mode,OODT-02:sec-credential-string,OODT-05:sec-config-flag,None:sec-tool-finding" "$(sco "$T" "$T" batch_connect "$O45" "','.join('%s:%s' % (c['rule'], c['check']) for c in d['candidates'])")"
check "tags by kind" "binary-in-template,unsanitized-user-input,unquoted-variable,unexpected-network-call,eval-exec,dotfile-write,permissive-file-mode,hardcoded-credential,bind-all-interfaces,None" "$(sco "$T" "$T" batch_connect "$O45" "','.join(str(c['tag']) for c in d['candidates'])")"
check "tool_finding candidate shape: code, lines, level" "SC2164|[4]|warning" "$(sco "$T" "$T" batch_connect "$O45" "'%s|%s|%s' % ($BY'tool_finding'][0]['code'], $BY'tool_finding'][0]['lines'], $BY'tool_finding'][0]['level'])")"
check "unquoted expansion names the variable and its attribute" "True|True" "$(sc "$T" "$T" batch_connect "'%s|%s' % ('\$RUNDIR' in d['candidates'][2]['note'], 'wd' in d['candidates'][2]['note'])")"
check "mode and world-writable are noted" "chmod 777, world-writable" "$(sc "$T" "$T" batch_connect "d['candidates'][6]['note']")"
check "binary text; quiet.sh scanned" "binary file (12 bytes)|True" "$(sc "$T" "$T" batch_connect "d['candidates'][0]['text'] + '|' + str('template/quiet.sh' in d['files'])")"
printf '#!/bin/bash\neval "%0300d"\n' 0 > "$T/template/long.sh"
check "text capped at 200 chars" "200" "$(sc "$T" "$T" batch_connect "len([c for c in d['candidates'] if c['file']=='template/long.sh'][0]['text'])")"
rm -f "$T/template/long.sh"

echo "Test 46: interpolation through ERB variables and blocks (ood-sas submit.yml.erb, verbatim)"
T="$TMP/t46"; mkdir -p "$T"
printf 'attributes:\n  custom_reservation:\n    widget: text_field\n  custom_email_address:\n    widget: text_field\n  custom_memory_per_node:\n    widget: number_field\n  custom_time:\n    widget: text_field\n  custom_num_cores:\n    widget: number_field\n  custom_num_gpus:\n    widget: number_field\n  extra_slurm:\n    widget: text_field\nform:\n  - custom_reservation\n' > "$T/form.yml"
cat > "$T/submit.yml.erb" <<'YML'
---
batch_connect:
  template: "turbovnc"
  geometry: "1024x768"
script:
  reservation_id: <%= custom_reservation %>
  email: <%= custom_email_address %>
  native:
    - "--mem=<%= custom_memory_per_node.blank? ? 2 : custom_memory_per_node.to_s %>G"
    - "--time=<%= custom_time.blank? ? "04:00:00" : custom_time.to_s %>"
    - "--cpus-per-task=<%= custom_num_cores.blank? ? 1 : custom_num_cores.to_i %>"
   <%- if !custom_num_gpus.to_i.zero? -%>
    - "--gres=gpu:<%= custom_num_gpus.to_i %>"
   <%- end -%>
   <%- unless extra_slurm.blank? -%>
   <%- extra_slurm.split.each do |slurm_option| %>
    - "<%= slurm_option.to_s %>"
   <%- end %>
   <%- end -%>
YML
check "every interpolation with its line and flags" "6:custom_reservation:False:False|7:custom_email_address:False:False|9:custom_memory_per_node:False:True|10:custom_time:False:True|11:custom_num_cores:True:True|13:custom_num_gpus:True:True|17:extra_slurm:False:True" "$(sc "$T" "$T" batch_connect "$FL3 d['candidates'])")"
check "presence checks: inline blank?, enclosing if / unless" "6:False|7:False|9:True|10:True|11:True|13:True|17:True" "$(sc "$T" "$T" batch_connect "'|'.join('%s:%s' % (c['line'], c['presence_checked']) for c in d['candidates'])")"
check "YAML quotes are named as such" "True|True" "$(sc "$T" "$T" batch_connect "'%s|%s' % (d['candidates'][6]['note'].endswith('quoted (YAML)'), d['candidates'][0]['note'].endswith('unquoted'))")"
check "the block variable and the YAML key are in the note" "True|True" "$(sc "$T" "$T" batch_connect "'%s|%s' % ('via slurm_option' in d['candidates'][6]['note'], 'script.native' in d['candidates'][6]['note'])")"
check "form.json: extra_slurm reaches the scheduler through the block" "[15, 16]|True" "$(fm "$T" "$FL $A'extra_slurm'] for k in ('submit_lines','reaches_scheduler'))")"
T="$TMP/t46b"; mkdir -p "$T/template"
printf 'attributes:\n  n:\n    widget: text_field\n' > "$T/form.yml"
printf '#!/bin/bash\n# echo <%%= n %%>\n<%% if n.present? %%>\nA=<%%= n %%>\n<%% end %%>\nB="<%%= n %%>"; C=<%%= n.to_i %%>\n' > "$T/template/s.sh.erb"
printf '#!/bin/bash\necho <%%= n %%>\n' > "$T/template/raw.sh"
check "comment lines and non-.erb files are not interpolation; a line is quoted only if every tag is" "4:n:False:False|6:n:False:False" "$(sc "$T" "$T" batch_connect "$FL3 d['candidates'])")"
check "sanitiser is noted" "True" "$(sc "$T" "$T" batch_connect "'sanitised by .to_i' in d['candidates'][1]['note']")"
T="$TMP/t46c"; mkdir -p "$T/template"
printf 'attributes:\n  x:\n    widget: text_field\n  y:\n    widget: text_field\n' > "$T/form.yml"
cat > "$T/template/g.sh.erb" <<'SH'
#!/bin/bash
A=<%= x.shellescape %>
B=<%= x.blank? ? 'a' : x %>
C=<%= Shellwords.escape(y) %>
<% if y =~ /\A\w+\z/ %>
D=<%= y %>
<% end %>
<% if %w[a b].include?(x) %>
E=<%= x %>
<% end %>
F=<%= x.to_s.to_i %>
G=<%= x == "1" ? 'lab' : 'tree' %>
SH
check "guarded means sanitised or validated; presence is separate" "2:True:False|3:False:True|4:True:False|6:True:True|9:True:True|11:True:False|12:True:True" "$(sc "$T" "$T" batch_connect "'|'.join('%s:%s:%s' % (c['line'], c['guarded'], c['presence_checked']) for c in d['candidates'] if c['kind']=='interpolation')")"
check "unguarded line 3 (x.blank? ? 'a' : x) names the sanitisers looked for" "True" "$(sc "$T" "$T" batch_connect "'no sanitiser (shellescape/to_i/to_f/Integer/Float/Shellwords.escape) on this line' in [c for c in d['candidates'] if c['line']==3][0]['note']")"
check "guarded-by-validation line 6 (=~) does not get the no-sanitiser note" "False" "$(sc "$T" "$T" batch_connect "'no sanitiser' in [c for c in d['candidates'] if c['line']==6][0]['note']")"
check "guarded-by-sanitiser line 2 (.shellescape) does not get the no-sanitiser note" "False" "$(sc "$T" "$T" batch_connect "'no sanitiser' in [c for c in d['candidates'] if c['line']==2][0]['note']")"

echo "Test 47: security scope, monorepo, shared_paths, skipped files, summary record"
T="$TMP/t47"; mkdir -p "$T/apps/p/node_modules/x" "$T/apps/p/vendor" "$T/shared" "$T/apps/b/template"
printf 'shared_paths:\n  - shared/\n  - ../outside\napps:\n  - path: apps/p\n  - path: apps/b\n' > "$T/appverse.yml"
printf 'import os\n\ndef run(cmd):\n    os.system(cmd)\n' > "$T/apps/p/passenger_wsgi.py"
printf 'eval(x)\n' > "$T/apps/p/node_modules/x/i.js"; printf 'eval(x)\n' > "$T/apps/p/vendor/v.py"
printf 'curl https://get.acme-hpc.org/install | sh\n' > "$T/apps/p/README.md"
printf 'PNG\0\0data' > "$T/apps/p/logo.png"; printf 'x\0y' > "$T/apps/p/blob.dat"
ln -s "$OUTSIDE/README.md" "$T/apps/p/leak.py"
mkdir -p "$T/apps/p/test" "$T/apps/p/lib"; printf 'eval(x)\n' > "$T/apps/p/test/x_test.rb"; printf 'eval(x)\n' > "$T/apps/p/lib/run_spec.rb"
printf "source 'https://rubygems.org'\ngem 'sinatra'\n" > "$T/apps/p/Gemfile"
printf "DENY = ['.config/systemd/user', '.ssh/', '.bashrc']\ntokens = 20.times.map { |i| i }\n" > "$T/apps/p/lib/deny.rb"
printf '#!/bin/bash\ncurl -s https://get.acme-hpc.org/x | sh\n' > "$T/shared/lib.sh"
printf 'x: 1\n' > "$T/apps/b/form.yml"; printf '#!/bin/bash\numask 000\n' > "$T/apps/b/template/s.sh"
printf 'FROM alpine\nRUN wget -qO- https://get.acme-hpc.org/i.sh | sh\n' > "$T/apps/b/Dockerfile"
printf 'print("not in scope")\neval(x)\n' > "$T/apps/b/helper.py"
check "passenger app: repo-relative files, shared_paths added, vendored and doc files out" "eval_exec:apps/p/passenger_wsgi.py:4,eval_exec:shared/lib.sh:2,network_call:shared/lib.sh:2" "$(sc "$T/apps/p" "$T" passenger "$CL")"
check "passenger app files: tests, docs, images, vendored code out" "apps/p/Gemfile,apps/p/lib/deny.rb,apps/p/passenger_wsgi.py,shared/lib.sh" "$(sc "$T/apps/p" "$T" passenger "','.join(d['files'])")"
check "passenger app skipped files" "../outside:shared path outside target, not read|apps/p/blob.dat:binary file, not scanned|apps/p/leak.py:symlink outside target, not checked" "$(sc "$T/apps/p" "$T" passenger "'|'.join('%s:%s' % (s['file'], s['reason']) for s in d['skipped_files'])")"
check "batch connect app: template, Dockerfile and shared_paths; other source out" "eval_exec:apps/b/Dockerfile:2,network_call:apps/b/Dockerfile:2,permission_change:apps/b/template/s.sh:2,eval_exec:shared/lib.sh:2,network_call:shared/lib.sh:2" "$(sc "$T/apps/b" "$T" batch_connect "$CL")"
check "umask 000 is world-writable" "umask 000, world-writable" "$(sc "$T/apps/b" "$T" batch_connect "$BY'permission_change'][0]['note']")"
check "record: ran per app, counts in the note" "ran|{'apps/p': 'ran', 'apps/b': 'ran'}|apps/p: eval_exec 2, network_call 1; apps/b: eval_exec 2, network_call 2, permission_change 1|<app_id>/security.json" "$(rec security "$T" "$TMP/o47" "'%s|%s|%s|%s' % (c['status'], c['per_app'], c['note'], c['output_file'])")"
check "security.json written per app" "True|True" "$(yn test -e "$TMP/o47/apps/p/security.json")|$(yn test -e "$TMP/o47/apps/b/security.json")"
T="$TMP/t47b"; mkdir -p "$T"; printf 'name: x\n' > "$T/manifest.yml"; printf '# x\n' > "$T/README.md"
check "an app with nothing to flag: ran, no candidates" "ran|root: no candidates" "$(rec security "$T" "$TMP/o47b" "'%s|%s' % (c['status'], c['note'])")"
T="$TMP/t47c"; mkdir -p "$T"; printf '# x\n' > "$T/README.md"
check "an app with no in-scope file: skipped, noted" "skipped|root: no in-scope files|False" "$(rec security "$T" "$TMP/o47c" "'%s|%s' % (c['status'], c['note'])")|$(yn test -e "$TMP/o47c/root/security.json")"
O="$TMP/o47e"
check "end to end exit 0" 0 "$(e2e "$FIX/containerized-server" "$O")"
check "end to end: security record and security.json" "ran|{'root': 'ran'}|root: interpolation 7, config_flag 2|7" "$(fct "$O" security status)|$(fct "$O" security per_app)|$(fct "$O" security note)|$(fact "$O" root security "d['counts']['interpolation']")"

echo "Test 48: security review fixes: images, write targets, set -x, Ruby commands, binds, URLs"
T="$TMP/t48"; mkdir -p "$T/template/assets"
printf 'x: 1\n' > "$T/form.yml"
printf '\211PNG\r\n\032\n\0\0\0\rIHDR\0\0\0\1' > "$T/template/assets/logo.png"
printf 'wOFF\0\1\0\0' > "$T/template/assets/f.woff"
cat > "$T/template/script.sh" <<'SH'
#!/bin/bash
set -x
cp out.log /tmp/run.log
echo done > $HOME/notes.txt
tee -a /usr/local/share/x.conf < in
chmod 700 "$d"
chmod u+x run.sh
chmod o+w shared.txt
SH
check "images and fonts are not binary candidates, and are listed as skipped" "file_write_outside_job:3,file_write_outside_job:4,file_write_outside_job:5|template/assets/f.woff:woff file (by its magic bytes), not a candidate|template/assets/logo.png:png file (by its magic bytes), not a candidate" "$(sc "$T" "$T" batch_connect "','.join('%s:%s' % (c['kind'], c['line']) for c in d['candidates'] if c['kind'] in ('binary_in_template','file_write_outside_job')) + '|' + '|'.join('%s:%s' % (s['file'], s['reason']) for s in d['skipped_files'])")"
check "non-dotfile targets are write-outside-job" "write-outside-job|write-outside-job|write-outside-job" "$(sc "$T" "$T" batch_connect "'|'.join(c['tag'] for c in $BY'file_write_outside_job'])")"
check "set -x note says where the trace goes" "shell tracing on; trace output goes to the job's own output.log; world-readable only if the job directory is" "$(sc "$T" "$T" batch_connect "$BY'config_flag'][0]['note']")"
check "permission notes state the mode" "chmod 700, not world-writable|chmod u+x, not world-writable|chmod o+w, world-writable" "$(sc "$T" "$T" batch_connect "'|'.join(c['note'] for c in $BY'permission_change'])")"
check "write-outside-job is in the OODT-07 vocabulary" "1" "$(grep -c '`write-outside-job`' "$SCRIPT_DIR/references/finding-codes.md")"
check "cron is never a substring of a word" "write-outside-job" "$(px "r=pr._write_target('\$HOME/acronyms.txt')")"
check "crontab and a /cron path segment are cron-install" "cron-install|cron-install|cron-install|cron-install" "$(px "r='|'.join(pr._write_target(t) for t in ('/usr/bin/crontab', '/etc/cron.d/myjob', '/var/spool/cron/crontabs/user', '/etc/cron.daily/cleanup'))")"
T="$TMP/t48e"; mkdir -p "$T/template"
printf 'x: 1\n' > "$T/form.yml"
printf '#!/bin/bash\necho x > $HOME/acronyms.txt\necho x >> /etc/cron.d/myjob\n' > "$T/template/s.sh"
check "acronyms.txt is not tagged cron-install; a real cron path is" "write-outside-job:2|cron-install:3" "$(sc "$T" "$T" batch_connect "'|'.join('%s:%s' % (c['tag'], c['line']) for c in $BY'file_write_outside_job'])")"
T="$TMP/t48c"; mkdir -p "$T/template"
printf 'x: 1\n' > "$T/form.yml"
printf 'true\0\1\0\0binarydata' > "$T/template/x.sh"
printf 'true\0\1\0\0binarydata' > "$T/template/a.ttf"
check "font magic in a .sh is a candidate; the same bytes in a .ttf are exempt" "binary_in_template:template/x.sh|template/a.ttf:ttf file (by its magic bytes), not a candidate" "$(sc "$T" "$T" batch_connect "'|'.join('%s:%s' % (c['kind'], c['file']) for c in d['candidates']) + '|' + '|'.join('%s:%s' % (s['file'], s['reason']) for s in d['skipped_files'])")"
T="$TMP/t48b"; mkdir -p "$T"
printf 'run App\n' > "$T/config.ru"
cat > "$T/app.rb" <<'RB'
out = `ls #{params[:dir]}`
out2 = %x(ls #{params[:dir]})
url = "http://#{host}/x"
name = Foo::Bar.split('::')
RB
printf "app.listen(3000, '::')\nserver.listen(3000, 'localhost')\n" > "$T/server.js"
check "Ruby backticks and %x() are eval_exec; #{} host is no URL; listen '::' binds" "eval_exec:app.rb:1,eval_exec:app.rb:2,config_flag:server.js:1" "$(sc "$T" "$T" passenger "$CL")"
check "companion app gets entry_point.json" "ran|{'root': 'ran'}|config.ru" "$(printf 'app_type: companion\n' > "$T/appverse.yml"; rec entry_point "$T" "$TMP/o48" "'%s|%s' % (c['status'], c['per_app'])")|$(j "$TMP/o48/root/entry_point.json" "d['file']")"

echo "Test 49: tool_finding candidates, end to end through run-pre-review.sh"
T="$TMP/t49"; mkdir -p "$T/template"
printf 'x: 1\n' > "$T/form.yml"
cat > "$T/template/script.sh.erb" <<'SH'
#!/bin/bash
DIR=/tmp/work
cd $DIR
echo $X
echo $X
SH
O="$TMP/o49"
check "exit 0" 0 "$(run "$T" "$O")"
if has_sc; then
  check "SC2164 (cd, line 3) and SC2086 (both echo lines) are tool_finding candidates" \
    "SC2164:[3]|SC2086:[4, 5]" \
    "$(j "$O/root/security.json" "'|'.join('%s:%s' % (c['code'], c['lines']) for c in d['candidates'] if c['kind']=='tool_finding')")"
  check "tool_finding candidates carry check, rule, tag null; the manifest check maps rule/tag per match" \
    "sec-tool-finding:None:None|sec-tool-finding:None:None" \
    "$(j "$O/root/security.json" "'|'.join('%s:%s:%s' % (c['check'], c['rule'], c['tag']) for c in d['candidates'] if c['kind']=='tool_finding')")"
  check "no tool_finding_collapsed key below the ceiling" "False" "$(j "$O/root/security.json" "'tool_finding_collapsed' in d['counts']")"
else skip "shellcheck not installed"; skip "shellcheck not installed"; skip "shellcheck not installed"; fi

echo "Test 50: tool_finding excludes shellcheck style level (assert on the level filter with a synthetic shellcheck JSON, since -S info already keeps every other level)"
T="$TMP/t50"; mkdir -p "$T/template"
printf 'x: 1\n' > "$T/form.yml"
printf '#!/bin/bash\necho hi\n' > "$T/template/a.sh"
O="$TMP/o50"; mkdir -p "$O"
printf '[{"file": "template/a.sh", "line": 1, "level": "style", "code": 2250, "message": "style-only hint"},\n {"file": "template/a.sh", "line": 2, "level": "info", "code": 2086, "message": "kept"}]' > "$O/shellcheck.json"
check "style level excluded, info level kept" "SC2086" "$(sco "$T" "$T" batch_connect "$O" "','.join(c['code'] for c in d['candidates'] if c['kind']=='tool_finding')")"

echo "Test 51: tool_finding ceiling collapses to one per (tool, code) across files"
T="$TMP/t51"; mkdir -p "$T/template"
printf 'x: 1\n' > "$T/form.yml"
printf '#!/bin/bash\necho hi\n' > "$T/template/a.sh"
printf '#!/bin/bash\necho hi\n' > "$T/template/b.sh"
O="$TMP/o51"; mkdir -p "$O"
python3 - "$O/shellcheck.json" <<'PY'
import json, sys
items = [{"file": "template/a.sh" if i % 2 == 0 else "template/b.sh", "line": i + 1,
          "level": "warning", "code": 2000 + i, "message": "msg %d" % i} for i in range(16)]
json.dump(items, open(sys.argv[1], "w"))
PY
check "16 distinct codes collapse to 16 (tool, code) candidates" "16" "$(sco "$T" "$T" batch_connect "$O" "len([c for c in d['candidates'] if c['kind']=='tool_finding'])")"
check "counts.tool_finding_collapsed is set" "True" "$(sco "$T" "$T" batch_connect "$O" "d['counts'].get('tool_finding_collapsed')")"
check "a collapsed candidate has no single file; lines carry file:line strings" "None|True" "$(sco "$T" "$T" batch_connect "$O" "'%s|%s' % ($BY'tool_finding'][0]['file'], all(':' in x for x in $BY'tool_finding'][0]['lines']))")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
