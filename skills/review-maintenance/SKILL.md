---
name: review-maintenance
description: Maintenance-signal review of an Appverse app repo — commit recency, releases, issue responsiveness, contributors, CHANGELOG, CI. Use for the maintenance aspect of an Appverse review, or when asked whether an app repo looks actively maintained.
argument-hint: "[github-url]"
---

# Maintenance Review (aspect)

Criteria: `${CLAUDE_PLUGIN_ROOT}/references/review-checklist.md` — section
"Maintenance Signals", including its target-for-inclusion line and the
brand-new-app waiver.

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first. This aspect needs
`<owner>/<repo>`; in submitter mode derive it from the git remote.

## Signals

With the `gh` CLI:

    gh api repos/<owner>/<repo> --jq '{pushed_at, archived, open_issues_count}'
    gh api repos/<owner>/<repo>/releases --jq 'length'
    gh api repos/<owner>/<repo>/contributors --jq 'length'
    gh api 'repos/<owner>/<repo>/issues?state=open&per_page=5' --jq '.[].comments'

In the working tree: CHANGELOG file present and current; CI configuration
present (`.github/workflows/`, or equivalent).

If `gh` is missing or unauthenticated: use `git log -1 --format=%ci` for
last-commit age and mark the other signals NOT CHECKED.

## Output

One repo-level table — Signal / Value / Assessment (Good sign / Concern, per the
checklist's table) — followed by **structured findings** per target-setup.md §4.
Each finding uses an MNT-XX rule code and a `defect_key` from the maintenance
mechanism-tag vocabulary in
`${CLAUDE_PLUGIN_ROOT}/references/finding-codes.md`.

Weight each signal the way the checklist's Maintenance Signals section frames it:
activity within 12 months is its target for inclusion, while releases, issue
responsiveness, contributors, CHANGELOG, and CI are good-practice indicators, not
requirements — a missing release is a suggestion, never a failure. Apply the
brand-new-app waiver where relevant and say so. Don't invent your own severity
scale, and keep labels consistent with the checklist and with your other
findings.
