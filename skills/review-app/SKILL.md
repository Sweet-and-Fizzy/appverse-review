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
- `${CLAUDE_PLUGIN_ROOT}/references/finding-codes.md` (rule codes, defect-key
  vocabularies, and stable ID computation)

## 1. Set up the target

Follow target-setup.md sections 1–3 once. You now have: mode (reviewer or
submitter), repo path, `<owner>/<repo>` if known, the reviewed commit (SHA +
date), repo shape, the app list with resolved fields, and `shared_paths`.

## 2. Run the four aspects in parallel

Dispatch four subagents concurrently — one per aspect: review-structure,
review-security, review-quality, review-maintenance. Each subagent's prompt:

> Read `${CLAUDE_PLUGIN_ROOT}/skills/<aspect>/SKILL.md` and follow it exactly.
> Read `${CLAUDE_PLUGIN_ROOT}/references/finding-codes.md` for rule codes and
> defect-key vocabularies.
> Prepared target (do not redo setup): repo path: <path>; mode: <mode>;
> owner/repo: <owner/repo or unknown>; reviewed commit: <SHA> (<date>);
> repo shape: <shape>; apps: <list of path + resolved fields>;
> shared_paths: <list>; schema source: <live|cached>;
> languages/frameworks detected: <e.g., Ruby/Sinatra, Python/Flask, shell>;
> dependency manifests: <Gemfile.lock, package-lock.json, requirements.txt, or none>;
> test suite: <command and result, or "none detected">.
>
> If a previous review of this repo is available, treat its findings as
> context only. Verify the current state independently — a fix may be
> incomplete, may have regressed, or may have introduced a new defect.
>
> Return your findings as structured finding records (per target-setup.md §4),
> any prose tables the skill specifies (capability profile, ratings), and any
> fenced JSON block the skill's Output section specifies (the quality aspect's
> assessments block, the maintenance aspect's maintenance assessment block).
> Do not make accept or reject judgments.

If subagent dispatch is unavailable, run the four aspect skill files yourself,
one at a time, in the order above.

## 3. Synthesize the report

Capture the appverse-review plugin's own HEAD short-SHA at run time (e.g.
`git -C ${CLAUDE_PLUGIN_ROOT} rev-parse --short HEAD`) for the provenance
string; if unavailable, write `unknown`.

