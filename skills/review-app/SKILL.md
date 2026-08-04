---
name: review-app
description: Full Appverse submission review — structure, security, quality, and maintenance — with a recommended decision and draft feedback. Use when asked to review an app submission or app repo for Appverse, to check a repo before submitting it to Appverse, or when given a GitHub URL of an Open OnDemand app to review.
argument-hint: "[github-url]"
---

# Appverse App Review (orchestrator)

Produce an evidence-backed review with a recommended decision. You recommend; a
human decides.

Read first:
- `${CLAUDE_PLUGIN_ROOT}/references/review-checklist.md` (canonical criteria,
  including the decision rules in its Step 3 (Decision))
- `${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` (setup procedure and
  findings format)

## 1. Set up the target

Follow target-setup.md sections 1–3 once. You now have: mode (reviewer or
submitter), repo path, `<owner>/<repo>` if known, the reviewed commit (SHA +
date), repo shape, the app list with resolved fields, and `shared_paths`.

## 2. Run the four aspects in parallel

Dispatch four subagents concurrently — one per aspect: review-structure,
review-security, review-quality, review-maintenance. Each subagent's prompt:

> Read `${CLAUDE_PLUGIN_ROOT}/skills/<aspect>/SKILL.md` and follow it exactly.
> Prepared target (do not redo setup): repo path: <path>; mode: <mode>;
> owner/repo: <owner/repo or unknown>; reviewed commit: <SHA> (<date>);
> repo shape: <shape>; apps: <list of path + resolved fields>;
> shared_paths: <list>; schema source: <live|cached>.
> Return only your findings in the skill's output format. Do not make accept or
> reject judgments.

If subagent dispatch is unavailable, run the four aspect skill files yourself,
one at a time, in the order above.

## 3. Synthesize the report

```markdown
# Appverse Review: <repo name>

**Repository:** <url or path>  **Mode:** reviewer|submitter  **Date:** <today>
**Reviewed commit:** `<full SHA>` (<commit date>)
**Repo shape:** declared monorepo (N apps) | declared single app | inferred single app

## Repo-level required criteria

| Criterion | Result | Evidence |
|---|---|---|
| README.md substantive | PASS/FAIL | ... |
| LICENSE present | PASS/FAIL | ... |
| Repo not archived | PASS/FAIL/NOT CHECKED | ... |
| shared_paths security review | PASS/FAIL/N-A | ... |

## App: <name> (<subpath>)

### Required criteria
| Criterion | Result | Evidence |
|---|---|---|
| Required metadata fields | PASS/FAIL | ... |
| YAML validity (manifest/form) | PASS/FAIL | ... |
| Standard OOD structure | PASS/FAIL | ... |
| No broken references | PASS/FAIL | ... |

### Security
<capability profile: table for Batch Connect, narrative for Passenger>

| Finding | OODT | Severity | Evidence |
|---|---|---|---|

### Quality
- Documentation: <rating> — <one-line justification>
- Portability: <rating> — <one-line justification>
- Code quality: <met/missed checkboxes with evidence>

| Quality finding | Type | Result | Evidence |
|---|---|---|---|
<!-- code-quality checkboxes AND correctness-&-polish defects (copy-paste
     artifacts, duplicate YAML keys, wrong help text, README typos) from the
     quality aspect, each with file:line -->

**Per-app decision:** <Accept | Accept with suggestions | Request changes | Reject>
<!-- Monorepos only: one line per app, rolled up by the Overall recommendation
     below. Single-app repos: omit this line — the Overall recommendation is the
     decision. -->

## Maintenance signals

| Signal | Value | Assessment |
|---|---|---|
| Last commit | ... | ... |
| Releases | ... | ... |
| Issues responsiveness | ... | ... |
| Contributors | ... | ... |
| CHANGELOG | ... | ... |
| CI | ... | ... |

## Catalog checks
<!-- Query the public JSON:API — see the checklist's "Reading the catalog
     without a login". These need no reviewer account; record what each
     returned. List an item as not checked only if its query actually failed,
     and say so. -->
- Duplicate check against the existing catalog — <result>
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why,
    per the checklist's Duplicate Check; edit before pasting into the issue or
    email>_
- `software` value matches a catalog Software entry — <result>. If it has no
  match, the reviewer creates the Software entry (should it exist), corrects
  the value, or requests changes; see the checklist's Software Entry Check
- `app_type` and `implementation_tags` are in the catalog vocabularies —
  <result>

## Overall recommendation
<one paragraph. Single-app repos: the decision and its rationale. Monorepos:
roll up the per-app decisions above. Draw only on findings already recorded in
the tables — do not introduce new problems here.>
```

Apply the decision rules in the checklist's Step 3 (Decision) table — including
how it treats security findings and its condition that an Accept is pending any
catalog check that could not be run. Follow the checklist's framing rather than
a separate copy here.

## 4. Mode-specific ending

**Derived-only rule.** The overall recommendation and the mode-specific ending
below are summaries — every problem or fix they mention must already appear as a
finding in a table above (required criteria, security, or the quality findings
table). If while writing the feedback you notice a real defect that is not yet
recorded, stop and add it to the appropriate findings table first, then
summarize it here. A problem must never appear for the first time in the
recommendation or the feedback message.

- **Reviewer mode:** append a draft contributor feedback message using the
  checklist's feedback guidance (specific, references files, links the README
  template or best-practices guide where relevant). Plain prose paragraphs,
  ready to paste into a Drupal moderation comment or GitHub issue. Label it
  "Draft feedback — edit before sending."
- **Submitter mode:** append a prioritized "Fix before submitting" list instead —
  required-criteria failures first (security findings at the top), then quality
  improvements, each with the file to change.

## 5. Wrap up

- Print the full report in the conversation.
- Offer to save it as `review-<owner>-<repo>.md` in the current directory.
- Reviewer mode: remove the temp clone (`rm -rf "$TMP"`).
