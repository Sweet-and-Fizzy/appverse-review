---
name: review-structure
description: Check an Appverse app repo's structure — required files, required metadata fields, YAML validity, standard OOD layout, broken references. Use for the structure aspect of an Appverse review, or when asked to check an OOD app repo's structure or metadata.
argument-hint: "[github-url]"
---

# Structure Review (aspect)

Criteria: `${CLAUDE_PLUGIN_ROOT}/references/review-rubric.md` — sections
"Repo shapes" and "Structure (gate criteria)". The substantive-README gate is
yours; README depth is review-quality's job.

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first. The orchestrator (or
target-setup.md) names the pre-review directory; if it is absent, every STR-06
record is NOT CHECKED with the note "pre-review facts not found".

## Repo-level checks

- Repository is public and accessible: the clone in setup succeeded. If it did
  not, this is the failed gate to report (see target-setup.md) and no other
  check can run.
- `README.md` exists and is substantive: not the unfilled template (placeholder
  text like "Key feature 1"), not just a title and contact line.
- `LICENSE` exists and contains an open-source license.
- Repo shape identifiable: `appverse.yml` or `manifest.yml` at root.
- Repo is not archived on GitHub.

## Per-app checks (use the resolved field set from setup)

- Required metadata fields for the repo shape, per the rubric's "Repository
  structure" section. For declared repos that includes `description`,
  `software`, `app_type`, `maintainer.name`, and `maintainer.support_url`; a
  missing field is a gate failure (STR-02, `missing-field:<name>`).
- `app_type` and `implementation_tags` are known values. The schema names the
  vocabularies but does not enumerate them; query the catalog's public JSON:API
  for the current terms (see the Reviewer Process doc,
  `${CLAUDE_PLUGIN_ROOT}/references/review-checklist.md`, "Reading the catalog without a
  login"). Matching is case-insensitive. Report the terms you found, not just a
  pass — a stale vocabulary is why this check silently drifts.
- Every `manifest.yml`, `appverse.yml`, and `form.yml` parses; report parse
  errors verbatim. A `form.yml.erb` cannot be YAML-parsed directly (unrendered
  ERB is not valid YAML) — check that it exists and has balanced ERB tags
  instead.
- ERB templates look renderable (balanced `<%= %>` tags). STR-06 comes from
  the pre-review facts, never from running `bash -n` yourself: read
  `<pre-review>/syntax.json` and record one STR-06 record per shell file —
  result PASS when `ok` is true, FAIL when false (severity high, evidence
  `<path>:1` plus the first stderr line), NOT CHECKED when `summary.json`'s
  `syntax` check did not run — with `defect_key` `<path>:bash-syntax-error`.
  Only a `stderr` that is a bash message (it starts with the file path and
  "line") is a syntax error; an entry whose `stderr` begins with one of the
  refusal reasons ("symlink outside target", "dangling symlink", "not a
  regular file") was never syntax-checked at all. Record that entry as NOT
  CHECKED (severity info, evidence `<path>:1` plus the stderr reason) when
  the path exists in the tree (an outside-resolving symlink or a FIFO); give
  a dangling symlink no findings record at all, since its path does not
  exist for check-keys — name it only in the STR-06 row summary. The gate
  table's STR-06 row summarises them: "N files pass; M fail: `<paths>`; K
  not checked: `<path>` (`<reason>`)".
- No broken references: variables and attributes used in `submit.yml.erb` and
  `template/` files exist in `form.yml` or `form.yml.erb`.
- Batch Connect apps have the standard layout: `form.yml` or `form.yml.erb`,
  `submit.yml.erb`, `template/`. OOD renders `form.yml.erb` at request time,
  so an app shipping only the `.erb` variant is complete.
- Passenger / companion apps — substitute checks for Batch Connect structure.
  Detect by `manifest.yml` role (`passenger_app`) or by the presence of a
  recognized entry point (`config.ru` for Ruby/Rack, `passenger_wsgi.py` for
  Python/WSGI):
  - Entry point exists and parses: `ruby -c config.ru` for Rack apps,
    `python -c "import py_compile; py_compile.compile('passenger_wsgi.py')"` for
    WSGI apps
  - If `manifest.yml` has a `role` field, it matches the layout (e.g.,
    `passenger_app` with an entry point, not a Batch Connect tree). A missing
    `role` is a WARN, not a FAIL — the app may still work
  - Dependency manifest (`Gemfile.lock`, `package-lock.json`, `requirements.txt`)
    present and consistent with the dependency file (STR-08,
    `dependency-manifest-inconsistent`)
  - If the repo ships a test suite, note whether it passes. When execution is
    restricted (CI, untrusted repo), report as
    `NOT CHECKED — execution restricted`

## Output

**Structured findings** per target-setup.md §4: one repo-level set, one per app.
Each finding uses an STR-XX rule code and a `defect_key` from the structure
mechanism-tag vocabulary in
`${CLAUDE_PLUGIN_ROOT}/references/finding-codes.md`.
