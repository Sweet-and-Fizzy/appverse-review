---
name: review-security
description: Security review of an AppVerse / Open OnDemand app repo — capability profile, unsafe-pattern checks, OODT threat classification. Use for the security aspect of an AppVerse review, or when asked to security-audit an OOD app.
argument-hint: "[github-url]"
---

# Security Review (aspect)

Rubric: `${CLAUDE_PLUGIN_ROOT}/references/security-rubric.md` — read it before
starting. It defines the capability baselines per app type, the pattern checks,
and the OODT (Open OnDemand App Threats) taxonomy. Expand OODT on first use in
the report, and never write it as "OAT" — that collides with OWASP's unrelated
Automated Threats catalog.

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first.

## Procedure

1. Determine each app's type (Batch Connect, Passenger, dashboard, widget) from
   its manifest `role` / declared `app_type` — the capability baseline differs.
2. Identify in-scope files. Batch Connect: `form.yml(.erb)`, `submit.yml.erb`,
   `template/**`, `connection.yml`, container definitions. Passenger: the full
   application source (routes, controllers, views, config, scripts). Always
   include `shared_paths`. List binary files that cannot be audited.
3. **Static analysis tool scan** — read the tool lookup table at
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
4. **Capability profile** — catalog what the code actually does: system access,
   network calls, file reads and writes, spawned processes, dynamic code loading,
   authentication posture.
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

## Output

- **Tool scan summary** — which tools were available and ran, which were not
  installed (with one-line install hint from the lookup table), and which had no
  applicable files. If no tools were available, a single line: "No static
  analysis tools detected — install suggestions listed below." followed by the
  relevant install hints for the file types found.
- The capability profile: a compact File / Capabilities / Anomalies table for
  Batch Connect apps; a short narrative for Passenger apps.
- Findings tables per target-setup.md §4, with two extra columns: OODT class and
  severity. Tool-corroborated findings include the tool name and finding ID in
  the Evidence column.

No decisions, no numeric risk scores.
