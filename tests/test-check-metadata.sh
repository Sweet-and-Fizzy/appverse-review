#!/usr/bin/env bash
# Test check-metadata.py: STR-02 findings agree with the pre-review's resolved metadata (metadata.json) and catalog.json.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHK="$SCRIPT_DIR/references/check-metadata.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { python3 "$CHK" "$@" > "$TMP/out" 2>&1; echo $?; }

# fact <dir> <shape> <root_maintainer JSON> <app JSON>...: a pre-review dir holding metadata.json
fact() { local dir="$1" shape="$2" rm="$3"; shift 3; mkdir -p "$dir"
  python3 - "$dir" "$shape" "$rm" "$@" <<'PY'
import json, sys
d, shape, rm, *apps = sys.argv[1:]
json.dump({"schema": "metadata/1", "shape": shape, "root_maintainer": json.loads(rm),
           "apps": [json.loads(a) for a in apps]}, open(d + "/metadata.json", "w"))
PY
}
# an <app_id> <missing JSON list> [maintainer source, or null]: one declared app; every field not missing is present;
# maintainer fields carry the maintainer mapping's source even when missing, as metadata_facts.py writes them
an() { python3 - "$1" "$2" "${3:-appverse.yml}" <<'PY'
import json, sys
aid, missing, msrc = sys.argv[1], json.loads(sys.argv[2]), json.loads(sys.argv[3]) if sys.argv[3] == "null" else sys.argv[3]
names = ["name", "description", "app_type", "software", "implementation_tags", "maintainer.name", "maintainer.support_url"]
fields = {}
for n in names:
    src = msrc if n.startswith("maintainer.") else (None if n in missing else "appverse.yml")
    fields[n] = {"value": None if n in missing else "v", "source": src}
print(json.dumps({"app_id": aid, "status": "declared", "note": None, "fields": fields,
                  "missing": missing, "software_missing": False}))
PY
}
# catalog <dir> <app_id> <app_type> <status>: a catalog.json with one app's app_type verdict
catalog() { printf '{"apps": [{"app_id": "%s", "checks": {"app_type": {"status": "%s", "value": "%s"}}}]}' "$2" "$4" "$3" > "$1/catalog.json"; }
# finding <app_id> <defect_key> [result]
finding() { printf '{"app_id":"%s","rule":"STR-02","defect_key":"%s","aspect":"structure","severity":"high","result":"%s","summary":"s","evidence":"x"}' "$1" "$2" "${3:-FAIL}"; }

echo "Test 1: all present, no records"
fact "$TMP/p1" monorepo null "$(an a '[]')"; echo "[]" > "$TMP/f1.json"
check "exit 0" 0 "$(run "$TMP/f1.json" "$TMP/p1")"
check "summary" "metadata: 1 apps, 0 problems" "$(tail -1 "$TMP/out")"

echo "Test 2: a missing field with its FAIL record"
fact "$TMP/p2" monorepo null "$(an a '["maintainer.support_url"]')"
echo "[$(finding a a/appverse.yml:missing-field:maintainer.support_url)]" > "$TMP/f2.json"
check "exit 0" 0 "$(run "$TMP/f2.json" "$TMP/p2")"

echo "Test 3: a missing field with no record"
check "exit 1" 1 "$(run "$TMP/f1.json" "$TMP/p2")"
check "line" 1 "$(grep -cxF 'MISSING a missing-field:maintainer.support_url (metadata.json lists it missing; record a STR-02 FAIL)' "$TMP/out")"
check "summary" "metadata: 1 apps, 1 problems" "$(tail -1 "$TMP/out")"

echo "Test 4: a FAIL for a field the fact resolves (the Tufts case)"
echo "[$(finding a a/manifest.yml:missing-field:maintainer.name)]" > "$TMP/f4.json"
check "exit 1" 1 "$(run "$TMP/f4.json" "$TMP/p1")"
check "line" 1 "$(grep -cxF 'MISMATCH a missing-field:maintainer.name: FAIL, but metadata.json resolves it from appverse.yml' "$TMP/out")"

echo "Test 5: a root FAIL for a maintainer field the root declares"
fact "$TMP/p5" monorepo '{"name": "T", "support_url": "u"}' "$(an a '[]')"
echo "[$(finding root appverse.yml:missing-field:maintainer.name)]" > "$TMP/f5.json"
check "exit 1" 1 "$(run "$TMP/f5.json" "$TMP/p5")"
check "line" 1 "$(grep -cxF 'MISMATCH root missing-field:maintainer.name: FAIL, but metadata.json resolves it from appverse.yml' "$TMP/out")"

