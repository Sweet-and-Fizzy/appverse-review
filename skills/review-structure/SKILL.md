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
- `app_type` and `implementation_tags` are known values. The schema names the
  vocabularies but does not enumerate them; query the catalog's public JSON:API
  for the current terms (see the checklist's "Reading the catalog without a
  login"). Matching is case-insensitive. Report the terms you found, not just a
  pass — a stale vocabulary is why this check silently drifts.
- Every `manifest.yml`, `appverse.yml`, and `form.yml` parses; report parse
  errors verbatim.
- ERB templates look renderable (balanced `<%= %>` tags); shell scripts pass
  `bash -n`.
- No broken references: variables and attributes used in `submit.yml.erb` and
  `template/` files exist in `form.yml`.
- Batch Connect apps have the standard layout: `form.yml`, `submit.yml.erb`,
  `template/`.

## Output

**Structured findings** per target-setup.md §4: one repo-level set, one per app.
Each finding uses an STR-XX rule code and a `defect_key` from the structure
mechanism-tag vocabulary in
`${CLAUDE_PLUGIN_ROOT}/references/finding-codes.md`.
