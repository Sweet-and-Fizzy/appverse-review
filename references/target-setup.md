# Target Setup (shared by all review skills)

Establish what to review before running any checks. The `review-app` orchestrator
runs this once and hands the results to each aspect; an aspect skill invoked on its
own runs it itself.

## 1. Target and mode

- A GitHub URL argument — delivered via `$ARGUMENTS` when the skill is invoked
  as a slash command (`https://github.com/<owner>/<repo>` or
  `https://github.com/<owner>/<repo>/tree/<ref>`): **reviewer mode**.

  **Resolve the ref to a SHA before cloning.** If the URL includes a ref
  (branch, tag, or SHA), use it; otherwise default to the repo's default branch.
  Resolve to a concrete commit SHA so the review is hash-matched to a known tree:

      REF="${ref:-HEAD}"
      SHA=$(gh api "repos/<owner>/<repo>/commits/$REF" --jq '.sha')
      TMP=$(mktemp -d) && git clone --depth 1 <url> "$TMP/repo"
      git -C "$TMP/repo" checkout "$SHA"
      bash "${CLAUDE_PLUGIN_ROOT}/references/run-pre-review.sh" "$TMP/repo" "$TMP/pre-review"

  This writes the tool and syntax facts the security and structure skills
  read; a local machine has whatever tools it has, and summary.json says so.
  The shell syntax check uses the first bash on PATH. The macOS system bash
  3.2 is fine unless a script fails under it: a file that fails is recorded
  as possibly valid on bash >= 4 and its STR-06 is NOT CHECKED. To confirm
  such a failure, put bash >= 4 first on PATH (`brew install bash`) and rerun.

  If `gh` is unavailable, shallow-clone and read the SHA from the checkout. The
  SHA must be recorded regardless of method.

  - Clone fails / repo not found: tell the user the repo may be private or
    nonexistent; suggest `gh auth login` for private repos. Stop. Report this
    as the failed gate "Repository is public and accessible" rather than as
    an error.
  - URL is not a github.com repo URL: say only GitHub repos are supported. Stop.
- No argument: **submitter mode**. Review the current working tree. Derive
  `<owner>/<repo>` from `git remote get-url origin` if available. If the tree has
  neither `appverse.yml` nor `manifest.yml` at its root, warn that this will fail
  gate criteria and confirm the directory is the app repo before continuing.

      PRE=$(mktemp -d) && bash "${CLAUDE_PLUGIN_ROOT}/references/run-pre-review.sh" . "$PRE"

  Pass `$PRE` as the pre-review directory.

Record the reviewed commit — every review is pinned to it:

    git -C <repo path> log -1 --format='%H %cs'

This gives the full SHA and commit date. The review artifact's `reviewed.sha`
field is this resolved commit — it is the hash-match anchor for re-review
and all `file:line` evidence. In submitter mode also note if the working tree
is dirty (`git status --porcelain` non-empty): report the SHA with
"+ uncommitted changes".

## 2. Schema

Fetch the live annotated schema:

    curl -fsSL https://raw.githubusercontent.com/Sweet-and-Fizzy/ood-appverse/main/docs/appverse.yml

If `curl` is not available, try `wget -qO-` with the same URL.

If the fetch fails (offline or neither tool available), use the cached copy at
`${CLAUDE_PLUGIN_ROOT}/references/appverse.yml` and note in the output that the
cached schema was used.

## 3. Repo shape and app list

- Root `appverse.yml` parses → **declared repo**. If it has an `apps:` list, it is
  a **monorepo**: the app list is every `apps[].path`, with each app's fields
  resolved by precedence — inline `apps[]` entry → `<subpath>/appverse.yml` →
  `<subpath>/manifest.yml` (name/description fallback only). Record any
  `shared_paths` for repo-level review.
- Root `manifest.yml` only → **inferred repo**, one app at the repo root.
- Neither, or root appverse.yml fails to parse → record as a gate-criterion
  failure and continue (do not abort). Report YAML parse errors verbatim.
- Archived on GitHub (`gh api repos/<owner>/<repo> --jq .archived`) → automatic
  gate-criterion failure; still complete the review.

## 4. Findings format (all aspect skills)

Aspects report findings, never decisions or verdicts. Output one repo-level
section plus one per app.

### Structured finding records

Each finding is a discrete record. Output findings as a fenced JSON array
after any prose tables (ratings, capability profiles) in the aspect's output:

```json
[
  {
    "app_id":      "root",
    "rule":        "OODT-05",
    "defect_key":  "template/script.sh.erb:bind-all-interfaces",
    "aspect":      "security",
    "severity":    "medium",
    "result":      "FAIL",
    "tag":         "unintentional",
    "summary":     "MLflow bound to 0.0.0.0:5000, reachable by other users",
    "evidence":    "template/script.sh.erb:24",
    "line":        24
  }
]
```

