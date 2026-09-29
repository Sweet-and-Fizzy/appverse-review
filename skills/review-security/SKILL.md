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

- **Tier 1 — Static.** Source-level analysis: structure, capability profile,
  pattern checks. Runs anywhere, including CI on a submitted PR.
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

1. Determine each app's type (Batch Connect, Passenger, dashboard, widget) from
   its manifest `role` / declared `app_type` — the capability baseline differs.
2. Identify in-scope files. Batch Connect: `form.yml(.erb)`, `submit.yml.erb`,
   `template/**`, `connection.yml`, container definitions. Passenger: the full
   application source (routes, controllers, views, config, scripts). Always
   include `shared_paths`. List binary files that cannot be audited.
   If the app declares `shared_paths`, include those directories in the
   security review scope. `shared_paths` is scope input, not a pass/fail
   criterion.
3. **Tier 1 — Capability profile.** Catalog what the code actually does: system
   access, network calls, file reads and writes, spawned processes, dynamic code
   loading, authentication posture.
   - Batch Connect: compare against the narrow baseline; anomalies (network calls
     from ERB, SSH-key reads, base64-decode-and-execute, writes to dotfiles or
     cron) are strong signals — flag each as a finding. Record any binary file
     under `template/` as a finding (OODT-04, tag `binary-in-template`) in
     addition to listing it as unauditable.
   - Passenger: report the full profile for transparency; flag only capabilities
     in the rubric's "Flagged" column. Never penalize an app for its designed
     purpose — a job composer running shell commands is its job; running them
     with CORS open to all origins is a finding.
4. **Tier 1 — Pattern checks.** Apply the rubric's pattern table across all
   in-scope files. Where a tool finding from step 5 confirms or adds to a manual
   finding, cite the tool as corroborating evidence (e.g., "bandit B602:
   subprocess with shell=True"). Where a tool surfaces something the manual scan
   missed, add it.
5. **Tier 2 — Read the pre-review results.** Read `<pre-review>/summary.json`.
   Render the tool-scan summary from it: one row per check except `syntax` and
   `catalog`; Status is `Run` for `ran` (shellcheck: `Run (ERB-stripped)`
   when its `note` says `.sh.erb file(s) scanned ERB-stripped`),
   `Not run (not installed)` for `not_installed`, `Not run (failed)` for `failed_to_run`, and
   `Not run (<note>)` for `skipped`. Result is rendered verbatim from the
   record's `finding_count` and `top_codes`, never counted or computed by
   you: `—` when `finding_count` is null (the tool did not run), `0 findings`
   when it is 0, otherwise `<finding_count> findings (<top_codes joined with
   ", ">)` (`1 finding (...)` for one). Install hints and notes never go in
   the Result column. Then read each tool's JSON and treat its findings exactly as
   before: corroboration for a step-4 finding, or a new finding classified
   under OODT. Never run a tool, never ask to run one, never write "pending
   approval". If the pre-review directory is missing, every row is
   `Not run (pre-review facts not found)` and tier 2 is reported as not run.
6. **Tier 3 — Runtime checks** (when the app is runnable). Where the app has a
   WSGI/Rack entry point (`passenger_wsgi.py`, `config.ru`), a test harness, or
   is otherwise runnable, exercise security-relevant paths rather than only
   reading source. Library defaults, framework middleware, and proxy assumptions
   are frequently invisible in source. If the app cannot be run (CI, no runtime
   environment), report tier 3 as `NOT CHECKED — no isolated execution environment`.
7. **Classify all findings.** After all tiers have run, classify every finding
   under OODT-01..08, rate severity
   Critical / High / Medium / Low per the rubric's "Rating findings" section
   and the scale in `${CLAUDE_PLUGIN_ROOT}/references/finding-codes.md`, and
   tag it unintentional or potentially malicious. Use the OODT mapping from
   the tool lookup table to classify tool-originated findings.

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

- **Check tiers ran** — state which tiers were executed (e.g., "Tiers 1–2;
  tier 3 not checked — no isolated execution environment"). Tier 2 counts as
  run only if at least one tool in `summary.json` has status `ran`.
- **Tool scan summary** (required) — a table with one row per relevant tool.
  A reader must be able to distinguish "clean scan" from "scanner not installed":

  | Tool | Status | Result |
  |---|---|---|
  | shellcheck | Run (ERB-stripped) | 2 findings (SC2164, SC2148) |
  | semgrep | Not run (not installed) | — |
  | bandit | Run | 0 findings |
  | trivy | Not run (no applicable files) | — |

  If no tools were available, use the table with every row showing
  `Not run (not installed)` and Result `—`. Never omit the table — its
  absence is indistinguishable from a clean scan.
- The capability profile: a compact File / Capabilities / Anomalies table for
  Batch Connect apps; a short narrative for Passenger apps.

### Findings

- **Structured findings** per target-setup.md §4. Each finding uses an OODT-XX
  rule code and a `defect_key` from the security mechanism-tag vocabulary in
  `${CLAUDE_PLUGIN_ROOT}/references/finding-codes.md`. Tool-corroborated
  findings include the tool name and finding ID in the `summary` field. Tag each
  finding in a `tag` field on the record, value `unintentional` or
  `potentially-malicious`, and repeat it in the report's Tag column, written
  as *potentially malicious* in the column.

No decisions, no numeric risk scores.
