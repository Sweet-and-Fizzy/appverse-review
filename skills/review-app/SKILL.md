---
name: review-app
description: Full Appverse submission review — structure, security, quality, and maintenance — with a recommended decision and draft feedback. Use when asked to review an app submission or app repo for Appverse, to check a repo before submitting it to Appverse, or when given a GitHub URL of an Open OnDemand app to review.
argument-hint: "[github-url]"
---

# Appverse App Review (orchestrator)

Produce an evidence-backed review with a recommended decision. You recommend; a
human decides.

Read first:
- `${CLAUDE_PLUGIN_ROOT}/references/review-rubric.md` (canonical criteria,
  including the decision rules in its "Decision rubric" section)
- `${CLAUDE_PLUGIN_ROOT}/references/review-checklist.md` (the Reviewer
  Process: catalog checks, feedback curation)
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
> pre-review dir: <path to the pre-review output, or "absent">
> (it holds `apps.json`, the app list with each `app_id`, `path` and
> `app_type`, and one fact directory per app, `<pre-review>/<app_id>/`, with
> `readme.json`, `form.json`, `template.json`, `entry_point.json` and
> `security.json` as they apply; `apps.json`'s `app_id` is the same `app_id`
> a finding record uses, "root" for a single-app repo, the normalised
> subpath for a monorepo app);
> checks manifest: `${CLAUDE_PLUGIN_ROOT}/references/checks.json`;
> languages/frameworks detected: <e.g., Ruby/Sinatra, Python/Flask, shell>;
> dependency manifests: <Gemfile.lock, package-lock.json, requirements.txt, or none>;
> test suite: <command and result, or "none detected">.
>
> If a previous review of this repo is available, treat its findings as
> context only. Verify the current state independently — a fix may be
> incomplete, may have regressed, or may have introduced a new defect.
>
> For each app, answer every manifest check for that app's `app_type` in your
> dimension, at least one row per check (Security: one row per candidate), each
> row's Check column holding `check: <id>`.
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
**Reviewed with:** appverse-review @ <plugin version> (`<appverse-review HEAD short SHA, captured at run time>`, https://github.com/Sweet-and-Fizzy/appverse-review) · **Model:** <the model id the run gave you; CI overwrites this from its parameters> · **Rubric:** https://openondemand.connectci.org/appverse-review-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|
| — | PASS/FAIL | Repository public and accessible (the clone succeeded) |
| STR-01 | PASS/FAIL | README.md — ... |
| STR-01 | PASS/FAIL | LICENSE — ... |
| — | PASS/FAIL/NOT CHECKED | Repo not archived |
<!-- Result values everywhere are exactly PASS, FAIL, WARN, NOT CHECKED. "Info" is a severity, never a result. -->

## Upkeep

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
     No open issues is neutral: it is not one of the good-practice signals.
     Only FAIL/WARN records count as findings here — a PASS or NOT CHECKED
     MNT-01 record does not make the repo stale. The artifact calls this
     dimension `maintenance`; its anchor is #upkeep. -->

## App: <name> (<subpath>)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | Low / Medium / High | <one-line phrase> |
| Documentation | Low / Medium / High | <one-line phrase> |

<!-- DERIVE the level from the aspect ratings, do not invent it:
     Portability: Portable = Low; Partially portable = Medium; Not portable = High.
     Documentation: Strong/Exemplary = Low; Adequate = Medium; Minimal = High.
     Low = good/low-concern; High = most to read. Never invert; never style High as a hazard.
     Monorepo: one Signals block PER app. No repo-level signal aggregate.
     There is no Security signal: security is the findings table below, never a level.
     These are the rules in ${CLAUDE_PLUGIN_ROOT}/references/artifact-envelope.md
     ("Indicators"). assemble-artifact.py computes the same levels from the
     findings and grades, and warns when a level written here disagrees. -->

<!-- Every dimension table below has a Check column. A row that answers a
     checks-manifest entry (references/checks.json, the entries whose
     app_types include this app's app_type) holds exactly `check: <id>` there,
     in manifest order; rows from the open-ended pass leave it empty.
     Evidence cites file:line in exactly one of these forms: path:N,
     path:N-M, or path:N,M (a comma list of lines or ranges), with the
     repo-relative path as the fact file gives it; a path-only candidate may
     be cited by the bare path. Never prose ("line 12 of script.sh",
     "script.sh: line 12"). A row answers exactly the candidates its
     Evidence cites: a PASS row clears a check that has candidates only by
     citing every one; a plain PASS is for a check with none.
     check-rows.py enforces this. -->

### Structure
| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | PASS/FAIL/WARN/NOT CHECKED | ... | Required metadata fields | ... |
| STR-03 | `check: str-03-yaml-valid` | PASS/FAIL/WARN/NOT CHECKED | ... | YAML validity | ... |
| STR-06 | `check: str-06-syntax` | PASS/FAIL/NOT CHECKED | ... | Template scripts syntactically correct: <N files pass; M fail; K not checked> (from pre-review syntax.json) | <every syntax.json entry with ok false, as path:N or path> |
| STR-07 | `check: str-07-layout` | PASS/FAIL/WARN/NOT CHECKED | ... | Standard OOD structure | ... |
| STR-04 | `check: str-04-references` | PASS/FAIL/WARN/NOT CHECKED | ... | No broken references | ... |
<!-- Passenger and companion apps: no str-06-syntax or str-07-layout row;
     instead a `check: entry-point-parses` row (STR-07) from entry_point.json
     (parses true = PASS, false = FAIL citing the file, "not_checked" = NOT
     CHECKED), placed where str-06-syntax would be, plus an STR-08 row when
     `consistent` is false. -->

### Security

Findings are classified under OODT (Open OnDemand App Threats); codes are defined in the rubric's Security section.

<!-- Paste <pre-review>/tool-table.md here verbatim: the Check tiers line, the tier 3 line, and the Tool / Status / Result table. Never retype it. If the file is absent, write "**Check tiers:** Tier 1 only" and the table with all four rows (shellcheck, semgrep, bandit, trivy) as "Not run (pre-review facts not found)" with Result "—". -->

#### Findings

<!-- One row per candidate in <pre-review>/<app_id>/security.json, grouped
     by check in manifest order (sec-interpolation, sec-eval-exec,
     sec-credential-string, sec-permissive-mode, sec-network-call,
     sec-file-write-outside-job, sec-config-flag, sec-binary-in-template),
     each citing its candidate's path:N. A check with no candidates has no
     row. Tag is the intent tag on a FAIL/WARN row and "—" on a PASS row.
     When security.json is absent, write "Candidate enumeration not run:
     <reason>." in place of the rows. When it lists no candidates and the
     open-ended pass found nothing, write the single line "security.json
     lists no candidates; no observations." in place of both tables. -->

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-XX | `check: sec-<id>` | FAIL/WARN/PASS | critical/high/medium/low/info | unintentional / potentially malicious / — (PASS) | <one-line reason> | path:N |

#### Additional observations (review)

<!-- The open-ended pass after the candidate loop: what security.json did not
     list, each summary saying so. `No findings.` when there is nothing. -->

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| OODT-XX | FAIL/WARN | critical/high/medium/low | unintentional / potentially malicious | <description>; not listed by security.json | path:N |

<!-- When no row in either table is FAIL or WARN, write exactly "No tool-detectable issues in the checked tiers." here; the Check tiers lines above stay as they are. Never write "safe". There is no security rating. -->

<capability profile, a summary of the rows above: table for Batch Connect, narrative for Passenger>

### Portability
- Rating: <Not portable | Partially portable | Portable> — <one-line justification>

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | PASS/WARN/NOT CHECKED | ... | <per template.json absolute_paths candidate, or a group in one file with one reason> | path:N |
| QUA-02 | `check: portability-rating` | PASS/FAIL | ... | <rating; PASS at Partially portable or above; a FAIL cites the hardcoded-* records and adds no record> | ... |

### Documentation
- Rating: <Minimal | Adequate | Strong | Exemplary> — <one-line justification>
- Evidence per rung (from readme.json rungs; a placeholder heading counts as none):
  what it launches: <"Heading", README.md:N, or none>; prerequisites: <…>; installation: <…>;
  configuration: <…>; known limitations: <…>;
  troubleshooting: <…>; screenshots: <…>; environment variables: <…>;
  info panel: <…>; architecture: <…>
<!-- Each line cites the readme.json rung: the heading text and README.md:N,
     or none when the rung is null. placeholder true forces
     "none (placeholder)". Screenshots and environment variables cite a
     screenshots image line or an env_vars assignment/phrase line; a rung
     whose only evidence is its heading says "heading only". A line may say
     none with a reason where the section does not deliver its rung; it may
     never cite a section readme.json does not list. The rating is the
     highest rung with every requirement satisfied above. Never claim a rung
     whose evidence line says none. -->

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | PASS/FAIL | ... | <rating; PASS at Adequate or above> | README.md:N |

### Code Quality
<!-- At least one row per manifest check for this app's app_type, ALWAYS, in
     manifest order (the code_quality entries of checks.json); PASS with
     evidence when clean, NOT CHECKED with the reason when it could not be
     examined. A check whose facts (form.json, template.json) list
     candidates answers each one, FAIL/WARN or PASS citing it; candidates in
     one file with one result and reason may share a row (path:N,M), but
     candidates with different results never share a row. Never
     omit a row: silence reads as clean. Then one row per correctness-&-polish
     finding (copy-paste artifacts, duplicate YAML keys, wrong help text,
     README typos), with the Check column empty. Code Quality is a findings
     category that feeds the decision rubric — it is NOT a signal
     dimension. -->

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-03 | `check: error-handling` | PASS/FAIL/WARN/NOT CHECKED | ... | Error handling in scripts | path:N |
| QUA-07 | `check: numeric-field-bounds` | ... | ... | Input validation on form fields | ... |
| QUA-08 | `check: magic-numbers` | ... | ... | Magic numbers / undocumented literals | ... |
| QUA-09 | `check: duplicated-blocks` | ... | ... | Duplicated code blocks | ... |
| QUA-04 | `check: dead-code` | ... | ... | Commented-out dead code | ... |
| QUA-10 | `check: erb-missing-value` | ... | ... | ERB handles missing/empty values | ... |
| QUA-06 | `check: icon-matches-target-os` | ... | ... | Desktop/panel icon matches target OS | ... |
| QUA-05/QUA-06 | | FAIL/WARN | ... | <correctness & polish finding> | path:N |

**Per-app decision:** <Accept | Accept with suggestions | Request changes | Reject>
<!-- This is a decision, derived from the gate criteria and finding
     properties above — not from the Signals block. Monorepos only: one line
     per app, rolled up by the Overall recommendation below. Single-app repos:
     omit this line — the Overall recommendation is the decision. -->

## Review scope

**Examined:** <list of files, directories, and surfaces that were reviewed>
**Not examined:** <list of files/surfaces not reached, with reason — e.g.,
"dashboard-plugin/ (needs a Rails host)", "runtime behavior (CI, no app
environment)">
**Tools:** <which pre-review checks ran, from summary.json; "pre-review facts
not found" if absent>

## Catalog checks
<!-- Query the public JSON:API — see the Reviewer Process's "Reading the catalog
     without a login". These need no reviewer account; record what each
     returned. List an item as not checked only if its query actually failed,
     and say so. -->
- Duplicate check against the existing catalog — <result>
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why,
    per the Reviewer Process's Duplicate check; edit before pasting into the issue or
    email>_
- `software` value matches a catalog Software entry — <result>. If it has no
  match, the reviewer creates the Software entry (should it exist), corrects
  the value, or requests changes; see the Reviewer Process's Software entry check
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

The repo-level sections come first: gate criteria, then Upkeep; the per-app
sections follow, each with the six subsection headings in the order shown
(Signals, Structure, Security, Portability, Documentation, Code Quality). Under
a heading with nothing to report, write `No findings.` List the apps in the same
order here and in the metadata JSON (§5). The artifact's indicators deep-link to
these headings by position, so a missing heading or a reordered app sends a
reader to the wrong app's section.

Apply the decision rubric below (from the rubric's "Decision rubric" section):

| Outcome | Criteria |
|---------|----------|
| **Accept** | Passes all gate criteria, adequate+ documentation, partially portable+ config. Always conditional on the duplicate/catalog checks the review cannot perform — word any Accept as pending those. |
| **Accept with suggestions** | Passes gate criteria but has clear improvement areas. A below-target Documentation or Portability rating belongs here, not Request changes, when gate criteria are otherwise met. |
| **Request changes** | Missing a required (gate) criterion but fixable. A fixable security misconfiguration, even High severity (e.g. CORS open to all origins), is Request changes, not Reject. |
| **Reject** | Duplicate app, no license, abandoned/unmaintained, not an OOD app, or a security finding tagged potentially malicious or unfixable without redesigning the app. |

Follow the rubric's framing rather than a separate copy here.

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
finding in a table above (gate criteria, security, or the quality findings
table). If while writing the feedback you notice a real defect that is not yet
recorded, stop and add it to the appropriate findings table first, then
summarize it here. A problem must never appear for the first time in the
recommendation or the feedback message.

**Inclusion floor — derive, don't recall.** Before writing the feedback, list
every finding whose `result` is FAIL or WARN and whose `severity` is Low or
above. Each of these is a fix-item and must be named in the feedback with the
file it lives in; group related items in one paragraph where that reads
better. Info-level polish may be summarized in one line or omitted. Write the
feedback first. Then end the section with a single HTML comment that lists
the `defect_key` of every fix-item the prose above addresses; it is a
checksum of what you wrote, not a list to satisfy:

    <!-- feedback-covers: submit.yml.erb:unsanitized-input, template/script.sh.erb:no-error-handling -->

`check-feedback-floor.py` (wrap-up, and CI) fails the review when a fix-item's
key is absent from that line, its file is not named in the prose, or the
paragraph that names the file gives neither a line number from the finding's
evidence nor a word from its defect key. Write the defect in plain words for
the contributor; the check is looking for the file and either the line or
what is wrong, not jargon. (This complements the Derived-only rule: feedback
⊆ findings, and fix-items ⊆ feedback.)

- **Reviewer mode:** append a draft contributor feedback message using the
  Reviewer Process's Step 4 feedback guidance (specific, references files, links the README
  template or best-practices guide where relevant). Plain prose paragraphs,
  ready to paste into a Drupal moderation comment or GitHub issue. Label it
  "Draft feedback — edit before sending."
- **Submitter mode:** append a prioritized "Fix before submitting" list instead —
  gate-criteria failures first (security findings at the top), then quality
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
  "public": "pass | fail",
  "model": "<the model id given to you by the run parameters; if none was given, the id you are running as>",
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
field is the model id the run gave you (CI overwrites it from the workflow's
parameters after the review; a model cannot verify its own identity). Token
counts and cost are not available from the review session; they are tracked
externally by the API provider.

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

- Then check the feedback floor and fix the feedback until it passes:

      python3 "${CLAUDE_PLUGIN_ROOT}/references/check-feedback-floor.py" \
        review-<owner>-<repo>.findings.json review-<owner>-<repo>.md

- Then validate finding keys and ratings, and fix the findings or the report
  until both pass:

      python3 "${CLAUDE_PLUGIN_ROOT}/references/check-keys.py" \
        review-<owner>-<repo>.findings.json --target "$TMP/repo"
      python3 "${CLAUDE_PLUGIN_ROOT}/references/check-rating.py" \
        review-<owner>-<repo>.md review-<owner>-<repo>.findings.json

  (`check-rating.py` checks Documentation only: the rating against its
  evidence lines and the Documentation signal against the rating.
  Reviewer mode's `$TMP/repo` is the clone from setup. When the repo was
  already checked out for you (CI: `$GITHUB_WORKSPACE/target-repo`), pass that
  path instead. In submitter mode use `.`.)

- Then check rows and evidence, and fix the report or the findings until both
  pass:

      python3 "${CLAUDE_PLUGIN_ROOT}/references/check-rows.py" \
        review-<owner>-<repo>.md review-<owner>-<repo>.findings.json \
        "${CLAUDE_PLUGIN_ROOT}/references/checks.json" <pre-review-dir>
      python3 "${CLAUDE_PLUGIN_ROOT}/references/check-evidence.py" \
        review-<owner>-<repo>.findings.json --target "$TMP/repo"

  (`check-rows.py` checks that every manifest check applicable to an app has
  a row and that every pre-review candidate is cited; `check-evidence.py`
  checks that every finding's `file:line` citation names a real file and
  line. `<pre-review-dir>` is `$TMP/pre-review` in reviewer mode, the
  run-supplied pre-review directory in CI, or `$PRE` in submitter mode.
  `check-evidence.py`'s `--target` follows the same rule as `check-keys.py`
  above.)

- Reviewer mode: remove the temp clone (`rm -rf "$TMP"`).
