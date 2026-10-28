#!/usr/bin/env bash
# Test metadata.json: each app's catalog fields resolved the way the hub's sync (RepoSyncService) resolves them.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$SCRIPT_DIR/references/run-pre-review.sh"
FIX="$SCRIPT_DIR/tests/fixtures"
export APPVERSE_CATALOG="$FIX/catalog"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
# jq-free JSON reads: j <file> <python expression over d>
j() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2" 2>&1; }
# repo <name>: a fresh fixture repo dir with an empty app dir a/; w <repo> <path> <text>: write one file
repo() { rm -rf "$TMP/$1"; mkdir -p "$TMP/$1/a"; echo "$TMP/$1"; }
w() { mkdir -p "$(dirname "$1/$2")"; printf '%s\n' "$3" > "$1/$2"; }
# meta <repo>: run the pre-review and print metadata.json's path
meta() { bash "$RUN" --no-catalog "$1" "$1.out" > /dev/null 2>&1; echo "$1.out/metadata.json"; }
# app <metadata.json> <app_id> <expression over a>: one app's entry
app() { j "$1" "(lambda a: $3)([x for x in d['apps'] if x['app_id']=='$2'][0])"; }

ROOT_M='maintainer:
  name: T
  support_url: https://x'
ENTRY='  - path: a
    name: A
    description: D
    app_type: batch-connect-basic
    software: s'

echo "Test 1: top-level maintainer inherited"
R=$(repo t1); w "$R" appverse.yml "$ROOT_M
apps:
$ENTRY"; w "$R" a/manifest.yml "role: batch_connect"
M=$(meta "$R")
check "nothing missing" "[]" "$(app "$M" a "a['missing']")"
check "maintainer source" "appverse.yml" "$(app "$M" a "a['fields']['maintainer.name']['source']")"
check "shape" "monorepo" "$(j "$M" "d['shape']")"
check "root_maintainer" "T" "$(j "$M" "d['root_maintainer']['name']")"
check "summary records metadata" "ran" "$(j "$R.out/summary.json" "[c for c in d['facts'] if c['name']=='metadata'][0]['status']")"

echo "Test 2: a partial maintainer of the app's own overrides, no merge"
R=$(repo t2); w "$R" appverse.yml "$ROOT_M
apps:
$ENTRY
    maintainer:
      name: Own"; w "$R" a/manifest.yml "role: batch_connect"
check "support_url missing" "['maintainer.support_url']" "$(app "$(meta "$R")" a "a['missing']")"

echo "Test 3: maintainer null inherits"
R=$(repo t3); w "$R" appverse.yml "$ROOT_M
apps:
$ENTRY
    maintainer: null"
M=$(meta "$R")
check "declared" "declared" "$(app "$M" a "a['status']")"
check "nothing missing" "[]" "$(app "$M" a "a['missing']")"

echo "Test 4: maintainer {} blocks inheritance"
R=$(repo t4); w "$R" appverse.yml "$ROOT_M
apps:
$ENTRY
    maintainer: {}"
check "both missing" "['maintainer.name', 'maintainer.support_url']" "$(app "$(meta "$R")" a "a['missing']")"

echo "Test 5: string maintainer"
R=$(repo t5); w "$R" appverse.yml "apps:
$ENTRY
    maintainer: T"
M=$(meta "$R")
check "both missing" "['maintainer.name', 'maintainer.support_url']" "$(app "$M" a "a['missing']")"
check "root_maintainer null" "None" "$(j "$M" "d['root_maintainer']")"

echo "Test 6: name and description fall back to manifest.yml; app_type does not"
R=$(repo t6); w "$R" appverse.yml "$ROOT_M
apps:
  - path: a
    software: s"; w "$R" a/manifest.yml "name: MN
description: MD
app_type: batch-connect-basic"
M=$(meta "$R")
check "only app_type missing" "['app_type']" "$(app "$M" a "a['missing']")"
check "name source" "a/manifest.yml" "$(app "$M" a "a['fields']['name']['source']")"
check "name value" "MN" "$(app "$M" a "a['fields']['name']['value']")"