```markdown
# Appverse Review: <repo name>

**Repository:** <url or path>  **Mode:** reviewer|submitter  **Date:** <today>
**Reviewed commit:** `<full SHA>` (<commit date>)  **Repo shape:** declared monorepo (N apps) | declared single app | inferred single app
**Reviewed with:** appverse-review @ <plugin version> (`<appverse-review HEAD short SHA, captured at run time>`) · **Rubric:** https://openondemand.connectci.org/appverse-security-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level required criteria

| Rule | Result | Evidence |
|---|---|---|
| STR-01 | PASS/FAIL | README.md — ... |
| STR-01 | PASS/FAIL | LICENSE — ... |
| — | PASS/FAIL/NOT CHECKED | Repo not archived |

## App: <name> (<subpath>)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Security | Low / Medium / High | <one-line phrase from the security findings> |
| Portability | Low / Medium / High | <one-line phrase> |
| Documentation | Low / Medium / High | <one-line phrase> |

<!-- DERIVE the level from the aspect ratings, do not invent it:
     Security: count OODT findings only. None = Low; Low or Info severity only = Medium;
       any Medium, High, or Critical = High.
     Portability: Portable = Low; Partially portable = Medium; Not portable = High.
     Documentation: Strong/Exemplary = Low; Adequate = Medium; Minimal = High.
     Low = good/low-concern; High = most to read. Never invert; never style High as a hazard.
     Monorepo: one Signals block PER app. No repo-level signal aggregate.
     These are the rules in ${CLAUDE_PLUGIN_ROOT}/references/artifact-envelope.md
     ("Indicators"). assemble-artifact.py computes the same levels from the
     findings and grades, and warns when a level written here disagrees. -->

### Structure
| Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|
| STR-02 | PASS/FAIL | ... | Required metadata fields | ... |
| STR-03 | PASS/FAIL | ... | YAML validity | ... |
| STR-07 | PASS/FAIL | ... | Standard OOD structure | ... |
| STR-04 | PASS/FAIL | ... | No broken references | ... |

### Security

**Check tiers:** <Tiers 1–2 | Tiers 1–3 | Tier 1 only>
<if not all tiers: "Tier N not checked — <reason>">

| Tool | Status | Result |
|---|---|---|
<!-- one row per relevant tool from the security aspect's tool-scan summary -->

<capability profile: table for Batch Connect, narrative for Passenger>

| Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|
| OODT-XX | FAIL/WARN | high/medium/low | <description> | file:line |

### Portability
- Rating: <Not portable | Partially portable | Portable> — <one-line justification>
<!-- Portability findings, each with file:line -->

### Documentation
- Rating: <Minimal | Adequate | Strong | Exemplary> — <one-line justification>
<!-- Documentation findings, each with file:line -->

### Code Quality
<!-- code-quality checkboxes AND correctness-&-polish defects (copy-paste artifacts,
     duplicate YAML keys, wrong help text, README typos), each with file:line.
     Code Quality is a findings category that feeds the decision rubric — it is NOT a signal dimension. -->

| Finding | Type | Result | Evidence |
|---|---|---|---|

**Per-app decision:** <Accept | Accept with suggestions | Request changes | Reject>
<!-- This is a decision, derived from the required criteria and finding
     properties above — not from the Signals block. Monorepos only: one line
     per app, rolled up by the Overall recommendation below. Single-app repos:
     omit this line — the Overall recommendation is the decision. -->

## Maintenance signals

| Signal | Value | Assessment |
|---|---|---|
| Last commit | ... | ... |
| Releases | ... | ... |
| Issues responsiveness | ... | ... |
| Contributors | ... | ... |
| CHANGELOG | ... | ... |
| CI | ... | ... |

| Dimension | Level | Evidence |
|---|---|---|
| Upkeep (repo-level) | Low / Medium / High | <one-line phrase> |
<!-- Upkeep, first match wins: an MNT-01 finding = High; brand-new-app waiver
     applied = Medium (say so in the evidence phrase); active within 12mo + 2+
     good-practice signals = Low; active within 12mo = Medium; otherwise High.
     No open issues counts as a good-practice signal. The artifact calls this
     dimension `maintenance`. -->

## Review scope

**Examined:** <list of files, directories, and surfaces that were reviewed>
**Not examined:** <list of files/surfaces not reached, with reason — e.g.,
"dashboard-plugin/ (needs a Rails host)", "runtime behavior (CI, no app
environment)">

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

The recommendation is the reviewer's decision, derived from the required
(gate) criteria and finding properties — NOT from the signal levels. Signals
describe the app for a deployer; they do not gate listing. A High signal never
forces a reject.

<one paragraph. Single-app repos: the decision and its rationale. Monorepos:
roll up the per-app decisions above. Draw only on findings already recorded in
the tables — do not introduce new problems here.>
```

Every `## App:` section has all six subsection headings, in the order shown
(Signals, Structure, Security, Portability, Documentation, Code Quality). Under
a heading with nothing to report, write `No findings.` List the apps in the same
order here and in the metadata JSON (§5). The artifact's indicators deep-link to
these headings by position, so a missing heading or a reordered app sends a
reader to the wrong app's section.

