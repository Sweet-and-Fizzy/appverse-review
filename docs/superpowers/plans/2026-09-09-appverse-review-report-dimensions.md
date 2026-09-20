# AppVerse Review — Report Dimension Alignment (Plan A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Regenerate the AppVerse review report around the dimension spine — each app leads with Low/Medium/High signal levels, with the reviewer's recommendation kept distinct — and tighten the Draft-Feedback floor, all within the appverse-review repo.

**Architecture:** This is a prompt-engineering change to Markdown SKILL files, not application code. The four aspect skills already emit the ratings that map to signal levels (quality emits Documentation Minimal/Adequate/Strong/Exemplary and Portability Not/Partially/Portable; maintenance emits its signals; security emits capability-profile + findings-with-severity). The change is concentrated in the **orchestrator** (`skills/review-app/SKILL.md`): its synthesis template derives Low/Med/High from the ratings the aspects already produce (per the PUBLIC-SIGNALS derivation table), reorganizes the per-app report to lead with a Signals block, adds Header/Disclaimer/Findings-header, moves `shared_paths` into Security, and adds the Draft-Feedback inclusion floor. Aspect-skill edits are minimal (a `shared_paths`-scope note in security; a Low/Med/High cross-reference where a skill states its rating).

**Tech Stack:** Markdown SKILL files (LLM instructions). "Tests" are regeneration checks — run a review against a known repo and verify the output structure — not unit tests. There is no code to pytest.

## Global Constraints

- **Signal levels are Low / Medium / High** (verbatim). Low = good/low-concern (green); High = most concern (red). Never invert; never style High as a hazard. (Source: PUBLIC-SIGNALS.md.)
- **Signals do NOT gate; the decision rubric does.** The report shows signals AND a separate recommendation; a High signal never forces a reject.
- **Derivation table (verbatim, from PUBLIC-SIGNALS "Deriving the levels"):**
  - Security: no findings = Low; low-severity-only = Medium; any Medium or High finding = High.
  - Portability: Portable = Low; Partially portable = Medium; Not portable = High.
  - Documentation: Strong or Exemplary = Low; Adequate = Medium; Minimal = High.
  - Upkeep: active within 12mo + 2+ good-practice signals = Low; active within 12mo = Medium; inactive > 12mo = High.
- **Four signal dimensions:** Security, Portability, Documentation, Upkeep (repo-level). **Structure** is pass/fail gate criteria, not a level.
- **Report is the interim PDF/Markdown.** Tool version/commit is stamped into the header at run time (PDF-only; do NOT reference the unmerged D8-2788 `field_arv_tool_version`).
- **Preserve the existing "Derived-only rule"** in review-app (every feedback item must already be a finding).
- **No behavior change to the four aspect skills' core assessments** — only add the `shared_paths`-scope note and level cross-references. Level derivation happens in the orchestrator.
- Scope is Plan A only. Do NOT touch the checklist/rubric docs or any Drupal/DocSync code (that is Plan B).

---

### Task 1: Branch + baseline reference review

**Files:**
- Create: (none — setup)
- Baseline artifact: `/tmp/planA-baseline-review.md` (throwaway)

**Interfaces:**
- Produces: a feature branch `fix/report-dimension-alignment` off `origin/main`; a captured baseline review of a known repo to diff structure against after each later task.

- [ ] **Step 1: Create the feature branch off origin/main**

```bash
cd ~/Sites/connectci/appverse-review
git fetch origin --quiet
git switch -c fix/report-dimension-alignment origin/main
```

