---
name: review-quality
description: Quality review of an Appverse app repo — documentation rating, configuration portability, code-quality checklist. Use for the quality aspect of an Appverse review, or when asked to assess an OOD app's documentation or code quality.
argument-hint: "[github-url]"
---

# Quality Review (aspect)

Criteria: `${CLAUDE_PLUGIN_ROOT}/references/review-rubric.md` — sections
"Portability", "Documentation", and "Code Quality", including the
target-for-inclusion thresholds and the named checks (`check: …`) in each.
Run every named check in those sections and record a finding for each one
that fails, with `file:line` evidence.

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first.

## Per-app assessment

- **Documentation**: rate Minimal / Adequate / Strong / Exemplary against the
  rubric's Documentation table and its four README questions (what does it
  launch, what must be installed, how to deploy, what to customize). One-line
  justification citing README sections present or missing. Before rating,
  write one evidence line per rung requirement (installation, configuration,
  known limitations, troubleshooting, screenshots, environment variables,
  info panel, architecture) naming the README section and line that satisfies
  it, or "none". A heading whose body is the README template's placeholder
  text counts as none. The rating is the highest rung whose requirements all
  have evidence; never claim a rung with a "none" line. Flag as QUA-01 a
  README that references another institution's paths, cluster names, or
  module names without saying they must change.
- **Configuration portability**: rate Not portable / Partially portable /
  Portable. Look for hardcoded cluster names, partitions, accounts, absolute
  site paths, and module versions in `submit.yml.erb`, `form.yml`,
  `form.yml.erb`, and `template/` scripts. Site-specific values documented in
  the README's configuration table count toward Partially portable;
  undocumented ones count against it.
- **Code quality** checkboxes, each with evidence: error handling (`set -e` or
  explicit checks), form input validation (min/max/required), no uncommented
  magic numbers / undocumented literals, no large duplicated blocks, no
  commented-out dead code, ERB templates handle missing or empty values
  gracefully. Record each as its own rule: QUA-03 error handling, QUA-07 input
  validation, QUA-08 magic numbers, QUA-09 duplicated blocks, QUA-04 dead code,
  QUA-10 ERB missing/empty values (codes in finding-codes.md). Every checkbox
  and named check gets a result row even when clean (PASS with evidence) or
  unexaminable (NOT CHECKED with the reason). An unmet target for inclusion —
  error handling, input validation — is recorded as FAIL, not WARN;
  suggestions that are unmet are WARN. The rubric's
  Code Quality section says which of these are
  targets for inclusion and which are improvement suggestions — weight each
  finding the way the rubric frames it, rather than applying your own
  severity scale, and keep the labels consistent with findings you record
  elsewhere in the review.

  **Magic numbers / undocumented literals** — look beyond classic bare integers.
  In OOD apps, undocumented hardcoded values commonly appear as:
  - Resource limits and tunables: OOM score adjustments, timeouts, memory
    limits, CPU counts (e.g., `echo 1000 > /proc/self/oom_score_adj`)
  - UI/desktop config: hex colors, resolution strings, panel sizes in Xfce/VNC
    configs
  - Ports and network addresses (especially when not the obvious default)
  - Module versions without a comment explaining why that version
  - Scheduler parameters: partition names, QOS values, walltime limits

  A hardcoded value is fine when it is the obvious default or is explained by
  its context (a `sleep 1` needs no comment). Flag values that a deployer at
  another site would need to understand or change, and that have no inline
  comment or README documentation explaining them.
- **Correctness & polish**: discrete defects that are not one of the fixed
  checkboxes above but are still worth fixing — copy-paste artifacts from a
  template the app was cloned from (e.g. a MATLAB reference left in a SAS app's
  `form.yml`, a CHANGELOG describing a different app), duplicate YAML keys
  (valid YAML but last-wins, so `form.yml`/`manifest.yml` parsing does not catch
  them), broken or wrong help text, and README typos. Record each as its own
  finding with `file:line` evidence before it is summarized anywhere.

## Output

Per app: the two ratings with one-line justifications, then **structured
findings** per target-setup.md §4 covering both the code-quality checkboxes and
the correctness-&-polish defects. Each finding uses a QUA-XX rule code and a
`defect_key` from the quality mechanism-tag vocabulary in
`${CLAUDE_PLUGIN_ROOT}/references/finding-codes.md`.

Result values are exactly FAIL, WARN, PASS, NOT CHECKED; "Info" is a severity, never a result.

Note which target-for-inclusion thresholds (Adequate+ docs, Partially portable+)
are not met — as findings (QUA-01 / QUA-02), not decisions.
