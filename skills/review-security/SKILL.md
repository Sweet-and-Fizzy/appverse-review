---
name: review-security
description: Security review of an Appverse / Open OnDemand app repo — capability profile, unsafe-pattern checks, OODT threat classification. Use for the security aspect of an Appverse review, or when asked to security-audit an OOD app.
argument-hint: "[github-url]"
---

# Security Review (aspect)

Rubric: `${CLAUDE_PLUGIN_ROOT}/references/security-rubric.md` — read it before
starting. It defines the capability baselines per app type, the pattern checks,
and the OODT (Open OnDemand App Threats) taxonomy. Expand OODT on first use in
the report and link it to the published rubric at
https://openondemand.connectci.org/appverse-security-rubric so readers can look
up a code.

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first.

## Check tiers

The security review consists of three tiers, distinguished by what they require:

- **Tier 1 — Static.** Source-level analysis: structure, capability profile,
  pattern checks. Runs anywhere, including CI on a submitted PR.
- **Tier 2 — Tooling.** Static analysis tools (shellcheck, bandit, semgrep,
  trivy, etc.). Needs installed binaries, no running app. Well suited to CI.
- **Tier 3 — Runtime.** Boot the app and exercise it. Realistically local or on
  a reviewer's machine.

The report must state which tiers ran. A CI invocation that runs tiers 1–2
reports tier 3 as `NOT CHECKED — requires a running app`. A thinner review
should look thinner, not identical to a full one.

## Procedure

1. Determine each app's type (Batch Connect, Passenger, dashboard, widget) from
   its manifest `role` / declared `app_type` — the capability baseline differs.
2. Identify in-scope files. Batch Connect: `form.yml(.erb)`, `submit.yml.erb`,
   `template/**`, `connection.yml`, container definitions. Passenger: the full
   application source (routes, controllers, views, config, scripts). Always
   include `shared_paths`. List binary files that cannot be audited.
3. **Tier 2 — Static analysis tool scan.** Read the tool lookup table at
   `${CLAUDE_PLUGIN_ROOT}/references/security-tools.md` and run available tools
   against the in-scope files. This step is **optional and best-effort**: the
   review proceeds normally if no tools are installed.
   1. Detect which file types exist in the in-scope files (`.sh`/`.sh.erb`,
      `.py`, `.rb`/`.erb`, `package.json`, `requirements.txt`, container defs).
   2. For each relevant tool (per the lookup table's file-pattern-to-tool
      mapping), run the detect command (`command -v <tool>`).
   3. Run each available tool using the commands in the lookup table. For
      `.sh.erb` files, apply the ERB preprocessing step before running
      shellcheck.
   4. Collect tool output for use in steps 4–6. Do not block on tool failures —
      if a tool errors, note the error and continue.
   5. Record the status of every relevant tool for the tool-scan summary.
4. **Tier 1 — Capability profile.** Catalog what the code actually does: system
   access, network calls, file reads and writes, spawned processes, dynamic code
   loading, authentication posture.
   - Batch Connect: compare against the narrow baseline; anomalies (network calls
     from ERB, SSH-key reads, base64-decode-and-execute, writes to dotfiles or
     cron) are strong signals — flag each as a finding.
   - Passenger: report the full profile for transparency; flag only capabilities
     in the rubric's "Flagged" column. Never penalize an app for its designed
     purpose — a job composer running shell commands is its job; running them
     with CORS open to all origins is a finding.
5. **Pattern checks** — apply the rubric's pattern table across all in-scope
   files. Where a tool finding from step 3 confirms or adds to a manual finding,
   cite the tool as corroborating evidence (e.g., "bandit B602: subprocess with
   shell=True"). Where a tool surfaces something the manual scan missed, add it.
6. Classify every finding under OODT-01..08, rate severity High / Medium / Low,
   and tag it unintentional or potentially malicious, per the rubric's "Rating
   findings" section. Use the OODT mapping from the tool lookup table to classify
   tool-originated findings.
7. **Tier 3 — Runtime checks** (when the app is runnable). Where the app has a
   `config.ru` (Passenger), a test harness, or is otherwise runnable, exercise
   security-relevant paths rather than only reading source. Library defaults,
   framework middleware, and proxy assumptions are frequently invisible in source.
   If the app cannot be run (CI, no runtime environment), report tier 3 as
   `NOT CHECKED — requires a running app`.

## Safe probing

A security review has broader-than-usual latitude to *read* and
narrower-than-usual latitude to *write*. Follow these rules for any runtime
verification:

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
  tier 3 not checked — requires a running app").
- **Tool scan summary** (required) — a table with one row per relevant tool.
  A reader must be able to distinguish "clean scan" from "scanner not installed":

  | Tool | Status | Result |
  |---|---|---|
  | shellcheck | ran | 2 findings (SC2086, SC2046) |
  | semgrep | **not installed** | `pip install semgrep` |
  | trivy | no applicable files | — |
  | bandit | ran | clean |

  If no tools were available, use the table with all rows showing "not installed"
  plus install hints. Never omit the table — its absence is indistinguishable
  from a clean scan.
- The capability profile: a compact File / Capabilities / Anomalies table for
  Batch Connect apps; a short narrative for Passenger apps.
- Findings tables per target-setup.md §4, with two extra columns: OODT class and
  severity. Tool-corroborated findings include the tool name and finding ID in
  the Evidence column.

No decisions, no numeric risk scores.
