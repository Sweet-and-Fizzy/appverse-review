# Security Scanner: Sinks, Credential Exposure, Non-shell Files — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The security scanner lists where a user- or admin-supplied value ends up, not only where it is assigned, so a secret on a shared node's command line, an option-injection sink, or a reflected request header gets a row the model must answer.

**Architecture:** Same four-layer split as PR 2: `pre-review.py` emits candidates (sites, never verdicts) into `security.json`; the manifest names the checks; `check-rows.py` requires a row per candidate; the security skill decides. New candidate kinds reuse the existing taint tracking (`_erb_taint`, `_shell_taint`) and the fixed-tag pattern (`SEC_KIND`, per-match tag as `config_flag` does). Every kind is bounded and measured against the recall set, per the walkthrough-fixes Global Constraints (consistency is not the metric; row growth is bounded).

**Tech Stack:** Python 3 stdlib in `references/`, bash suites in `tests/`, the corpus and `run-corpus.sh` from the walkthrough-fixes branch.

**Spec:** `docs/review-of-run-36732089153-tillicum.md` §6 (6a sinks, 6b non-shell files, 6c non-attribute count), §7 (tool findings; artefacts), §8 (admin-set secrets are cross-user). Priority order 6a, §8, 6b, 6c. Branch: `feat/security-sinks` off `fix/walkthrough-2026-09-30` once that PR merges (or off main after it lands); plugin 0.9.0.

## Global Constraints

- The walkthrough-fixes Global Constraints apply (generality; must-not tests; recall set; bounded rows; a checker never requires prose).
- Fixed tags per kind; when a kind has more than one natural tag the manifest tag is null and the candidate carries `rule`/`tag` per match (the `config_flag` precedent). Vocabulary already holds every tag used here: OODT-02 `token-cli-visible`, `secret-in-log`; OODT-05 `cors-wildcard`, `disabled-auth`, `unescaped-output-html`, `unescaped-output-javascript`; OODT-03 `path-traversal`; OODT-01 `unsanitized-user-input`.
- Row growth bounds: sinks are one candidate per (variable, line); a variable with more than 8 sink lines collapses to one candidate listing them; request-handler candidates are limited to the three site-specific patterns (no candidate per route definition) and to files under `template/` for Batch Connect apps; Passenger apps keep tools + capability profile for handlers.
- `security.json.files[]` entries gain `scanned: "candidates" | "tools_only" | "not_read"` — `candidates` when any kind scan read the file, `tools_only` when only a tool examined it, `not_read` otherwise.
- Nothing the model copies from facts goes unchecked: the non-attribute interpolation count and the Examined grouping are rendered by pre-review into `tool-table.md` (which the skill already pastes verbatim), not typed by the model.
- Measurement: three CI runs on tillicum (the §9 table plus the new rows) and one on ood-sas; `run-corpus.sh --update` only after the sweep is read.

---

### Task 1: `sink` candidates for later uses of a tainted variable

**Files:**
- Modify: `references/pre-review.py` (`scan_security` after the `unquoted_expansion` block: reuse `carried` from `_shell_taint`; `SEC_KINDS`, `SEC_KIND`), `references/check-rows.py` (`SECURITY_KINDS["sec-interpolation"]` gains `sink`), `references/security-tools.md`, `skills/review-security/SKILL.md` (kind table row; decision guidance for sinks), `tests/test-pre-review.sh`, `tests/test-check-rows.sh`, `tests/test-docs-spine.sh`

**Contract:** kind `sink`, check `sec-interpolation`, rule OODT-01, tag `unsanitized-user-input`. For every shell template variable that `_shell_taint` reports as carrying a form attribute, one candidate at each later line in the same file where `$VAR`/`${VAR…}` appears in a command, an array literal or append (`X=(…)`, `X+=(…)`), a heredoc body, or a `read`/`eval`/`source` argument. Not candidates (listed in `note` as `also used at: N, M (test/echo)`): test contexts (`[ … ]`, `[[ … ]]`, `test …`), `${#VAR}`, `${VAR:-…}` used only inside a test, and bare `echo`/`printf` lines. Fields: `source_line` (the assignment), `attributes`, `text`, `note`. Skip a sink line that is already an `unquoted_expansion` candidate for the same variable (that candidate carries the sink). Ceiling: more than 8 sink lines for one variable → one candidate with `lines: [...]`.

