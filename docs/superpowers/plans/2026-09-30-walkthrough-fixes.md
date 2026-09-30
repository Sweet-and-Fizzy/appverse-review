# Walkthrough Fixes (post-PR 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the six things Bill's method still flags on the 2026-09-30 report, the false stub gate the tillicum run exposed, and the three security-scanner gaps its §6 names (sinks and argv secrets first), without narrowing what the review can find: two escapes in the feedback floor, a security claim that contradicts its own rows, tool findings with no disposition, a "suggestion" recorded as a failure, a README-vs-form.yml mismatch no check asks about, and three wrong or stale doc sentences.

**Architecture:** Every fix is a general rule, never a special case for ood-sas. Mechanical facts stay in `pre-review.py`; questions the model must answer are manifest checks with a row per candidate; claims the report makes are verified by the existing checkers. Each task carries a "Must not" line, and the plan ends with a regression sweep over the nine existing runs: a rule that rejects a legitimate report is a defect in the rule.

**Tech Stack:** Python 3 stdlib scripts in `references/`, bash test suites in `tests/` (house style: exit 0/1/2, one line per problem, summary last, `check` helper, exact-string assertions, SKIP-aware). bash 3.2 on the dev host; PyYAML only in the scratchpad venv.

**Spec:** `docs/bill-method-walkthrough-2026-09-30.md` (the replay: Summary of Suggestions, Draft Feedback vs findings, Security section) and, for the mechanism, `.superpowers/plan-facts-and-rows.md` Global Constraints (stable IDs, `defect_key`, manifest fields, citation grammar, `; reviewed OK:`). Branch: `fix/walkthrough-2026-09-30` off `feat/facts-and-rows` (PR #56); plugin version 0.8.0.

## Global Constraints

- The plan-facts-and-rows Global Constraints apply unchanged: `defect_key = {anchor}:{tag}`; one record per (app_id, rule, file:tag), worst result and max severity; a row answers exactly the candidates it cites; citations `path:N`, `N-M`, `N,M`, `; reviewed OK:` for PASS sites; `parse_citations` in `repo_paths.py` is the only citation parser; fact files under `<out>/<app_id>/`; manifest fields id, section, app_types, fact_source, rule, tag, row_required, dimension; `checks-sync.py --verify` and docs-spine must stay green.
- **Generality rule.** No script may name ood-sas, `odyssey`, `set -x`, `extra_slurm`, SC2164 or any other value from the walkthrough as a special case. A fix is a rule stated in the docstring in general terms, with the walkthrough case as one test among others.
- **Must-not rule.** Every checker change ships with at least one test of a legitimate report that the old rule accepted and the new rule must still accept.
- **Regression gate.** Task 7 runs every checker over the nine existing runs (`scratchpad/pr2m/*`, `run6`, `run7`, `exp2/*`) and the Task 6 sample. Every new failure must correspond to a defect the walkthrough names; any other new failure is fixed in the rule before the PR opens.
- Severity vocabulary: `critical`, `high`, `medium`, `low`, `info`. Fix-items are FAIL/WARN at `low` or above.
- Tests: exact strings, SKIP when a tool is absent, never a tautology.

---

### Task 1: Feedback floor — the line or the mechanism must sit with the file, and pseudo-anchors have a subject

**Files:**
- Modify: `references/check-feedback-floor.py` (`line_named`, `defect_named`, `main` around the `evidence_path` branch)
- Test: `tests/test-feedback-floor.sh`

**Why (walkthrough "Draft Feedback vs findings"):** OODT-08 `debug-tracing-enabled` passed because "lines 44/45" from a form.yml sentence sat in a paragraph that also named script.sh.erb. MNT-02 `releases:no-releases` passed on its covers-line key alone because its evidence has no repo path, so the prose check was skipped.

**Rules (general):**
1. Rule 3 (line or mechanism word) is evaluated on the **sentence window** that names the file: from the sentence containing the file token up to, but not including, the first later sentence that names a different file (a filename-shaped token with a stem of two or more characters and a letter-led extension; `e.g.`, `3.1`, `v2.0` are not files; the basename of the item's own file is not a different file). A sentence ends at `.`, `;`, `:` followed by whitespace, or a newline. A paragraph that names the file once and then describes several defects over the following sentences passes; a line number in a sentence about another file does not. (Amended 2026-09-30 after the task review: a two-sentence window rejected five of nine real reports.)
2. A fix-item whose evidence has no repo path (a pseudo-anchor) has a **subject**: the anchor's own words. Table: `releases` → `release`; `CHANGELOG.md` → `changelog`; `LICENSE` → `license`; `.github/workflows` → `ci`, `workflow`; `root` → the mechanism words of its tag. The subject is treated like a file name: some paragraph must contain it (rule 2), and rule 3 applies in that paragraph's sentence window. A covers-line key alone never satisfies a fix-item.

**Interfaces:**
- Produces: `sentence_windows(prose, token) -> list[str]`, `subject_words(defect_key) -> list[str]`; `MISSING` reasons unchanged (`file not named in feedback`, `defect not described in feedback`) plus `subject not named in feedback` for pseudo-anchors.

- [ ] **Step 1: Write the failing tests** (append; renumber from the suite's last test)

```bash
echo "Test 25: a line number in a sentence about another file does not describe this file's defect"
cat > "$TMP/t25.json" <<'EOF'
[{"app_id":"root","rule":"OODT-08","defect_key":"template/script.sh.erb:debug-tracing-enabled","result":"WARN","severity":"low","evidence":"template/script.sh.erb:19,44,54"},
 {"app_id":"root","rule":"QUA-06","defect_key":"form.yml:duplicate-yaml-key:custom_num_cores.help","result":"WARN","severity":"low","evidence":"form.yml:44,45"}]
EOF
cat > "$TMP/t25.md" <<'EOF'
## Draft feedback
<!-- feedback-covers: template/script.sh.erb:debug-tracing-enabled, form.yml:duplicate-yaml-key:custom_num_cores.help -->
The script template/script.sh.erb needs a shebang. In form.yml the duplicate help keys on lines 44/45 should be merged.
EOF
check "exit 1" 1 "$(run "$TMP/t25.json" "$TMP/t25.md")"
check "OODT-08 missing" 1 "$(grep -cF 'MISSING OODT-08 template/script.sh.erb:debug-tracing-enabled (defect not described in feedback)' "$TMP/out")"
check "QUA-06 covered" 0 "$(grep -cF 'MISSING QUA-06' "$TMP/out")"

echo "Test 26: file in one sentence, line in the next: still covered"
cat > "$TMP/t26.md" <<'EOF'
## Draft feedback
<!-- feedback-covers: template/script.sh.erb:debug-tracing-enabled, form.yml:duplicate-yaml-key:custom_num_cores.help -->
template/script.sh.erb turns on tracing. Lines 19, 44 and 54 each run set -x; drop them before release. form.yml has duplicate help keys at lines 44/45.
EOF
check "exit 0" 0 "$(run "$TMP/t26.json" "$TMP/t26.md" 2>/dev/null || run "$TMP/t25.json" "$TMP/t26.md")"

echo "Test 27: a pseudo-anchor fix-item needs its subject in the prose, not only its covers key"
cat > "$TMP/t27.json" <<'EOF'
[{"app_id":"root","rule":"MNT-02","defect_key":"releases:no-releases","result":"WARN","severity":"low","evidence":"releases"}]
EOF
printf '## Draft feedback\n<!-- feedback-covers: releases:no-releases -->\nThe README is fine.\n' > "$TMP/t27a.md"
check "exit 1" 1 "$(run "$TMP/t27.json" "$TMP/t27a.md")"
check "reason" 1 "$(grep -cF 'MISSING MNT-02 releases:no-releases (subject not named in feedback)' "$TMP/out")"
printf '## Draft feedback\n<!-- feedback-covers: releases:no-releases -->\nThere are no tagged releases yet; tag one when the next change lands.\n' > "$TMP/t27b.md"
check "subject named: exit 0" 0 "$(run "$TMP/t27.json" "$TMP/t27b.md")"
```
(Use `$TMP/t25.json` for Test 26 as well; drop the `||` form when writing it.)

- [ ] **Step 2: Run to verify they fail:** `bash tests/test-feedback-floor.sh` — Tests 25 and 27 FAIL, 26 passes.

- [ ] **Step 3: Implement**

```python
SENTENCE_END = re.compile(r"(?<=[.;:])\s+|\n")
PSEUDO_SUBJECTS = {"releases": ["release"], "CHANGELOG.md": ["changelog"], "LICENSE": ["license"],
                   ".github/workflows": ["ci", "workflow"]}

def sentences(paragraph):
    return [s for s in SENTENCE_END.split(paragraph) if s.strip()]

def sentence_windows(paragraph, candidates):
    """Each sentence naming a candidate, joined with the sentence after it."""
    ss = sentences(paragraph)
    return [" ".join(ss[i:i + 2]) for i, s in enumerate(ss) if any(token_in_prose(c, s) for c in candidates)]

def subject_words(defect_key):
    anchor = str(defect_key or "").split(":", 1)[0]
    if anchor == "root":
        return mechanism_words(defect_key)
    return PSEUDO_SUBJECTS.get(anchor, [])
```
`defect_named` iterates `sentence_windows(p, candidates)` instead of whole paragraphs. In `main`, when `evidence_path` is None: `subject = subject_words(key)`; if it is empty, keep today's behaviour (nothing to verify); otherwise `candidates = tuple(subject)`, paragraphs are found with `word_named`-style matching (hyphen/underscore-insensitive, whole word), `subject not named in feedback` when none, then rule 3 on the window. `root` anchors use `token_in_prose` on the mechanism words.

- [ ] **Step 4: Run the suite:** all pass. Any earlier test that encoded "anywhere in the paragraph" is rewritten to the window rule and the rewrite is named in the commit message.
- [ ] **Step 5: Commit:** `git add references/check-feedback-floor.py tests/test-feedback-floor.sh && git commit -m "feedback floor: line or mechanism must sit in the file's sentence window; pseudo-anchors need their subject in the prose"`

**Must not:** reject a paragraph that names the file, then gives the line in the next sentence (Test 26); reject a pseudo-anchor item whose prose says "changelog" or "release" without a line number.

---

### Task 2: Suggestions are never FAIL — a `weight` on manifest checks, enforced by check-rating

**Files:**
- Modify: `references/checks.yml`, `references/checks.json` (via `checks-sync.py`), `references/check-rating.py`, `skills/review-maintenance/SKILL.md` (one sentence), `tests/test-check-rating.sh`, `tests/test-docs-spine.sh`
- Reference: `references/review-rubric.md` Code Quality table (rows marked `Target for inclusion` or `Suggestion`) and the Maintenance signals text ("a release is a positive signal … never a failure").

**Why:** MNT-02 `releases:no-releases` was recorded FAIL low; the rubric says a missing release is never a failure. The rule generalises: every check the rubric calls a suggestion, and every maintenance good-practice signal (MNT-02 to MNT-06), is WARN at most.

- [ ] **Step 1: Manifest.** Add `weight: target | suggestion` to every `code_quality` check in `checks.yml`, copied from the rubric table (`error-handling`, `numeric-field-bounds`, `magic-numbers` per the rubric's own column; `duplicated-blocks`, `dead-code`, `erb-missing-value` are `suggestion`; `icon-matches-target-os` per the rubric row). Add the field to the header comment. Run `python3 references/checks-sync.py` (venv python) to regenerate `checks.json`; `--verify` exit 0.
- [ ] **Step 2: docs-spine test:** for each code_quality check, the rubric row containing `` `check: <id>` `` ends with the cell matching its weight (`Target for inclusion` ↔ `target`, `Suggestion` ↔ `suggestion`). Exact-string `has` per check, generated in a loop over `checks.json` with python3.
- [ ] **Step 3: check-rating failing tests**

```bash
echo "Test N: a suggestion check or a maintenance good-practice signal recorded as FAIL is a MISMATCH"
# findings with QUA-04 template/script.sh.erb:commented-out-code FAIL low  and  MNT-02 releases:no-releases FAIL low, report otherwise consistent
check "exit 1" 1 "$(run "$TMP/ok.md" "$TMP/fail-suggestion.json")"
check "QUA-04 line" 1 "$(grep -cF 'MISMATCH root QUA-04 template/script.sh.erb:commented-out-code: suggestion (check dead-code) recorded as FAIL' "$TMP/out")"
check "MNT-02 line" 1 "$(grep -cF 'MISMATCH root MNT-02 releases:no-releases: good-practice signal recorded as FAIL' "$TMP/out")"
echo "Test N+1: a target check FAIL and an MNT-01 FAIL are not mismatches"
# QUA-03 template/script.sh.erb:no-set-e FAIL low and MNT-01 root:stale-repo FAIL high -> exit 0
```
- [ ] **Step 4: Implement** in `check-rating.py`: load `checks.json` beside the script; `SUGGESTION_CHECKS = {c["id"]: (c["rule"], c["tag"]) for c in checks if c.get("weight") == "suggestion"}`; a record matches a check when its rule equals the check's rule and its tag (before any `:` qualifier) equals the check's tag. `GOOD_PRACTICE_RULES = {"MNT-02", "MNT-03", "MNT-04", "MNT-05", "MNT-06"}`. A matching record with result FAIL prints the MISMATCH line above; exit 1. Docstring gains rule 3. The findings argument is now read (update the docstring sentence that says it is not).
- [ ] **Step 5: Maintenance skill:** after "a missing release is a suggestion, never a failure", add: "Records under MNT-02 to MNT-06 are WARN at most; `check-rating.py` rejects a FAIL." docs-spine `has` for that sentence.
- [ ] **Step 6: Run** rating, docs-spine, and `checks-sync.py --verify`; commit: `feat: manifest weight (target|suggestion); check-rating rejects a suggestion or good-practice signal recorded as FAIL`

**Must not:** touch MNT-01 or any `target` check; reject a WARN.

---

### Task 3: The security claim sentence follows the rows

**Files:**
- Modify: `references/check-rating.py`, `skills/review-security/SKILL.md` (the "When no row or observation is FAIL or WARN" bullet), `references/review-rubric.md` (the sentence at "is the claim when neither produces a FAIL or WARN"), `tests/test-check-rating.sh`, `tests/test-docs-spine.sh`

**Why:** report:80 says "No tool-detectable issues in the checked tiers." under two WARN rows, in all three runs.

- [ ] **Step 1: Failing tests** (check-rating): a report whose Security section has a `| OODT-01 | … | WARN |` row and the sentence → exit 1, line `MISMATCH root security: "No tool-detectable issues in the checked tiers." with 2 FAIL/WARN rows above it`; a report with only PASS rows and the sentence → 0; PASS rows and no sentence → 1, `MISMATCH root security: no FAIL/WARN rows but the sentence "No tool-detectable issues in the checked tiers." is missing`; the "security.json lists no candidates; no observations." line counts as the no-findings form.
- [ ] **Step 2: Implement:** rule 4 in check-rating: within each app's `### Security` section (up to the next `### `), count table rows whose first cell is an `OODT-` code and whose Result cell (the cell after the Check cell when present, else the second) normalises to FAIL or WARN (reuse `normalize_result` from check-rows via importlib); the sentence must be present iff the count is 0.
- [ ] **Step 3: Skill and rubric text:** the bullet becomes "When no row in either table is FAIL or WARN, write exactly … Never write it when any row is FAIL or WARN, and never write 'safe'." docs-spine asserts the new bullet string.
- [ ] **Step 4: Run, commit:** `check-rating: the security claim sentence appears iff no security row is FAIL or WARN`

**Must not:** read rows outside the Security section; require the sentence when the section says `security.json lists no candidates; no observations.`

---

### Task 4: Tool findings are candidates

**Files:**
- Modify: `references/pre-review.py` (write `<out>/<app_id>/tool_findings.json`), `references/checks.yml` + `checks.json`, `references/check-rows.py` (candidate function), `references/compare-runs.py` (inherits via check-rows' candidate functions; verify), `skills/review-security/SKILL.md` (step 5 and the kind table), `references/security-tools.md`, `references/review-rubric.md` (one row in the Security section's check list if it enumerates checks), `tests/test-pre-review.sh`, `tests/test-check-rows.sh`, `tests/test-docs-spine.sh`

**Why:** five shellcheck findings appear in the tool table and get no disposition. The general rule: every tool finding is a candidate the model answers, like every interpolation.

**Contract:**
- `tool_findings.json`: `{"findings": [{"tool": "shellcheck"|"semgrep"|"bandit", "file": "<repo-relative>", "line": N, "code": "SC2164"|"<semgrep check_id>"|"B602", "level": "<tool's own level>", "message": "<tool's message>"}]}`, sorted by tool, file, line; only files under the app's path; written for every app that has facts (empty list allowed); absent tools contribute nothing. Paths as the pre-review already restores them (repo-relative, ERB stripping preserved line numbers).
- Manifest entry:
  ```yaml
  - id: sec-tool-finding
    section: Tier 2 — Tooling
    app_types: [batch_connect, passenger, companion, widget]
    fact_source: tool_findings.json
    rule: null
    tag: null
    row_required: when_candidates
    dimension: security
  ```
- check-rows: candidates are the findings' `file:line`; a candidate is **answered by any row of any check that cites that file:line** (a tool finding at an interpolation line is corroboration, already cited there), or by a `check: sec-tool-finding` row. Unanswered → `UNCITED <app> sec-tool-finding <file:line>`.
- Skill: step 5 says: for each tool finding not already cited by a candidate row, write one `check: sec-tool-finding` row: PASS with the reason (ERB artefact, style-only, false positive: say which) or FAIL/WARN with the rule and tag the finding maps to (the existing shellcheck-code guidance in `security-tools.md`), and a record under that rule. Rows may group findings of one code with `N,M` citations and `; reviewed OK:`.

- [ ] **Step 1: pre-review test:** a fixture with `template/script.sh.erb` containing `cd $DIR` (SC2164 under `-S info`) → `tool_findings.json` has one entry with `code: "SC2164"`, `file: "template/script.sh.erb"`, `line: 2`; SKIP when shellcheck is absent; without any tool installed the file is `{"findings": []}`.
- [ ] **Step 2: pre-review implementation:** after the tool runs, normalise: shellcheck JSON (`file`, `line`, `code` → `"SC%d"`, `level`, `message`); semgrep `results[]` (`path`, `start.line`, `check_id`, `extra.severity`, `extra.message`); bandit `results[]` (`filename`, `line_number`, `test_id`, `issue_severity`, `issue_text`). Filter to the app dir; write per app.
- [ ] **Step 3: check-rows test:** a `tool_findings.json` with two findings, one at a line already cited by a `sec-interpolation` row and one not: with no `sec-tool-finding` row → exit 1 with exactly one `UNCITED root sec-tool-finding template/script.sh.erb:25`; add a `| OODT-01 | \`check: sec-tool-finding\` | PASS | — | — | SC2164: cd without exit; ERB template, before.sh sets -e | reviewed OK: template/script.sh.erb:25 |` row → exit 0. The real manifest test (Test 14) gains the row.
- [ ] **Step 4: check-rows implementation:** `candidates()` branch for `fact_source == "tool_findings.json"`; the "answered by any row" rule implemented by collecting every citation in the app section once and checking membership before the per-check rule.
- [ ] **Step 5: compare-runs:** confirm the new check appears in the per-candidate table with no code change (it reuses `candidates()`); add one test line asserting a `sec-tool-finding` row in the table.
- [ ] **Step 6: docs:** security skill kind table row `| sec-tool-finding | tool_findings.json entries |`; `security-tools.md` describes the file; rubric mentions the row under Tier 2; docs-spine asserts the manifest id appears in the skill.
- [ ] **Step 7: Run** pre-review (minutes), rows, compare-runs, docs-spine, `checks-sync.py --verify`; commit in two commits (facts; checker+skill).

**Must not:** double-count a tool finding at a line another row already cites; require rows when no tool ran (empty list → no candidates → no row); fail Passenger apps that have no shell files.

---

### Task 5: Site values the README must agree with

**Files:**
- Modify: `references/pre-review.py` (`form.json`: `fixed` on attributes; new `site_values` list), `references/checks.yml` + `checks.json`, `references/check-rows.py` (`form_candidates` branch), `skills/review-quality/SKILL.md` (Portability: a row per site value), `references/finding-codes.md` (QUA-06 `readme-inconsistency:<name>` qualifier form, if not already listed), `references/review-rubric.md` (Portability: one sentence), `tests/test-pre-review.sh`, `tests/test-check-rows.sh`, `tests/test-docs-spine.sh`

**Why:** README.md:115 says the cluster is `odyssey`; form.yml:3 says `odyssey3`. Bill caught it in August; no check asks. General rule: every fixed site value in form.yml that the README mentions is a candidate; the model says whether the README agrees.

**Contract:**
- `form.json` attributes gain `fixed: true|false` — true when the attribute has a `value` and no editable widget (widget null or `hidden_field`), false otherwise. (Data only; existing candidate sets are unchanged so nothing narrows.)
- `form.json.site_values`: `[{"name": "cluster", "value": "odyssey3", "line": 3, "readme_lines": [115]}]`, one entry per: top-level `cluster` value (each element when a list), each `fixed` attribute's value, and each `bc_queue`/partition-like attribute's fixed value (i.e. the same `fixed` rule; no name list). `readme_lines` are the README lines (1-based) whose text contains the attribute name or the value as a whole token, from the same README `readme.json` used. Entries with no `readme_lines` are still listed (the model may PASS them as "not mentioned").
- Manifest entry: `id: site-values-documented`, `section: Portability`, `app_types: [batch_connect]`, `fact_source: [form.json, readme.json]`, `rule: QUA-06`, `tag: readme-inconsistency`, `row_required: when_candidates`, `dimension: portability`, `weight: suggestion`.
- Row per site value: `PASS` citing `form.yml:N` and, when mentioned, `README.md:M` (`; reviewed OK:` form), or `WARN` QUA-06 `readme-inconsistency:<name>` citing both lines when the README states a different value. Record anchor `README.md` (the file that is wrong).
- check-rows candidates: `form.yml:<line>` per site value (app-prefixed in a monorepo).

- [ ] **Step 1: pre-review tests:** form.yml with top-level `cluster: "alpha"` and attribute `desktop: { value: xfce }` and a README containing "cluster is beta" and "desktop: xfce": `site_values` has two entries, `cluster` with `readme_lines` = the "cluster is beta" line, `desktop` likewise; `fixed` true for `desktop`, false for a `text_field`.
- [ ] **Step 2: Implement** in the form scanner; README lines from the README text already read for `readme.json`.
- [ ] **Step 3: check-rows tests:** with two site values and no rows → two `UNCITED root site-values-documented form.yml:N`; a PASS row with `form.yml:3; reviewed OK: README.md:115` and a WARN row → 0.
- [ ] **Step 4: Implement** the `form_candidates` branch.
- [ ] **Step 5: Skill and docs:** quality skill Portability gets the row rule and the tag table line `| site-values-documented | readme-inconsistency:<name> (QUA-06) |`; rubric Portability adds "The README's stated site values must match form.yml (`check: site-values-documented`)"; finding-codes lists the qualifier form; docs-spine asserts the id in rubric and skill.
- [ ] **Step 6: Run** pre-review, rows, docs-spine, `checks-sync.py --verify`; commit.

**Must not:** make `fixed` attributes drop out of `erb-missing-value` or `sec-interpolation` candidates; flag a value the README does not mention as a finding (that is the portability rating's job); match `cluster` inside another word (whole-token match).

---

### Task 6: Doc sentences that are wrong or stale

**Files:**
- Modify: `skills/review-quality/SKILL.md` (QUA-10 guidance), `references/review-rubric.md` (QUA-10 row text; Draft feedback guidance; catalog lines ~471/476), `references/review-checklist.md` (lines ~97, ~135, ~156), `skills/review-app/SKILL.md` (Draft feedback rules; catalog checks block), `skills/review-security/SKILL.md` (OODT link in the section header, lines ~12-13), `tests/test-docs-spine.sh`

- [ ] **Step 1:** QUA-10: replace any "empty string" explanation with: "A blank form field arrives as `nil` (YAML null), not an empty string; `.to_s` turns it into `""`. An unguarded `<%= context.x %>` therefore writes nothing (or `nil` under `.inspect`) into the YAML, which is why a guard or default is needed." docs-spine `has` the first sentence.
- [ ] **Step 2:** Catalog: Process:97 stays; Process:135 and :156 and Rubric:471/476 now say: the review performs the catalog reads when it can reach the catalog and states which pages it read; the duplicate check is still the reviewer's to settle. The review-app skill's catalog block requires the report to state the pages read ("pages 1–N of the app list"). docs-spine `lacks "the review cannot see the catalog"` in the checklist; `has` the pages sentence in the skill.
- [ ] **Step 3:** Draft feedback rule (review-app skill + rubric Draft feedback guidance): "Never advise removing a comment or help text that states a real constraint (a partition that requires a GPU, a limit); advise rewording it." docs-spine `has`.
- [ ] **Step 4:** Security section header: the OODT taxonomy line links to the rubric's Security section (`https://openondemand.connectci.org/appverse-review-rubric#security`) as the security skill line 12-13 intends; docs-spine `has` the URL in the skill's report template.
- [ ] **Step 5:** `bash tests/test-docs-spine.sh`; commit `docs: blank ERB values are nil; catalog reads are performed and page-limited; never advise deleting a real caveat; OODT link`.

**Must not:** change any exact string that check-rating or check-rows matches (the security sentence is Task 3's; keep it byte-identical).

---

### Task 8: Documentation rungs may be met by content; stub is the structure gate's call, never the rung ladder's

**Files:**
- Modify: `references/pre-review.py` (`readme.json` rungs: `content_lines` per rung; modest synonym widening), `skills/review-quality/SKILL.md` (Documentation rules), `skills/review-structure/SKILL.md` (STR-01 stub definition, if it needs a sentence), `references/review-rubric.md` (Documentation section), `references/check-rating.py` (rule 1 acceptance of `Minimal` below the ladder; stub line requires a failed STR-01 gate), `tests/test-pre-review.sh`, `tests/test-check-rating.sh`, `tests/test-docs-spine.sh`
- Spec: `docs/review-of-run-36732089153-tillicum.md` §1 (three rules compose into a false stub), §2, §4.

**Why:** UWrc/tillicum-llama-chat has a 15 KB README with 29 headings and was rated `Minimal — not supported (stub README; see QUA-01)` with a QUA-01 `docs-stub` FAIL high and a "required change that blocks listing", because no heading contains one of the five prerequisites synonyms, the quality skill forbids claiming a rung `readme.json` has no entry for, and "no prerequisites evidence" is the skill's stub trigger. The structure skill's own stub definition (unfilled template, or title and contact only) was met, and its STR-01 row said PASS on the same page.

**Rules (general):**
1. **Stub is one thing, decided once.** A README is a stub only when the structure gate STR-01 says so, from `readme.json` facts: placeholder-only sections, or no content beyond a title and a contact line (define from `readme.json`: every rung null AND fewer than N non-blank non-heading lines, N=10, OR every heading's body placeholder). The quality skill never declares a stub. Below-Minimal on the ladder is a Documentation rating of `Minimal` with a QUA-01 `docs-minimal` record (WARN low by default; the rubric says which rungs are targets), never a gate failure.
2. **A rung is met by a heading match or by cited content.** `readme.json` rungs keep `match: heading|intro` and add `content_lines`: README line numbers (outside fenced code, outside headings) whose text contains one of the rung's content keywords (prerequisites: `require`, `prerequisite`, `depend`, `must exist`, `must be installed`, `needs`, `module load`, `available on`; the other rungs get their own short lists, written into `RUNGS` beside the heading synonyms). The model may claim a rung with no heading match only by citing `README.md:N` where N is in `content_lines` or inside a matched heading's body, and the evidence line says `content: README.md:N` instead of a heading name. `check-rating.py` accepts `content: README.md:N` as non-"none" evidence; `check-evidence.py` already verifies the line exists.
3. **Synonyms widen modestly:** prerequisites adds `setup`, `getting started`, `environment`, `defaults`; the other rungs unchanged unless the tillicum README shows the same gap for them (check and say).
4. **Agreement:** `check-rating.py` rule 1 accepts `Minimal` with zero supported rungs when a QUA-01 `docs-minimal` record exists for the app; the stub line `Minimal — not supported (stub README; see QUA-01)` is accepted only when a QUA-01 `docs-stub` FAIL record exists AND the report's STR-01 gate row for the README is FAIL (parse the gate table; MISMATCH `stub rating with a passing STR-01 gate` otherwise). Rule 2 unchanged (Minimal → High).
5. **Upkeep wording (§4):** a maintenance signal the skill deliberately does not compute says `Not assessed` with the reason `not read by design`; `unavailable` is reserved for a source that was tried and failed. One sentence in `skills/review-maintenance/SKILL.md` and the report template; docs-spine asserts it.

- [ ] **Step 1: pre-review tests:** a README whose prerequisites live under `## Current defaults` with a line "Requires an A100 partition and the container path below": `rungs.prerequisites` has `match: null`, `content_lines: [<that line>]`; a README with `## Requirements` keeps `match: "heading"`; fenced code lines never appear in `content_lines`; a README of a title and a contact line gives `stub: true` in `readme.json` (new top-level field, from rule 1's definition), the tillicum-shaped README gives `stub: false`.
- [ ] **Step 2: Implement** in the readme scanner.
- [ ] **Step 3: check-rating tests:** evidence line `prerequisites: content: README.md:19` counts as supported; `Minimal` with no supported rung and a `docs-minimal` record → exit 0; the stub line with a `docs-stub` FAIL record and STR-01 PASS → exit 1 with the MISMATCH line; with STR-01 FAIL → exit 0. The task-6 sample and the three pr2m reports must still pass rule 1.
- [ ] **Step 4: Implement** in check-rating.
- [ ] **Step 5: Skills and rubric:** quality skill: replace the stub trigger with rule 1's sentence and add the content-citation rule; structure skill: STR-01 reads `readme.json.stub`; rubric Documentation: "A rung is supported by a matching heading or by cited README content; a README is a stub only by the STR-01 definition." docs-spine asserts the three sentences. Maintenance skill: rule 5's sentence.
- [ ] **Step 6: Regenerate the tillicum facts** (`run-pre-review.sh` on a clone of UWrc/tillicum-llama-chat at f7c8d35 into a temp dir) and show `prerequisites.content_lines` non-empty and `stub: false`; record in the report. Run pre-review, rating, docs-spine; commit.

**Must not:** let the model claim a rung with no citation; rate a placeholder-only README above Minimal; change the stub line string; make `docs-stub` reachable from the quality skill.

---

### Task 9: Security scanner — sinks, credential exposure, non-shell files, and an honest "examined"

**Files:**
- Modify: `references/pre-review.py` (`scan_security`, `SEC_KINDS`, `SEC_KIND`, file selection), `references/checks.yml` + `checks.json`, `references/check-rows.py` (`SECURITY_KINDS` map), `skills/review-security/SKILL.md` (kind table, "Examined" line, the non-attribute count sentence), `references/security-tools.md` (security.json contract), `references/review-rubric.md` (Security check list, one line per new check), `references/finding-codes.md` (only if a tag is missing; the tags below exist), `tests/test-pre-review.sh`, `tests/test-check-rows.sh`, `tests/test-docs-spine.sh`
- Spec: `docs/review-of-run-36732089153-tillicum.md` §6 (6a sinks and argv secrets; 6b non-shell files; 6c non-attribute interpolations). Priority order 6a, 6b, 6c.

**Why:** every OODT-01 candidate sits on the assignment line `VAR="<%= attr %>"`; where `VAR` is consumed is never a candidate, so `template/script.sh.erb:84` (`--api-key "$API_KEY"` into the argv of a long-running process on a shared node, readable through `ps`) got no row and the report told the submitter nothing. `view.html.erb`, `form.js` and a hand-written `proxy.py` are scanned by tools only or not at all, while the report's "Examined" list implies otherwise.

**Contract (general, fixed tags; per-candidate `rule`/`tag` exactly as `config_flag` already does):**
1. **`sink` kind** (6a), check `sec-interpolation`, rule OODT-01, tag `unsanitized-user-input`. For every shell-file interpolation that assigns a variable (`VAR="<%= … %>"`, `VAR=<%= … %>`, `export VAR=…`, `declare`/`local`), emit one candidate at each later line in the same file that uses `$VAR`, `${VAR`, or `"$VAR"` inside a command, an array literal or append (`X=(…)`, `X+=(…)`), a heredoc body, or a `read`/`eval`/`source` argument. Skip test contexts (`[ … ]`, `[[ … ]]`, `test …`, `${#VAR}`, `${VAR:-…}` used only in a test) and bare `echo`/`printf` lines, but list those skipped lines in the candidate's `note` as `also used at: N, M (tests/echo)`. Candidate fields: `source_line` (the assignment), `attributes` (from the assignment), `text` (the sink line, capped as today), `note`.
2. **`credential_exposure` kind** (6a), new check `sec-credential-exposure`, rule OODT-02, tag null in the manifest, per-candidate tag `token-cli-visible` when a secret-named variable reaches argv (a command line or an array later expanded into one) and `secret-in-log` when it reaches `echo`/`printf`/`logger`/a redirect to a `.log` file. Secret-named: variable or attribute name matching `(?i)(api[_-]?key|token|secret|passw(or)?d|credential|private[_-]?key)`. Works on any shell file, whether the value came from a form attribute or from the environment.
3. **Non-shell files** (6b): `.html.erb` and `.js.erb` join the interpolation scan; an attribute interpolation there is kind `interpolation` with per-candidate rule OODT-05 and tag `unescaped-output-html` (`.html.erb`) or `unescaped-output-javascript` (`.js.erb`). New **`request_handler` kind**, check `sec-request-handler`, rule OODT-05, tag null, for `.py`, `.rb`, `.js` files under the app: a route or method handler definition (`def do_[A-Z]+`, `@app.route`, `@bp.route`, Sinatra `get '/…'`, Express `app.(get|post|use)(`) → tag `partial-auth-coverage`; a request header reflected into a response header (`Origin` read and written to `Access-Control-Allow-Origin`, `Authorization` forwarded) → tag `cors-wildcard` for Origin, `disabled-auth` for Authorization pass-through; a request path used to build a file path or an upstream URL (`self.path`, `request.path`, `req.url`, `req.path`) → rule OODT-03, tag `path-traversal`. One candidate per site, file and line.
4. **Examined means one thing** (6b): each entry of `security.json.files` gains `scanned: "candidates" | "tools_only" | "not_read"` (`candidates` when a kind scan read it; `tools_only` when only shellcheck/semgrep/bandit saw it; `not_read` for skipped/binary/oversize). The security skill's "Examined" line lists files by that field, in three groups, and never implies a `tools_only` file was read for candidates.
5. **Non-attribute interpolations** (6c): `security.json.counts.non_attribute_interpolations` and a per-file map `non_attribute_interpolations: {"submit.yml.erb": 1, "template/before.sh.erb": 1}`; the skill writes under the Findings table exactly `N interpolation(s) of OOD-provided values (not form attributes) are not listed as candidates.` with N from the facts; docs-spine asserts the sentence; check-rows ignores them.
6. Manifest: two new entries (`sec-credential-exposure`, `sec-request-handler`), section `Pattern checks (all app types)`, all app types, fact_source `security.json`, `row_required: when_candidates`, dimension `security`, `weight: target`. `SECURITY_KINDS` in check-rows gains `sink` under `sec-interpolation` and the two new checks. `compare-runs` inherits.

- [ ] **Step 1: pre-review tests (fixtures in a temp dir; exact strings):** (a) a script with `API_KEY="<%= context.api_key %>"` at line 2, `ARGS=(--api-key "$API_KEY")` at line 4, `[ -n "$API_KEY" ] && echo set` at line 5, `run "${ARGS[@]}"` at line 6 → one `sink` candidate at line 4 with `source_line: 2`, note listing `also used at: 5 (tests/echo)`; one `credential_exposure` candidate at line 4, tag `token-cli-visible`; `echo "$API_KEY" >> run.log` at line 7 → a second `credential_exposure` with tag `secret-in-log`. (b) `view.html.erb` with `<%= context.name %>` inside a `<script>` → `unescaped-output-javascript`; outside → `unescaped-output-html`; `<%= csrftoken %>` counted, not listed. (c) `proxy.py` with `def do_GET(self):`, `origin = self.headers.get('Origin')` followed by `self.send_header('Access-Control-Allow-Origin', origin)`, and `upstream = base + self.path` → three `request_handler` candidates with the tags above. (d) `files[].scanned` is `candidates` for the shell file and the html.erb, `tools_only` for a `.txt`? (no: `.txt` is `not_read`), `tools_only` for a `.py` that only bandit read when the request-handler scan found nothing but the file was read — define: `candidates` whenever a kind scan read the file, so `.py` is `candidates`; `tools_only` is reserved for files only a tool examined (e.g. a `.rb` when Ruby scanning is off). Write the rule in the docstring and test one of each.
- [ ] **Step 2: Implement** in `scan_security` (new helpers `_sink_candidates(lines, assignments)`, `_credential_candidates`, `_request_handler_candidates`); keep the 1 MB cap and symlink refusal for the new file types.
- [ ] **Step 3: check-rows tests:** a `sink` candidate unanswered → `UNCITED root sec-interpolation template/script.sh.erb:4`; a `credential_exposure` candidate unanswered → `UNCITED root sec-credential-exposure …`; the real manifest test gains the two rows.
- [ ] **Step 4: Implement** the check-rows map; run `checks-sync.py --verify`.
- [ ] **Step 5: Skill, security-tools, rubric, docs-spine:** kind table rows for `sink`, `credential_exposure`, `request_handler`; the "Examined" grouping sentence; the non-attribute count sentence; rubric Security list gains the two checks; docs-spine asserts the ids in skill and rubric and the two sentences.
- [ ] **Step 6: Prove on tillicum:** `run-pre-review.sh` on a clone of UWrc/tillicum-llama-chat at f7c8d35 → `credential_exposure` at `template/script.sh.erb:84` (`token-cli-visible`), `sink` candidates at 136 and 138 and 176/177, `request_handler` candidates in `template/proxy.py` including the Origin reflection at 212–216, `view.html.erb` listed with `scanned: candidates`; also on ood-sas (`sink` count small; no credential candidates) and the five clones (record counts in the report; every `credential_exposure` must be a real secret-named variable).
- [ ] **Step 7:** Run pre-review, rows, compare-runs, docs-spine; commit in two commits (scanner; checker+docs).

**Must not:** list bare `echo`/test uses as sinks (note them instead); emit a credential candidate for a variable that is not secret-named; treat a `.py` file the request-handler scan read as `tools_only`; change any existing candidate's line, kind or tag on ood-sas (Task 7's sweep checks the count stays 14 plus the new kinds).

---

### Task 7: Regression sweep and one CI run (controller)

- [ ] **Step 1:** For each of the nine runs under the scratchpad (`pr2m/36678163506`, `pr2m/36678169915`, `pr2m/36678176175`, `run6`, `run7`, `exp2/*`) and the Task 6 sample: run floor, keys, rating (the new rules), rows (with the run's own `pre-review/` where present; the new candidate kinds need `tool_findings.json` and `site_values`, so regenerate facts for ood-sas at 462790a1 into a temp dir and pass that) and evidence. Record a before/after table in `.superpowers/sdd/<plan>/regression.md`.
- [ ] **Step 2:** Every new failure must be one of: the OODT-08 or MNT-02 floor escapes; the security sentence under WARN rows; MNT-02 FAIL; unanswered tool findings; unanswered site values. Any other new failure is a rule that is too tight: fix it and add the report's shape as a Must-not test in that task.
- [ ] **Step 3:** Bump `.claude-plugin/plugin.json` to 0.8.0; docs-spine/assemble tests that pin the version updated.
- [ ] **Step 3b: Other repos.** Run `run-pre-review.sh` on the five clones under `scratchpad/t3clones` (bc_osc_jupyter, bc_osc_rstudio_server, bc_osc_codeserver, ood-myjobs, ood-api) and the six `tests/fixtures/*`; tabulate per repo the `tool_findings.json` count and codes and the `site_values` entries with their `readme_lines`. Every entry must be a real tool finding or a real fixed site value; a false positive (a value that is not site-specific, a README line matched inside another word) is a scanner defect fixed before the PR. Record the table in `regression.md`.
- [ ] **Step 4:** Push; three Sonnet runs from the branch: fasrc/ood-sas, UWrc/tillicum-llama-chat (the false-stub case; expect Documentation rated from content, no docs-stub, STR-01 PASS, and a `sec-credential-exposure` row for `template/script.sh.erb:84`) and Sweet-and-Fizzy/ood-api (Passenger, no form.yml or template). Expected: all green; the ood-sas report has `sec-tool-finding` and `site-values-documented` rows, the security sentence absent under WARN rows, MNT-02 WARN, floor covering every fix-item; the Passenger report has no site-value rows and no spurious tool-finding rows. `gh workflow run appverse-review.yaml --ref fix/walkthrough-2026-09-30 -f target_repo=<repo> -f model=sonnet -f correlation_id=walkthrough-<n>`. The former single-run step:
- [ ] **Step 4 (superseded):** Push; one Sonnet run of fasrc/ood-sas from the branch (`gh workflow run appverse-review.yaml --ref fix/walkthrough-2026-09-30 -f target_repo=fasrc/ood-sas -f model=sonnet -f correlation_id=walkthrough-1`). Expected: green; the report has `sec-tool-finding` and `site-values-documented` rows; the security sentence absent under WARN rows; MNT-02 WARN; floor covers every fix-item. If red, the failing check's lines go in the PR body and the repair-step PR is next.
- [ ] **Step 5:** PR against `feat/facts-and-rows` (retarget to main when #56 merges), body: what each rule is in general terms, the walkthrough item it closes, the regression table, the run id.

---

## Self-Review

**Spec coverage.** Walkthrough Summary items: security sentence → T3; tool findings dropped → T4; floor 15/15 wrong (OODT-08, MNT-02) → T1; MNT-02 FAIL → T2; odyssey/odyssey3 unrecorded → T5; blank value = null → T6; GPU caveat advice → T6 rule; catalog docs → T6; OODT link → T6. Not covered on purpose: OODT-08 classification (a judgment call), row granularity (R2 allows grouping), "derived-only" feedback in runs 2–3 (needs a feedback→findings reverse check; noted for the repair-step PR).
**Placeholder scan.** Test N numbering is resolved by the implementer from the suite's last test; every other value is given.
**Type consistency.** `tool_findings.json` key `findings`; `site_values` inside `form.json`; manifest ids `sec-tool-finding`, `site-values-documented`; `weight` values `target`/`suggestion`; MISMATCH line forms fixed in T2 and T3 and reused in T7.
**Andrew's constraint.** Each task's Must-not line and T7's regression sweep are the guard against fixes that narrow the review. T4 and T5 add questions rather than filters; T1–T3 verify claims the report already makes; nothing removes a candidate or a row.
