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

  If `gh` is unavailable, shallow-clone and read the SHA from the checkout. The
  SHA must be recorded regardless of method.

  - Clone fails / repo not found: tell the user the repo may be private or
    nonexistent; suggest `gh auth login` for private repos. Stop.
  - URL is not a github.com repo URL: say only GitHub repos are supported. Stop.
- No argument: **submitter mode**. Review the current working tree. Derive
  `<owner>/<repo>` from `git remote get-url origin` if available. If the tree has
  neither `appverse.yml` nor `manifest.yml` at its root, warn that this will fail
  required criteria and confirm the directory is the app repo before continuing.

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
- Neither, or root appverse.yml fails to parse → record as a required-criteria
  failure and continue (do not abort). Report YAML parse errors verbatim.
- Archived on GitHub (`gh api repos/<owner>/<repo> --jq .archived`) → automatic
  required-criteria failure; still complete the review.

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
    "defect_key":  "script.sh.erb:bind-all-interfaces",
    "aspect":      "security",
    "severity":    "medium",
    "result":      "FAIL",
    "summary":     "MLflow bound to 0.0.0.0:5000, reachable by other users",
    "evidence":    "template/script.sh.erb:24",
    "line":        24
  }
]
```

Field definitions:

| Field | Required | Identity (hashed) | Description |
|---|---|---|---|
| `app_id` | Yes | Yes | `"root"` for single-app repos; subpath for monorepos |
| `rule` | Yes | Yes | Code from `finding-codes.md` (OODT-XX, STR-XX, QUA-XX, MNT-XX) |
| `defect_key` | Yes | Yes | `{primary_file}:{mechanism_tag}` per `finding-codes.md` |
| `aspect` | Yes | No | `security`, `structure`, `quality`, or `maintenance` |
| `severity` | Yes | No | `high`, `medium`, `low`, or `info` |
| `result` | Yes | No | `FAIL`, `WARN`, `PASS`, or `NOT CHECKED` |
| `summary` | Yes | No | Human-readable description — display text, not identity |
| `evidence` | Yes | No | `file:line` plus a short quote. Every FAIL/WARN needs evidence |
| `line` | No | No | Primary line number (integer), for tooling convenience |

The stable ID is computed from the three identity fields:
`sha256(app_id + rule + defect_key)[:16]`. See `finding-codes.md` for the
full identity design, rule code tables, and mechanism-tag vocabularies.

### Human-readable table (alongside the JSON)

Also output the traditional table for readability — it is generated from the
same findings, not written independently:

| Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|

### General rules

- Skip vendored and build directories: `node_modules/`, `vendor/`, `dist/`,
  `.git/`.
- Every FAIL or WARN must have `evidence` with a `file:line` reference.
- Use the mechanism-tag vocabulary in `finding-codes.md` for `defect_key`.
  Novel findings use `other:{short-description}`.