echo "Test 7: a name of \"0\" is missing"
R=$(repo t7); w "$R" appverse.yml "$ROOT_M
apps:
  - path: a
    name: \"0\"
    description: D
    app_type: batch-connect-basic
    software: s"
check "name missing" "['name']" "$(app "$(meta "$R")" a "a['missing']")"

echo "Test 8: an empty name blocks the manifest fallback"
R=$(repo t8); w "$R" appverse.yml "$ROOT_M
apps:
  - path: a
    name: \"\"
    description: D
    app_type: batch-connect-basic
    software: s"; w "$R" a/manifest.yml "name: M"
check "name missing" "['name']" "$(app "$(meta "$R")" a "a['missing']")"

echo "Test 9: a single declared repo takes title as its name"
R=$(repo t9); w "$R" appverse.yml "title: X
description: D
app_type: batch-connect-basic
software: s
$ROOT_M"
M=$(meta "$R")
check "shape" "single" "$(j "$M" "d['shape']")"
check "name from title" "X" "$(app "$M" root "a['fields']['name']['value']")"
check "nothing missing" "[]" "$(app "$M" root "a['missing']")"
check "root_maintainer null on the single path" "None" "$(j "$M" "d['root_maintainer']")"

echo "Test 10: a single declared repo does not fall back to manifest.yml"
R=$(repo t10); w "$R" appverse.yml "app_type: batch-connect-basic
software: s
$ROOT_M"; w "$R" manifest.yml "name: MN
description: MD"
check "name and description missing" "['name', 'description']" "$(app "$(meta "$R")" root "a['missing']")"

echo "Test 11: a YAML tag makes the root unparsed, not refused"
R=$(repo t11); w "$R" appverse.yml "title: !!str X"; w "$R" manifest.yml "name: MN"
M=$(meta "$R")
check "shape" "unparsed" "$(j "$M" "d['shape']")"
check "app status" "unparsed" "$(app "$M" root "a['status']")"
check "nothing demanded" "[]" "$(app "$M" root "a['missing']")"

echo "Test 12: an unparseable member appverse.yml is treated as empty"
R=$(repo t12); w "$R" appverse.yml "$ROOT_M
apps:
$ENTRY"; w "$R" a/appverse.yml ": : :"
M=$(meta "$R")
check "status" "declared" "$(app "$M" a "a['status']")"
check "nothing missing" "[]" "$(app "$M" a "a['missing']")"

echo "Test 13: an inferred repo demands nothing"
R=$(repo t13); w "$R" manifest.yml "name: MN"
M=$(meta "$R")
check "shape" "inferred" "$(j "$M" "d['shape']")"
check "status" "inferred" "$(app "$M" root "a['status']")"
check "nothing demanded" "[]" "$(app "$M" root "a['missing']")"

echo "Test 14: anchors are refused, with a note that the hub may read the file"
R=$(repo t14); w "$R" appverse.yml "maintainer: &m
  name: T
  support_url: https://x
title: X"
M=$(meta "$R")
check "shape" "refused" "$(j "$M" "d['shape']")"
check "status" "refused" "$(app "$M" root "a['status']")"
check "nothing demanded" "[]" "$(app "$M" root "a['missing']")"
check "note" "uses YAML anchors or aliases, which this tool does not read; the hub may read it" "$(app "$M" root "a['note']")"

echo "Test 15: an app the shape resolver skips demands nothing"
R=$(repo t15); w "$R" appverse.yml "$ROOT_M
apps:
  - path: nope"
M=$(meta "$R")
check "status" "skipped" "$(app "$M" nope "a['status']")"
check "nothing demanded" "[]" "$(app "$M" nope "a['missing']")"

echo "Test 16: software is reported on its own, never in missing"
R=$(repo t16); w "$R" appverse.yml "$ROOT_M
apps:
  - path: a
    name: A
    description: D
    app_type: batch-connect-basic"
M=$(meta "$R")
check "software_missing" "True" "$(app "$M" a "a['software_missing']")"
check "not in missing" "[]" "$(app "$M" a "a['missing']")"

echo
echo "metadata facts: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
