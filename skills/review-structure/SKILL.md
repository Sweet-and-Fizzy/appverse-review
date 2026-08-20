---
name: review-structure
description: Check an Appverse app repo's structure — required files, required metadata fields, YAML validity, standard OOD layout, broken references. Use for the structure aspect of an Appverse review, or when asked to check an OOD app repo's structure or metadata.
argument-hint: "[github-url]"
---

# Structure Review (aspect)

Criteria: `${CLAUDE_PLUGIN_ROOT}/references/review-checklist.md` — sections
"Repository Structure", "Documentation Minimum" (the substantive-README gate
only; rating is review-quality's job), and "Basic Functionality".

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first.

## Repo-level checks

- `README.md` exists and is substantive: not the unfilled template (placeholder
  text like "Key feature 1"), not just a title and contact line.
- `LICENSE` exists and contains an open-source license.
- Repo shape identifiable: `appverse.yml` or `manifest.yml` at root.
- Repo is not archived on GitHub.

## Per-app checks (use the resolved field set from setup)

- Required metadata fields for the repo shape, per the checklist's Repository
  Structure section.
- `app_type` is a known value per the appverse.yml schema reference.
- Every `manifest.yml`, `appverse.yml`, and `form.yml` parses; report parse
  errors verbatim. A `form.yml.erb` cannot be YAML-parsed directly (unrendered
  ERB is not valid YAML) — check that it exists and has balanced ERB tags
  instead.
- ERB templates look renderable (balanced `<%= %>` tags); shell scripts pass
  `bash -n`.
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
    present and consistent with the dependency file
  - If the repo ships a test suite, note whether it passes. When execution is
    restricted (CI, untrusted repo), report as
    `NOT CHECKED — execution restricted`

## Output

Findings tables per target-setup.md §4: one repo-level table, one per app.
