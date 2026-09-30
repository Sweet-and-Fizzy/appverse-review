---
name: review-security
description: Security review of an Appverse / Open OnDemand app repo — capability profile, unsafe-pattern checks, OODT threat classification. Use for the security aspect of an Appverse review, or when asked to security-audit an OOD app.
argument-hint: "[github-url]"
---

# Security Review (aspect)

Rubric: `${CLAUDE_PLUGIN_ROOT}/references/review-rubric.md` — section
"Security". Read it before starting. It defines the check tiers, the
capability baselines per app type, the pattern checks, and the OODT (Open
OnDemand App Threats) taxonomy. Expand OODT on first use in the report and
link it to the published rubric at
https://openondemand.connectci.org/appverse-review-rubric so readers can look
up a code.

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first.

## Check tiers

The security review consists of three tiers, distinguished by what they require:

- **Tier 1 — Static.** Source-level analysis: every candidate site the
  pre-review listed in `security.json`, answered one by one, then an
  open-ended reading for what the enumeration missed, then the capability
  profile. Runs anywhere, including CI on a submitted PR.
- **Tier 2 — Tooling.** Static analysis tools (shellcheck, bandit, semgrep,
  trivy). Run before the review by references/run-pre-review.sh; the skill
  reads its output and never runs a tool itself. Needs installed binaries, no
  running app; the pre-review summary says which ran.
- **Tier 3 — Runtime.** Boot the app and exercise it. Realistically local or on
  a reviewer's machine.

The report must state which tiers ran. A CI invocation that runs tiers 1–2
reports tier 3 as `NOT CHECKED — no isolated execution environment`. A thinner review
should look thinner, not identical to a full one.

## Procedure

The per-app security review is a loop over the checks manifest,
`${CLAUDE_PLUGIN_ROOT}/references/checks.json` (human copy `checks.yml`): the
entries with `dimension: security` whose `app_types` include the app's type.
Their fact source is `<pre-review>/<app_id>/security.json`, which lists
candidate sites, not verdicts. Security has no rating: the rows are the output.

1. Determine each app's type (Batch Connect, Passenger, dashboard, widget) from
   `<pre-review>/apps.json` (`app_type`), which resolves it from the manifest
   `role` / declared `app_type` and the entry-point files; confirm it against
   the manifest. The capability baseline differs by type.
2. Identify in-scope files. Batch Connect: `form.yml(.erb)`, `submit.yml.erb`,
   `template/**`, `connection.yml`, container definitions. Passenger: the full
   application source (routes, controllers, views, config, scripts). Always
   include `shared_paths`. `security.json`'s `scope` and `files` are the
   scanner's view of the same set, and its `skipped_files` are the files it
   could not read; list those, and any other binary file, as unauditable.
   If the app declares `shared_paths`, include those directories in the
   security review scope. `shared_paths` is scope input, not a pass/fail
   criterion.
