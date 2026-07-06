---
name: review-structure
description: Check an AppVerse app repo's structure — required files, required metadata fields, YAML validity, standard OOD layout, broken references. Use for the structure aspect of an AppVerse review, or when asked to check an OOD app repo's structure or metadata.
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
  errors verbatim.
- ERB templates look renderable (balanced `<%= %>` tags); shell scripts pass
  `bash -n`.
- No broken references: variables and attributes used in `submit.yml.erb` and
  `template/` files exist in `form.yml`.
- Batch Connect apps have the standard layout: `form.yml`, `submit.yml.erb`,
  `template/`.

## Output

Findings tables per target-setup.md §4: one repo-level table, one per app.
