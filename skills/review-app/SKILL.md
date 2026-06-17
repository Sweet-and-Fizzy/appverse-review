---
name: review-app
description: Full AppVerse submission review — structure, security, quality, and maintenance — with a recommended decision and draft feedback. Use when asked to review an app submission or app repo for AppVerse, to check a repo before submitting it to AppVerse, or when given a GitHub URL of an Open OnDemand app to review.
argument-hint: "[github-url]"
---

# AppVerse App Review (orchestrator)

Produce an evidence-backed review with a recommended decision. You recommend; a
human decides.

Read first:
- `${CLAUDE_PLUGIN_ROOT}/references/review-checklist.md` (canonical criteria,
  including the decision rules in its Step 4)
- `${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` (setup procedure and
  findings format)

## 1. Set up the target

Follow target-setup.md sections 1–3 once. You now have: mode (reviewer or
submitter), repo path, `<owner>/<repo>` if known, repo shape, the app list with
resolved fields, and `shared_paths`.

## 2. Run the four aspects in parallel

Dispatch four subagents concurrently — one per aspect: review-structure,
review-security, review-quality, review-maintenance. Each subagent's prompt:

> Read `${CLAUDE_PLUGIN_ROOT}/skills/<aspect>/SKILL.md` and follow it exactly.
> Prepared target (do not redo setup): repo path: <path>; mode: <mode>;
> owner/repo: <owner/repo or unknown>; repo shape: <shape>; apps: <list of
> path + resolved fields>; shared_paths: <list>; schema source: <live|cached>.
> Return only your findings in the skill's output format. Do not make accept or
> reject judgments.

If subagent dispatch is unavailable, run the four aspect skill files yourself,
one at a time, in the order above.

## 3. Synthesize the report

```markdown
# AppVerse Review: <repo name>

**Repository:** <url or path>  **Mode:** reviewer|submitter  **Date:** <today>
**Repo shape:** declared monorepo (N apps) | declared single app | inferred single app

## Repo-level required criteria

| Criterion | Result | Evidence |
|---|---|---|
| README.md substantive | PASS/FAIL | ... |
| LICENSE present | PASS/FAIL | ... |
| Repo not archived | PASS/FAIL/NOT CHECKED | ... |
| shared_paths security review | PASS/FAIL/N-A | ... |

## Maintenance signals

| Signal | Value | Assessment |
|---|---|---|
| Last commit | ... | ... |
| Releases | ... | ... |
| Issues responsiveness | ... | ... |
| Contributors | ... | ... |
| CHANGELOG | ... | ... |
| CI | ... | ... |

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

| Finding | OAT | Severity | Evidence |
|---|---|---|---|

### Quality
- Documentation: <rating> — <one-line justification>
- Portability: <rating> — <one-line justification>
- Code quality: <met/missed checkboxes with evidence>

### Recommended decision: <Accept | Accept with suggestions | Request changes | Reject>

## Not checked (requires catalog access)
- Duplicate check against the existing catalog
- `software` value matches a catalog Software entry

## Overall recommendation
<one paragraph; for monorepos, summarize per-app decisions>
```

Decision rules are the checklist's Step 4 table. Security findings count as
"security concerns" for its Reject row only when tagged potentially malicious or
when the exposure cannot be fixed without redesigning the app; a fixable
misconfiguration — even High severity, like CORS open to all origins — points to
Request changes, not Reject. **Any Accept must be worded as conditional on the
human reviewer completing the duplicate/catalog checks listed under "Not
checked".**

## 4. Mode-specific ending

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
