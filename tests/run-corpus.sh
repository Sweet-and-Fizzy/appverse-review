#!/usr/bin/env bash
# Run check-all.py over every committed corpus run and diff its output
# against tests/corpus/expected/<run-id>.txt. Prints PASS/DIFF per run and
# exits 1 if any run diverges from its expected file.
#
# Also computes, per run, the off-candidate recall against
# tests/recall-set/<target>.json: a defect counts as recalled when a
# FAIL/WARN record in that run's findings.json has the recall item's key.
# The recall table is informational unless the run's expected file sets a
# floor with a leading "# recall-floor: N/M" comment line, in which case
# recall below that floor is also a diff (and fails the run).
#
#   tests/run-corpus.sh            # check every run against expected/
#   tests/run-corpus.sh --update   # rewrite expected/ from current checkers
#
# POSIX/bash-3.2 compatible: no associative arrays, no mapfile.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR" || exit 2

CORPUS_DIR="tests/corpus"
EXPECTED_DIR="$CORPUS_DIR/expected"
TARGETS_DIR="$CORPUS_DIR/.targets"
CHECK_ALL="references/check-all.py"
CHECKS_JSON="references/checks.json"

UPDATE=0
if [ "${1:-}" = "--update" ]; then
  UPDATE=1
fi

# resolve_target <run-dir> -> prints an absolute --target path on stdout
resolve_target() {
  run_dir="$1"
  tgt_file="$run_dir/target.txt"
  if [ ! -f "$tgt_file" ]; then
    echo "error: $tgt_file missing" >&2
    return 1
  fi
  spec=$(head -1 "$tgt_file")
  case "$spec" in
    *" @ "*)
      repo="${spec%% @ *}"
      sha="${spec##* @ }"
      name=$(echo "$repo" | tr '/' '-')
      dest="$TARGETS_DIR/$name"
      if [ ! -d "$dest/.git" ]; then
        mkdir -p "$TARGETS_DIR"
        echo "cloning $repo @ $sha -> $dest" >&2
        rm -rf "$dest"
        git clone --quiet --depth 50 "https://github.com/$repo" "$dest" >&2 || return 1
      fi
      current=$(git -C "$dest" rev-parse HEAD 2>/dev/null || echo "")
      case "$current" in
        "$sha"*) : ;;
        *)
          git -C "$dest" fetch --quiet --depth 50 origin "$sha" >&2 || true
          git -C "$dest" checkout --quiet "$sha" >&2 || return 1
          ;;
      esac
      echo "$SCRIPT_DIR/$dest"
      ;;
    *)
      # a bare path, relative to the repo root (e.g. a tests/fixtures checkout)
      echo "$SCRIPT_DIR/$spec"
      ;;
  esac
}

# recall_file_for <run-id> -> prints the matching tests/recall-set/*.json or nothing
recall_file_for() {
  case "$1" in
    ood-sas-*) echo "tests/recall-set/ood-sas.json" ;;
    tillicum-*) echo "tests/recall-set/tillicum.json" ;;
    *) echo "" ;;
  esac
}

# recall_table <run-dir> <recall-file>
recall_table() {
  run_dir="$1"; recall_file="$2"
  [ -f "$recall_file" ] || return 0
  [ -f "$run_dir/findings.json" ] || return 0
  python3 - "$run_dir/findings.json" "$recall_file" <<'PYEOF'
import json, sys
findings_path, recall_path = sys.argv[1], sys.argv[2]
try:
    findings = json.load(open(findings_path))
except (OSError, ValueError):
    findings = []
recorded = set()
for f in findings:
    if isinstance(f, dict) and str(f.get("result", "")).upper() in ("FAIL", "WARN"):
        key = f.get("defect_key")
        if key:
            recorded.add(key)
        rule = f.get("rule")
        if rule and key:
            recorded.add("{}:{}".format(rule, key))
items = json.load(open(recall_path))
hits = 0
total_candidates = 0
for item in items:
    key = item.get("key", "")
    is_candidate = bool(item.get("candidate"))
    hit = key in recorded
    if is_candidate:
        total_candidates += 1
        if hit:
            hits += 1
    mark = "HIT " if hit else "MISS"
    cflag = "candidate" if is_candidate else "known-miss"
    print("    {} {} {:<10} {}".format(mark, cflag, item.get("rule", "?"), key))
if total_candidates:
    print("  recall: {}/{} candidate defects recalled".format(hits, total_candidates))
else:
    print("  recall: no candidate defects in this recall set")
PYEOF
}

if [ "$UPDATE" -eq 1 ]; then
  mkdir -p "$EXPECTED_DIR"
fi

total=0
diffs=0
for run_dir in "$CORPUS_DIR"/*/; do
  run_dir="${run_dir%/}"
  run_id="$(basename "$run_dir")"
  case "$run_id" in
    expected|.targets) continue ;;
  esac
  [ -f "$run_dir/report.md" ] || continue
  [ -f "$run_dir/findings.json" ] || continue
  total=$((total + 1))

  target=$(resolve_target "$run_dir")
  rc_target=$?
  if [ "$rc_target" -ne 0 ] || [ -z "$target" ]; then
    echo "DIFF  $run_id (could not resolve --target)"
    diffs=$((diffs + 1))
    continue
  fi

  pre_review_dir="$run_dir/pre-review"

  out=$(python3 "$CHECK_ALL" "$run_dir/report.md" "$run_dir/findings.json" "$CHECKS_JSON" "$pre_review_dir" --target "$target")
  rc=$?
  actual=$(printf '%s\nexit: %s' "$out" "$rc")

  expected_file="$EXPECTED_DIR/$run_id.txt"
  if [ "$UPDATE" -eq 1 ]; then
    printf '%s\n' "$actual" > "$expected_file"
    echo "UPDATED $run_id (exit $rc)"
  else
    if [ -f "$expected_file" ]; then
      # Ignore any leading "# " comment lines in the expected file (used to
      # note a known-wrong verdict, per the Must-not rule) when diffing.
      expected=$(grep -v '^# ' "$expected_file")
      if [ "$expected" = "$actual" ]; then
        echo "PASS  $run_id (exit $rc)"
      else
        echo "DIFF  $run_id"
        diff <(echo "$expected") <(echo "$actual") | sed 's/^/    /'
        diffs=$((diffs + 1))
      fi
    else
      echo "DIFF  $run_id (no expected/$run_id.txt; run with --update to create it)"
      diffs=$((diffs + 1))
    fi
  fi

  recall_file=$(recall_file_for "$run_id")
  if [ -n "$recall_file" ] && [ -f "$recall_file" ]; then
    echo "  recall against $recall_file:"
    recall_table "$run_dir" "$recall_file"
  fi
done

echo
echo "run-corpus: $total run(s), $diffs diff(s)"
if [ "$UPDATE" -eq 1 ]; then
  exit 0
fi
[ "$diffs" -eq 0 ]
