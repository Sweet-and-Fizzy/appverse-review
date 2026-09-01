---
name: review-quality
description: Quality review of an Appverse app repo — documentation rating, configuration portability, code-quality checklist. Use for the quality aspect of an Appverse review, or when asked to assess an OOD app's documentation or code quality.
argument-hint: "[github-url]"
---

# Quality Review (aspect)

Criteria: `${CLAUDE_PLUGIN_ROOT}/references/review-checklist.md` — section
"Quality Criteria" (Documentation Quality, Configuration Portability, Code
Quality), including the target-for-inclusion thresholds.

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first.

## Per-app assessment

- **Documentation**: rate Minimal / Adequate / Strong / Exemplary against the
  checklist's documentation table and its four README questions (what does it
  launch, what must be installed, how to deploy, what to customize). One-line
  justification citing README sections present or missing.
- **Configuration portability**: rate Not portable / Partially portable /
  Portable. Look for hardcoded cluster names, partitions, accounts, absolute
  site paths, and module versions in `submit.yml.erb`, `form.yml`, and
  `template/` scripts.
- **Code quality** checkboxes, each with evidence: error handling (`set -e` or
  explicit checks), form input validation (min/max/required), no uncommented
  magic numbers / undocumented literals, no large duplicated blocks, no
  commented-out dead code, ERB templates handle missing or empty values
  gracefully. The checklist's Code Quality section says which of these are
  targets for inclusion and which are improvement suggestions — weight each
  finding the way the checklist frames it, rather than applying your own
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

Note which target-for-inclusion thresholds (Adequate+ docs, Partially portable+)
are not met — as findings (QUA-01 / QUA-02), not decisions.
