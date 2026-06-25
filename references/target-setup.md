# Target Setup (shared by all review skills)

Establish what to review before running any checks. The `review-app` orchestrator
runs this once and hands the results to each aspect; an aspect skill invoked on its
own runs it itself.

## 1. Target and mode

- A GitHub URL argument — delivered via `$ARGUMENTS` when the skill is invoked
  as a slash command (`https://github.com/<owner>/<repo>`): **reviewer mode**.
  Shallow-clone the default branch:

      TMP=$(mktemp -d) && git clone --depth 1 <url> "$TMP/repo"

  - Clone fails / repo not found: tell the user the repo may be private or
    nonexistent; suggest `gh auth login` for private repos. Stop.
  - URL is not a github.com repo URL: say only GitHub repos are supported. Stop.
- No argument: **submitter mode**. Review the current working tree. Derive
  `<owner>/<repo>` from `git remote get-url origin` if available. If the tree has
  neither `appverse.yml` nor `manifest.yml` at its root, warn that this will fail
  required criteria and confirm the directory is the app repo before continuing.

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
findings table plus one per app:

| Criterion | Result | Evidence |
|---|---|---|

- Result: PASS / FAIL / WARN / NOT CHECKED.
- Evidence: `file:line` plus a short quote or description. Every FAIL/WARN needs
  evidence.
- Skip vendored and build directories: `node_modules/`, `vendor/`, `dist/`,
  `.git/`.
