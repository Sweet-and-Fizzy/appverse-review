---
name: review-app
description: Full Appverse submission review — structure, security, quality, and maintenance — with a recommended decision and draft feedback. Use when asked to review an app submission or app repo for Appverse, to check a repo before submitting it to Appverse, or when given a GitHub URL of an Open OnDemand app to review.
argument-hint: "[github-url]"
---

# Appverse App Review (orchestrator)

Produce an evidence-backed review with a recommended decision. You recommend; a
human decides.

You are the orchestrator. Your job is setup, dispatch and synthesis; the
four aspect reviews are done by subagents, each in its own context. Keep your
own context small: it has to hold the four results and the whole report at
the end.

Read now only `${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` (setup
procedure and findings format). Read the rest when §3 says to, not before:
`references/review-rubric.md` (canonical criteria and the "Decision rubric"),
`references/review-checklist.md` (the Reviewer Process: catalog checks,
feedback curation) and `references/finding-codes.md` (rule codes,
vocabularies, stable IDs).

## 1. Set up the target

Follow target-setup.md sections 1–3 once. You now have: mode (reviewer or
submitter), repo path, `<owner>/<repo>` if known, the reviewed commit (SHA +
date), repo shape, the app list with resolved fields, and `shared_paths`.

Do not read the pre-review fact files (`readme.json`, `form.json`,
`template.json`, `security.json` and the rest), the aspect skill files, or the
target repo's code yourself. `apps.json` and `summary.json` are enough for
setup. The subagents read everything else.

## 2. Run the four aspects in parallel

Your next action after setup is a single message containing four Agent tool
calls, one per aspect, in this order: review-structure, review-security,
review-quality, review-maintenance. Run them in the foreground. Do not start
any aspect's work yourself first, and do not read anything between setup and
this message. Each call's description is "Review <aspect> aspect" and its
prompt is:

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

Only if your tool list has no Agent (or Task) tool at all, run the four
aspect skill files yourself, one at a time, in the order above. When the tool
is present, always dispatch, whatever the size of the repo.

## 3. Synthesize the report

Now read `references/review-rubric.md`, `references/review-checklist.md` and
`references/finding-codes.md`, then build the report from the four results.

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
<!-- A signal a source was tried for and failed to provide (e.g. `gh`
     missing/unauthenticated) is NOT CHECKED, reason "unavailable". A signal
     the maintenance skill deliberately does not compute is "Not assessed",
     reason "not read by design" — never "unavailable" for a source that was
     never tried. -->

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

Low means little for a deployer to look at; High means the most to read. A
signal is not a grade and does not gate listing.

<!-- DERIVE the level from the aspect ratings, do not invent it:
     Portability: Portable = Low; Partially portable = Medium; Not portable = High.
     Documentation: Strong/Exemplary = Low; Adequate = Medium; Minimal or Below minimal = High.
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

Findings are classified under OODT (Open OnDemand App Threats); codes are defined in the rubric's Security section at https://openondemand.connectci.org/appverse-review-rubric#security.

<!-- Paste <pre-review>/tool-table.md here verbatim: the Check tiers line, the tier 3 line, and the Tool / Status / Result table. Never retype it. If the file is absent, write "**Check tiers:** Tier 1 only" and the table with all four rows (shellcheck, semgrep, bandit, trivy) as "Not run (pre-review facts not found)" with Result "—". -->

#### Findings

<!-- One row per candidate in <pre-review>/<app_id>/security.json, grouped
     by check in manifest order (sec-interpolation, sec-eval-exec,
     sec-credential-string, sec-permissive-mode, sec-network-call,
     sec-file-write-outside-job, sec-config-flag, sec-binary-in-template,
     sec-tool-finding), each citing its candidate's path:N. A check with no
     candidates has no row. Tag is the intent tag on a FAIL/WARN row and "—"
     on a PASS row. A sec-tool-finding row's Summary starts with its code;
     it records under the rule security-tools.md's code table gives (OODT,
     or QUA-xx/STR-xx for a hygiene code, kept in this table), its Rule
     cell is "—" on a PASS row, and candidates marked artifact true share
     one PASS row that says they are artefacts of linting OOD's job-script
     files one at a time.
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

<!-- When no row in either table is FAIL or WARN, whatever its Rule cell, write exactly "No tool-detectable issues in the checked tiers." here; the Check tiers lines above stay as they are. Never write "safe". There is no security rating. -->

<capability profile, a summary of the rows above: table for Batch Connect, narrative for Passenger>

### Portability
- Rating: <Not portable | Partially portable | Portable> — <one-line justification>

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | PASS/WARN/NOT CHECKED | ... | <per template.json absolute_paths candidate, or a group in one file with one reason> | path:N |
| QUA-02 | `check: portability-rating` | PASS/FAIL | ... | <rating; PASS at Partially portable or above; a FAIL cites the hardcoded-* records and adds no record> | ... |

