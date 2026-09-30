# Walkthrough Fixes (post-PR 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the six things Bill's method still flags on the 2026-09-30 report without narrowing what the review can find: two escapes in the feedback floor, a security claim that contradicts its own rows, tool findings with no disposition, a "suggestion" recorded as a failure, a README-vs-form.yml mismatch no check asks about, and three wrong or stale doc sentences.

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
1. Rule 3 (line or mechanism word) is evaluated on the **sentence window** that names the file: the sentence containing the file token plus the sentence immediately after it. A sentence ends at `.`, `;`, `:` followed by whitespace, or a newline. A paragraph that names the file in one sentence and gives the line in the next still passes; a line number three sentences away from the file, or in a sentence about another file, does not.
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

### Task 7: Regression sweep and one CI run (controller)

- [ ] **Step 1:** For each of the nine runs under the scratchpad (`pr2m/36678163506`, `pr2m/36678169915`, `pr2m/36678176175`, `run6`, `run7`, `exp2/*`) and the Task 6 sample: run floor, keys, rating (the new rules), rows (with the run's own `pre-review/` where present; the new candidate kinds need `tool_findings.json` and `site_values`, so regenerate facts for ood-sas at 462790a1 into a temp dir and pass that) and evidence. Record a before/after table in `.superpowers/sdd/<plan>/regression.md`.
- [ ] **Step 2:** Every new failure must be one of: the OODT-08 or MNT-02 floor escapes; the security sentence under WARN rows; MNT-02 FAIL; unanswered tool findings; unanswered site values. Any other new failure is a rule that is too tight: fix it and add the report's shape as a Must-not test in that task.
- [ ] **Step 3:** Bump `.claude-plugin/plugin.json` to 0.8.0; docs-spine/assemble tests that pin the version updated.
- [ ] **Step 3b: Other repos.** Run `run-pre-review.sh` on the five clones under `scratchpad/t3clones` (bc_osc_jupyter, bc_osc_rstudio_server, bc_osc_codeserver, ood-myjobs, ood-api) and the six `tests/fixtures/*`; tabulate per repo the `tool_findings.json` count and codes and the `site_values` entries with their `readme_lines`. Every entry must be a real tool finding or a real fixed site value; a false positive (a value that is not site-specific, a README line matched inside another word) is a scanner defect fixed before the PR. Record the table in `regression.md`.
- [ ] **Step 4:** Push; three Sonnet runs from the branch: fasrc/ood-sas, OSC/bc_osc_jupyter (Batch Connect, a different shape) and Sweet-and-Fizzy/ood-api (Passenger, no form.yml or template). Expected: all green; the ood-sas report has `sec-tool-finding` and `site-values-documented` rows, the security sentence absent under WARN rows, MNT-02 WARN, floor covering every fix-item; the Passenger report has no site-value rows and no spurious tool-finding rows. `gh workflow run appverse-review.yaml --ref fix/walkthrough-2026-09-30 -f target_repo=<repo> -f model=sonnet -f correlation_id=walkthrough-<n>`. The former single-run step:
- [ ] **Step 4 (superseded):** Push; one Sonnet run of fasrc/ood-sas from the branch (`gh workflow run appverse-review.yaml --ref fix/walkthrough-2026-09-30 -f target_repo=fasrc/ood-sas -f model=sonnet -f correlation_id=walkthrough-1`). Expected: green; the report has `sec-tool-finding` and `site-values-documented` rows; the security sentence absent under WARN rows; MNT-02 WARN; floor covers every fix-item. If red, the failing check's lines go in the PR body and the repair-step PR is next.
- [ ] **Step 5:** PR against `feat/facts-and-rows` (retarget to main when #56 merges), body: what each rule is in general terms, the walkthrough item it closes, the regression table, the run id.

---

## Self-Review

**Spec coverage.** Walkthrough Summary items: security sentence → T3; tool findings dropped → T4; floor 15/15 wrong (OODT-08, MNT-02) → T1; MNT-02 FAIL → T2; odyssey/odyssey3 unrecorded → T5; blank value = null → T6; GPU caveat advice → T6 rule; catalog docs → T6; OODT link → T6. Not covered on purpose: OODT-08 classification (a judgment call), row granularity (R2 allows grouping), "derived-only" feedback in runs 2–3 (needs a feedback→findings reverse check; noted for the repair-step PR).
**Placeholder scan.** Test N numbering is resolved by the implementer from the suite's last test; every other value is given.
**Type consistency.** `tool_findings.json` key `findings`; `site_values` inside `form.json`; manifest ids `sec-tool-finding`, `site-values-documented`; `weight` values `target`/`suggestion`; MISMATCH line forms fixed in T2 and T3 and reused in T7.
**Andrew's constraint.** Each task's Must-not line and T7's regression sweep are the guard against fixes that narrow the review. T4 and T5 add questions rather than filters; T1–T3 verify claims the report already makes; nothing removes a candidate or a row.
