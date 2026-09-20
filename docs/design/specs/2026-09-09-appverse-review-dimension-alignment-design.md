# AppVerse Review — dimension alignment (report, checklist, skill)

**Date:** 2026-09-09
**Status:** Design — approved, revised after adversarial review, pre-plan
**Repos:** appverse-review (primary) + cyberteam_drupal (Plan B publish/referrer changes)

## Why

Bill Horka reviewed the current PDF report and the reviewer checklist against each other and found real inconsistencies: the same topic (Documentation) classified two ways, Security fitting neither "Required" nor "Quality," and "Quality" criteria that secretly carry hard accept gates. Root cause: the checklist's two-bucket **Required vs Quality** scheme conflates two independent axes — *is it a gate?* and *what dimension is it?*

The review-system planning already resolved this by organizing around **dimensions**: hard pass/fail criteria plus per-dimension signals, with the reviewer's decision as a separate thing. The entity model (Jira **D8-2788**, branch `D8-2788|appverse-review-config`, not yet merged) and PUBLIC-SIGNALS.md use that spine. This spec brings the two interim artifacts — the generated report and the reviewer checklist — onto the same spine, plus small skill tweaks.

**Framing (corrected after review): the content is portal-durable; only the PDF rendering is interim.** PUBLIC-SIGNALS is explicit that the four-skill output is unchanged and the portal is "a presentation layer over the existing output." So the dimension spine, the derivation rules, the Process/Rubric docs, and the enumerated checks are the *content layer the portal will render* — worth doing right. The only genuinely throwaway artifact is the PDF rendering itself. Do not under-invest in the content because "it's interim"; do keep the PDF rendering cheap.

## The three-legged model (the spine — shared vocabulary, all artifacts use it verbatim)

The review has **three** kinds of content, not two. The original spec dropped the third; this is the central correction.

1. **Gate criteria (pass/fail).** Hard requirements an app must meet to list. These live primarily in the **Structure** dimension (license, README present, YAML validity, standard layout, scripts parse via `bash -n`) — but gates are NOT only structural (see the decision rubric below).

2. **Descriptive signals (Low / Medium / High concern).** Per-dimension heat-map for a deployer, NOT a gate. Four signal dimensions:
   - **Security** — signal + findings.
   - **Portability** — signal.
   - **Documentation** — signal.
   - **Upkeep** (maintenance) — signal, repo-level.
   Levels are **Low = good end** (green, nothing to read), **High = most concern** (red, read before deploying). Derivation per PUBLIC-SIGNALS "Deriving the levels": Security — no findings=Low, low-severity-only=Medium, any Med/High=High; Portability — Portable=Low, Partially=Medium, Not=High; Documentation — Strong/Exemplary=Low, Adequate=Medium, Minimal=High; Upkeep — active+2 good-practice signals=Low, active=Medium, inactive>12mo=High.
   Note the concern-polarity caveat: "High" reads intuitively as bad for Security/Upkeep but can misread as *good* on Documentation/Portability (which are quality scales relabeled as inverted concern). The docs must state Low=good/High=concern explicitly on every axis, and never style High as a hazard (per PUBLIC-SIGNALS "Red is not a warning").

3. **Decision rubric (accept / accept-with-suggestions / request-changes / reject).** The reviewer's decision, derived from **criteria + finding properties**, orthogonal to the concern signals. This is the old checklist Step 3 table, preserved verbatim — NOT dropped. All five reject triggers and the accept-boundary rule are carried through:
   - **Reject:** duplicate app; no license; **abandoned/unmaintained**; not an OOD app; a security finding tagged **potentially malicious or unfixable-without-redesign**.
   - **Request changes:** missing a required gate criterion but fixable. A *fixable* security misconfiguration, even High severity (e.g. CORS-open), is request-changes, NOT reject.
   - **Accept with suggestions:** required criteria pass but there are clear improvement areas — and critically, **below-target Documentation or Portability belongs HERE, not in Request-changes.** This is the operationalized answer to Bill's "are quality criteria secretly gates?" — no: a Medium/High Documentation or Portability *signal* does not gate; only a failed *criterion* does.
   - **Accept:** passes all required criteria, adequate+ docs, partially-portable+ config — always conditional on the duplicate/catalog checks the tool can't perform.
   Two consequences for the spine: (a) a security finding's *maliciousness/fixability* is a reject-trigger that is a **property of a finding**, not a signal level — so Security is both a signal axis AND a source of gate-triggering findings; (b) **Upkeep likewise has a decision role** — "abandoned/unmaintained" is a reject, so Upkeep is a signal axis whose extreme also feeds the decision rubric. Neither is "just a signal."
   **Signals do not gate; the decision rubric does.** PUBLIC-SIGNALS keeps these separate ("the display is not the decision", lines 169-171) — the decision rules persist ALONGSIDE the signals. (This corrects the original spec, which wrongly told Bill his decision-rule framing was superseded; it is not — Bill was describing the decision rubric, which is still live.)