### Documentation
- Rating: <Below minimal | Minimal | Adequate | Strong | Exemplary> — <one-line justification>
- Evidence per rung (from readme.json rungs; a placeholder heading counts as none):
  what it launches: <"Heading", README.md:N, or none>; prerequisites: <…>; installation: <…>;
  configuration: <…>; known limitations: <…>;
  troubleshooting: <…>; screenshots: <…>; environment variables: <…>;
  info panel: <…>; architecture: <…>
<!-- Each line cites the readme.json rung: the heading text and README.md:N,
     or none when the rung is null. placeholder true forces
     "none (placeholder)". Screenshots and environment variables cite a
     screenshots image line or an env_vars assignment/phrase line; a rung
     whose only evidence is its heading says "heading only". A rung with no
     readme.json heading may cite the one README line that delivers it as
     content: README.md:N (a text line, which check-evidence.py verifies).
     A line may say none with a reason where the section does not deliver
     its rung; it may never claim a rung without a citation. The rating is
     the highest rung with every requirement satisfied above; with none for
     Minimal it is Below minimal. Never claim a rung whose evidence line
     says none. Only when readme.json stub is true does the rating line
     read "Minimal — not supported (stub README; see QUA-01)". In
     meta.json assessments, Below minimal and a stub are "minimal". -->

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
| QUA-10 | `check: erb-missing-value` | ... | ... | ERB handles missing/nil values | ... |
| QUA-06 | `check: icon-matches-target-os` | ... | ... | Desktop/panel icon matches target OS | ... |
| QUA-05/QUA-06 | | FAIL/WARN | ... | <correctness & polish finding> | path:N |

**Per-app decision:** <Accept | Accept with suggestions | Request changes | Reject>
<!-- This is a decision, derived from the gate criteria and finding
     properties above — not from the Signals block. Monorepos only: one line
     per app, rolled up by the Overall recommendation below. A High security
     FAIL sets at least Request changes, and a Critical one Reject, for every
     app, wherever in the repo it was found: installing one app clones the
     whole repo. Single-app repos: omit this line — the Overall
     recommendation is the decision. -->

## Review scope

**Examined:** <list of files, directories, and surfaces that were reviewed>
**Not examined:** <list of files/surfaces not reached, with reason — e.g.,
"dashboard-plugin/ (needs a Rails host)", "runtime behavior (CI, no app
environment)">
**Tools:** <which pre-review checks ran, from summary.json; "pre-review facts
not found" if absent>

## Catalog checks
<!-- Write only this heading and the marker line below. A script
     (references/insert-catalog.py) replaces the marker with the block the
     pre-review step wrote from the catalog: the Software entry, vocabulary
     and same-software results, and the duplicate-rationale placeholder for
     the reviewer. Do not query the catalog and do not write catalog results
     yourself. -->
<!-- catalog-checks -->

## Overall recommendation

The recommendation is the reviewer's decision, derived from the required
(gate) criteria and finding properties — NOT from the signal levels. Signals
describe the app for a deployer; they do not gate listing. A High signal never
forces a reject.

<one paragraph, opening with the decision in bold, e.g. **Request changes.**
Single-app repos: the decision and its rationale. Monorepos:
roll up the per-app decisions above: the recommendation is the strictest of them. Draw only on findings already recorded in
the tables — do not introduce new problems here. Never describe a below-target
Documentation or Portability rating as blocking listing or as needed before
listing: it moves the decision to Accept with suggestions, nothing more.>
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
| **Accept** | Passes all gate criteria, adequate+ documentation, partially portable+ config. Always conditional on the duplicate check, which the review performs the catalog reads for but leaves the decision itself to the reviewer — word any Accept as pending that. |
| **Accept with suggestions** | Passes gate criteria but has clear improvement areas. A below-target Documentation or Portability rating belongs here, not Request changes, when gate criteria are otherwise met. |
| **Request changes** | Missing a required (gate) criterion but fixable. A missing LICENSE is Request changes: the contributor adds one file. A fixable security misconfiguration, even High severity (e.g. CORS open to all origins), is Request changes, not Reject. |
| **Reject** | Duplicate app, abandoned/unmaintained, not an OOD app, or a security finding tagged potentially malicious or unfixable without redesigning the app. |

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
key is absent from that line, its file is not named in the prose, or its
defect is not described where the file is named. The description must sit
in the sentence window that runs from the sentence naming the file up to
the first later sentence naming a different file, as a line number from the
finding's evidence, a word of its defect key other than the file's own
name, or a value quoted from its evidence. A repo-wide item with no file is
named by its subject word (release, commit, issue, CI) and still needs such
a description in that window, unless its tag has nothing beyond the subject
(`no-releases`, `no-ci`, `no-changelog`). Write the defect in plain words
for the contributor; the check is looking for the file and either the line
or what is wrong, not jargon. (This complements the Derived-only rule:
feedback ⊆ findings, and fix-items ⊆ feedback.)