echo "Test 6: one root record answers a maintainer field every app lacks"
fact "$TMP/p6" monorepo null "$(an a '["maintainer.name"]' null)" "$(an b '["maintainer.name"]' null)"
echo "[$(finding root appverse.yml:missing-field:maintainer.name)]" > "$TMP/f6.json"
check "exit 0" 0 "$(run "$TMP/f6.json" "$TMP/p6")"
check "no MISSING" 0 "$(grep -c '^MISSING' "$TMP/out")"

echo "Test 7: the root record does not answer when one app declares a maintainer of its own"
fact "$TMP/p7" monorepo null "$(an a '["maintainer.name"]' null)" "$(an b '["maintainer.name"]' b/appverse.yml)"
check "exit 1" 1 "$(run "$TMP/f6.json" "$TMP/p7")"
check "both apps named" 2 "$(grep -c '^MISSING [ab] missing-field:maintainer.name ' "$TMP/out")"

echo "Test 8: an unknown-app-type FAIL for a type the catalog knows"
fact "$TMP/p8" monorepo null "$(an a '[]')"; catalog "$TMP/p8" a batch-connect-basic known
echo "[$(finding a appverse.yml:app-type-not-in-vocabulary)]" > "$TMP/f8.json"
check "exit 1" 1 "$(run "$TMP/f8.json" "$TMP/p8")"
check "line" 1 "$(grep -cxF "MISMATCH a app-type-not-in-vocabulary: FAIL, but catalog.json lists 'batch-connect-basic' as a known app type" "$TMP/out")"

echo "Test 9: the legacy other: key is read the same way"
echo "[$(finding a appverse.yml:other:app-type-not-in-vocabulary)]" > "$TMP/f9.json"
check "exit 1" 1 "$(run "$TMP/f9.json" "$TMP/p8")"
check "line" 1 "$(grep -c '^MISMATCH a app-type-not-in-vocabulary:' "$TMP/out")"

echo "Test 10: an unknown app type the catalog also calls unknown is fine"
fact "$TMP/p10" monorepo null "$(an a '[]')"; catalog "$TMP/p10" a dashboards unknown
check "exit 0" 0 "$(run "$TMP/f8.json" "$TMP/p10")"

echo "Test 11: no catalog.json skips the app_type rule"
check "exit 0" 0 "$(run "$TMP/f8.json" "$TMP/p1")"

echo "Test 12: an app that is not declared is skipped"
fact "$TMP/p12" inferred null '{"app_id": "root", "status": "inferred", "note": null, "fields": {}, "missing": [], "software_missing": false}'
echo "[$(finding root manifest.yml:missing-field:name)]" > "$TMP/f12.json"
check "exit 0" 0 "$(run "$TMP/f12.json" "$TMP/p12")"

echo "Test 13: a present-but-empty value (in missing) may be FAILed"
fact "$TMP/p13" monorepo null "$(an a '["name"]')"
echo "[$(finding a appverse.yml:missing-field:name)]" > "$TMP/f13.json"
check "exit 0" 0 "$(run "$TMP/f13.json" "$TMP/p13")"

echo "Test 14: PASS and WARN records are not FAILs"
echo "[$(finding a a/manifest.yml:missing-field:maintainer.name PASS)]" > "$TMP/f14.json"
check "exit 0" 0 "$(run "$TMP/f14.json" "$TMP/p1")"

echo "Test 15: no metadata.json: not judged"
mkdir -p "$TMP/p15"
check "exit 0" 0 "$(run "$TMP/f4.json" "$TMP/p15")"
check "summary" "metadata: not judged (no metadata.json in $TMP/p15)" "$(tail -1 "$TMP/out")"

echo "Test 16: unreadable findings is exit 2"
echo "{" > "$TMP/f16.json"
check "exit 2" 2 "$(run "$TMP/f16.json" "$TMP/p1")"

echo "Test 17: a missing-field:software FAIL is right when software_missing is set"
fact "$TMP/p17" monorepo null "$(an a '[]' | python3 -c 'import json,sys; a=json.load(sys.stdin); a["software_missing"]=True; a["fields"]["software"]={"value": None, "source": None}; print(json.dumps(a))')"
echo "[$(finding a appverse.yml:missing-field:software)]" > "$TMP/f17.json"
check "exit 0" 0 "$(run "$TMP/f17.json" "$TMP/p17")"
check "a software FAIL where software is present is a MISMATCH" 1 "$(run "$TMP/f17.json" "$TMP/p1")"

echo
echo "check-metadata: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