- [ ] **Step 1: pre-review test:** fixture `template/script.sh.erb`: line 2 `API_KEY="<%= context.api_key %>"`, line 3 `[ -n "$API_KEY" ] && echo set`, line 4 `ARGS=(--api-key "$API_KEY")`, line 5 `run "${ARGS[@]}"`, line 6 `cat <<EOF`, line 7 `key=$API_KEY`, line 8 `EOF` → sink candidates at 4 and 7 with `source_line: 2`, `attributes: ["api_key"]`, note `also used at: 3 (test/echo)`; none at 3 or 5. A variable used on 9 command lines → one collapsed candidate.
- [ ] **Step 2: Implement** `_sink_candidates(lines, carried, family)` next to the `unquoted_expansion` block; reuse `_code_part`, `_is_comment`, `_scan_quotes`.
- [ ] **Step 3: check-rows test:** an unanswered sink → `UNCITED root sec-interpolation template/script.sh.erb:4`; a row citing `:4` answers it; the real manifest test unchanged (no new check id).
- [ ] **Step 4: Skill guidance:** for a sink row the question is "where does this end up": argv of a long-running process on a shared node, a file, a network call, an option string; PASS needs the reason. `security-tools.md` documents the kind and the ceiling. docs-spine asserts the kind-table row.
- [ ] **Step 5:** prove on tillicum (clone at f7c8d35): sinks at `template/script.sh.erb:84`, `:136`, `:138`, `:176`/`:177`; on ood-sas: report the count (expected small). Run pre-review, rows, docs-spine; commit.

**Must not:** emit a sink for a test or bare echo line; duplicate an `unquoted_expansion` candidate; exceed the ceiling.

---

### Task 2: `credential_exposure` candidates; admin-set values are cross-user

**Files:**
- Modify: `references/pre-review.py` (new kind; `_form_attrs` must expose widget so `hidden_field` is known — check `scan_form` output; `SEC_KIND`), `references/checks.yml` + `checks.json` (new check), `references/check-rows.py` (`SECURITY_KINDS["sec-credential-exposure"] = ("credential_exposure",)`), `references/finding-codes.md` (no new tags; confirm), `references/security-tools.md`, `references/review-rubric.md` (Security check list row), `skills/review-security/SKILL.md`, `tests/test-pre-review.sh`, `tests/test-check-rows.sh`, `tests/test-docs-spine.sh`

**Contract:** kind `credential_exposure`, check `sec-credential-exposure`, rule OODT-02, manifest tag null; per-candidate tag `token-cli-visible` when a secret-named variable reaches argv (a command line, or an array later expanded into one), `secret-in-log` when it reaches `echo`/`printf`/`logger`/a redirect to a `.log` file. Secret-named: variable or attribute name matching `(?i)(api[_-]?key|token|secret|passw(or)?d|credential|private[_-]?key)`. Works on any shell file in scope, whether the value came from a form attribute or the environment. `admin_set: true` when the source attribute is a `hidden_field` or has `display: false` (§8: a shared site secret, cross-user); `admin_set: false` for a user-typed field; `admin_set: null` when the source is not a form attribute. Manifest entry: `id: sec-credential-exposure`, `section: Pattern checks (all app types)`, all app types, `fact_source: security.json`, `rule: OODT-02`, `tag: null`, `row_required: when_candidates`, `dimension: security`.