3. **Tier 1 — Candidate loop.** Read `security.json`'s `candidates`. Each has
   `kind`, `check` (the manifest id), `file` (repo-relative), `line`, `text`,
   `rule`, `tag` (the scanner always emits one), `note`, and for
   `interpolation` also `attributes`, `guarded`, `presence_checked` and
   `quoted`. Go through the
   security checks in manifest order, and within each check through its
   candidates in file and line order:

   | Check | Candidate kinds |
   |---|---|
   | `sec-interpolation` | `interpolation`, `unquoted_expansion` |
   | `sec-eval-exec` | `eval_exec` |
   | `sec-credential-string` | `credential_string` |
   | `sec-permissive-mode` | `permission_change` |
   | `sec-network-call` | `network_call` |
   | `sec-file-write-outside-job` | `file_write_outside_job` |
   | `sec-config-flag` | `config_flag` |
   | `sec-binary-in-template` | `binary_in_template` |

   **Records: one record per file per tag.** Every finding record is keyed
   `{file}:{tag}`, and a key appears once per app. Candidates of one check
   that share a file and a tag share one record, whose `evidence` may carry
   several citations. FAIL and WARN candidates lead: `path:N,M` plus a short
   quote. PASS candidates in that file follow, after a semicolon, as
   `reviewed OK: path:N,M` (for example `template/script.sh.erb:22;
   reviewed OK: template/script.sh.erb:9,23`). A file whose candidates are
   all PASS gets one PASS record for the check, with `evidence` listing
   every PASS line in that file as `path:N,M`. **The record merge rule:**
   when several candidates merge into one record this way, the record's
   `result` is the worst among them (FAIL > WARN > PASS) and its `severity`
   the highest; the report's rows stay per candidate regardless — a row
   still answers each candidate on its own.

   The key's parts: `rule` is the candidate's `rule` (the manifest's when
   absent), and the tag is the candidate's `tag` — the scanner always emits
   one, so there is no no-tag fallback to apply. Each row answers exactly
   the candidate it cites (see Output for the row and citation form).

   For every candidate, decide FAIL, WARN or PASS and write one row with a
   one-line reason; never skip a candidate, and never merge two candidates
   into one row. Read the cited line in context before deciding:
   - An `interpolation` that is `guarded` and `quoted`, or whose value cannot
     reach a shell (a select whose options the app defines, a number field
     with bounds), is usually PASS; say which. An unguarded, unquoted value
     from a free-text field reaching a shell command is a finding.
     `presence_checked: true` is not a guard — a presence test only confirms
     a value was supplied, it does not sanitise it, so a candidate that is
     `presence_checked` but not `guarded` is judged the same as one with
     neither.
   - Batch Connect: compare against the narrow baseline. Network calls from
     ERB, SSH-key reads, base64-decode-and-execute, and writes to dotfiles or
     cron are strong signals and are FAIL. A `binary_in_template` candidate
     is always a finding (OODT-04, `binary-in-template`), and the file is also
     listed as unauditable.
   - Passenger: a capability in the rubric's "Flagged" column is a finding;
     one the app needs for its designed purpose is PASS, with the reason
     ("job composer: running sbatch is its purpose"). Never penalize an app
     for its designed purpose; running shell commands with CORS open to all
     origins is a finding.

   A check with no candidates has no row: Security rows are required only
   where `security.json` lists a candidate (`row_required: when_candidates`).
   If `security.json` is absent (the pre-review directory is absent, or
   `summary.json`'s `security` record says the app was skipped or failed),
   there are no candidate rows: say so in one line above the table
   ("Candidate enumeration not run: <reason>") and do the whole pattern
   table from the rubric in step 4.
4. **Tier 1 — Additional observations (review).** After the loop, read the
   in-scope files for anything the enumeration did not list: the rubric's
   capability baseline and pattern table (CSRF on state-changing endpoints,
   partial authentication coverage, disabled framework protections,
   container isolation, debug output, a network call or dotfile write the
   scanner missed). Record each as a finding under the vocabulary tag where
   one fits, else `other:{short-description}`, in the "Additional
   observations (review)" table, and say in its summary that `security.json`
   did not list it: that note is the signal for improving the scanner. An
   observation at a line a candidate already covers belongs in that
   candidate's row, not here.
5. **Tier 2 — Read the pre-review results.** The pre-review script has
   already rendered the Check tiers line and the tool-scan table into
   `<pre-review>/tool-table.md`. Paste that file's contents verbatim as the
   Check tiers line and the table; never retype, reorder, recount, or reword
   any of it. Then read `<pre-review>/summary.json` and each tool's JSON. A
   tool finding at a candidate's line is corroboration: cite the tool and
   finding ID in that row's summary (e.g., "bandit B602: subprocess with
   shell=True"). A tool finding at no candidate's line is an additional
   observation (step 4). Never run a tool, never ask to
   run one, never write "pending approval". If `tool-table.md` is absent,
   write the Check tiers line as `Tier 1 only` and the table with all four
   rows (shellcheck, semgrep, bandit, trivy) as
   `Not run (pre-review facts not found)` with Result `—`.
6. **Tier 3 — Runtime checks** (when the app is runnable). Where the app has a
   WSGI/Rack entry point (`passenger_wsgi.py`, `config.ru`), a test harness, or
   is otherwise runnable, exercise security-relevant paths rather than only
   reading source. Library defaults, framework middleware, and proxy assumptions
   are frequently invisible in source. If the app cannot be run (CI, no runtime
   environment), report tier 3 as `NOT CHECKED — no isolated execution environment`.
7. **Classify every row.** Every FAIL or WARN row and observation is
   classified under OODT-01..08 (the candidate's `rule` is the default; a
   `network_call` that exposes a service to other users is OODT-05 rather
   than OODT-04), rated Critical / High / Medium / Low per the rubric's
   "Rating findings" section and the scale in
   `${CLAUDE_PLUGIN_ROOT}/references/finding-codes.md`, and tagged
   unintentional or potentially malicious. A PASS row has severity `info`
   and `—` in the Tag column; its PASS record's `tag` field is
   `unintentional`, since the record schema requires one.
   Use the OODT mapping from the tool lookup table to classify
   tool-originated findings.
8. **Capability profile.** Last, summarize what the code does (system
   access, network calls, file reads and writes, spawned processes, dynamic
   code loading, authentication posture), drawing on the rows above. It is a
   summary for the reader and adds no findings: anything it would flag is
   already a row or an observation.

## Safe probing

A security review has broader-than-usual latitude to *read* and
narrower-than-usual latitude to *write*.

**Tier 3 execution environment.** The target app is untrusted code — a hostile
entry point (`config.ru`, `passenger_wsgi.py`, Gemfile hook) runs its payload on
boot, before any probe reaches the app. Do not run tier 3 on a reviewer's
workstation or any machine with access to real user data. Until a dedicated
review container exists (e.g., an OOD sandbox built from the ood-demo image),
tier 3 should run only inside a disposable VM or container with no network
egress and no mounted user filesystems. If no isolated environment is available,
report tier 3 as `NOT CHECKED — no isolated execution environment`.

Follow these rules for any runtime verification:

- **Never verify a filesystem finding against real user data.** Set
  `HOME` to a temporary directory for the duration of any probe. Everything
  needed to demonstrate a deny-list bypass (`.bashrc`, `.ssh/authorized_keys`)
  works identically against a synthetic home, and the probe becomes
  reproducible.
- **Probes must be reversible.** If a probe cannot be undone by deleting a temp
  directory, do not run it. Cleanup that depends on a later shell call is not
  reliable — a permission prompt, denied command, or killed agent leaves the
  side effect in place.
- **Prefer probes with no persistent effect.** A `curl` that reads a response
  header is better than one that writes a file.
- **Report unverified findings as unverified.** "Static reading suggests X; not
  exercised because it would require writing outside a sandbox" is a legitimate
  and useful finding. It is better than a confirmed finding that damaged the
  reviewer's environment.

## Output

- **Check tiers ran and tool scan summary** (required) — the contents of
  `<pre-review>/tool-table.md`, pasted verbatim: the Check tiers line, the
  tier 3 line, and the four-row Tool / Status / Result table. Never retype
  it. If the file is absent, write `**Check tiers:** Tier 1 only` and the
  table with every row `Not run (pre-review facts not found)` and Result
  `—`. Never omit the table — its absence is indistinguishable from a clean
  scan.

### Findings

- **Candidate rows**, one per `security.json` candidate, in the loop's
  order:

  | Rule | Check | Result | Severity | Tag | Summary | Evidence |
  |---|---|---|---|---|---|---|
  | OODT-01 | `check: sec-interpolation` | FAIL | medium | unintentional | `<%= jupyter_args %>` unquoted in the job script; a free-text value reaches the shell | template/script.sh.erb:12 |
  | OODT-04 | `check: sec-network-call` | PASS | info | — | `curl` to localhost health check; stays on the node | template/script.sh.erb:30 |

  The Check column holds exactly `` `check: <id>` `` with the manifest id.
  Result is exactly FAIL, WARN or PASS. Tag is the intent tag,
  *unintentional* or *potentially malicious*, on a FAIL or WARN row and `—`
  on a PASS row. Evidence cites the candidate
  as `path:N` (a range `path:N-M`, a list `path:N,M`), with the
  repo-relative path exactly as `security.json` gives it; never prose such
  as "line 12 of script.sh". A row answers exactly the candidates it cites.
- **Additional observations (review)**, a second table under that heading
  after the candidate rows, with the same columns minus Check (Rule / Result / Severity / Tag /
  Summary / Evidence), one row per step-4 observation, each summary saying
  that `security.json` did not list it. Write `No findings.` under the
  heading when the open-ended pass found nothing. When `security.json`
  lists no candidates and there are no observations, write the single line
  "security.json lists no candidates; no observations." in place of both
  tables.
- When no row or observation is FAIL or WARN, write exactly "No
  tool-detectable issues in the checked tiers." under the tables. Never
  write "safe".
- **Capability profile**, after the tables: a compact File / Capabilities
  / Anomalies table for Batch Connect apps; a short narrative for Passenger
  apps.
- **Structured findings** per target-setup.md §4. Each finding uses an OODT-XX
  rule code and a `defect_key` built as step 3 says, from the candidate and
  the manifest, or for an observation from the security mechanism-tag
  vocabulary in `${CLAUDE_PLUGIN_ROOT}/references/finding-codes.md`.
  Tool-corroborated findings include the tool name and finding ID in the
  `summary` field. Tag each finding in a `tag` field on the record, value
  `unintentional` or `potentially-malicious`, and repeat it in the report's
  Tag column, written as *potentially malicious* in the column.

No security rating or level, no decisions, no numeric risk scores.
