---
name: review-security
description: Security review of an AppVerse / Open OnDemand app repo — capability profile, unsafe-pattern checks, OAT threat classification. Use for the security aspect of an AppVerse review, or when asked to security-audit an OOD app.
argument-hint: "[github-url]"
---

# Security Review (aspect)

Rubric: `${CLAUDE_PLUGIN_ROOT}/references/security-rubric.md` — read it before
starting. It defines the capability baselines per app type, the pattern checks,
and the OAT threat taxonomy.

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first.

## Procedure

1. Determine each app's type (Batch Connect, Passenger, dashboard, widget) from
   its manifest `role` / declared `app_type` — the capability baseline differs.
2. Identify in-scope files. Batch Connect: `form.yml(.erb)`, `submit.yml.erb`,
   `template/**`, `connection.yml`, container definitions. Passenger: the full
   application source (routes, controllers, views, config, scripts). Always
   include `shared_paths`. List binary files that cannot be audited.
3. **Capability profile** — catalog what the code actually does: system access,
   network calls, file reads and writes, spawned processes, dynamic code loading,
   authentication posture.
   - Batch Connect: compare against the narrow baseline; anomalies (network calls
     from ERB, SSH-key reads, base64-decode-and-execute, writes to dotfiles or
     cron) are strong signals — flag each as a finding.
   - Passenger: report the full profile for transparency; flag only capabilities
     in the rubric's "Flagged" column. Never penalize an app for its designed
     purpose — a job composer running shell commands is its job; running them
     with CORS open to all origins is a finding.
4. **Pattern checks** — apply the rubric's pattern table across all in-scope
   files.
5. Classify every finding under OAT-01..08, rate severity High / Medium / Low,
   and tag it unintentional or potentially malicious, per the rubric's "Rating
   findings" section.

## Output

- The capability profile: a compact File / Capabilities / Anomalies table for
  Batch Connect apps; a short narrative for Passenger apps.
- Findings tables per target-setup.md §4, with two extra columns: OAT class and
  severity.

No decisions, no numeric risk scores.