- [ ] **Step 1: pre-review tests:** the Task 1 fixture plus `echo "$API_KEY" >> run.log` at line 9 and `form.yml` with `api_key: {widget: hidden_field, value: ""}` → two candidates: line 4 `token-cli-visible` `admin_set: true`; line 9 `secret-in-log` `admin_set: true`; a `text_field` source → `admin_set: false`; `TOKEN=$(cat ~/.token)` then `curl -H "Authorization: $TOKEN"` → `token-cli-visible` with `admin_set: null`; a variable named `KEYBOARD` → no candidate.
- [ ] **Step 2: Implement** `_credential_candidates(lines, assignments, attrs_meta)`; the assignment map comes from Task 1's sink pass (variable → source line, attributes) extended with plain shell assignments.
- [ ] **Step 3: check-rows tests:** unanswered → `UNCITED root sec-credential-exposure template/script.sh.erb:4`; the real manifest test gains the row.
- [ ] **Step 4: Skill:** decision guidance: a secret in argv on a shared compute node is readable through `ps`/`/proc`; `admin_set: true` is cross-user (FAIL, at least medium); base64 or quoting is transport, not protection; the fix to suggest is a key file or an environment variable read inside the container. `security-tools.md` and the rubric row; docs-spine asserts the id in the skill and rubric; `checks-sync.py --verify`.
- [ ] **Step 5:** prove on tillicum: `template/script.sh.erb:84` `token-cli-visible`, `admin_set: true`. Run pre-review, rows, docs-spine; commit.

**Must not:** emit a candidate for a non-secret-named variable; treat a user-typed field as admin-set; add a candidate for a secret that only appears in a test context.

---

### Task 3: Non-shell files: `.html.erb`/`.js.erb` interpolation and site-specific request-handler patterns

**Files:**
- Modify: `references/pre-review.py` (`_security_scope` keeps `.html.erb`/`.js.erb` in scope for Batch Connect — check `NOT_SOURCE`; `_interpolations` family for html/js; new `request_handler` kind), `references/checks.yml` + `checks.json`, `references/check-rows.py`, `references/security-tools.md`, `references/review-rubric.md`, `skills/review-security/SKILL.md`, `tests/test-pre-review.sh`, `tests/test-check-rows.sh`, `tests/test-docs-spine.sh`

**Contract:**
- An attribute interpolation in a `.html.erb` file is kind `interpolation` with per-candidate rule OODT-05 and tag `unescaped-output-html`, or `unescaped-output-javascript` when the site is inside a `<script>` element or a `.js.erb` file. Same check (`sec-interpolation`), so no new manifest entry.
- Kind `request_handler`, check `sec-request-handler`, rule OODT-05, manifest tag null; exactly three patterns, per file and line: a request header reflected into a response header (`Origin` read then written to `Access-Control-Allow-Origin` → tag `cors-wildcard`; `Authorization` forwarded to an upstream → tag `disabled-auth`), and a request path used to build a file path or an upstream URL (`self.path`, `request.path`, `req.url`, `req.path` concatenated or formatted into `open(`, `os.path.join(`, `urljoin(`, an f-string URL → rule OODT-03, tag `path-traversal`). Python, Ruby and JavaScript files. For Batch Connect apps only files under `template/`; for other app types the scan runs on all source but is capped at 10 candidates per file (then one per pattern per file with `lines`). No candidate for a route definition by itself. Manifest entry: `id: sec-request-handler`, `section: Pattern checks (all app types)`, all app types, `fact_source: security.json`, `rule: OODT-05`, `tag: null`, `row_required: when_candidates`, `dimension: security`.

- [ ] **Step 1: pre-review tests:** `view.html.erb` with `<%= context.name %>` outside a script → `unescaped-output-html`; inside `<script>` → `unescaped-output-javascript`; `template/proxy.py` with `origin = self.headers.get('Origin')` then `self.send_header('Access-Control-Allow-Origin', origin)` → `cors-wildcard` at the send_header line; `upstream = base + self.path` → `path-traversal`; a `def do_GET(self):` alone → no candidate; a Passenger app's `app.rb` with 12 reflections → capped.
- [ ] **Step 2: Implement** `_request_handler_candidates(lines, family)` and the html/js interpolation family.
- [ ] **Step 3: check-rows tests** (`UNCITED root sec-request-handler template/proxy.py:214`); the real manifest test gains the row.
- [ ] **Step 4: Docs, docs-spine, checks-sync.**
- [ ] **Step 5:** prove on tillicum: `view.html.erb` in `files` with `scanned: candidates`; `template/proxy.py` Origin reflection at 212–216. On Sweet-and-Fizzy/ood-api (Passenger): report the candidate count and confirm the cap. Commit.

