#!/usr/bin/env bash
# Run check-all.py over every committed corpus run and diff its output
# against tests/corpus/expected/<run-id>.txt. Prints PASS/DIFF per run and
# exits 1 if any run diverges from its expected file.
#
# Also measures recall per run against tests/recall-set/<target>.json, where
# <target> is the run id without its last -<suffix> (ood-sas-run6 ->
# ood-sas). A recall set is {"groups": {name: [run ids]}, "items": [...]};
# an item is recalled when a FAIL/WARN record in the run's findings.json has
# a defect_key in the item's "keys", or its evidence (or its anchor file and
# "line") cites a line in the item's optional "lines" ({file: [N, ...]}).
# Citations after "reviewed OK:" never count. Items with "candidate": true
# are ones the candidate list enumerates; the rest are off-candidate, the
# defects only the open-ended pass can find. Each run prints both columns
# (hits/items); the end prints the off-candidate column per run and its mean
# per group (for ood-sas: pre-rows vs rows runs, split by model).
#
# An expected file may set a floor with a leading "# recall-floor: N/M"
# line (text after N/M is a comment): the run must recall at least N of its
# off-candidate items and the set must hold exactly M of them, else the run
# is a DIFF. Leading "# " lines note known-wrong or not-applicable verdicts;
# the diff ignores them and --update keeps them.
#
#   tests/run-corpus.sh            # check every run against expected/
#   tests/run-corpus.sh --update   # rewrite expected/ from current checkers
#
# RUN_CORPUS_DIR and RUN_CORPUS_RECALL_DIR override tests/corpus and
# tests/recall-set (for tests/test-run-corpus.sh).
#
# POSIX/bash-3.2 compatible: no associative arrays, no mapfile.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR" || exit 2

CORPUS_DIR="${RUN_CORPUS_DIR:-tests/corpus}"
RECALL_DIR="${RUN_CORPUS_RECALL_DIR:-tests/recall-set}"
EXPECTED_DIR="$CORPUS_DIR/expected"
TARGETS_DIR="tests/corpus/.targets"
CHECK_ALL="references/check-all.py"
CHECKS_JSON="references/checks.json"

UPDATE=0
if [ "${1:-}" = "--update" ]; then
  UPDATE=1
fi

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
RECALL_PY="$WORK/recall.py"
RECALL_STATE="$WORK/recall.tsv"
: > "$RECALL_STATE"
cat > "$RECALL_PY" <<'PYEOF'
"""recall.py table <run-dir> <recall-file> <run-id> <state-file> [N/M]
   recall.py summary <state-file>"""
import json, os, re, sys

CITE = re.compile(r"(?:(?<![\w./-])([\w.][\w./-]*)|(?<![^\s;,(])):"
                  r"(\d+(?:\s*[-–]\s*\d+)?(?:\s*,\s*\d+(?:\s*[-–]\s*\d+)?)*)")
REVIEWED_OK = re.compile(r"reviewed OK:", re.I)
RANGE_CAP = 500


def cited(record):
    """{(path, line)} the record cites as defect lines: its evidence before
    any "reviewed OK:", a bare :N continuing the last path, and its anchor
    file (the defect_key's path) at its "line" field."""
    out = set()
    text = record.get("evidence")
    text = REVIEWED_OK.split(text)[0] if isinstance(text, str) else ""
    path = None
    for m in CITE.finditer(text):
        if m.group(1):
            if not re.search(r"[A-Za-z]", m.group(1)):
                continue
            path = m.group(1)
        if path is None:
            continue
        for part in m.group(2).split(","):
            ends = [int(x) for x in re.split(r"\s*[-–]\s*", part.strip())]
            lo, hi = ends[0], ends[-1]
            if hi < lo or hi - lo > RANGE_CAP:
                hi = lo
            out.update((path, n) for n in range(lo, hi + 1))
    key, line = record.get("defect_key"), record.get("line")
    if isinstance(key, str) and isinstance(line, int) and not isinstance(line, bool):
        out.add((key.split(":", 1)[0], line))
    return out


def recalled(item, records):
    keys = set(item.get("keys") or [])
    lines = {(p, n) for p, ns in (item.get("lines") or {}).items() for n in ns}
    for r in records:
        key = r.get("defect_key")
        if key in keys or "%s:%s" % (r.get("rule"), key) in keys:
            return True
        if lines & cited(r):
            return True
    return False


def load_set(path):
    data = json.load(open(path))
    return data.get("groups") or {}, data.get("items") or []


