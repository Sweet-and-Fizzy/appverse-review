# Appverse Review

Claude Code plugin for AI-assisted review of Appverse (Open OnDemand) app
submissions. Evaluates structure, security, quality, and maintenance against
a shared rubric.

## Project Layout

- `.claude-plugin/` — plugin metadata (`plugin.json`, `marketplace.json`)
- `skills/` — one SKILL.md per review aspect plus an orchestrator
  - `review-app/` — orchestrator: runs all aspects, synthesizes report
  - `review-structure/` — required files, metadata, YAML validity, layout
  - `review-security/` — capability profile, pattern checks, OODT classification
  - `review-quality/` — documentation rating, portability, code quality
  - `review-maintenance/` — commit recency, releases, CI, CHANGELOG
- `references/` — shared rubrics and setup procedures used by all skills
- `tests/fixtures/` — deliberately broken app repos for calibration
- `tests/TESTING.md` — expected findings per fixture, coverage matrix
- `.github/workflows/` — CI workflow for running reviews via GitHub Actions

## Testing Artifact Consistency

When editing any file under `tests/fixtures/`, you MUST also update
`tests/TESTING.md` to keep file:line references accurate. Conversely, when
editing `tests/TESTING.md`, verify that every file:line reference matches the
actual fixture file content.

Before committing changes to fixtures or the testing guide:
1. Check that every `file:line` reference in TESTING.md points to the correct
   line in the corresponding fixture file
2. Check that defect descriptions match what is actually in the code
3. Check that no referenced variable, function, or pattern has been renamed
   or removed without updating the guide

## Security Rubric

`references/security-rubric.md` is the canonical security criteria shared by
the review skill and the future automated audit pipeline. Changes here affect
both systems — update carefully and check that OODT category references in
skill files and TESTING.md stay consistent. The taxonomy is named OODT (Open
OnDemand App Threats).
