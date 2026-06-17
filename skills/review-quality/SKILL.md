---
name: review-quality
description: Quality review of an AppVerse app repo — documentation rating, configuration portability, code-quality checklist. Use for the quality aspect of an AppVerse review, or when asked to assess an OOD app's documentation or code quality.
argument-hint: "[github-url]"
---

# Quality Review (aspect)

Criteria: `${CLAUDE_PLUGIN_ROOT}/references/review-checklist.md` — section
"Quality Criteria" (Documentation Quality, Configuration Portability, Code
Quality), including the target-for-inclusion thresholds.

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first.

## Per-app assessment

- **Documentation**: rate Minimal / Adequate / Strong / Exemplary against the
  checklist's documentation table and its four README questions (what does it
  launch, what must be installed, how to deploy, what to customize). One-line
  justification citing README sections present or missing.
- **Configuration portability**: rate Not portable / Partially portable /
  Portable. Look for hardcoded cluster names, partitions, accounts, absolute
  site paths, and module versions in `submit.yml.erb`, `form.yml`, and
  `template/` scripts.
- **Code quality** checkboxes, each PASS/FAIL/WARN with evidence: error handling
  (`set -e` or explicit checks), no uncommented magic numbers, no large
  duplicated blocks, no commented-out dead code, form input validation
  (min/max/required), ERB templates handle missing or empty values gracefully.

## Output

Per app: the two ratings with one-line justifications, then a findings table per
target-setup.md §4 for the code-quality items. Note which target-for-inclusion
thresholds (Adequate+ docs, Partially portable+) are not met — as findings, not
decisions.