Field definitions:

| Field | Required | Identity (hashed) | Description |
|---|---|---|---|
| `app_id` | Yes | Yes | `"root"` for single-app repos; subpath for monorepos. Same value as `apps.json`'s `app_id` for the app; the per-app pre-review fact directory is `<pre-review>/<app_id>/` |
| `rule` | Yes | Yes | Code from `finding-codes.md` (OODT-XX, STR-XX, QUA-XX, MNT-XX) |
| `defect_key` | Yes | Yes | `{anchor}:{mechanism_tag}` per `finding-codes.md`. The anchor is relative to the repo root, so a monorepo app's anchor includes its subpath (`apps/good-app/form.yml:missing-min`) |
| `aspect` | Yes | No | `security`, `structure`, `quality`, or `maintenance` |
| `severity` | Yes | No | `critical`, `high`, `medium`, `low`, or `info`. A finding for a manifest check takes the check's `default_severity` (`checks.json`) unless the evidence clearly warrants another, and the summary says why; a suggestion check stays `info` |
| `result` | Yes | No | `FAIL`, `WARN`, `PASS`, or `NOT CHECKED` |
| `summary` | Yes | No | Human-readable description — display text, not identity |
| `evidence` | Yes | No | `file:line` plus a short quote. Every FAIL/WARN needs evidence |
| `line` | No | No | Primary line number (integer), for tooling convenience |
| `tag` | Security only | No | `unintentional` or `potentially-malicious` |

**The skill does not emit an `id` field.** The stable ID is computed
downstream from the three identity fields (`app_id`, `rule`, `defect_key`)
using `sha256(app_id + "\0" + rule + "\0" + defect_key)[:16]` (first 16 hex
characters). See `finding-codes.md` for the full identity design.

### Human-readable table (alongside the JSON)

Also output the traditional table for readability — it is generated from the
same findings, not written independently:

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|

The **Check column** is the contract with the checks manifest
(`references/checks.json`, human copy `checks.yml`). A row that answers a
manifest entry holds exactly `` `check: <id>` `` with the entry's id; a row
from the open-ended pass leaves it empty. Each aspect answers every entry of
its dimension that applies to the app's `app_type` (from
`<pre-review>/apps.json`): at least one row per entry, and where the entry's
fact file lists candidates, every candidate cited by some row (Security:
one row per candidate, and no row for a check with none). The orchestrator
template names each dimension's columns (Security adds Tag).
`check-rows.py` fails the run on a missing row or an uncited candidate.

**Citation form.** Evidence cites a location in exactly one of these forms:
`path:N`, `path:N-M` (a range), or `path:N,M` (a comma list of lines or
ranges), with the path repo-relative (a monorepo app's path includes its
subpath) and exactly as the fact file gives it; a candidate with no line
(a `syntax.json` or `entry_point.json` file) is cited by its bare path.
Never prose: "line 12 of script.sh" and "script.sh: line 12" cite nothing.
A row answers exactly the candidates its Evidence cites, whatever its
Result; candidates with different results never share a row, so a PASS row for a check with candidates must cite each one it
clears; a plain PASS with no citation is only for a check with no
candidates. In a finding record, `evidence` starts with the same form
followed by a short quote, and `check-evidence.py` fails the run on a path
or line that does not exist in the reviewed tree.

### General rules

- Skip vendored and build directories: `node_modules/`, `vendor/`, `dist/`,
  `.git/`.
- Every FAIL or WARN must have `evidence` with a `file:line` reference in the
  citation form above.
- Use the mechanism-tag vocabulary in `finding-codes.md` for `defect_key`.
  A finding on a manifest candidate is keyed `{candidate file}:{tag}` with
  the manifest entry's `tag`, except for the fixed exceptions in
  `finding-codes.md` (security candidates carry their own `tag`, which
  wins). Novel findings from the open-ended pass use the vocabulary
  tag that fits, else `other:{short-description}`.
- One record per file per tag: a `defect_key` appears once per app.
  Candidates of a check that share a file and a tag share one record, and
  its `evidence` may carry several citations separated by semicolons: the
  FAIL/WARN lines first, then the PASS lines in that file as
  `reviewed OK: path:N,M` (`template/script.sh.erb:22; reviewed OK:
  template/script.sh.erb:9,23`). A file whose candidates are all PASS gets
  one PASS record listing every PASS line as `path:N,M`. The aspect skill
  names the key for a check with no candidates.
