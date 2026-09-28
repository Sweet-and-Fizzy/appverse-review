---
name: review-maintenance
description: Maintenance-signal review of an Appverse app repo — commit recency, releases, issue responsiveness, contributors, CHANGELOG, CI. Use for the maintenance aspect of an Appverse review, or when asked whether an app repo looks actively maintained.
argument-hint: "[github-url]"
---

# Maintenance Review (aspect)

Criteria: `${CLAUDE_PLUGIN_ROOT}/references/review-rubric.md` — section
"Upkeep", including its target-for-inclusion line and the brand-new-app
waiver.

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first. This aspect needs
`<owner>/<repo>`; in submitter mode derive it from the git remote.

## Signals

With the `gh` CLI:

    gh api repos/<owner>/<repo> --jq '{pushed_at, archived, open_issues_count}'
    gh api repos/<owner>/<repo>/releases --jq 'length'
    gh api repos/<owner>/<repo>/contributors --jq 'length'
    gh api 'repos/<owner>/<repo>/issues?state=open&per_page=5' --jq '.[].comments'

The fetched `archived` value confirms review-structure's not-archived gate
rather than producing a second, separately worded finding.

A repo with no open issues is neutral on issue responsiveness: report it as
neither a good sign nor a concern.

In the working tree: CHANGELOG file present and current; CI configuration
present (`.github/workflows/`, or equivalent).

If `gh` is missing or unauthenticated: use `git log -1 --format=%ci` for
last-commit age and mark the other signals NOT CHECKED.

## Output

One repo-level table — Signal / Value / Assessment (Good sign / Concern, per the
rubric's table) — followed by **structured findings** per target-setup.md §4.
Each finding uses an MNT-XX rule code and a `defect_key` from the maintenance
mechanism-tag vocabulary in
`${CLAUDE_PLUGIN_ROOT}/references/finding-codes.md`.

Anchors for repo-level findings are the fixed pseudo-anchors in
finding-codes.md: `releases` (MNT-02), `CHANGELOG.md` (MNT-03; `CHANGELOG`
when the file is absent), `.github/workflows` (MNT-04), `contributors`
(MNT-05), `issues` (issue responsiveness), `commits` (MNT-01). Never invent
an anchor such as `RELEASES` or `github/commits`.

Weight each signal the way the rubric's Upkeep section frames it:
activity within 12 months is its target for inclusion, while releases, issue
responsiveness, contributors, CHANGELOG, and CI are good-practice indicators, not
requirements — a missing release is a suggestion, never a failure. Apply the
brand-new-app waiver where relevant and say so. Don't invent your own severity
scale, and keep labels consistent with the rubric and with your other
findings.

Then one **maintenance assessment block**, as a fenced JSON block:

```json
{
  "maintenance_assessment": {
    "active_within_12mo": true,
    "waiver_brand_new": false,
    "signals": {
      "releases": true,
      "changelog": false,
      "ci": true,
      "multiple_contributors": true,
      "issues_responded": null
    },
    "summary": "<one-line evidence phrase, e.g. Active, 3 releases, CI green>"
  }
}
```

| Field | Value |
|---|---|
| `active_within_12mo` | `true` when the last push or commit is within 12 months |
| `waiver_brand_new` | `true` only when you are applying the checklist's brand-new-app waiver |
| `signals.releases` | `true` when the repo has at least one release |
| `signals.changelog` | `true` when a CHANGELOG is present and current |
| `signals.ci` | `true` when CI configuration is present |
| `signals.multiple_contributors` | `true` when there is more than one contributor |
| `signals.issues_responded` | `true` when open issues have responses; `null` when there are no open issues |

A signal marked NOT CHECKED is `false`, and the `summary` names the signals that
were not checked. `null` is reserved for `issues_responded` with no open issues.
It is neutral — there was nothing to respond to, so it is evidence neither way —
and it is not a stand-in for "could not verify", which is `false`.

When `active_within_12mo` is `false` and no waiver applies, the findings include
MNT-01. Field definitions:
`${CLAUDE_PLUGIN_ROOT}/references/artifact-envelope.md` ("Indicator inputs").