Apply the decision rubric below (from the checklist's Step 3):

| Outcome | Criteria |
|---------|----------|
| **Accept** | Passes all required criteria, adequate+ documentation, partially portable+ config. Always conditional on the duplicate/catalog checks the review cannot perform — word any Accept as pending those. |
| **Accept with suggestions** | Passes required criteria but has clear improvement areas. A below-target Documentation or Portability rating belongs here, not Request changes, when required criteria are otherwise met. |
| **Request changes** | Missing a required (gate) criterion but fixable. A fixable security misconfiguration, even High severity (e.g. CORS open to all origins), is Request changes, not Reject. |
| **Reject** | Duplicate app, no license, abandoned/unmaintained, not an OOD app, or a security finding tagged potentially malicious or unfixable without redesigning the app. |

Follow the checklist's framing (Step 3) rather than a separate copy here.

### Structured findings block

After the Markdown report, emit a single fenced JSON block containing **all**
findings from all four aspects, merged into one array. Each finding is a
structured record per target-setup.md §4 — the same records the aspects
returned, collected into one place. This block is the machine-readable
counterpart to the human-readable tables above; every finding must appear in
both. Do **not** include an `id` field — stable IDs are computed downstream
from the identity fields (`app_id`, `rule`, `defect_key`).

## 4. Mode-specific ending

**Derived-only rule.** The overall recommendation and the mode-specific ending
below are summaries — every problem or fix they mention must already appear as a
finding in a table above (required criteria, security, or the quality findings
table). If while writing the feedback you notice a real defect that is not yet
recorded, stop and add it to the appropriate findings table first, then
summarize it here. A problem must never appear for the first time in the
recommendation or the feedback message.

**Inclusion floor.** Every finding at Low severity or above, and every failed
required (gate) criterion, must be represented in the Draft Feedback.
Info-level polish (e.g. an undocumented hex constant) may be summarized in one
line or omitted. The feedback is a prioritized note, not a copy of the
findings table — but it must not silently drop a real fix-item. (This
complements the Derived-only rule: feedback ⊆ findings, and now fix-level
findings ⊆ feedback.)

- **Reviewer mode:** append a draft contributor feedback message using the
  checklist's feedback guidance (specific, references files, links the README
  template or best-practices guide where relevant). Plain prose paragraphs,
  ready to paste into a Drupal moderation comment or GitHub issue. Label it
  "Draft feedback — edit before sending."
- **Submitter mode:** append a prioritized "Fix before submitting" list instead —
  required-criteria failures first (security findings at the top), then quality
  improvements, each with the file to change.

## 5. Emit review metadata

After synthesizing the report, save a small metadata JSON alongside it. This
is assembled into the full review artifact by `assemble-artifact.py` — the
orchestrator does not produce the artifact directly.

Save to `review-<owner>-<repo>.meta.json`:

```json
{
  "repo_url": "<url or empty for submitter mode>",
  "sha": "<full SHA from setup>",
  "ref": "<branch/tag/SHA reviewed>",
  "repo_shape": "inferred_single | declared_monorepo | declared_single",
  "not_archived": "pass | fail",
  "model": "<the model you are running as, e.g. claude-sonnet-4-6>",
  "recommendation": {
    "decision": "<Accept | Accept with suggestions | Request changes | Reject>",
    "note": "<the Overall recommendation paragraph, verbatim>"
  },
  "apps": [
    {
      "app_id": "root",
      "name": "<app name from manifest/appverse.yml>",
      "decision": "<per-app decision, or same as recommendation for single-app>",
      "assessments": {
        "documentation": "minimal | adequate | strong | exemplary",
        "documentation_summary": "<one-line evidence phrase>",
        "portability": "not_portable | partially_portable | portable",
        "portability_summary": "<one-line evidence phrase>"
      },
      "reported_signals": {
        "security": "Low | Medium | High",
        "portability": "Low | Medium | High",
        "documentation": "Low | Medium | High"
      }
    }
  ],
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
    "summary": "<one-line evidence phrase>",
    "reported_signal": "Low | Medium | High"
  }
}
```

`assessments` is the quality aspect's assessments block for that app and
`maintenance_assessment` is the maintenance aspect's block — copy each as the
aspect emitted it, without re-grading. `reported_signals` and `reported_signal`
are the levels you wrote in the report's Signals blocks and Upkeep row. Field
definitions: `${CLAUDE_PLUGIN_ROOT}/references/artifact-envelope.md`
("Indicator inputs"). If an aspect did not run, leave its block out.

For monorepos, include one entry per app in the `apps` array. The `model`
field is the Claude model ID you are running as — report it directly, do not
guess. Token counts and cost are not available from the review session; they
are tracked externally by the API provider.

## 6. Wrap up

- Print the full report (Markdown + structured JSON block) in the conversation.
- Offer to save the Markdown report as `review-<owner>-<repo>.md` and the
  structured findings as `review-<owner>-<repo>.findings.json` in the current
  directory. After saving the JSON, compute stable IDs:

      python3 "${CLAUDE_PLUGIN_ROOT}/references/compute-ids.py" \
        < review-<owner>-<repo>.findings.json \
        > review-<owner>-<repo>.findings.json.tmp \
        && mv review-<owner>-<repo>.findings.json.tmp \
              review-<owner>-<repo>.findings.json

- Reviewer mode: remove the temp clone (`rm -rf "$TMP"`).
