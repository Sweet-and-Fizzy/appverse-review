# AppVerse Review — Reviewer Process + General Rubric (Plan B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the reviewer checklist into a work-ordered Reviewer Process doc and a general Review Rubric on the dimension spine, re-point every consumer (skills, portal DocSync, portal view, links), and publish the rubric at `/appverse-review-rubric` with the old security-rubric slug redirecting to it.

**Architecture:** Two Markdown reference files in `appverse-review` are the deliverable; everything else is re-pointing. `references/review-checklist.md` keeps its filename (the portal's DocSync map key and node 11932 depend on it) but becomes the **Reviewer Process** doc, reordered to the order a reviewer works. A new `references/review-rubric.md` absorbs every criteria definition from the checklist plus the whole of `references/security-rubric.md`, organized as gate criteria → four signal dimensions → Code Quality findings → decision rubric, with the enumerated named checks living in the section the relevant aspect skill reads. `security-rubric.md` is deleted. On the portal side, node 12246 (today the Security Rubric page) is **retitled and re-aliased** to become the Review Rubric page, and DocSync's map key for it changes to the new file. The plugin's four aspect skills read the rubric sections by name, exactly as they read the checklist sections today, so the enumerated checks need no new mechanism.

**Tech Stack:** Markdown (LLM-consumed reference docs and SKILL files); a bash structural test in `tests/`; PHP (one constant + one PHPUnit unit test in `cyberteam_drupal`'s `ood_software` module); Drupal config YAML (one view text change); drush on Pantheon live for the content cutover.

**Spec:** `docs/design/specs/2026-09-09-appverse-review-dimension-alignment-design.md` — sections "The three-legged model", "Plan B — checklist split + rubric + Drupal", "3b. Enumerated named-checks", "What to flag back to Bill", "Success criteria", "Sequencing".

**One deviation from the spec, decided here:** the spec says "new Drupal node + alias" for the rubric. This plan **reuses node 12246** instead. Reasons: the portal's `redirect.settings.yml` has `auto_redirect: true`, so changing the node's alias creates the 301 from `/appverse-security-rubric` automatically; no orphan node is left behind; and DocSync logs-and-skips a 404 for a missing source file, which makes the merge order forgiving (see Task 8). If Andrew prefers a fresh node, Task 7's `DOC_MAP` edit and Task 8's content ops change nid only.

## Global Constraints

Copied from the spec. Every task's requirements include these.

- **The three legs, verbatim:** (1) **Gate criteria (pass/fail)** — hard requirements an app must meet to list; (2) **Descriptive signals (Low / Medium / High concern)** on four dimensions — Security, Portability, Documentation, Upkeep (repo-level) — a heat-map for a deployer, NOT a gate; (3) **Decision rubric** (accept / accept-with-suggestions / request-changes / reject) derived from criteria + finding properties, orthogonal to the signals.
- **Signals do not gate; the decision rubric does.** The decision table from the checklist's Step 3 is preserved verbatim, including all reject triggers and the accept boundary.
- **Low = good end, High = most concern**, stated explicitly on every axis; never invert; never style High as a hazard.
- **Derivation table (verbatim, PUBLIC-SIGNALS "Deriving the levels"):** Security — no findings = Low, Low/Info severity only = Medium, any Medium/High/Critical = High. Portability — Portable = Low, Partially portable = Medium, Not portable = High. Documentation — Strong/Exemplary = Low, Adequate = Medium, Minimal = High. Upkeep — active within 12mo + two or more good-practice signals = Low, active within 12mo = Medium, inactive over 12mo = High.
- **Code Quality** is a findings category consumed by the decision rubric. It is not a signal dimension and not a Structure gate. The docs must give it an explicit home.
- **README has two roles:** "README present and substantive" is a Structure *gate*; README depth (Minimal/Adequate/Strong/Exemplary) is the Documentation *signal*. State this so the double-classification complaint cannot recur.
- **`shared_paths` is Security scope input**, not a repo-level criterion.
- **Security stays the deepest section.** Do not force parity with the other dimensions.
- **Enumerated named checks — starting set, short, not exhaustive:** desktop/panel icon references match the target OS (Code Quality); numeric form-field bounds (Code Quality); hardcoded scratch/cluster/partition paths (Portability).
- **Preserve every existing rule code, OODT code, severity term, and rating term unchanged.** TESTING.md's OODT references must stay valid (CLAUDE.md rule).
- **Out of scope (spec):** per-app Upkeep for monorepos; the six-month re-flag mechanism (state that it will be a portal feature; no manual action); the appverse_review entity model.
- **Plugin repo commits:** plain messages, no attribution trailers. Commit per task on the feature branch.
- **Portal repo (from Andrew's working notes, not the portal's CLAUDE.md, which predates the incident):** never raw `git worktree add`; use `vendor/bin/robo tree:new`. Never run `composer patches-repatch` as a verification step; it has left a worktree unbootable on this machine. One PHPUnit file per invocation. Paths are under `web/` (the real tree; `docroot` is the symlink).

**Deliberate content changes in Task 2 (not verbatim carry-overs; list them in the plugin PR body so they are reviewed as rule changes):**
- "Repo is not archived on GitHub" and the Passenger/companion layout paragraph are promoted from `review-structure/SKILL.md` into the Structure gate; the checklist never stated them.
- Duplicate YAML keys are named as a Code Quality finding (never a gate); the checklist did not mention them and no skill fails an app on them.
- `appverse.yml` validity is added beside `manifest.yml` validity.
- README and LICENSE are stated as repo-level checks that a monorepo's apps share.
- The four README questions and the "different institution's paths" / "no Configuration section" red flags move from the old pass/fail Documentation Minimum into the Documentation *signal* (`QUA-01` findings). Only "stub / unfilled template" remains a gate. This is the spec's "README has two roles" applied; it matches what `review-structure` and `review-quality` already do, but it weakens the doc's stated requirement and must be stated in the rubric.
- Upkeep: a repo with no open issues is **neutral** on the issue-responsiveness signal (decided 2026-09-23). The checklist never stated a rule. PR 43's assembler currently counts `issues_responded: null` in the repo's favor (`assemble-artifact.py` ~line 190), and its envelope doc, maintenance skill, and orchestrator Upkeep comment say the same; a request on PR 43 asks Matt to make null neutral so the tool and the rubric agree. If PR 43 lands with the favorable rule, the rubric sentence and the tool disagree until one is changed; do not merge Plan B with that disagreement open.
- Security signal "counts `OODT-` findings only" comes from PR 43's `artifact-envelope.md`, not the spec's derivation table.
- The review template's Upkeep line uses Low / Medium / High in place of the old `[Active / Moderate / Inactive]` placeholder, which no skill ever emitted.
- Portability target: the checklist said "If Not portable, ask the contributor to centralize configuration before accepting"; the rubric says below-target is "accept with suggestions" with that ask, which is what the decision table already said.
- Upkeep target: the checklist's "flag for follow-up review in 6 months" becomes "the catalog will schedule it; no manual tracking", per the spec's out-of-scope decision.

---

### Task 1: Branch, spec note, and the structural test (red)

**Files:**
- Create: `tests/test-docs-spine.sh`
- Modify: `docs/design/specs/2026-09-09-appverse-review-dimension-alignment-design.md` (one paragraph under "Plan B")

**Interfaces:**
- Produces: branch `feat/plan-b-rubric` off `origin/main`; a bash test that encodes the document structure Tasks 2–4 must satisfy. Later tasks run it after each change; it must go green by the end of Task 4.

- [ ] **Step 1: Create the branch**

```bash
cd ~/Sites/connectci/appverse-review
git fetch origin --quiet
git switch -c feat/plan-b-rubric origin/main
```

- [ ] **Step 2: Record the node-reuse decision in the spec**

In `docs/design/specs/2026-09-09-appverse-review-dimension-alignment-design.md`, directly under the line `### Plan B — checklist split + rubric + Drupal (cross-repo lockstep unit)`, insert:

```markdown
> **Plan-time decision (2026-09-23):** the rubric reuses portal node 12246 (retitled, re-aliased to `/appverse-review-rubric`) rather than a new node. `redirect.settings.yml` has `auto_redirect: true`, so the alias change creates the 301 from `/appverse-security-rubric` automatically. See `docs/superpowers/plans/2026-09-23-appverse-review-plan-b-rubric.md`.
```

- [ ] **Step 3: Write the structural test**

Create `tests/test-docs-spine.sh`:

```bash
#!/usr/bin/env bash
# Structural test for the Reviewer Process + Review Rubric split (Plan B).
# Asserts the two reference docs have the spine headings, that the old
# Required/Quality bucketing is gone, that the security content moved intact,
# and that no file in the repo still points at security-rubric.md.
set -u
cd "$(dirname "$0")/.."

pass=0; fail=0
ok()   { echo "  PASS  $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail+1)); }
has()  { grep -q -F -- "$2" "$1" && ok "$3" || bad "$3"; }
lacks(){ grep -q -F -- "$2" "$1" && bad "$3" || ok "$3"; }

RUBRIC=references/review-rubric.md
PROCESS=references/review-checklist.md

echo "Test 1: files"
[ -f "$RUBRIC" ] && ok "rubric exists" || bad "rubric exists"
[ -f "$PROCESS" ] && ok "process doc exists" || bad "process doc exists"
[ -f references/security-rubric.md ] && bad "security-rubric.md removed" || ok "security-rubric.md removed"

echo "Test 2: rubric spine headings (in order)"
expected_rubric="# Appverse Review Rubric
## How to read this rubric
## Repo shapes
## Structure (gate criteria)
## Security
## Portability
## Documentation
## Code Quality
## Upkeep
## Decision rubric
## Appendix: common issues in real apps"
headings() { awk '/^```/{f=!f; next} !f' "$1" | grep -E '^#{1,2} '; }   # skip fenced code blocks
actual_rubric=$(headings "$RUBRIC")
[ "$actual_rubric" = "$expected_rubric" ] && ok "H1/H2 sequence" || { bad "H1/H2 sequence"; diff <(echo "$expected_rubric") <(echo "$actual_rubric"); }

echo "Test 3: process doc headings (in order)"
expected_process="# Appverse Reviewer Process
## Before you start
## Step 1: Gate the app
## Step 2: Open the review report
## Step 3: Verify the findings
## Step 4: Curate the feedback
## Step 5: Decide
## Appendix: Review template"
actual_process=$(headings "$PROCESS")
[ "$actual_process" = "$expected_process" ] && ok "H1/H2 sequence" || { bad "H1/H2 sequence"; diff <(echo "$expected_process") <(echo "$actual_process"); }

echo "Test 4: the two-bucket scheme is gone"
lacks "$RUBRIC"  "## Required Criteria" "rubric has no Required Criteria heading"
lacks "$RUBRIC"  "## Quality Criteria"  "rubric has no Quality Criteria heading"
lacks "$PROCESS" "## Required Criteria" "process has no Required Criteria heading"
lacks "$PROCESS" "## Quality Criteria"  "process has no Quality Criteria heading"

echo "Test 5: security content moved intact"
for code in OODT-01 OODT-02 OODT-03 OODT-04 OODT-05 OODT-06 OODT-07 OODT-08; do
  has "$RUBRIC" "| $code |" "rubric lists $code"
done
has "$RUBRIC" "### Capability baseline: Batch Connect apps" "batch-connect baseline present"
has "$RUBRIC" "### Capability baseline: Passenger apps"     "passenger baseline present"
has "$RUBRIC" "### Pattern checks (all app types)"           "pattern checks present"
has "$RUBRIC" "GHSA-2cwp-8g29-9q32"                          "advisory reference kept"

echo "Test 6: three legs and derivation present"
has "$RUBRIC" "Signals do not gate; the decision rubric does." "gate/signal separation stated"
has "$RUBRIC" "| **Accept with suggestions** |" "decision table present"
has "$RUBRIC" "Low = " "Low/High polarity stated"
for dim in Security Portability Documentation Upkeep; do
  has "$RUBRIC" "**$dim signal:**" "$dim derivation line"
done

echo "Test 7: enumerated named checks"
has "$RUBRIC" "check: icon-matches-target-os" "icon check"
has "$RUBRIC" "check: numeric-field-bounds"   "bounds check"
has "$RUBRIC" "check: hardcoded-site-paths"   "site-path check"

echo "Test 8: no referrer still points at the old file or slug"
stale=$(git grep -n -F -e "security-rubric.md" -e "appverse-security-rubric" \
  -- . ':!docs' ':!reviews' ':!tests' ':!references/review-rubric.md' || true)
[ -z "$stale" ] && ok "no stale references" || { bad "no stale references"; echo "$stale"; }

echo
echo "Done: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
```

Note on Test 8: it scans tracked files only (`git grep`), because the working tree has untracked roadmap drafts at the repo root that mention the old file. `review-rubric.md` is allowed to mention the old slug once, in its own "moved from" note, so it is excluded. `docs/` and `reviews/` hold history and are excluded. Tests 2 and 3 skip fenced code blocks, since the Process doc's verbatim JSON:API section contains bash comment lines that would otherwise read as headings.

- [ ] **Step 4: Run it and confirm it fails**

```bash
chmod +x tests/test-docs-spine.sh
bash tests/test-docs-spine.sh
```

Expected: exit code 1. Test 1 fails on "rubric exists" and "security-rubric.md removed"; Tests 2, 3, 5, 6, 7, 8 fail; in Test 4 the two rubric-side checks pass vacuously (the file does not exist yet) and the two process-side checks fail. Roughly 3 passed, 29 failed.

- [ ] **Step 5: Commit**

```bash
git add tests/test-docs-spine.sh docs/design/specs/2026-09-09-appverse-review-dimension-alignment-design.md docs/superpowers/plans/2026-09-23-appverse-review-plan-b-rubric.md
git commit -m "test: structural test for the Process/Rubric split; add Plan B and record node-reuse decision"
```

---

### Task 2: Write `references/review-rubric.md`

**Files:**
- Create: `references/review-rubric.md`
- Read (sources to move from): `references/review-checklist.md`, `references/security-rubric.md`

**Interfaces:**
- Produces: the section names the skills will cite in Task 4: `Repo shapes`, `Structure (gate criteria)`, `Security`, `Portability`, `Documentation`, `Code Quality`, `Upkeep`, `Decision rubric`. Produces the three named checks with these exact labels: `check: icon-matches-target-os`, `check: numeric-field-bounds`, `check: hardcoded-site-paths`.

"Verbatim" below means copy the referenced lines of the current file unchanged except where an edit is called out. Line numbers refer to the files as they are on `origin/main` at `f389f99`.

- [ ] **Step 1: Write the file**

Create `references/review-rubric.md` with this content. Where a block says *verbatim from X:N–M*, paste those lines.

````markdown
# Appverse Review Rubric

> **Related Docs:**
> [Appverse Reviewer Process](https://openondemand.connectci.org/appverse-reviewer-checklist) |
> [Appverse Contributor Guide](https://openondemand.connectci.org/appverse-contributor-documentation) |
> [Appverse Best Practices](https://openondemand.connectci.org/appverse-best-practices) |
> [Appverse README Template](https://github.com/tamu-edu/appverse_readme_template)

The criteria for Appverse app review. The automated review (Appverse Review)
and the human reviewer both work from this document; the
[Reviewer Process](https://openondemand.connectci.org/appverse-reviewer-checklist)
says what to do with it and in what order. This page replaces the earlier
Security Rubric, which is now the Security section below.

## How to read this rubric

A review produces three kinds of content. Keeping them apart is the point of
this document.

1. **Gate criteria (pass / fail).** Hard requirements an app must meet to be
   listed. They live in the Structure section. An app that fails one cannot be
   accepted until it is fixed.
2. **Signals (Low / Medium / High).** A per-dimension reading for a deployer
   on four axes: Security, Portability, Documentation, and Upkeep. **Low = the
   good end; High = the most to read before deploying**, on every axis.
   Signals describe; they never decide. A High signal on its own does not
   reject an app, and a Low signal does not accept one.
3. **The decision.** Accept, accept with suggestions, request changes, or
   reject, derived from the gate criteria and from properties of individual
   findings. The rules are in the Decision rubric section at the end.

**Signals do not gate; the decision rubric does.** Two consequences worth
stating: a fixable High-severity security finding is "request changes", not
"reject", even though it makes the Security signal High; and a Documentation
or Portability signal below the target for inclusion lands in "accept with
suggestions", not "request changes".

**Code Quality** is a fourth kind of content: findings that are neither a gate
nor a signal. They are reported as findings and the decision rubric sets a
target for two of them (error handling and input validation).

**The README has two roles.** "README present and substantive" is a Structure
gate (a stub fails). README depth (Minimal / Adequate / Strong / Exemplary)
is the Documentation signal. Same file, two different legs.

Each finding the automated review records carries a rule code (`STR-`, `OODT-`,
`QUA-`, `MNT-`), a severity, and `file:line` evidence. The severity scale is
defined in the plugin's `finding-codes.md`.

## Repo shapes

*(verbatim from review-checklist.md:89–103, then append the two paragraphs
below; the verbatim block already says shared_paths are reviewed once at repo
level and included in the security review, so the first appended paragraph is
one sentence)*

`shared_paths` is scope input for the security review; it is not a pass/fail
criterion.

`appverse.yml` is optional when a root `manifest.yml` is present: the catalog
infers a single app from the manifest. A repo with neither file has no
identifiable shape and fails the Structure gate below.

## Structure (gate criteria)

All of these are pass / fail. Every one must pass for the app to be listed.

### Repository structure

Every repo, regardless of shape:

| Check | What to look for |
|-------|------------------|
| `README.md` exists and is substantive | Not the unfilled template (placeholder text like "Key feature 1"), not just a title and contact line. Depth is rated separately as the Documentation signal |
| `LICENSE` exists | Open source license present (MIT recommended) |
| Repo shape is identifiable | Root `appverse.yml` (declared) or root `manifest.yml` (inferred) — see Repo shapes |
| Repo is not archived on GitHub | An archived repo cannot be maintained |

README and LICENSE are checked once at repo level. In a monorepo the apps share
them; an app-level README at a subpath is welcome but is not required by this
gate.

**Inferred repos** (root `manifest.yml`, no `appverse.yml`):

*(verbatim from review-checklist.md:121–123)*

**Declared repos** (root `appverse.yml`), checked per app after field-precedence
resolution. The same fields are required whether the repo declares one app or
several:

*(verbatim from review-checklist.md:127–133, with two edits: in the `software`
row replace "see Software Entry Check for what to do when it doesn't" with
"see the Reviewer Process, Software entry check, for what to do when it
doesn't"; in the `maintainer` row replace "a missing one is a required-criteria
failure" with "a missing one fails this gate")*

### Batch Connect layout

Standard OOD structure: `form.yml` or `form.yml.erb`, `submit.yml.erb`, and a
`template/` directory containing the job script (`script.sh.erb`, or `script.sh`
when nothing is templated). OOD renders `form.yml.erb` at request time, so an
app shipping only the `.erb` variant is complete; shipping both is unusual and
worth a look.

Passenger and companion apps substitute their own layout check: an entry point
that exists and parses (`config.ru` for Ruby/Rack, `passenger_wsgi.py` for
Python/WSGI), a `manifest.yml` `role` consistent with that layout, and a
dependency manifest (`Gemfile.lock`, `package-lock.json`, `requirements.txt`)
consistent with the dependency file.

### Validity

| Check | What to look for |
|-------|------------------|
| `manifest.yml` and `appverse.yml` are valid YAML | Parse without errors |
| `form.yml` is valid YAML; `form.yml.erb` has balanced ERB tags | `form.yml.erb` cannot be YAML-parsed before rendering, so it is checked for balanced `<% %>` tags instead |
| Template scripts are syntactically correct | ERB templates render; shell scripts pass `bash -n` (for `.sh.erb`, strip ERB tags first — see [security-tools.md](https://github.com/Sweet-and-Fizzy/appverse-review/blob/main/references/security-tools.md)). This is a gate. Shellcheck is a best-effort tier-2 tool: run it when available, but its absence never fails this criterion |
| No obviously broken references | Module names, paths, and variables referenced in `submit.yml.erb` and `template/` exist in `form.yml` or `form.yml.erb` |

## Security

Security is both a **signal** (how much a deployer should read before
installing) and a source of **findings**, some of whose properties feed the
decision rubric directly. Every finding is classified under the OODT taxonomy
and rated on the five-level severity scale.

**Security signal:** no security findings = Low; Low or Info severity only =
Medium; any Medium, High, or Critical finding = High. The signal counts
`OODT-` findings only; a high-severity Structure failure does not move it.

**Decision role:** a finding tagged *potentially malicious*, or one that cannot
be fixed without redesigning the app, is a reject trigger. A fixable High
finding is "request changes". Low and Medium findings do not by themselves
block "accept with suggestions" (see Decision rubric).

### How the automated review checks security

The security review has three tiers, named in every report so a thinner
review looks thinner rather than identical to a full one:

- **Tier 1 — Static.** Source-level reading: capability profile and pattern
  checks. Runs anywhere, including CI on a submitted pull request.
- **Tier 2 — Tooling.** Static analysis tools (shellcheck, bandit, semgrep,
  trivy, and others per the plugin's `security-tools.md`). Needs installed
  binaries, not a running app. Best-effort: the review proceeds without them.
- **Tier 3 — Runtime.** Boot the app and exercise it. Realistically only on a
  reviewer's machine. A CI run reports it as `NOT CHECKED — requires a running
  app`.

Two complementary methods feed the same classification. The **capability
profile** catalogs what the app does (system access, network calls, file
reads and writes, spawned processes, dynamic code loading, authentication
posture) and compares it with the baseline for the app's type below. The
**pattern checks** catch capabilities used unsafely, regardless of app type.

*(verbatim from security-rubric.md:10–21, the two bullets explaining the
methods)*

### Capability baseline: Batch Connect apps

*(verbatim from security-rubric.md:25–37)*

### Capability baseline: Passenger apps

*(verbatim from security-rubric.md:41–61)*

### Pattern checks (all app types)

*(verbatim from security-rubric.md:65–83)*

### OODT — Open OnDemand App Threats

*(verbatim from security-rubric.md:87–104)*

### Rating findings

*(verbatim from security-rubric.md:108–138, including the closing blockquote
that says numeric scoring, the commit-polling pipeline, and catalog badges are
defined elsewhere)*

## Portability

How much a deployer at another site has to change before the app runs.

| Level | Description |
|-------|-------------|
| **Not portable** | Hardcoded paths, cluster names, module versions throughout |
| **Partially portable** | Some hardcoding, but main config is in form.yml attributes |
| **Portable** | All site-specific values centralized and clearly marked |

**Portability signal:** Portable = Low; Partially portable = Medium; Not
portable = High.

**Target for inclusion:** Partially portable or above. Below the target is
"accept with suggestions" when the gate criteria pass; ask the contributor to
centralize configuration.

Where to look: `submit.yml.erb`, `form.yml`, `form.yml.erb`, and `template/`
scripts, for cluster names, partitions, accounts, absolute site paths, and
module versions.

**Named checks** (recorded as `QUA-02` findings with `file:line` evidence):

- `check: hardcoded-site-paths` — scratch, project, or home paths, cluster or
  partition names, or a module version that appears in a script or template
  rather than in a `form.yml` attribute or a documented configuration value.
  Documented site-specific values in the README's configuration table count
  toward Partially portable; undocumented ones count against it.

## Documentation

How well the README answers a deployer who has never seen the app. The README
should follow the [Appverse README Template](https://github.com/tamu-edu/appverse_readme_template).

*(verbatim from review-checklist.md:141–146, the four-questions table)*

| Level | Description |
|-------|-------------|
| **Minimal** | What it launches + prerequisites only |
| **Adequate** | Above + installation + configuration + known limitations |
| **Strong** | Above + troubleshooting + screenshots + environment variable docs |
| **Exemplary** | Above + user-facing info panel + architecture explanation |

**Documentation signal:** Strong or Exemplary = Low; Adequate = Medium;
Minimal = High.

**Target for inclusion:** Adequate or above. Below the target is "accept with
suggestions" when the gate criteria pass. A README that fails the Structure
gate (stub or unfilled template) is a gate failure, not a Minimal rating. The
four questions above are how the signal is rated; they are not a gate. This
was previously listed under "Required Criteria" as Documentation Minimum, and
the earlier reviewer checklist and report disagreed about it; the split here
is the resolution.

**Red flags** (recorded as `QUA-01` findings):

*(verbatim from review-checklist.md:151–152 only, the "different institution's
paths" and "No Configuration section" bullets; 149–150 are the stub/unfilled
template cases, which are the Structure gate above, not a rating)*

## Code Quality

Findings about how the app is written. They are not a signal and not a gate.
They are reported with `file:line` evidence, and the decision rubric sets a
target for the first two.

| Check | Target |
|-------|--------|
| Error handling in scripts (`set -e` or explicit checks) | Target for inclusion |
| Input validation on form fields (min/max/required) | Target for inclusion |
| No undocumented magic numbers or hardcoded literals (resource limits, tunables, ports, hex colors, module versions) without comments | Suggestion |
| No large blocks of duplicated code | Suggestion |
| No commented-out dead code | Suggestion |
| ERB templates handle missing/empty values gracefully | Suggestion |

**Correctness and polish** defects are also Code Quality findings: copy-paste
artifacts from the template an app was cloned from (a MATLAB reference in a
SAS app, a CHANGELOG describing a different app), duplicate YAML keys (valid
YAML, but last-wins, so the parser does not catch them and the author almost
certainly did not intend it), wrong help text, and README typos.

**Named checks:**

- `check: numeric-field-bounds` — every numeric form field (`number_field`,
  or a text field that is parsed as a number in `submit.yml.erb`) has `min`
  and `max`, and free-text fields that reach the scheduler have a `pattern` or
  are otherwise constrained. A missing bound is an input-validation finding.
- `check: icon-matches-target-os` — desktop and panel configuration under
  `template/` (for example `xfce4-panel.xml` `button-icon`, `.desktop` `Icon=`)
  references an icon that exists on the OS the README says the app was tested
  on. A Fedora icon in an app documented for Rocky Linux is a polish finding.

## Upkeep

Repo-level signals about the project's health. Upkeep is a signal on the repo,
not on each app.

*(verbatim from review-checklist.md:215–222, the signals table)*

**Upkeep signal:** active within 12 months and two or more good-practice
signals = Low; active within 12 months = Medium; inactive over 12 months =
High. The good-practice signals are releases, a current CHANGELOG, CI,
multiple contributors, and responded-to issues. A repo with no open issues is
neutral on that last signal: it counts neither for nor against, because there
is no evidence of responsiveness either way.

**Target for inclusion:** active within 12 months. For a brand-new app, waive
the history requirement and say so in the evidence phrase; the follow-up
review of brand-new apps will be scheduled by the catalog once reviews are
stored there, so no manual tracking is needed today.

**Decision role:** an abandoned or unmaintained repo is a reject trigger.
Good-practice signals never push the axis down and never fail an app.

*(verbatim from review-checklist.md:226, the paragraph beginning "The other
signals")*

## Decision rubric

The reviewer's decision. Derived from the gate criteria and from properties of
individual findings, never from the signal levels.

*(verbatim from review-checklist.md:267–272, the four-row table)*

Any Accept is conditional on the catalog checks the automated review cannot
perform (duplicate check, Software entry, vocabulary terms); the Reviewer
Process says how to run them.

## Appendix: common issues in real apps

*(verbatim from review-checklist.md:288–300)*
````

- [ ] **Step 2: Resolve every verbatim block**

Open `references/review-checklist.md` and `references/security-rubric.md` at the cited lines and paste the content in place of each `*(verbatim from …)*` marker. Then confirm no marker remains:

```bash
grep -n "verbatim from" references/review-rubric.md
```

Expected: no output.

- [ ] **Step 3: Run the structural test**

```bash
bash tests/test-docs-spine.sh
```

Expected: Test 1 "rubric exists" passes; Tests 2, 5, 6, 7 pass; Test 4's rubric-side checks pass and its process-side checks fail; Tests 1 (security-rubric.md removed), 3, and 8 still fail. If Test 2 fails, its diff shows which heading is off.

- [ ] **Step 4: Commit**

```bash
git add references/review-rubric.md
git commit -m "docs: add the general Review Rubric on the dimension spine"
```

---

### Task 3: Rewrite `references/review-checklist.md` as the Reviewer Process

**Files:**
- Modify: `references/review-checklist.md` (full rewrite; filename unchanged)

**Interfaces:**
- Consumes: the rubric section names from Task 2.
- Produces: the H2 sequence Test 3 expects; the sections `Step 1: Gate the app` (duplicate check, Software entry, JSON:API reads) and `Step 4: Curate the feedback` that the skills cite in Task 4.

- [ ] **Step 1: Write the file**

Replace the whole file with this content. Line numbers in verbatim markers refer to the file *before* this rewrite (as on `origin/main`); take a copy first:

```bash
cp references/review-checklist.md /tmp/planB-checklist-before.md
```

````markdown
# Appverse Reviewer Process

> **Related Docs:**
> [Appverse Review Rubric](https://openondemand.connectci.org/appverse-review-rubric) |
> [Appverse Contributor Guide](https://openondemand.connectci.org/appverse-contributor-documentation) |
> [Appverse Best Practices](https://openondemand.connectci.org/appverse-best-practices) |
> [Appverse README Template](https://github.com/tamu-edu/appverse_readme_template)

What a reviewer does, in the order it happens, when an app is submitted to the
Appverse catalog. The criteria themselves live in the
[Review Rubric](https://openondemand.connectci.org/appverse-review-rubric);
this page only refers to them.

The goal of review is to ensure that apps in the catalog are **useful,
deployable, and maintainable** by the broader HPC community. We're not looking
for perfection — we're looking for apps that meet a quality bar and don't
create confusion in the catalog.

Most of the checking is done by **Appverse Review**, which produces an
evidence-backed report covering structure, security, quality, and maintenance,
with `file:line` findings, Low / Medium / High signals per dimension, and a
recommended decision. The reviewer receives that report, verifies it, curates
the feedback, and makes the call. The review recommends; a human decides.

## Before you start

*(verbatim from /tmp/planB-checklist-before.md:232, the "Apps awaiting review"
paragraph)*

The report is generated against a specific commit. If the repo has moved on
since the report was run, get a fresh report before doing anything else.

## Step 1: Gate the app

Decide whether this app belongs in the catalog at all, before reading about its
quality.

*(verbatim from /tmp/planB-checklist-before.md:19–26, the four-question table
and its lead-in)*

### Duplicate check

*(verbatim from /tmp/planB-checklist-before.md:30–38)*

### Reading the catalog without a login

*(verbatim from /tmp/planB-checklist-before.md:42–70)*

### Software entry check

*(verbatim from /tmp/planB-checklist-before.md:74–85; its "Query for it with
the command above" now correctly points at the section above)*

Monorepos: a declared repo with an `apps:` list is reviewed as one app per
entry, each with its own findings and its own decision (see the rubric's Repo
shapes section). Gate the repo once; decide per app.

## Step 2: Open the review report

Begin with the Appverse Review report for the submitted repo. Read the header
first: the reviewed commit, the version of the review tool, and the disclaimer.
The report is organized the way the rubric is:

- **Repo-level gate criteria** (pass / fail) and the repo's **Upkeep** signal.
- Per app: a **Signals** block (Security, Portability, Documentation at Low /
  Medium / High with an evidence phrase), then the app's **Structure** gate
  results, then **Security**, **Portability**, **Documentation**, and **Code
  Quality** findings, each with a rule code, severity, and `file:line`.
- **Review scope**: which security tiers ran and what was not checked.
- **Catalog checks** the tool could not perform, left for you.
- The tool's **recommendation** and rationale, and a **draft feedback** note.

Low is the good end of every signal. A High signal means "read this section
before deploying", not "reject".

## Step 3: Verify the findings

*(verbatim from /tmp/planB-checklist-before.md:249–263, "Read the report
against the repo…" through "…before it reaches the contributor.", with two
edits: in item 3 replace "Quality ratings" with "Portability and Documentation
ratings"; in item 4 replace "Maintenance signals are current" with "Upkeep
signals are current")*

## Step 4: Curate the feedback

The draft feedback in the report is the tool's first pass. Make it yours:

- Every item in the feedback must already appear as a finding in the report.
  If you notice a real defect the report missed, add it as a finding first,
  then mention it.
- Genuine fix-items (Low severity and above, plus any failed gate criterion)
  belong in the feedback. Info-level polish can be summarized or left out.
- Be specific: name the file and line, say what to change, and link an example
  where one exists.

*(verbatim from /tmp/planB-checklist-before.md:278–284, the good/poor feedback
examples and the Best Practices link)*

## Step 5: Decide

Apply the [Decision rubric](https://openondemand.connectci.org/appverse-review-rubric):
accept, accept with suggestions, request changes, or reject. The decision comes
from the gate criteria and from properties of individual findings (a
potentially-malicious security finding, an unmaintained repo, a duplicate).
It does not come from the signal levels: a High signal is something a deployer
should read, not a reason to reject.

Any Accept is conditional on the catalog checks in Step 1. If one could not be
run, say which and why in the feedback rather than leaving it unmarked.

Record the decision in the catalog (moderation state on the app) and send the
feedback to the contributor by the channel the submission came in on.

## Appendix: Review template

Copy this template when recording a review by hand:

```markdown
## App Review: [App Name]

**Repository:** [URL]
**Reviewed commit:** [SHA] ([date])
**Reviewer:** [Name]
**Date:** [Date]

### Gate criteria
- [ ] Repo shape identifiable and required metadata present (see the rubric's Structure section)
- [ ] README.md (substantive)
- [ ] LICENSE (open source)
- [ ] Standard OOD app structure and valid YAML / templates

For Monorepos: repeat the per-app criteria and decision for each entry in `apps[]`.

### Signals
- Security: [Low / Medium / High] — findings classified under OODT, with severity and file:line evidence
- Portability: [Low / Medium / High] — [Not portable / Partially portable / Portable]
- Documentation: [Low / Medium / High] — [Minimal / Adequate / Strong / Exemplary]
- Upkeep (repo): [Low / Medium / High] — last commit, releases, CI, CHANGELOG

### Code quality
- Findings with file:line evidence

### Catalog checks
- [ ] Duplicate check against the existing catalog — [outcome and rationale]
- [ ] `software` value matches a catalog Software entry (create the entry if the software should exist)
- [ ] `app_type` and `implementation_tags` are in the catalog vocabularies

Query these against the public JSON:API — see "Reading the catalog without a
login". Record what each returned. If one could not be run, say which and why,
rather than leaving it unmarked.

### Decision: [Accept / Accept with suggestions / Request changes / Reject]
- If any catalog check above could not be run, Accept is conditional on it

### Feedback
[Specific items to address or improve — every item must already appear above]
```
````

- [ ] **Step 2: Resolve every verbatim block and confirm nothing was dropped**

```bash
grep -n "verbatim from" references/review-checklist.md          # expect none
grep -c "" /tmp/planB-checklist-before.md references/review-checklist.md references/review-rubric.md
```

Then check that each of these strings from the old checklist now appears in at least one of the two new files (`grep -l`): `Same app, forked with minor changes`, `Add Appverse Software form`, `filter%5Btitle%5D`, `maintainer.support_url`, `Key feature 1`, `Within 12 months`, `CORS open to all origins`, `ProteinStructure-OOD`, `Missing or stub README`. (`Not portable` appears in both, in the rubric's table and the Process appendix template; that is expected.)

- [ ] **Step 3: Run the structural test**

```bash
bash tests/test-docs-spine.sh
```

Expected: Tests 3 and 4 pass; only "security-rubric.md removed" (Test 1) and Test 8 still fail.

- [ ] **Step 4: Commit**

```bash
git add references/review-checklist.md
git commit -m "docs: rewrite the checklist as the Reviewer Process, in work order"
```

---

### Task 4: Delete `security-rubric.md` and re-point every referrer

**Files:**
- Delete: `references/security-rubric.md`
- Modify: `skills/review-security/SKILL.md:9-14`, `skills/review-structure/SKILL.md:9-11,26,30`, `skills/review-quality/SKILL.md:9-11,19,30-32`, `skills/review-maintenance/SKILL.md:9-11,35,40,45`, `skills/review-app/SKILL.md:13-14,64,162,168,172,188,197,228`, `references/finding-codes.md:91`, `README.md:9-10,123-124,170-172`, `CLAUDE.md:35-40`

**Interfaces:**
- Consumes: rubric section names (Task 2), process section names (Task 3).
- Produces: every skill reads `review-rubric.md` for criteria and `review-checklist.md` only for process; the report header's rubric link is `https://openondemand.connectci.org/appverse-review-rubric`.

Line numbers are as on `origin/main` at `f389f99`. Always locate an edit by its quoted text, not the number.

- [ ] **Step 0: Rebase onto current main and account for PR 43**

```bash
git fetch origin
git rebase origin/main
git log --oneline -3 origin/main
```

If PR 43 (`mkonda/indicator-levels`, indicator levels in the artifact) has merged, three things change for this task: `review-app/SKILL.md` lines after 43 shift by up to 17 (64→66, 162→172, 168→178, 172→182, 188→205, 197→214, 228→245); `review-quality` and `review-maintenance` cited lines keep their numbers; and `review-maintenance/SKILL.md` gains one more referrer at its line 70, `` `true` only when you are applying the checklist's brand-new-app waiver ``, which becomes `` `true` only when you are applying the rubric's brand-new-app waiver ``. If PR 43 has not merged, note in the plugin PR body that whichever lands second must re-run `tests/test-docs-spine.sh` after merging.

- [ ] **Step 1: Delete the old file**

```bash
git rm references/security-rubric.md
```

- [ ] **Step 2: review-security**

Replace lines 9–14 (the paragraph beginning `Rubric:`) with:

```markdown
Rubric: `${CLAUDE_PLUGIN_ROOT}/references/review-rubric.md` — section
"Security". Read it before starting. It defines the check tiers, the
capability baselines per app type, the pattern checks, and the OODT (Open
OnDemand App Threats) taxonomy. Expand OODT on first use in the report and
link it to the published rubric at
https://openondemand.connectci.org/appverse-review-rubric so readers can look
up a code.
```

- [ ] **Step 3: review-structure**

Replace lines 9–11 with:

```markdown
Criteria: `${CLAUDE_PLUGIN_ROOT}/references/review-rubric.md` — sections
"Repo shapes" and "Structure (gate criteria)". The substantive-README gate is
yours; README depth is review-quality's job.
```

Line 26: `per the checklist's Repository` → `per the rubric's Repository` (the following line's `Structure section` stays; the rubric H3 is "Repository structure"). Line 30: `(see the checklist's "Reading the catalog without a` → `(see the Reviewer Process doc, \`${CLAUDE_PLUGIN_ROOT}/references/review-checklist.md\`, "Reading the catalog without a`.

- [ ] **Step 4: review-quality**

Replace lines 9–11 with:

```markdown
Criteria: `${CLAUDE_PLUGIN_ROOT}/references/review-rubric.md` — sections
"Portability", "Documentation", and "Code Quality", including the
target-for-inclusion thresholds and the named checks (`check: …`) in each.
Run every named check in those sections and record a finding for each one
that fails, with `file:line` evidence.
```

Line 19: `checklist's documentation table` → `rubric's Documentation table`. Lines 30–32: `The checklist's Code Quality section says which of these are` → `The rubric's Code Quality section says which of these are`; `finding the way the checklist frames it` → `finding the way the rubric frames it`.

- [ ] **Step 5: review-maintenance**

Replace lines 9–11 with:

```markdown
Criteria: `${CLAUDE_PLUGIN_ROOT}/references/review-rubric.md` — section
"Upkeep", including its target-for-inclusion line and the brand-new-app
waiver.
```

Line 35: `checklist's table` → `rubric's table`. Line 40: `the way the checklist's Maintenance Signals section frames it` → `the way the rubric's Upkeep section frames it`. Line 45: `consistent with the checklist and with your other` → `consistent with the rubric and with your other`.

- [ ] **Step 6: review-app**

Lines 13–14 become:

```markdown
- `${CLAUDE_PLUGIN_ROOT}/references/review-rubric.md` (canonical criteria,
  including the decision rules in its "Decision rubric" section)
- `${CLAUDE_PLUGIN_ROOT}/references/review-checklist.md` (the Reviewer
  Process: catalog checks, feedback curation)
```

Line 64: replace `https://openondemand.connectci.org/appverse-security-rubric` with `https://openondemand.connectci.org/appverse-review-rubric`.

Lines 162, 168, 172: `the checklist's "Reading the catalog` → `the Reviewer Process's "Reading the catalog`; `per the checklist's Duplicate Check` → `per the Reviewer Process's Duplicate check`; `see the checklist's Software Entry Check` → `see the Reviewer Process's Software entry check`.

Line 188: `Apply the decision rubric below (from the checklist's Step 3):` → `Apply the decision rubric below (from the rubric's "Decision rubric" section):`. Line 197: `Follow the checklist's framing (Step 3) rather than a separate copy here.` → `Follow the rubric's framing rather than a separate copy here.` Line 228: `checklist's feedback guidance` → `Reviewer Process's feedback guidance (Step 4)`.

- [ ] **Step 7: finding-codes, README, CLAUDE.md**

`references/finding-codes.md:91`: `` `security-rubric.md`. `` → `` the Security section of `review-rubric.md`. ``

`README.md:9–10`:
```markdown
[reviewer process](references/review-checklist.md) and
[review rubric](references/review-rubric.md).
```
`README.md:123–124`:
```
  review-checklist.md    Reviewer Process (work-ordered; published as the reviewer page)
  review-rubric.md       Review Rubric: gate criteria, signal dimensions, OODT taxonomy, decision rules
```
`README.md:170–172`:
```markdown
- **Rubric changes** — edit [references/review-rubric.md](references/review-rubric.md)
  and update the corresponding skill files
- **Security taxonomy** — edit the Security section of [references/review-rubric.md](references/review-rubric.md)
  and update OODT references in skill files and [tests/TESTING.md](tests/TESTING.md)
```

`CLAUDE.md` lines 35–40: replace the "Security Rubric" section with:

```markdown
## Review Rubric

`references/review-rubric.md` is the canonical review criteria shared by the
review skills, the published reviewer docs (synced to the portal by
DocSync), and the future automated audit pipeline. Its Security section holds
the OODT (Open OnDemand App Threats) taxonomy. Changes here affect all of
them — update carefully and check that OODT category references in skill
files and TESTING.md stay consistent. `references/review-checklist.md` is the
Reviewer Process doc; it contains no criteria definitions.
```

- [ ] **Step 8: Run the structural test and the fixture-consistency check**

```bash
bash tests/test-docs-spine.sh
grep -n "OODT-0[1-8]" tests/TESTING.md | wc -l    # unchanged from before Task 1
```

Expected: `Done: N passed, 0 failed.` and exit 0. TESTING.md is untouched by this plan, so its OODT references remain valid.

- [ ] **Step 9: Commit**

```bash
git add -A references skills README.md CLAUDE.md
git commit -m "refactor: point every skill and doc at the Review Rubric; remove security-rubric.md"
```

---

### Task 5: Regeneration check (the real end-to-end test)

**Files:**
- Create (throwaway, gitignored): `reviews/review-fasrc-ood-sas-planb.md`

**Interfaces:**
- Consumes: the whole branch.
- Produces: evidence that the skills still run against the new reference files and that the report's rubric link and vocabulary are right.

- [ ] **Step 1: Run a review with the branch's skills**

In a Claude Code session with the plugin loaded from this checkout (`claude --plugin-dir ~/Sites/connectci/appverse-review` or the marketplace pointed at the branch), run:

```
/appverse-review:review-app https://github.com/fasrc/ood-sas
```

Save the report as `reviews/review-fasrc-ood-sas-planb.md`.

- [ ] **Step 2: Check the output**

```bash
R=reviews/review-fasrc-ood-sas-planb.md
grep -n "appverse-review-rubric" $R            # header rubric link → new slug
grep -n "appverse-security-rubric" $R           # expect none
grep -n -E "^### (Signals|Structure|Security|Portability|Documentation|Code Quality)" $R
grep -n -i "required criteria\|quality criteria" $R   # expect none in headings
```

Expected: the header links the new slug; the six per-app headings are present in order; no Required/Quality bucket headings. Compare the Signals block and findings against `reviews/review-fasrc-ood-sas-dimensions.md` (the Plan A reference): same five security findings, same ratings.

- [ ] **Step 3: Check the named checks fired where they should**

For fasrc/ood-sas the rubric's named checks should produce: `check: numeric-field-bounds` findings for `custom_num_cores` and `custom_memory_per_node` (no `max`) and `extra_slurm` (unconstrained text); `check: icon-matches-target-os` for `xfce4-panel.xml` `fedora-logo-icon` on a Rocky-tested app; `check: hardcoded-site-paths` for `/scratch/` in `script.sh.erb`. Confirm each appears as a finding with `file:line`.

- [ ] **Step 4: Open a pull request (do not merge yet)**

```bash
git push -u origin feat/plan-b-rubric
gh pr create --title "docs: Reviewer Process + general Review Rubric (Plan B of Bill's feedback)" --body-file - <<'EOF'
## What this is

Plan B of the response to Bill Horka's review-format feedback: the reviewer checklist becomes a work-ordered Reviewer Process doc, and the criteria move into a general Review Rubric on the dimension spine (gate criteria, four Low/Medium/High signal dimensions, Code Quality findings, decision rubric). The Security Rubric is now the rubric's Security section. Every skill reads the rubric by section name, as it read the checklist before.

## Merge order — read before merging

The portal must deploy first: connectci-platform/portal PR <number> changes the DocSync map key from `security-rubric.md` to `review-rubric.md` and the live content ops retitle and re-alias node 12246. Merging this PR before that deploy leaves the live security-rubric page stale (DocSync will log a 404 for the deleted file). See `docs/superpowers/plans/2026-09-23-appverse-review-plan-b-rubric.md` Task 8.

## Deliberate rule changes (not verbatim moves; please review as such)

- Structure gate gains "repo not archived", the Passenger/companion layout check, and `appverse.yml` validity. All three are what the structure skill already enforces; the checklist never listed them. Duplicate YAML keys are named as a Code Quality finding, not a gate.
- README and LICENSE are stated as repo-level checks that a monorepo's apps share.
- The four README questions move from the old pass/fail Documentation Minimum into the Documentation signal. Only a stub or unfilled-template README remains a gate. This matches what the skills already do.
- Portability below target is stated as "accept with suggestions" (the decision table's rule) instead of the checklist's "centralize before accepting".
- Upkeep: a repo with no open issues is neutral on the issue-responsiveness signal (PR #43's assembler currently counts it in favor; that is being changed to match). The six-month re-review flag is described as a future catalog feature rather than a manual step.
- Security signal counts `OODT-` findings only, matching the artifact envelope doc in PR #43.
- The review template's Upkeep line uses Low / Medium / High in place of `[Active / Moderate / Inactive]`.

## Verified

- `tests/test-docs-spine.sh` passes.
- Regenerated the fasrc/ood-sas review under the new files; structure, findings, and ratings match the Plan A reference, the header links `/appverse-review-rubric`, and the three named checks fire where expected.
EOF
```

---

### Task 6: Portal — Jira ticket, worktree, and the DocSync map change (with test)

**Files (cyberteam_drupal):**
- Modify: `web/modules/custom/ood_software/src/Service/DocSyncService.php:44-49`
- Create: `web/modules/custom/ood_software/tests/src/Unit/Service/DocSyncMapTest.php`

**Interfaces:**
- Produces: `DocSyncService::DOC_MAP` maps `…/appverse-review/main/references/review-rubric.md` to `12246` and no longer maps `security-rubric.md`.

- [ ] **Step 1: Create the Jira ticket and the worktree**

Create a D8 ticket in Jira (via `acli` or the UI) using the portal CLAUDE.md structure. Suggested text:

```
Title: Publish the Appverse Review Rubric; retire the Security Rubric page
Why: The appverse-review docs are being split into a Reviewer Process page and a general Review Rubric so the report and the reviewer docs use one vocabulary (Bill Horka's feedback). The portal syncs those docs from GitHub and links to them.
What:
- DocSyncService::DOC_MAP: replace the security-rubric.md key with review-rubric.md, same node (12246).
- views.view.my_appverse: intro text links both the Reviewer Process and the Review Rubric.
- Live content ops (after deploy): retitle node 11932 to "Appverse Reviewer Process" and node 12246 to "Appverse Review Rubric" with alias /appverse-review-rubric (auto-redirect from /appverse-security-rubric).
Testing: unit test DocSyncMapTest asserts the review-rubric key is present, the security-rubric key is absent, and every key is a raw.githubusercontent.com markdown URL. View text is presentation only; verified in the browser. Redirect verified with curl on live after the content ops.
```

Then, from the main portal checkout (never raw `git worktree add`):

```bash
cd ~/Sites/connectci/cyberteam_drupal
git fetch origin
git branch md-<ticket> origin/md-dev
vendor/bin/robo tree:new md-<ticket>
```

`tree:new` has left the DB empty on this machine before (its inner import runs inside the container). If `ddev drush status` in the new worktree shows no DB, finish it by hand:

```bash
cd ~/Sites/connectci/worktrees/md-<ticket>
ddev import-db --file=backups/site.sql.gz
ddev drush cset --input-format=yaml jsonapi_extras.settings validate_configuration_integrity false -y
ddev drush deploy -y
ddev drush sset drupal_seamless_cilogon.seamless_login_enabled 0
mkdir -p web/profiles
```

- [ ] **Step 2: Write the failing unit test**

Create `web/modules/custom/ood_software/tests/src/Unit/Service/DocSyncMapTest.php`:

```php
<?php

namespace Drupal\Tests\ood_software\Unit\Service;

use Drupal\ood_software\Service\DocSyncService;
use Drupal\Tests\UnitTestCase;

/**
 * Guards the DocSync source map: which GitHub files feed which doc nodes.
 *
 * The map is a constant, so the test is a contract check: the Review Rubric
 * source is present, the retired Security Rubric source is gone, and every
 * key is a raw.githubusercontent.com markdown URL that basename() can name.
 *
 * @group ood_software
 *
 * @coversDefaultClass \Drupal\ood_software\Service\DocSyncService
 */
class DocSyncMapTest extends UnitTestCase {

  const RUBRIC_URL = 'https://raw.githubusercontent.com/Sweet-and-Fizzy/appverse-review/main/references/review-rubric.md';
  const RETIRED_URL = 'https://raw.githubusercontent.com/Sweet-and-Fizzy/appverse-review/main/references/security-rubric.md';
  const PROCESS_URL = 'https://raw.githubusercontent.com/Sweet-and-Fizzy/appverse-review/main/references/review-checklist.md';

  /**
   * The rubric source feeds node 12246 and the retired source is gone.
   */
  public function testRubricReplacesSecurityRubric(): void {
    $map = DocSyncService::DOC_MAP;
    $this->assertArrayHasKey(self::RUBRIC_URL, $map);
    $this->assertSame(12246, $map[self::RUBRIC_URL]);
    $this->assertArrayNotHasKey(self::RETIRED_URL, $map);
  }

  /**
   * The reviewer process keeps its node.
   */
  public function testProcessDocKeepsNode(): void {
    $this->assertSame(11932, DocSyncService::DOC_MAP[self::PROCESS_URL]);
  }

  /**
   * Every key is a raw GitHub markdown URL and every nid is a positive int.
   */
  public function testMapShape(): void {
    foreach (DocSyncService::DOC_MAP as $url => $nid) {
      $this->assertMatchesRegularExpression('#^https://raw\.githubusercontent\.com/.+/main/.+\.md$#', $url);
      $this->assertIsInt($nid);
      $this->assertGreaterThan(0, $nid);
    }
  }

}
```

- [ ] **Step 3: Run it and confirm it fails**

```bash
cd ~/Sites/connectci/worktrees/md-<ticket>
ddev exec "cd web/modules/custom/ood_software && ../../../../vendor/bin/phpunit tests/src/Unit/Service/DocSyncMapTest.php"
```

Expected: `testRubricReplacesSecurityRubric` fails on `assertArrayHasKey` (rubric URL not present); the other two pass.

- [ ] **Step 4: Change the map**

In `DocSyncService.php`, replace line 46:

```php
    'https://raw.githubusercontent.com/Sweet-and-Fizzy/appverse-review/main/references/security-rubric.md' => 12246,
```

with:

```php
    'https://raw.githubusercontent.com/Sweet-and-Fizzy/appverse-review/main/references/review-rubric.md' => 12246,
```

and update the docblock above the constant (lines 38–43) so the second sentence reads: `Review-skill docs (the reviewer process and the review rubric) are maintained in the appverse-review plugin repo under references/; broader Appverse docs live in ood-appverse under docs/.`

- [ ] **Step 5: Run the test again**

Same command as Step 3. Expected: 3 tests, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add web/modules/custom/ood_software/src/Service/DocSyncService.php web/modules/custom/ood_software/tests/src/Unit/Service/DocSyncMapTest.php
git commit -m "D8-<ticket>: sync the Review Rubric into node 12246 in place of the Security Rubric"
```

---

### Task 7: Portal — view intro text, local render check, PR

**Files (cyberteam_drupal):**
- Modify: `web/sites/default/config/default/views.view.my_appverse.yml:704`

**Interfaces:**
- Produces: the Manage Repos view links both docs by their live aliases.

- [ ] **Step 1: Edit the view text**

Line 704 currently:

```yaml
          content: '<p class="appverse-manage-intro">Reviewing a submission? Follow the <a href="/appverse-reviewer-checklist">Reviewer Checklist</a>.</p>'
```

Change to:

```yaml
          content: '<p class="appverse-manage-intro">Reviewing a submission? Follow the <a href="/appverse-reviewer-checklist">Reviewer Process</a> and the <a href="/appverse-review-rubric">Review Rubric</a>.</p>'
```

Import and check it renders (presentation only, no automated test):

```bash
ddev drush cim -y
ddev drush uli --uri=https://md-<ticket>.ddev.site
```

Open `/appverse/manage-repos` as the admin and confirm the sentence and both links.

- [ ] **Step 2: Render the branch's rubric locally to check DocSync output**

DocSync only runs on live, and the map points at `main`, so simulate one sync against the plugin branch's raw file to check the markdown renders (H1 stripped, TOC rail populated, tables intact):

```bash
RAW=https://raw.githubusercontent.com/Sweet-and-Fizzy/appverse-review/feat/plan-b-rubric/references/review-rubric.md
curl -sL "$RAW" | sed -E '1{/^# /d}' > /tmp/rubric-body.md
ddev drush php:eval '
$n = \Drupal::entityTypeManager()->getStorage("node")->load(12246);
$n->set("body", ["value" => file_get_contents("/var/www/html/../../tmp/rubric-body.md"), "format" => "markdown"]);
$n->save(); echo "ok\n";'
```

If the path mapping into the container is awkward, copy the file into the worktree root first (`cp /tmp/rubric-body.md .` and read `/var/www/html/rubric-body.md`), then delete it. Open `/node/12246` locally: the left rail should list the H2s from "How to read this rubric" to "Appendix", the OODT table should render, and no raw markdown should show. Then reset the local body from the DB backup is unnecessary; this is a local DB.

- [ ] **Step 3: Commit, push, open the PR**

```bash
git add web/sites/default/config/default/views.view.my_appverse.yml
git commit -m "D8-<ticket>: link both reviewer docs from the Manage Repos intro"
git push -u origin md-<ticket>
gh pr create --base md-dev --title "D8-<ticket>: publish the Appverse Review Rubric, retire the Security Rubric page" --body-file - <<'EOF'
## Why
appverse-review is splitting its reviewer docs into a Reviewer Process page and a general Review Rubric (Sweet-and-Fizzy/appverse-review PR <number>). The portal syncs those docs from GitHub and links to them.

## What
- `DocSyncService::DOC_MAP`: `review-rubric.md` now feeds node 12246; the `security-rubric.md` key is removed.
- Manage Repos intro links both the Reviewer Process and the Review Rubric.

## Live content ops (after this deploys, before the plugin PR merges)
See the plugin plan, Task 8: retitle 11932 and 12246, set 12246's alias to `/appverse-review-rubric` (auto-redirect creates the 301 from `/appverse-security-rubric`).

## Testing
- `DocSyncMapTest` (unit): rubric key present → 12246, security-rubric key absent, map shape.
- View text: presentation only, checked in the browser on the multidev.
- Redirect: `curl -sI https://openondemand.connectci.org/appverse-security-rubric` returns 301 to `/appverse-review-rubric` after the content ops.
EOF
```

Fill in the plugin PR number from Task 5 Step 4, and go back and put this PR's number into the plugin PR body.

---

### Task 8: Cutover runbook (live), then merge the plugin PR

**Files:** none in either repo. This task is operations on Pantheon live plus two merges, in a fixed order.

**Interfaces:**
- Consumes: portal PR (Task 7) merged and deployed to live; plugin PR (Task 5) approved.

- [ ] **Step 1: Merge and deploy the portal PR to live**

Follow the normal md-dev → main release path. Confirm on live:

```bash
terminus drush connectci.live -- php:eval 'print_r(\Drupal\ood_software\Service\DocSyncService::DOC_MAP);'
```

Expected: the `review-rubric.md` key → 12246 is present.

- [ ] **Step 2: Retitle and re-alias the two doc nodes on live**

```bash
terminus drush connectci.live -- php:eval '
$s = \Drupal::entityTypeManager()->getStorage("node");
$p = $s->load(11932); $p->setTitle("Appverse Reviewer Process"); $p->save();
$r = $s->load(12246); $r->setTitle("Appverse Review Rubric");
$r->set("path", ["alias" => "/appverse-review-rubric", "pathauto" => 0]);
$r->save();
echo "done\n";'
```

Node 11932 keeps `/appverse-reviewer-checklist` on purpose: the view, the ood-appverse docs, and the DocSync map all use it, and the process doc is what that page now is.

- [ ] **Step 3: Verify the alias and the automatic redirect**

```bash
curl -sI https://openondemand.connectci.org/appverse-review-rubric | head -1        # 200
curl -sI https://openondemand.connectci.org/appverse-security-rubric | grep -i -E "^HTTP|^location"   # 301 → /appverse-review-rubric
curl -sI https://openondemand.connectci.org/appverse-reviewer-checklist | head -1   # 200
```

If the redirect is missing (auto-redirect only fires when the alias changes through the path field), create it:

```bash
terminus drush connectci.live -- php:eval '
\Drupal\redirect\Entity\Redirect::create(["redirect_source" => "appverse-security-rubric", "redirect_redirect" => "internal:/node/12246", "status_code" => 301, "language" => "en"])->save();
echo "redirect created\n";'
```

- [ ] **Step 4: Merge the plugin PR and force a sync**

Merge `feat/plan-b-rubric` into `appverse-review` `main`. Then either wait for the doc-sync cron or run it now:

```bash
terminus drush connectci.live -- php:eval '\Drupal::service("ood_software.doc_sync")->syncAll();'
terminus drush connectci.live -- watchdog:show --filter=ood_software --count=5
```

Expected log lines: `Synced review-checklist.md to node 11932.` and `Synced review-rubric.md to node 12246.` No 404 for `security-rubric.md` (its key is gone).

- [ ] **Step 5: Verify the live pages**

Open `/appverse-review-rubric`: title "Appverse Review Rubric", left rail lists the spine sections, OODT table present, GitHub edit link points at `references/review-rubric.md`. Open `/appverse-reviewer-checklist`: title "Appverse Reviewer Process", Steps 1–5 in order, related-docs bar links the rubric. Follow the old `/appverse-security-rubric` link from a search engine result or bookmark: lands on the rubric.

- [ ] **Step 6: Follow-ups to file, not do here**

- `ood-appverse` docs: `docs/app-best-practices.md:5` and `docs/appverse-contributor-guide.md:544` say "Reviewer Checklist"; the link still works. Retitle to "Reviewer Process" in a one-line PR there.
- `appverse-planning` `review-system/PUBLIC-SIGNALS.md` cites checklist line numbers (`checklist:154`, `:164`, `:192`, `:194`, `:210-213`, `:239`) that no longer exist; replace with rubric section names.
- The reply to Bill (spec: "What to flag back to Bill") can now point at the live rubric and process pages plus the regenerated ood-sas review.

---

## Self-Review

**Spec coverage.** Checklist split → Task 3. General Rubric on the spine with Security deepest → Task 2. Enumerated named checks in the sections the aspect skills read, no new mechanism → Task 2 (checks) + Task 4 Step 4 (quality skill told to run them). New slug `/appverse-review-rubric` with the old slug redirecting → Task 8 Steps 2–3 (node reuse, deviation recorded in Task 1). DocSync map edit → Task 6. Timing hazard closed → portal-first order in Task 8 and the merge-order warning in both PR bodies. Referrer inventory: `review-security/SKILL.md:13` (Task 4 Step 2), `review-checklist.md:5,:157` (rewritten in Task 3), report header rubric link (Task 4 Step 6), Process↔Rubric cross-links (Tasks 2–3 related-docs bars), `views.view.my_appverse.yml` (Task 7). Bill's checklist-side items: work-order reorder (Task 3), appverse.yml optional-if-manifest (Task 2 Repo shapes), declared-repo fields same for one or many apps (Task 2 Structure), six-month flag (Task 2 Upkeep, stated as a future portal feature per spec's out-of-scope), YAML validity documented and template-script syntax as a gate (Task 2 Validity), "template/" defined precisely (Task 2 Batch Connect layout), tiers and capability profile explained (Task 2 Security), Security categorized consistently (Task 2), quality secret gates resolved by the decision rubric (Task 2 How to read + Decision rubric). Out of scope items untouched.

**Placeholder scan.** `<ticket>` and `<number>` are runtime parameters the executor fills from the Jira ticket and PR numbers created in Tasks 5–7; every other step carries its content. The verbatim markers cite exact line ranges of existing files and Tasks 2–3 each include a grep that fails the task if a marker survives.

**Consistency.** Section names used by skills in Task 4 (`Repo shapes`, `Structure (gate criteria)`, `Security`, `Portability`, `Documentation`, `Code Quality`, `Upkeep`, `Decision rubric`) match the H2s asserted by Test 2 in Task 1 and written in Task 2. Named-check labels in Task 4 and Task 5 match Task 2 and Test 7. Node ids (11932, 12246) and slugs match across Tasks 6–8. The process doc's H2s in Task 3 match Test 3.