**Code Quality** (error handling, input validation, magic numbers, dead code, duplication) is its own set of findings that feed (a) the decision rubric where the checklist sets a hard target ("at least error handling and input validation") and (b) are reported as findings. It is not one of the four signal dimensions and is not a Structure gate; it is a findings category consumed by the decision rubric. The docs must give it an explicit home rather than leaving it stranded (Bill's sharpest "secret gate" instance).

**README note:** "README present/substantive" is a Structure *gate* (a stub fails); "README depth" (Minimal/Adequate/Strong/Exemplary) is the Documentation *signal*. Same artifact, two roles — but on two different legs (gate vs signal), which is legitimate and must be stated so it doesn't re-create Bill's double-classification complaint.

## Scope — split into two plans

The four changes share a *vocabulary* (the spine), not a *deliverable*. They are differently coupled, so they become two plans:

### Plan A — report + vocabulary + Draft-Feedback (pure appverse-review, no Drupal)
1. **Report redesign** on the spine (below).
2. **Low/Med/High vocabulary** across the report + skills.
3. **Draft-Feedback inclusion floor** (3a below).
4. **Per-aspect level-derivation ripple** — real work, enumerated: each aspect skill (or the orchestrator) must emit or enable derivation of the dimension level. Today `review-quality` emits "Documentation: Strong/Adequate/…" and "Portability: Portable/…"; the orchestrator applies the PUBLIC-SIGNALS table to produce Low/Med/High. `shared_paths` moves from Structure into Security as scope input (Bill A2) — a behavior change in the structure+security aspects. These are edits across `review-app` + the four aspect SKILLs, not one template edit.

Ships independently. **Sequencing caveat:** if A ships before B, the live checklist still uses Required/Quality while the new report uses dimensions — transiently inconsistent (an inverted version of Bill's complaint). So land B-then-A or both together; A-alone is acceptable only briefly.

### Plan B — checklist split + rubric + Drupal (cross-repo lockstep unit)
1. **Checklist split:** `review-checklist.md` → **Reviewer Process** doc, reordered to work-order (gate the app → open report → verify → curate → decide). Criteria definitions move out to the Rubric.
2. **General Rubric:** repurpose `security-rubric.md`'s content into a general Review Rubric on the spine (Structure gates, four signal dimensions with derivation, Code Quality findings, and the decision rubric). Security stays the deepest section (genuinely — don't force parity).
3. **Enumerated named-checks (3b)** in the Rubric — see 3b for the mechanism requirement.
4. **Drupal / cross-repo (first-class, not deferred):**
   - The general Rubric publishes to a **new slug `/appverse-review-rubric`** (new Drupal node + alias), with **`/appverse-security-rubric` redirecting** to it. (Decision made: correct-facing over stable-but-stale.)
   - `DocSyncService.php` map: keep `review-checklist.md`→11932 (now the Process doc); add a **new entry** for the general-rubric source file → new node. Note the map key is the full raw-GitHub URL incl. filename, so this is a real code edit in cyberteam_drupal.
   - **Timing hazard:** DocSync pulls `main` on a schedule. The moment Plan B merges, the next sync overwrites node content automatically — so the redirect + new node must be in place *before or with* the merge, not after. This window is not deferrable.
   - **Referrer inventory (complete):** `review-security/SKILL.md:13` (links security-rubric URL); `review-checklist.md:5` and `:157` (inside the file being repurposed); the report header's rubric link (Plan A); Process↔Rubric cross-links; and **`cyberteam_drupal` `views.view.my_appverse.yml:693`** hardcodes `/appverse-reviewer-checklist` in view config. Every one updated as part of Plan B.

### Out of scope / deferred
- Per-app Upkeep for monorepos — D8-2841 (portal-era).
- 6-month re-flag — scheduled query once reviews are Drupal entities; no interim action.
- PUBLIC-SIGNALS terminology — already updated (committed `faccb6b`).
- The appverse_review entity model / field_arv_tool_version — Jira D8-2788, separate, unmerged.

## Report structure (Plan A)

Per app: **Header** (provenance: reviewed-app commit + appverse-review tool version/commit **stamped into the PDF at run time** — PDF-only for now, no dependency on the unmerged D8-2788 field; note D8-2788 will carry it durably later) · **Disclaimer** (plain no-warranty/advisory; not OSS-license indemnification; lawyer input before anything stronger) · **Repo-level** (Structure criteria pass/fail; repo-level Upkeep signal) · then per app: **Signals** block first (Security/Portability/Documentation Low/Med/High + evidence phrase) · **Structure criteria** pass/fail (`shared_paths` now Security scope input, not a repo criterion) · **Findings** under an explicit header, by aspect, severity + evidence · **Code Quality** findings · **Recommendation** (the decision, via the decision rubric, explicitly separate from the signals) · **Review scope / not-checked** · **Draft feedback**.

This absorbs Bill A1–A4.

## Skill tweaks

**3a. Draft-Feedback inclusion floor** (`review-app/SKILL.md`): the feedback is the reviewer's prioritized note, not a table dump — but genuine fix-items (roughly Low severity and above, plus any failed gate criterion) should appear; Info-level polish may be summarized/omitted. Keeps the existing "Derived-only rule." (Bill D1 — the omitted ERB-empty-values would clear this floor; magic-numbers may be summarized.) Interim pressure eases once the portal shows the contributor the full report.

**3b. Enumerated named-checks** in the general Rubric (Plan B). Short, not exhaustive; grow as patterns recur. Starting set: desktop/panel icon references match target OS (structure/quality); numeric form-field bounds (quality); hardcoded scratch/cluster/partition paths (portability). **Mechanism (verified):** every aspect skill already reads a `references/` criteria file via `${CLAUDE_PLUGIN_ROOT}/references/…` — `review-structure`/`review-quality`/`review-maintenance` each already read `review-checklist.md` (SKILL.md:9), and `review-security` reads `security-rubric.md`. So external-rubric reference is the existing pattern, not a new mechanism. The Plan-B split naturally re-homes each aspect skill onto the general Rubric as its criteria source; the enumerated cross-dimension checks live in that Rubric, and each check lands in the section the relevant aspect skill reads (structure/quality checks in the general-rubric sections those skills consume; security checks in the security section). This is a consequence of the split's re-pointing, not extra standalone work.

## D2 — dropped-findings-between-runs (context, not a new build)

Bill saw a finding present in review 1, absent in review 2. This is addressed by the re-review flow, which **is built**: stable finding IDs (PRs #37/#38 merged to appverse-review `main` — `finding-codes.md`, `compute-ids.py`, `assemble-artifact.py`) plus the skill's reconciliation instruction (`review-app/SKILL.md:38`: "if a previous review is available, treat its findings as prior context"). It works **when the prior review is supplied to the run** — demonstrated manually on the OOD-Dashboard re-review (2026-09-09), where prior findings were fed in and each verified fixed/present. What is NOT yet automated is *auto-locating* the prior artifact; a human/orchestrator supplies it. So D2 is a capability that exists, not an unbuilt system (the planning `ARTIFACT-SCHEMA.md` "not built" language is stale vs. the merged code — see the cleanup TODO). 3b (rubric enumeration) is the complementary answer for *first*-pass recall where there is no prior review. Route Bill's "enumerate in the rubric?" to 3b; route "why did it drop?" to the re-review flow.

## What to flag back to Bill (context, not fixes — SHOW via the regenerated review, don't just assert)

- **Signals don't gate, but the decision rubric does** — his High→request-changes / Critical→reject framing is CORRECT and preserved (the decision rubric); it is not superseded. (Original spec got this wrong.)
- **appverse.yml optional-if-manifest** — docs are already correct; `isEmptyRepo()` = neither present. Clarify; his confusion traces to the HiGlass had-neither case.
- **Dropped findings** — handled by the re-review flow when the prior review is supplied (see D2); rubric enumeration (3b) firms first-pass recall.
- Terms are Low/Med/High.
The reply comes AFTER a regenerated reference review exists, so we respond with a better artifact + a note on what changed, and can point at the decision rubric actually working rather than asserting his concern is stale.

## Success criteria

- Report + Process doc + Rubric doc use the one spine and Low/Med/High; no Required-vs-Quality bucketing remains (only fully true when Plan A + Plan B both land — hence the sequencing caveat).
- The three legs are all present in the docs: gate criteria, signals with derivation, AND the decision rubric (incl. malicious/duplicate/not-OOD reject triggers and the Code-Quality target).
- Bill A1–A4 reflected in the regenerated report (checked against the bucket-A list in the dispositions notes, which is the source of truth for "bucket A").
- Plan B: general rubric at `/appverse-review-rubric` with redirect from the old slug; DocSync map updated; ALL referrers in both repos updated; redirect/node in place at-or-before merge (timing hazard closed).
- A regenerated reference review (e.g. re-run fasrc/ood-sas) reads correctly under the new structure — "reads correctly" = A1–A4 present, three legs present, no Required/Quality language, signals+recommendation clearly distinct. (Defining the pass condition so it isn't purely subjective.)

## Sequencing

Plan B (or B+A together) before A-alone, because A-first leaves the live checklist transiently inconsistent with the new report. The reply to Bill follows the regenerated reference review.