**Required vs. recommended vs. suggested.** A fix-item is Required when it
blocks listing or triggers Request changes: a gate criterion, or any OODT
FAIL. It is Recommended when it is a target miss in any dimension —
Documentation rated below Adequate, Portability rated Not portable, or a
`code_quality` check whose manifest `weight` is `target`
(`references/checks.yml`) recorded FAIL — needed to reach the target rating
but not to block listing. It is Suggested when it is a `weight: suggestion`
check, a maintenance signal MNT-02 to MNT-06, or polish (any other
FAIL/WARN). Word the feedback accordingly rather than flattening every
fix-item into the same register.

**Never advise removing a real caveat.** Never advise removing a comment or
help text that states a real constraint (a partition that requires a GPU, a
limit); advise rewording it.

- **Reviewer mode:** append a draft contributor feedback message using the
  Reviewer Process's Step 4 feedback guidance (specific, references files, links the README
  template or best-practices guide where relevant). Plain prose paragraphs.
  The portal pre-fills the reviewer's response with it, and the response
  becomes the body of the decision email. That email already greets the
  contributor, states each app's decision, says how to re-submit and says a
  reply reaches the reviewer, so open with the first finding: no greeting or
  thank-you, no restating the decision, no re-submit or "reply to me"
  instructions, and no sign-off. Label it "Draft feedback — edit before
  sending."
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

- Then write the Catalog checks section from the catalog read, and check the
  report and findings against every checker in one pass, fixing the findings
  or the report until it passes:

      python3 "${CLAUDE_PLUGIN_ROOT}/references/insert-catalog.py" \
        review-<owner>-<repo>.md <pre-review-dir>
      python3 "${CLAUDE_PLUGIN_ROOT}/references/check-all.py" \
        review-<owner>-<repo>.md review-<owner>-<repo>.findings.json \
        "${CLAUDE_PLUGIN_ROOT}/references/checks.json" <pre-review-dir> \
        --target "$TMP/repo"

  (`check-all.py` runs, in order:
  `check-feedback-floor.py`: every FAIL/WARN fix-item of Low or above has
  its key in the `feedback-covers` line, its file (or, for a repo-wide
  item, its subject word) named in the Draft Feedback, and its defect
  described in the sentence window there (a line number, a word of its
  defect key other than the file's own name, or a value quoted from its
  evidence).
  `check-keys.py`: every defect_key is a valid, stable `{anchor}:{tag}`
  with a real or pseudo anchor and a vocabulary tag, and a FAIL/WARN
  record's evidence cites its own anchor file when it cites any file.
  `check-rating.py`: Documentation's rating is no higher than its evidence
  lines support, its signal follows the rating, no `content:` line is
  cited for two rungs, the stub line and Below minimal follow
  `readme.json`'s `stub`; no suggestion-class check (any tag in its
  checks.json `tags`) or MNT-02 to MNT-06 signal is FAIL; and
  "No tool-detectable issues in the checked tiers." never sits under a
  FAIL or WARN Security row of any rule code.
  `check-rows.py`: every manifest check applicable to an app has a row, and
  every pre-review candidate is cited.
  `check-evidence.py`: every `file:line` citation names a real file and
  line, every `content:` citation names a README content line, and a
  literal value the summary asserts is on the cited line is there (within
  two lines of a check-rows candidate line); a value that is not is a
  `NOTE` line, which does not fail the run.
  `check-catalog.py`: the Catalog checks section is exactly the pre-review
  step's `catalog-checks.md`, which `insert-catalog.py` writes there; never
  edit that section by hand.
  `check-meta.py` (when `review-<owner>-<repo>.meta.json` exists): the
  metadata has the recommendation and its note, `not_archived`, `public`, and
  an app list (section 5).
  `check-decisions.py` (when the meta.json exists): every decision is at
  least the floor its findings set. A High FAIL needs Request changes and a
  Critical FAIL needs Reject. A security or repo-level one sets that floor
  for every app and the recommendation; any other sets it for its own app.
  `check-sections.py`: the report has Upkeep, Review scope and an Overall
  recommendation that states its decision, every app of a monorepo has a
  Per-app decision line, and those decisions match the meta.json.
  Its output groups each checker's problem lines under a `[floor]`/`[keys]`/
  `[rating]`/`[rows]`/`[evidence]`/`[catalog]`/`[meta]`/`[decisions]`/`[sections]` prefix, followed by that checker's
  summary line. It exits 1 if any checker failed, including a report
  missing a section a checker needs (`MISSING section: ...`), and 2 if any
  could not run, including a checker that crashed (`crashed: ...`).
  `<pre-review-dir>` is `$TMP/pre-review` in reviewer mode, the
  run-supplied pre-review directory in CI, or `$PRE` in submitter mode.
  `--target` is `$TMP/repo` in reviewer mode (the clone from setup), the
  already-checked-out repo in CI (`$GITHUB_WORKSPACE/target-repo`), or `.`
  in submitter mode.)

- Reviewer mode: remove the temp clone (`rm -rf "$TMP"`).