- [ ] **Step 2: Stage the approved spec onto the branch (it's currently untracked on main)**

```bash
git add docs/design/specs/2026-09-09-appverse-review-dimension-alignment-design.md
git add docs/superpowers/plans/2026-09-09-appverse-review-report-dimensions.md
git commit -m "docs: add dimension-alignment spec and Plan A"
```

- [ ] **Step 3: Capture a baseline of the CURRENT report structure**

There is a saved reference review already in the repo. Copy it as the pre-change baseline so later tasks can show the structural change:

```bash
cp reviews/review-fasrc-ood-sas.md /tmp/planA-baseline-review.md
grep -nE '^#{1,3} ' /tmp/planA-baseline-review.md
```

Expected: section headers showing the OLD structure (Repo-level required criteria, per-app Required criteria / Security / Quality, Maintenance signals, Overall recommendation) — i.e. NO leading Signals block, NO Header provenance/Disclaimer, security findings without a dedicated Findings header. This is the "before" you are changing.

- [ ] **Step 4: Commit (branch state only — nothing else to commit here)**

No commit needed; the branch and baseline file are the deliverable. Proceed.

---

### Task 2: Restructure the per-app report section around dimensions

**Files:**
- Modify: `skills/review-app/SKILL.md` — the "## 3. Synthesize the report" template (the fenced report skeleton around lines 48–148).

**Interfaces:**
- Consumes: the aspect skills' existing ratings (quality: Documentation Minimal/Adequate/Strong/Exemplary, Portability Not/Partially/Portable; maintenance: its signals; security: capability profile + findings with severity).
- Produces: the new per-app section layout — a leading Signals block (Low/Med/High) followed by dimension-organized detail subsections — plus a repo-level Upkeep signal and the derivation instruction. Later tasks add the Header/Findings-header (Task 3) and rework the recommendation (Task 4).

**Target per-app layout (Decision A + three subsections, agreed 2026-09-09):**
```
## App: <name> (<subpath>)
  ### Signals            ← Security / Portability / Documentation @ Low/Med/High + evidence phrase
  ### Structure          ← gate criteria (metadata, YAML validity, standard layout, no broken references), PASS/FAIL
  ### Security           ← detail behind the Security signal: check-tiers, tool table, capability profile, findings (Findings header added in Task 3)
  ### Portability        ← detail behind the Portability signal (moved out of the old ### Quality)
  ### Documentation      ← detail behind the Documentation signal (moved out of the old ### Quality)
  ### Code Quality       ← code-quality findings (feeds the decision rubric, NOT a signal dimension)
  **Per-app decision:** … ← PRESERVE this line (monorepo only); Task 4 rewords it. Do not delete it here.
```
The old `### Required criteria` table becomes `### Structure`. The old `### Quality` section SPLITS into three: `### Portability`, `### Documentation`, `### Code Quality`. Upkeep/Maintenance stays repo-level (unchanged section). **Monorepo:** each `## App:` gets its own Signals block; there is NO repo-level signal aggregate. Upkeep is the one repo-level signal.

- [ ] **Step 1: Structural expectation (the "test")**

A regenerated per-app section must contain, in order: `### Signals` (Security/Portability/Documentation each Low/Med/High + phrase), then `### Structure`, `### Security`, `### Portability`, `### Documentation`, `### Code Quality`. No `### Quality` umbrella and no `### Required criteria` heading remain. The recommendation does NOT appear inside the Signals block. A repo-level Upkeep signal row exists.

- [ ] **Step 2: Verify the current template lacks it**

Run: `grep -nE '### Signals|### Structure|### Portability|### Documentation|### Code Quality|Upkeep' skills/review-app/SKILL.md`
Expected: none present — the current template has `### Required criteria`, `### Security`, `### Quality`. Confirms the change.

- [ ] **Step 3: Add the per-app Signals block**

In the fenced skeleton, as the first subsection under `## App:`, insert:

```markdown
### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Security | Low / Medium / High | <one-line phrase from the security findings> |
| Portability | Low / Medium / High | <one-line phrase> |
| Documentation | Low / Medium / High | <one-line phrase> |

<!-- DERIVE the level from the aspect ratings, do not invent it:
     Security: no findings = Low; low-severity only = Medium; any Medium/High finding = High.
     Portability: Portable = Low; Partially portable = Medium; Not portable = High.
     Documentation: Strong/Exemplary = Low; Adequate = Medium; Minimal = High.
     Low = good/low-concern; High = most to read. Never invert; never style High as a hazard.
     Monorepo: one Signals block PER app. No repo-level signal aggregate. -->
```

- [ ] **Step 4: Rename `### Required criteria` → `### Structure`**

Change the heading `### Required criteria` to `### Structure`. Keep its PASS/FAIL table (metadata, YAML validity, standard layout, no broken references) as the gate criteria. (In Task 3 the `shared_paths` repo-level row moves to Security; the per-app Structure gates stay here.)

- [ ] **Step 5: Split `### Quality` into three subsections**

Replace the single `### Quality` section with three, in this order after `### Security`:

```markdown
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
```

Preserve the `**Per-app decision:**` line and its monorepo comment exactly where it was (end of the per-app section) — Task 4 rewords it.

- [ ] **Step 6: Add the repo-level Upkeep signal**

In the repo-level portion (near the existing repo-level criteria / maintenance), add:

```markdown
| Upkeep (repo-level) | Low / Medium / High | <one-line phrase> |
<!-- Upkeep: active within 12mo + 2+ good-practice signals = Low; active within 12mo = Medium; inactive > 12mo = High. -->
```

(The detailed Maintenance signals table stays as-is; Upkeep is its Low/Med/High summary.)

- [ ] **Step 7: Verify the new structure**

Run: `grep -nE '### Signals|### Structure|### Security|### Portability|### Documentation|### Code Quality|Upkeep|Never invert' skills/review-app/SKILL.md`
Expected: all six per-app subsection headings in order, the Upkeep row, the derivation comment. `grep -nE '### Required criteria|### Quality' skills/review-app/SKILL.md` should now return NOTHING.

- [ ] **Step 8: Commit**

```bash
git add skills/review-app/SKILL.md
git commit -m "feat: restructure per-app report around dimensions (signals + structure/security/portability/documentation/code-quality)"
```

---

### Task 3: Header (provenance + disclaimer) and Findings header

**Files:**
- Modify: `skills/review-app/SKILL.md` — top of the synthesis template (header block) and the security section.
- Modify: `skills/review-security/SKILL.md` — add a `Findings` header requirement to its output and move `shared_paths` to scope input.

**Interfaces:**
- Consumes: the Signals-block template from Task 2.
- Produces: report Header (reviewed-app commit + appverse-review tool version/commit stamped at run time + rubric link) and Disclaimer; an explicit `### Findings` header before the security findings table; `shared_paths` presented as Security scope input, not a repo-level required criterion.

- [ ] **Step 1: Write the structural expectation**

Regenerated report must have, at the top: a Header line with the reviewed commit AND an `appverse-review @ <version> (<commit>)` provenance string AND a rubric link; a Disclaimer line (plain no-warranty). Security section must have an explicit `### Findings` header. The repo-level required-criteria table must NOT list `shared_paths` (it moves to Security).

- [ ] **Step 2: Verify current state**

Run: `grep -nE 'shared_paths|Disclaimer|appverse-review @|### Findings' skills/review-app/SKILL.md skills/review-security/SKILL.md`
Expected: `shared_paths` currently appears as a repo-level required criterion in review-app; no Disclaimer, no provenance string, no explicit Findings header. Confirms the changes.

- [ ] **Step 3: Add Header + Disclaimer to the synthesis template**

In `skills/review-app/SKILL.md`, at the top of the report skeleton (after the `# Appverse Review: <repo>` title), add:

```markdown
**Reviewed:** `<full SHA>` (<commit date>) · **Reviewed with:** appverse-review @ <plugin version> (`<appverse-review HEAD short SHA, captured at run time>`) · **Rubric:** https://openondemand.connectci.org/appverse-security-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._
```

Add an instruction line just before the skeleton: "Capture the appverse-review plugin's own HEAD short-SHA at run time (e.g. `git -C ${CLAUDE_PLUGIN_ROOT} rev-parse --short HEAD`) for the provenance string; if unavailable, write `unknown`."

- [ ] **Step 4: Move shared_paths out of repo-required-criteria**

In `skills/review-app/SKILL.md`, remove the `shared_paths security review` row from the repo-level required-criteria table. In `skills/review-security/SKILL.md`, add to the setup/scope step: "If the app declares `shared_paths`, include those directories in the security review scope. `shared_paths` is scope input, not a pass/fail criterion."

- [ ] **Step 5: Add the Findings header to the security aspect output**

In `skills/review-security/SKILL.md` output section, ensure the findings table is preceded by an explicit `### Findings` (or `**Findings**`) header, separated from the capability-profile table.

- [ ] **Step 6: Verify**

Run: `grep -nE 'Disclaimer|appverse-review @|Reviewed with|### Findings|shared_paths' skills/review-app/SKILL.md skills/review-security/SKILL.md`
Expected: Disclaimer + provenance present in review-app; `shared_paths` no longer a repo-required-criteria row (now a security scope note in review-security); Findings header present in review-security.

- [ ] **Step 7: Commit**

```bash
git add skills/review-app/SKILL.md skills/review-security/SKILL.md
git commit -m "feat: add report header provenance, disclaimer, findings header; move shared_paths to security scope"
```

---

### Task 4: Recommendation kept separate from signals

**Files:**
- Modify: `skills/review-app/SKILL.md` — the "## Overall recommendation" section and the per-app decision line.

**Interfaces:**
- Consumes: the Signals block (Task 2) and Findings header (Task 3).
- Produces: report language that presents the recommendation as the reviewer's decision, explicitly distinct from the signals, with the decision-rubric framing (signals describe; the decision rubric decides).

- [ ] **Step 1: Structural expectation**

The report's recommendation section must state (in template guidance) that the recommendation is derived from criteria + finding properties (not from signal levels): a High signal does not force a reject; a fixable High-severity misconfig is request-changes; malicious/unfixable-security, duplicate, not-OOD, or abandoned/unmaintained are the reject triggers; below-target Documentation/Portability is accept-with-suggestions, not request-changes.

- [ ] **Step 2: Verify current state**

Run: `grep -nE 'signals|decision rubric|the display is not the decision|request changes|reject' skills/review-app/SKILL.md`
Expected: current recommendation section has decision guidance but no explicit "signals describe / recommendation decides" separation and no statement that signals don't gate. Confirms the change.

- [ ] **Step 3: Edit the recommendation section**

In `skills/review-app/SKILL.md` "## Overall recommendation", add a lead sentence: "The recommendation is the reviewer's decision, derived from the required (gate) criteria and finding properties — NOT from the signal levels. Signals describe the app for a deployer; they do not gate listing." Then state the decision rubric verbatim from the spec's three-legged model: Accept / Accept-with-suggestions (below-target docs/portability lives here) / Request-changes (missing fixable gate criterion; fixable High-severity security is here, not reject) / Reject (duplicate; no license; abandoned/unmaintained; not an OOD app; malicious or unfixable security finding).

- [ ] **Step 4: Verify**

Run: `grep -nE 'do not gate|abandoned|malicious|below-target|derived from' skills/review-app/SKILL.md`
Expected: the separation statement and all four decision outcomes with their triggers present.

- [ ] **Step 5: Commit**

```bash
git add skills/review-app/SKILL.md
git commit -m "feat: state recommendation as decision-rubric output, separate from signals"
```

---

### Task 5: Draft-Feedback inclusion floor

**Files:**
- Modify: `skills/review-app/SKILL.md` — the "## 4. Mode-specific ending" / Draft-feedback section (around lines 150–168).

**Interfaces:**
- Consumes: the findings tables produced by the aspects.
- Produces: a rule that genuine fix-items reach the Draft Feedback while Info-polish may be summarized; preserves the existing Derived-only rule.

- [ ] **Step 1: Structural expectation**

The Draft-feedback section must instruct: every finding at roughly Low severity and above, plus any failed gate criterion, should appear in the Draft Feedback; Info-level polish may be summarized or omitted. The existing "Derived-only rule" (feedback ⊆ findings) stays.

- [ ] **Step 2: Verify current state**

Run: `grep -nE 'Draft feedback|Derived-only|inclusion|Info-level|severity' skills/review-app/SKILL.md`
Expected: Derived-only rule present; no inclusion floor stating which findings must reach the feedback. Confirms the gap Bill flagged (ERB-empty-values omitted).

- [ ] **Step 3: Add the inclusion floor**

In the Draft-feedback guidance, add: "Inclusion floor: every finding at Low severity or above, and every failed required (gate) criterion, must be represented in the Draft Feedback. Info-level polish (e.g. an undocumented hex constant) may be summarized in one line or omitted. The feedback is a prioritized note, not a copy of the findings table — but it must not silently drop a real fix-item. (This complements the Derived-only rule: feedback ⊆ findings, and now fix-level findings ⊆ feedback.)"

- [ ] **Step 4: Verify**

Run: `grep -nE 'Inclusion floor|Low severity or above|prioritized note' skills/review-app/SKILL.md`
Expected: the floor present alongside the retained Derived-only rule.

- [ ] **Step 5: Commit**

```bash
git add skills/review-app/SKILL.md
git commit -m "feat: add Draft-Feedback inclusion floor so fix-items are not dropped"
```

---

### Task 6: Regeneration verification (the real end-to-end test)

**Files:**
- Create: `/tmp/planA-regen-review.md` (throwaway)

**Interfaces:**
- Consumes: all prior tasks (the edited skills).
- Produces: a freshly-regenerated review demonstrating the new structure end to end, and a structural diff against the Task-1 baseline.

- [ ] **Step 1: Regenerate a review with the edited skills**

Run the review-app skill against a known, already-reviewed repo (fasrc/ood-sas is the baseline; or re-run OOD-Dashboard). Use the same repo as the Task-1 baseline so the comparison is apples-to-apples. Save output to `/tmp/planA-regen-review.md`.

- [ ] **Step 2: Verify the new structure is present**

Run: `grep -nE 'Reviewed with: appverse-review @|Disclaimer|### Signals|Low|Medium|High|Upkeep|### Findings|do not gate' /tmp/planA-regen-review.md`
Expected: provenance line, disclaimer, a Signals block leading each app with Low/Med/High levels, an Upkeep signal, an explicit Findings header, and the signals-don't-gate recommendation language.

- [ ] **Step 3: Verify the derivation is correct on a known case**

Cross-check one dimension against the derivation table: e.g. if the app had "Partially portable" in the quality aspect, the Portability signal must read **Medium** (not Low/High). Confirms the orchestrator applied the table rather than inventing levels.

- [ ] **Step 4: Verify a fix-item reaches the Draft Feedback**

Confirm a Low+ finding that the OLD baseline omitted from Draft Feedback now appears (for fasrc/ood-sas, the "ERB handles missing/empty values" finding). Confirms Task 5.

- [ ] **Step 5: Structural diff against baseline (record the change for the eventual Bill reply)**

Run: `diff <(grep -E '^#{1,3} ' /tmp/planA-baseline-review.md) <(grep -E '^#{1,3} ' /tmp/planA-regen-review.md)`
Expected: the new structure (Signals-led, Findings header, provenance) vs the old (Required/Quality). Save this diff — it is what we show Bill.

- [ ] **Step 6: Commit the regenerated reference review into reviews/ as the new-structure exemplar**

```bash
cp /tmp/planA-regen-review.md reviews/review-fasrc-ood-sas-dimensions.md
git add reviews/review-fasrc-ood-sas-dimensions.md
git commit -m "docs: regenerated fasrc/ood-sas review under the new dimension structure"
```

---

## Self-Review

**Spec coverage (Plan A items):**
- Report redesign around dimensions → Tasks 2, 3, 4. ✓
- Low/Med/High vocabulary → Task 2 (derivation) + Global Constraints. ✓
- Draft-Feedback inclusion floor → Task 5. ✓
- Per-aspect level-derivation ripple → resolved to be orchestrator-side (Task 2 derives from existing aspect ratings), with the minimal aspect edits (shared_paths note, Findings header) in Task 3. ✓
- Bill A1 (disclaimer) → Task 3; A2 (shared_paths→security) → Task 3; A3 (Findings header) → Task 3; A4 (provenance header, PDF-only) → Task 3. ✓
- Recommendation separate from signals + decision rubric preserved → Task 4. ✓
- End-to-end verification + reference artifact for Bill → Task 6. ✓
- Plan B items (checklist split, rubric, Drupal) → correctly absent. ✓

**Placeholder scan:** No TBD/TODO; each edit step gives the actual Markdown to insert and the exact grep to verify. "Tests" are regeneration/grep checks, honestly labeled (no fake pytest). ✓

**Type/naming consistency:** "Signals" block, "Low / Medium / High", "Upkeep", "### Findings", "inclusion floor", branch `fix/report-dimension-alignment` used consistently across tasks. ✓

**Note on TDD adaptation:** this plan cannot use failing-unit-test-first because the deliverables are LLM instructions in Markdown. Each task's "test" is a structural grep of the edited skill and, in Task 6, a regenerated review checked against the derivation table and the baseline. This is the faithful analog of red→green for prompt edits.