**Must not:** emit a candidate per route definition; scan Passenger apps' handlers without the cap; list OOD-provided values (`csrftoken`, `host`, `port`) as interpolation candidates (they are counted by Task 4).

---

### Task 4: Examined means one thing; counts rendered, not copied

**Files:**
- Modify: `references/pre-review.py` (`security.json.files[]` → objects with `scanned`; `counts.non_attribute_interpolations` and per-file map; `tool-table.md` gains two lines: the Examined grouping and `N interpolation(s) of OOD-provided values (not form attributes) are not listed as candidates.`; tool-finding artefacts per the walkthrough-fixes follow-up: `artifact: true` for `SC2148`/`SC2154` on `.sh.erb`, listed apart in the table), `references/check-rows.py` (ignore non-attribute counts; read `files[].file` for the new object shape), `references/compare-runs.py` (same), `references/security-tools.md`, `skills/review-security/SKILL.md` (paste the two rendered lines; never type them), `tests/test-pre-review.sh`, `tests/test-check-rows.sh`, `tests/test-docs-spine.sh`

- [ ] **Step 1: tests:** `files[]` shape `{"file": "template/script.sh.erb", "scanned": "candidates"}`, a `.rb` file only bandit/semgrep saw → `tools_only`, a binary → `not_read`; `<%= cluster %>` in submit.yml.erb and `<%= csrftoken %>` in before.sh.erb → `non_attribute_interpolations: {"submit.yml.erb": 1, "template/before.sh.erb": 1}`, count 2, no candidates; `tool-table.md` contains the exact two lines; SC2148 on a `.sh.erb` → `artifact: true` and the table says `4 of them ERB-stripping artefacts`.
- [ ] **Step 2: Implement.** Every reader of `security.json.files` (check-rows, compare-runs, the skill) handles the object shape; keep a one-release tolerance for the old string shape in the readers (the corpus holds old facts).
- [ ] **Step 3: Skill:** the Examined line and the count line come from `tool-table.md` verbatim; docs-spine asserts the paste instruction; `run-corpus.sh` still 11/11 (readers tolerate the old shape).
- [ ] **Step 4:** commit.

**Must not:** ask the model to compute either line; break the corpus's old-shape facts.

---

### Task 5: Measure (controller)

- [ ] Three Sonnet runs on UWrc/tillicum-llama-chat at f7c8d35 and one on fasrc/ood-sas from the branch. Per the tillicum report §9 table plus: new rows at `script.sh.erb:84` (credential, `admin_set: true`, FAIL), `:136`/`:138` (sinks), `after.sh:35` (SC2086 tool finding), `proxy.py:212-216` (Origin reflection); the `api_key` row's verdict changed from PASS. Off-candidate recall not below the tillicum baseline (the `--offline` observation present). Turns per run recorded; under 85. `compare-runs.py` over the three tillicum runs; the prerequisites evidence line cites the same README line in all three.
- [ ] `run-corpus.sh --update` after the numbers are read; add the best tillicum run to the corpus with its expected file; bump to 0.9.0; PR body with the table and the recall column.

---

## Self-Review

**Spec coverage.** 6a (sinks) → T1; §8 (admin-set argv secret, cross-user) → T2; 6b (`.html.erb`, request handlers limited to site-specific patterns, `scanned` field) → T3 + T4; 6c (non-attribute count rendered) → T4; §7 (tool findings) landed in the walkthrough-fixes PR (Task 4 there); the artefact labelling → T4 here; §9 → T5.
**Placeholder scan.** Fixture line numbers are given; the only open value is the tillicum candidate counts, recorded at T5.
**Type consistency.** Kinds `sink`, `credential_exposure`, `request_handler`; checks `sec-credential-exposure`, `sec-request-handler`; `admin_set` true|false|null; `files[].scanned`; `counts.non_attribute_interpolations`; ceilings 8 (sinks per variable) and 10 (handler candidates per file).
**Adversarial-review carry-overs.** No candidate per route definition (arch F14); rendered lines instead of copied (arch F15); bounded growth and recall measurement (DA F1); T3 limited to `template/` for Batch Connect and capped elsewhere.
