# Walkthrough Fixes (post-PR 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the six things Bill's method still flags on the 2026-09-30 report and the false stub gate the tillicum run exposed, with a committed corpus and CI test job so a rule that rejects a legitimate report is caught by a test, not by hand, without narrowing what the review can find: two escapes in the feedback floor, a security claim that contradicts its own rows, tool findings with no disposition, a "suggestion" recorded as a failure, a README-vs-form.yml mismatch no check asks about, and three wrong or stale doc sentences.

**Architecture:** Every fix is a general rule, never a special case for ood-sas. Mechanical facts stay in `pre-review.py`; questions the model must answer are manifest checks with a row per candidate; claims the report makes are verified by the existing checkers. Each task carries a "Must not" line, and the plan ends with a regression sweep over the nine existing runs: a rule that rejects a legitimate report is a defect in the rule.

**Tech Stack:** Python 3 stdlib scripts in `references/`, bash test suites in `tests/` (house style: exit 0/1/2, one line per problem, summary last, `check` helper, exact-string assertions, SKIP-aware). bash 3.2 on the dev host; PyYAML only in the scratchpad venv.

**Spec:** `docs/bill-method-walkthrough-2026-09-30.md` (the replay: Summary of Suggestions, Draft Feedback vs findings, Security section) and, for the mechanism, `.superpowers/plan-facts-and-rows.md` Global Constraints (stable IDs, `defect_key`, manifest fields, citation grammar, `; reviewed OK:`). Branch: `fix/walkthrough-2026-09-30` off `feat/facts-and-rows` (PR #56); plugin version 0.8.0.

## Global Constraints

- The plan-facts-and-rows Global Constraints apply unchanged: `defect_key = {anchor}:{tag}`; one record per (app_id, rule, file:tag), worst result and max severity; a row answers exactly the candidates it cites; citations `path:N`, `N-M`, `N,M`, `; reviewed OK:` for PASS sites; `parse_citations` in `repo_paths.py` is the only citation parser; fact files under `<out>/<app_id>/`; manifest fields id, section, app_types, fact_source, rule, tag, row_required, dimension; `checks-sync.py --verify` and docs-spine must stay green.
- **Generality rule.** No script may name ood-sas, `odyssey`, `set -x`, `extra_slurm`, SC2164 or any other value from the walkthrough as a special case. A fix is a rule stated in the docstring in general terms, with the walkthrough case as one test among others.
- **Must-not rule.** Every checker change ships with at least one test of a legitimate report that the old rule accepted and the new rule must still accept.
- **Regression gate.** Task 7 runs every checker over the nine existing runs (`scratchpad/pr2m/*`, `run6`, `run7`, `exp2/*`) and the Task 6 sample. Every new failure must correspond to a defect the walkthrough names; any other new failure is fixed in the rule before the PR opens.
- **Consistency is not the success metric.** Every task is judged against a recall set: a fixed list of known defects per target (ood-sas: the walkthrough's "missed" items and Bill's 2026-08-27 notes; tillicum: the report's "Verified against source" table and §6; fixtures: `tests/TESTING.md`), split into candidate-enumerated and off-candidate. A change that lowers off-candidate recall on the Task 7 runs is a regression even when every checker passes. The nine ood-sas runs already show the direction: off-candidate defect categories per run fell from about 2.2 before the rows to 0.33 with them. Adding rows is not neutral; it spends attention and turns.
- **A checker fails a claim the report makes that its rows or facts contradict; it never requires prose.** A missing boilerplate sentence is not a defect.
- **Row growth is bounded.** A scanner that emits candidates proportional to the target's size caps them (per-code grouping, a ceiling per app) and the sweep records candidate counts and turns per run.
- Severity vocabulary: `critical`, `high`, `medium`, `low`, `info`. Fix-items are FAIL/WARN at `low` or above. Suggestion-class and good-practice records can be fix-items (a submitter should see them); the Draft feedback's required-vs-suggested split keys on the check's `weight`, not on severity (Task 6 states it).
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

**Fix round 2 (adversarial review 2026-09-30):** the subject table is total — every pseudo-anchor in `repo_paths.PSEUDO_ANCHORS` gets a subject (default: the anchor lowercased with extension and trailing `s` stripped; overrides `.github/workflows` → ci, workflow; `commits` → commit; `issues` → issue; `contributors` → contributor), an anchor with no subject is `MISSING (no subject for pseudo-anchor <anchor>)`, never a pass; one test asserts every non-file pseudo-anchor yields a subject. Mechanism words drop tokens that are file-name fragments or bare verbs (`erb`, `yml`, `sh`, `set`, `md`). Known limitation, recorded: a hostname or log-file token (`output.log`, `llama.cpp`, `osc.github.io`) in a later sentence cuts the window; the medium-term fix is a per-paragraph `<!-- covers: key -->` marker (repair-step PR).

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

**Follow-up in this task (adversarial review 2026-09-30):** `check-rating.py` exits 2 when `checks.json` cannot be loaded (today `load_suggestion_checks` returns `{}` and silently disables rule 3). Task 2 is one-directional on purpose: it never forces FAIL on an unmet target, since "unmet" is judgment; the sweep measures that drift instead.

---

### Task 3: The security claim sentence follows the rows

**Files:**
- Modify: `references/check-rating.py`, `skills/review-security/SKILL.md` (the "When no row or observation is FAIL or WARN" bullet), `references/review-rubric.md` (the sentence at "is the claim when neither produces a FAIL or WARN"), `tests/test-check-rating.sh`, `tests/test-docs-spine.sh`

**Why:** report:80 says "No tool-detectable issues in the checked tiers." under two WARN rows, in all three runs.

- [ ] **Step 1: Failing tests** (check-rating): a report whose Security section has a `| OODT-01 | … | WARN |` row and the sentence → exit 1, line `MISMATCH root security: "No tool-detectable issues in the checked tiers." with 2 FAIL/WARN rows above it`; a report with only PASS rows and the sentence → 0; PASS rows and no sentence → 0 (a missing sentence is not a defect: Global Constraints); the "security.json lists no candidates; no observations." form → 0.
- [ ] **Step 2: Implement:** rule 4 in check-rating: within each app's `### Security` section (up to the next `### `), count table rows whose first cell is an `OODT-` code and whose Result cell (the cell after the Check cell when present, else the second; the offset is computed per table) normalises to FAIL or WARN; the sentence may not be present when the count is above 0. (Amended 2026-09-30 after the adversarial reviews: the reverse direction, "sentence required when no row fails", is dropped.)
- [ ] **Step 3: Skill and rubric text:** the bullet becomes "When no row in either table is FAIL or WARN, write exactly … Never write it when any row is FAIL or WARN, and never write 'safe'." docs-spine asserts the new bullet string.
- [ ] **Step 4: Run, commit:** `check-rating: the security claim sentence never appears above a FAIL or WARN security row`

**Must not:** read rows outside the Security section; require the sentence when the section says `security.json lists no candidates; no observations.`

---

### Task 4: Tool findings are candidates, one per tool, code and file

**Files:**
- Modify: `references/pre-review.py` (`security.json`: a `tool_finding` kind; `SEC_KINDS`/`SEC_KIND`), `references/checks.yml` + `checks.json`, `references/check-rows.py` (`SECURITY_KINDS` and a code-naming rule for this check), `skills/review-security/SKILL.md` (step 5 and the kind table), `references/security-tools.md`, `references/review-rubric.md` (one row in the Security check list), `tests/test-pre-review.sh`, `tests/test-check-rows.sh`, `tests/test-docs-spine.sh`

**Why:** five shellcheck findings appear in the tool table and get no disposition. The walkthrough's own case is SC2086 at `template/script.sh.erb:72`, the eval candidate's line, which the eval PASS row never mentions. The general rule: every tool finding is a candidate the model answers, and answering means naming the code.

**Contract:**
- `security.json` gains kind `tool_finding`, check `sec-tool-finding`, rule null, tag null (the record, when FAIL/WARN, uses the rule and tag the code maps to in `security-tools.md`; the row lives in Security and the record may be `QUA-xx`, say so once in the skill). **One candidate per (tool, code, file)**: `{"kind": "tool_finding", "check": "sec-tool-finding", "tool": "shellcheck"|"semgrep"|"bandit", "code": "SC2164"|"<semgrep check_id>"|"B602", "file": "<repo-relative>", "lines": [N, M], "level": "<tool's level>", "text": "<message>"}`. Excluded: shellcheck `style` level, semgrep `INFO`. Ceiling: when an app has more than 15 tool-finding candidates, collapse to one per (tool, code) across files (lines carry the files as `file:line` strings) and set `counts.tool_finding_collapsed: true`. trivy is excluded because its findings are not line-anchored; the contract says so.
- check-rows: a `sec-tool-finding` candidate is answered by a row of this check whose Evidence cites the candidate's file with at least one of its lines **and whose Summary names the code** (`SC2164`, `B602`, the check_id as a whole token); a row of another check never answers it (R1: a row answers exactly the candidates it cites, and the recall metric agrees). Unanswered → `UNCITED <app> sec-tool-finding <file>:<code>`.
- Skill step 5: for each tool-finding candidate write one row: PASS with the reason (ERB artefact, style-only, false positive, or already covered by a candidate row, naming which) or FAIL/WARN with the mapped rule and tag and a record; the row's summary starts with the code. Rows may group lines with `N,M` citations.
- Manifest entry: `id: sec-tool-finding`, `section: Tier 2 — Tooling`, all app types, `fact_source: security.json`, `rule: null`, `tag: null`, `row_required: when_candidates`, `dimension: security`.

- [ ] **Step 1: pre-review test:** a fixture with `template/script.sh.erb` containing `cd $DIR` (SC2164 under `-S info`) and an unquoted `$X` on two lines (SC2086) → two `tool_finding` candidates, `SC2164` with `lines: [2]` and `SC2086` with both lines; SKIP when shellcheck is absent; a style-level code (SC2250 forced with a `# shellcheck enable=` directive, or assert on the level filter with a synthetic shellcheck JSON) is excluded; 16 synthetic codes across two files collapse to per-code candidates with `tool_finding_collapsed: true`.
- [ ] **Step 2: Implement** in `scan_security`: read the tool JSON the pre-review already wrote (shellcheck `file`,`line`,`code`→`SC%d`,`level`,`message`; semgrep `results[].path`,`start.line`,`check_id`,`extra.severity`,`extra.message`; bandit `results[].filename`,`line_number`,`test_id`,`issue_severity`,`issue_text`), filter to the app's files, group.
- [ ] **Step 3: check-rows test:** two candidates; a `sec-interpolation` PASS row citing `template/script.sh.erb:2` does not answer SC2164 (`UNCITED root sec-tool-finding template/script.sh.erb:SC2164`); a `| QUA-03 | \`check: sec-tool-finding\` | PASS | — | — | SC2164: cd without exit; before.sh sets -e | template/script.sh.erb:2 |` row answers it; a row citing the line whose summary omits the code does not. The real manifest test gains the row.
- [ ] **Step 4: Implement** the `SECURITY_KINDS` entry and the code-naming rule; `compare-runs` inherits through `candidates()` — add one test asserting the row appears in the per-candidate table.
- [ ] **Step 5: docs** (kind table, `security-tools.md` contract incl. the trivy sentence and the ceiling, rubric row, docs-spine ids); **Step 6:** run pre-review, rows, compare-runs, docs-spine, `checks-sync.py --verify`; two commits.

**Must not:** answer a tool finding by coincidence of line; emit style/INFO-level candidates; exceed the ceiling; fail Passenger apps with no shell files.
---

### Task 5: Cited values must be on the cited line (replaces the site-values check)

**Files:**
- Modify: `references/check-evidence.py`, `tests/test-check-evidence.sh`, `references/review-checklist.md` (one sentence under Step 3, what the check verifies)

**Why:** run 1 wrote "`odyssey3` … documented in the README configuration table | README.md:99" in a rating row; README.md:115 says `odyssey`. The same class produced `CHANGELOG.md:10` for :11 and "mkdir at line 21" for :22. The cause is an unchecked factual claim, not a missing row. (The former Task 5, a site-value candidate per fixed form attribute, is dropped: it misread OOD form semantics — an attribute with a value and no widget is an editable text field — and would have added rows that are mostly PASS. Adversarial review 2026-09-30.)

**Rule (general):** for every finding, and for every report row that carries a citation, a value written in backticks in the summary that is a single token (no spaces, 3 or more characters, not a path, not a code like `SC2086`, not purely numeric) must occur as a substring on at least one cited line of the cited file (any group, any line in a range). Otherwise `BAD <rule> <key> <evidence> (\`<value>\` is not on <path>:<N>)`. Findings JSON: read `summary` and `evidence`. Report rows: read the Summary and Evidence cells of every table row with a `check:` marker, via the shared row parser.

- [ ] **Step 1: tests:** a QUA-02 finding with summary "`odyssey3` documented at" and evidence `README.md:115` where line 115 holds `odyssey` → exit 1 with the BAD line; the same with line 115 holding `odyssey3` → 0; a value inside a range `README.md:110-120` present on 118 → 0; `\`SC2164\``, `\`form.yml\``, `\`42\`` and `\`ab\`` are skipped; a report row with the value in its Summary cell and the line in its Evidence cell is checked the same way.
- [ ] **Step 2: Implement** (`cited_values(text)`, `value_on_lines(value, path, lines)` with the existing line cache); add report-row scanning behind the existing `--report` argument if present, else add `--report <md>` (optional; findings-only when absent).
- [ ] **Step 3:** checklist sentence; run evidence suite; commit.

**Must not:** flag a value that appears anywhere in the cited range; flag codes, paths, numbers or two-letter tokens; add rows.
---

### Task 6: Doc sentences that are wrong or stale

**Files:**
- Modify: `skills/review-quality/SKILL.md` (QUA-10 guidance), `references/review-rubric.md` (QUA-10 row text; Draft feedback guidance; catalog lines ~471/476), `references/review-checklist.md` (lines ~97, ~135, ~156), `skills/review-app/SKILL.md` (Draft feedback rules; catalog checks block), `skills/review-security/SKILL.md` (OODT link in the section header, lines ~12-13), `tests/test-docs-spine.sh`

- [ ] **Step 1:** QUA-10: replace any "empty string" explanation with: "A blank form field arrives as `nil` (YAML null), not an empty string; `.to_s` turns it into `""`. An unguarded `<%= context.x %>` therefore writes nothing (or `nil` under `.inspect`) into the YAML, which is why a guard or default is needed." docs-spine `has` the first sentence.
- [ ] **Step 2:** Catalog: Process:97 stays; Process:135 and :156 and Rubric:471/476 now say: the review performs the catalog reads when it can reach the catalog and states which pages it read; the duplicate check is still the reviewer's to settle. The review-app skill's catalog block requires the report to state the pages read ("pages 1–N of the app list"). docs-spine `lacks "the review cannot see the catalog"` in the checklist; `has` the pages sentence in the skill.
- [ ] **Step 3:** Draft feedback rule (review-app skill + rubric Draft feedback guidance): "Never advise removing a comment or help text that states a real constraint (a partition that requires a GPU, a limit); advise rewording it." docs-spine `has`.
- [ ] **Step 4:** Security section header: the OODT taxonomy line links to the rubric's Security section (`https://openondemand.connectci.org/appverse-review-rubric#security`) as the security skill line 12-13 intends; docs-spine `has` the URL in the skill's report template.
- [ ] **Step 4b:** Upkeep wording (from the tillicum report §4): a maintenance signal the skill deliberately does not compute says `Not assessed` with the reason `not read by design`; `unavailable` is reserved for a source that was tried and failed (maintenance skill + report template). Required-vs-suggested in the Draft feedback keys on the check's `weight` (review-app skill). Reviewer Process lines ~173-175 say what the floor actually verifies: that the file and a line or mechanism word appear near each other, not that the advice is right. Unwrap the soft-wrapped sentence in `skills/review-maintenance/SKILL.md` (Task 2's deferred item) and restore the standard `has` assertion. Add the rubric table row for `icon-matches-target-os` with its weight cell (`Suggestion`) so docs-spine's fallback goes.
- [ ] **Step 4c:** docs-spine: assert checker-matched strings by reading the constants from the checker (`python3 -c 'import …; print(X)'`), not as restated literals; drop the advisory-prose asserts this task would otherwise add (the QUA-10 nil sentence, the GPU caveat, the Upkeep wording) — keep structural checks only.
- [ ] **Step 5:** `bash tests/test-docs-spine.sh`; commit `docs: blank ERB values are nil; catalog reads are performed and page-limited; never advise deleting a real caveat; OODT link; upkeep not-assessed wording`.

**Must not:** change any exact string that check-rating or check-rows matches (the security sentence is Task 3's; keep it byte-identical).

---

### Task 8a: Extract `report_parse.py`

**Files:**
- Create: `references/report_parse.py`; Test: `tests/test-report-parse.sh`
- Modify: `references/check-rows.py`, `references/check-rating.py`, `references/compare-runs.py` (import instead of importlib-by-path and instead of private copies)

**Why:** check-rating and compare-runs load `check-rows.py` by file path and call its internals; check-rating keeps its own `app_sections` that ends a section at `"
## "` while check-rows uses `^## `. Two parsers can disagree on one report, and Task 8 needs a third table read.

- [ ] **Step 1:** move `app_sections`, `subsection`, `section_for`, `split_row`, `is_separator`, `header_name`, `normalize_result`, `rows_by_check` into `report_parse.py` with one implementation (check-rows' regex form wins); check-rows keeps `candidates()`. Suite: one test per function, exact strings, including the escaped-pipe and Evidence-overflow rows, the `:---` separator, and a single-app report using `##` headings.
- [ ] **Step 2:** all three scripts import it (`from report_parse import …`, same style as `repo_paths`); their suites stay green (rows 80+, rating 71+, compare-runs 48+).
- [ ] **Step 3:** commit `refactor: report_parse.py, one report parser for rows, rating and compare-runs`.

**Must not:** change any suite's expected output.

---

### Task 8: Documentation rungs may be met by cited content; stub is decided once, from the facts

**Files:**
- Modify: `references/pre-review.py` (`readme.json`: `stub` and `content_line_count`), `skills/review-quality/SKILL.md`, `skills/review-structure/SKILL.md` (STR-01 reads the fact), `references/review-rubric.md` (Documentation), `references/check-rating.py` (rule 1: `content:` evidence; `Below minimal`; the stub line needs the fact), `references/check-evidence.py` (a `content:` citation must not be a heading, fence or placeholder line), `tests/test-pre-review.sh`, `tests/test-check-rating.sh`, `tests/test-check-evidence.sh`, `tests/test-docs-spine.sh`
- Spec: `docs/review-of-run-36732089153-tillicum.md` §1, §2.

**Why:** UWrc/tillicum-llama-chat's 15 KB README was rated a stub because no heading matched one of five synonyms and the skill forbids claiming a rung the scanner did not list. `tests/fixtures/broken-app` (a title and a contact line) is the canonical stub and must stay one; `ood-myjobs` (87 lines, no prerequisites heading, no keyword line) is the next tillicum, so keyword lists are not the fix.

**Rules (general):**
1. **Stub is a fact.** `readme.json.stub` is true when the README has fewer than 6 content lines OR every heading's body is placeholder text. A content line is non-blank, not a heading, not inside a fence, not a placeholder line, not a contact/email line (contains `@` or starts with `Contact`), not a badge/image-only line (`![` or `[![`). `content_line_count` is recorded. The structure skill's STR-01 README gate reads `stub` and nothing else; the quality skill never declares a stub.
2. **A rung is met by a heading match or by cited content.** The model may claim a rung with no heading match by writing `content: README.md:N` on the evidence line. `check-rating.py` accepts `content: README.md:N` as non-"none" evidence; `check-evidence.py` verifies N exists and is a content line under rule 1's definition (not a heading, fence or placeholder line). The reviewer judges whether the line delivers the rung. No keyword lists; no synonym widening beyond `defaults` and `getting started` for prerequisites (words no other rung uses).
3. **Below minimal is its own rating.** When no rung supports Minimal and `stub` is false, the rating line reads `Below minimal` (maps to High in rule 2) with a QUA-01 `docs-minimal` WARN record. `Minimal` keeps its meaning. The stub line `Minimal — not supported (stub README; see QUA-01)` is accepted only when `readme.json.stub` is true (check-rating takes the pre-review directory as an optional third argument; when absent it falls back to a STR-01 `readme-not-substantive` FAIL record in the findings, never to the Markdown gate table) and a QUA-01 `docs-stub` FAIL record exists.

- [ ] **Step 1: pre-review tests:** `tests/fixtures/broken-app` → `stub: true`, `content_line_count: 0`; `tests/fixtures/passenger-flask-app` (3 lines) → `stub: false` (say its count); a synthetic 7-line README with an intro, a prerequisite sentence, an install line → `stub: false`; a README whose every section body is template placeholder text → `stub: true`; tillicum-shaped (many headings, none matching prerequisites) → `stub: false`.
- [ ] **Step 2: Implement** in the readme scanner.
- [ ] **Step 3: check-rating tests:** evidence `prerequisites: content: README.md:19` counts as supported; `Below minimal` with zero supported rungs and a `docs-minimal` record → 0, and maps to High; `Minimal` with zero supported rungs → MISMATCH; the stub line with `stub: true` facts and a `docs-stub` FAIL record → 0; with `stub: false` facts → `MISMATCH root documentation: stub rating but readme.json says the README is not a stub`; without facts, the STR-01 record decides. The task-6 sample and the three pr2m reports still pass rule 1.
- [ ] **Step 4: check-evidence test:** `content: README.md:N` where N is a heading → BAD `(README.md:N is a heading, not content)`; where N is inside a fence → BAD; a content line → ok.
- [ ] **Step 5: Implement** rating and evidence; **Step 6: skills and rubric** (quality: content-citation rule, `Below minimal`, no stub declaration; structure: STR-01 reads the fact; rubric Documentation: the three sentences); docs-spine asserts the checker-matched strings by reading the constants from check-rating (`python3 -c`), not by restating them.
- [ ] **Step 7:** regenerate tillicum facts (clone at f7c8d35): `stub: false`; regenerate broken-app: `stub: true`. Run pre-review, rating, evidence, docs-spine; commit.

**Must not:** let the model claim a rung without a citation; make `docs-stub` reachable from the quality skill; rate a placeholder-only README above `Below minimal`; change the stub line string.
---

### Task 9: moved to its own plan

The security-scanner work from the tillicum report's §6 (sink candidates, a credential-exposure kind for secret-named variables reaching argv or logs, `.html.erb` interpolation, request-handler sites limited to Origin reflection, Authorization forwarding and request-path use under `template/`, the `scanned` field, the non-attribute count rendered by pre-review rather than copied by the model) is its own PR, in that priority order, immediately after this one merges. Both adversarial reviews (2026-09-30) said the same: it is three scanner projects, it doubles this PR's regression surface, and a candidate per route definition is a row with no question. The brief written for it (`.superpowers/sdd/…/task-9-brief.md`) is the starting point for that plan.
---

### Task 10: The corpus, the CI test job, and one wrap-up command

**Files:**
- Create: `tests/corpus/<run-id>/{report.md, findings.json, meta.json, pre-review/…}` for the nine ood-sas runs (trimmed: report, findings, meta, and the `pre-review/` facts where present) plus the tillicum run 36732089153 and the Task 6 sample; `tests/corpus/expected/<run-id>.txt` (per checker: exit code and problem lines); `tests/run-corpus.sh`; `tests/recall-set/{ood-sas,tillicum}.json` (the known-defect lists from the Global Constraints, each item with `key`, `candidate: true|false`); `references/check-all.py`; `.github/workflows/tests.yaml`
- Modify: `.github/workflows/appverse-review.yaml` (the wrap-up loop and the Verify step call `check-all.py`), `skills/review-app/SKILL.md` §6 (one command)

**Why:** the Must-not rule is checked once by hand against files outside the repo; no CI runs the suites; the tillicum run spent 28 checker calls in its wrap-up loop and 75 of 100 turns.

- [ ] **Step 1: `check-all.py <report.md> <findings.json> <checks.json> <pre-review-dir> --target <dir>`** runs floor, keys, rating, rows, evidence in that order, prints every problem line prefixed by the checker name, then one summary line per checker, and exits 1 if any failed (2 if any could not run). Test: a corpus run that fails two checkers prints both blocks and exits 1.
- [ ] **Step 2: `tests/run-corpus.sh`** runs `check-all.py` over every corpus run and diffs against `expected/`; prints per-run PASS/DIFF; exit 1 on any diff. Also computes, per run, the off-candidate recall against `tests/recall-set/<target>.json` (a defect counts as recalled when a FAIL/WARN record has its key) and prints a table; the table is informational unless the run's expected file sets a floor.
- [ ] **Step 3:** `tests.yaml` on `pull_request` and `workflow_dispatch`: ubuntu-latest, python3 with PyYAML, shellcheck, semgrep pinned as the review workflow pins it; runs every `tests/test-*.sh` and `tests/run-corpus.sh`.
- [ ] **Step 4:** the review workflow's wrap-up prompt and Verify step use `check-all.py`; docs-spine asserts the command string in the skill and the workflow.
- [ ] **Step 5:** commit in two commits (corpus + expected; scripts + workflow).

**Must not:** commit any token or secret in `meta.json`; commit report PDFs or HTML; let a corpus run's expected file encode a known-wrong verdict without a comment line saying so.

---

### Task 7: Regression sweep and three CI runs (controller)

- [ ] **Step 1:** For each of the nine runs under the scratchpad (`pr2m/36678163506`, `pr2m/36678169915`, `pr2m/36678176175`, `run6`, `run7`, `exp2/*`) and the Task 6 sample: run floor, keys, rating (the new rules), rows (with the run's own `pre-review/` where present; the new candidate kinds need `tool_findings.json` and `site_values`, so regenerate facts for ood-sas at 462790a1 into a temp dir and pass that) and evidence. Record a before/after table in `.superpowers/sdd/<plan>/regression.md`.
- [ ] **Step 2:** Every new failure must be one of: the OODT-08 or MNT-02 floor escapes; the security sentence under WARN rows; MNT-02 FAIL; unanswered tool findings; unanswered site values. Any other new failure is a rule that is too tight: fix it and add the report's shape as a Must-not test in that task.
- [ ] **Step 3:** Bump `.claude-plugin/plugin.json` to 0.8.0; docs-spine/assemble tests that pin the version updated.
- [ ] **Step 3c: Recall and budget.** For each CI run: off-candidate recall against `tests/recall-set/` (Task 10), turns used (from the run log), tool-finding candidate count. Acceptance: off-candidate recall on ood-sas not below the rows-run baseline (0.33 categories per run) and the Additional observations table non-empty or stating what was read; turns under 85 of 100; a run over the ceiling fails the sweep. Record the target-result drift (unmet targets recorded WARN) as a measured quantity.
- [ ] **Step 3b: Other repos.** Run `run-pre-review.sh` on the five clones under `scratchpad/t3clones` (bc_osc_jupyter, bc_osc_rstudio_server, bc_osc_codeserver, ood-myjobs, ood-api) and the six `tests/fixtures/*`; tabulate per repo the `tool_findings.json` count and codes and the `site_values` entries with their `readme_lines`. Every entry must be a real tool finding or a real fixed site value; a false positive (a value that is not site-specific, a README line matched inside another word) is a scanner defect fixed before the PR. Record the table in `regression.md`.
- [ ] **Step 4:** Push; three Sonnet runs from the branch: fasrc/ood-sas, UWrc/tillicum-llama-chat (the false-stub case; expect Documentation rated from content, no docs-stub, STR-01 PASS, and a `sec-credential-exposure` row for `template/script.sh.erb:84`) and Sweet-and-Fizzy/ood-api (Passenger, no form.yml or template). Expected: all green; the ood-sas report has `sec-tool-finding` and `site-values-documented` rows, the security sentence absent under WARN rows, MNT-02 WARN, floor covering every fix-item; the Passenger report has no site-value rows and no spurious tool-finding rows. `gh workflow run appverse-review.yaml --ref fix/walkthrough-2026-09-30 -f target_repo=<repo> -f model=sonnet -f correlation_id=walkthrough-<n>`. The former single-run step:
- [ ] **Step 4 (superseded):** Push; one Sonnet run of fasrc/ood-sas from the branch (`gh workflow run appverse-review.yaml --ref fix/walkthrough-2026-09-30 -f target_repo=fasrc/ood-sas -f model=sonnet -f correlation_id=walkthrough-1`). Expected: green; the report has `sec-tool-finding` and `site-values-documented` rows; the security sentence absent under WARN rows; MNT-02 WARN; floor covers every fix-item. If red, the failing check's lines go in the PR body and the repair-step PR is next.
- [ ] **Step 5:** PR against `feat/facts-and-rows` (retarget to main when #56 merges), body: what each rule is in general terms, the walkthrough item it closes, the regression table, the run id.

---

## Self-Review

**Spec coverage.** Walkthrough Summary items: security sentence → T3; tool findings dropped → T4; floor 15/15 wrong (OODT-08, MNT-02) → T1; MNT-02 FAIL → T2; odyssey/odyssey3 unrecorded → T5; blank value = null → T6; GPU caveat advice → T6 rule; catalog docs → T6; OODT link → T6. Not covered on purpose: OODT-08 classification (a judgment call), row granularity (R2 allows grouping), "derived-only" feedback in runs 2–3 (needs a feedback→findings reverse check; noted for the repair-step PR).
**Placeholder scan.** Test N numbering is resolved by the implementer from the suite's last test; every other value is given.
**Type consistency.** `tool_findings.json` key `findings`; `site_values` inside `form.json`; manifest ids `sec-tool-finding`, `site-values-documented`; `weight` values `target`/`suggestion`; MISMATCH line forms fixed in T2 and T3 and reused in T7.
**Andrew's constraint.** Each task's Must-not line, T7's regression sweep and T10's corpus are the guard against fixes that narrow the review. Adding rows is not neutral (Global Constraints): T4 adds bounded rows with a ceiling; the old T5 was dropped for a claim check that adds none; T8 removes a gate that fired on a real README; T9 is deferred. The success metric is off-candidate recall, not agreement.
**Adversarial reviews (2026-09-30).** Devil's advocate and architecture reviews are in the plan workspace (`da-review-plan.md`, `arch-review-plan.md`); rulings are in the ledger.