def table(run_dir, recall_file, run_id, state, floor):
    try:
        findings = json.load(open(os.path.join(run_dir, "findings.json")))
    except (OSError, ValueError):
        findings = []
    records = [f for f in findings if isinstance(f, dict)
               and str(f.get("result", "")).upper() in ("FAIL", "WARN")]
    groups, items = load_set(recall_file)
    group = next((g for g, runs in sorted(groups.items()) if run_id in runs), "ungrouped")
    try:
        model = json.load(open(os.path.join(run_dir, "meta.json"))).get("model") or "unknown"
    except (OSError, ValueError, AttributeError):
        model = "unknown"
    tally = {True: [0, 0], False: [0, 0]}
    for item in items:
        on = bool(item.get("candidate"))
        hit = recalled(item, records)
        tally[on][1] += 1
        tally[on][0] += hit
        print("    %s %-13s %-8s %s" % ("HIT " if hit else "MISS", "candidate" if on else "off-candidate",
                                      item.get("rule", "?"), item.get("defect", "?")))
    print("  recall: candidate %d/%d, off-candidate %d/%d (group %s, %s)"
          % (tally[True][0], tally[True][1], tally[False][0], tally[False][1], group, model))
    with open(state, "a") as f:
        f.write("\t".join([recall_file, group, model, run_id, str(tally[False][0]), str(tally[False][1])]) + "\n")
    if floor:
        m = re.match(r"^(\d+)/(\d+)$", floor)
        if not m:
            print("  recall-floor %s: not N/M" % floor)
            return 1
        need, size = int(m.group(1)), int(m.group(2))
        if tally[False][1] != size:
            print("  recall-floor %s: the set has %d off-candidate items, not %d" % (floor, tally[False][1], size))
            return 1
        if tally[False][0] < need:
            print("  recall-floor %s: below the floor (%d/%d)" % (floor, tally[False][0], tally[False][1]))
            return 1
        print("  recall-floor %s: met (%d/%d)" % (floor, tally[False][0], tally[False][1]))
    return 0


def summary(state):
    rows = [l.rstrip("\n").split("\t") for l in open(state) if l.strip()]
    if not rows:
        return 0
    print()
    print("off-candidate recall (hits/items per run):")
    for recall_file in sorted({r[0] for r in rows}):
        print("  %s" % recall_file)
        mine = [r for r in rows if r[0] == recall_file]
        for r in mine:
            print("    %-10s %-26s %s/%s  %s" % (r[1], r[3], r[4], r[5], r[2]))
        for group in sorted({r[1] for r in mine}):
            runs = [r for r in mine if r[1] == group]
            mean = sum(int(r[4]) for r in runs) / float(len(runs))
            models = sorted({r[2] for r in runs})
            split = ""
            if len(models) > 1:
                split = " (%s)" % "; ".join(
                    "%s %.2f over %d" % (m, sum(int(r[4]) for r in runs if r[2] == m)
                                         / float(sum(1 for r in runs if r[2] == m)),
                                         sum(1 for r in runs if r[2] == m)) for m in models)
            print("    %s mean: %.2f off-candidate hits per run over %d run(s)%s" % (group, mean, len(runs), split))
    return 0


if __name__ == "__main__":
    if sys.argv[1] == "table":
        sys.exit(table(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5],
                       sys.argv[6] if len(sys.argv) > 6 else ""))
    sys.exit(summary(sys.argv[2]))
PYEOF

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
    /*)
      echo "$spec"
      ;;
    *)
      # a bare path, relative to the repo root (e.g. a tests/fixtures checkout)
      echo "$SCRIPT_DIR/$spec"
      ;;
  esac
}

# recall_file_for <run-id> -> the recall set for the run's target (the run
# id without its last -<suffix>), or nothing when there is none
recall_file_for() {
  f="$RECALL_DIR/${1%-*}.json"
  if [ -f "$f" ]; then echo "$f"; fi
}

# leading_comments <file>: the file's leading "# " lines
leading_comments() {
  awk '/^# /{print; next} {exit}' "$1"
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

  meta_arg=(); [ -f "$run_dir/meta.json" ] && meta_arg=(--meta "$run_dir/meta.json")
  out=$(python3 "$CHECK_ALL" "$run_dir/report.md" "$run_dir/findings.json" "$CHECKS_JSON" "$pre_review_dir" --target "$target" ${meta_arg[@]+"${meta_arg[@]}"})
  rc=$?
  actual=$(printf '%s\nexit: %s' "$out" "$rc")

  expected_file="$EXPECTED_DIR/$run_id.txt"
  floor=""
  if [ "$UPDATE" -eq 1 ]; then
    comments=""
    if [ -f "$expected_file" ]; then
      comments=$(leading_comments "$expected_file")
    fi
    if [ -n "$comments" ]; then
      printf '%s\n%s\n' "$comments" "$actual" > "$expected_file"
    else
      printf '%s\n' "$actual" > "$expected_file"
    fi
    echo "UPDATED $run_id (exit $rc)"
  else
    if [ -f "$expected_file" ]; then
      floor=$(sed -n 's/^# recall-floor: *\([0-9][0-9]*\/[0-9][0-9]*\).*$/\1/p' "$expected_file" | head -1)
      # Ignore any "# " comment lines in the expected file (used to note a
      # known-wrong verdict, per the Must-not rule) when diffing.
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
  if [ -n "$recall_file" ]; then
    echo "  recall against $recall_file:"
    if ! python3 "$RECALL_PY" table "$run_dir" "$recall_file" "$run_id" "$RECALL_STATE" "$floor"; then
      echo "DIFF  $run_id (recall floor)"
      diffs=$((diffs + 1))
    fi
  elif [ -n "$floor" ]; then
    echo "DIFF  $run_id (recall-floor set but no recall set for this target)"
    diffs=$((diffs + 1))
  fi
done

python3 "$RECALL_PY" summary "$RECALL_STATE"

echo
echo "run-corpus: $total run(s), $diffs diff(s)"
if [ "$UPDATE" -eq 1 ]; then
  exit 0
fi
[ "$diffs" -eq 0 ]
