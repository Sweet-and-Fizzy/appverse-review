# Review of appverse-review run 36732089153 (tillicum-llama-chat)

**Run:** https://github.com/Sweet-and-Fizzy/appverse-review/actions/runs/36732089153
**Branch:** `feat/facts-and-rows` (PR #56) at `c79435b`, version 0.7.0, model claude-sonnet-4-6
**Target:** https://github.com/UWrc/tillicum-llama-chat at `f7c8d35` (2026-09-09)
**Why this run:** first real submission reviewed on the facts-and-rows branch. The three measurement runs on 2026-09-30 were all against fasrc/ood-sas; this is an app with a different shape (Apptainer, GPU partitions, a Python reverse proxy, an LLM server with tool use).

All five checkers passed (floor, keys, rating, rows, evidence). The findings were verified against a fresh clone of the target. Every finding I checked is accurate; the problems below are in the rules, not the model's reading of the code.

## 1. A substantive README is rated as a stub and fails the STR-01 gate

**What happened.** The README is 14,939 bytes with 29 headings covering architecture, deployment, model catalog management, advanced options, logs, a verification checklist, and eight troubleshooting entries. The report rates Documentation as `Minimal — not supported (stub README; see QUA-01)`, records a QUA-01 `docs-stub` FAIL at severity high, and the draft feedback lists "Add a Prerequisites section" as a **required change that blocks listing**.

**Why.** Three rules compose into this:

- `pre-review.py` (RUNGS, line 691) maps the prerequisites rung to the first heading whose words contain `requirements`, `requirement`, `prerequisites`, `prerequisite`, or `dependencies`. This README has no such heading, so `readme.json` has `"prerequisites": null`. The content is there: "Current defaults" (line 17) lists cluster, QoS, GPUs, container path; "Deployment" (line 271) lists what must exist on the host. It just isn't under a heading with one of those five words.
- `skills/review-quality/SKILL.md` (line 158-167): "you may never claim a rung `readme.json` shows no heading or content entry for" and "When even Minimal is unsupported (no what-it-launches or no prerequisites evidence), the README is a stub". So a null prerequisites rung forces `none`, `none` at Minimal forces stub.
- `check-rating.py` then requires the `docs-stub` FAIL record for the rating line to pass, so the model produces it.

The model saw the contradiction. The Signals table on the same page says `Documentation | High | README is substantive but lacks a prerequisites section and a configuration section; cannot reach Adequate`, and the evidence line for prerequisites reads `none (no prerequisites heading; prerequisites content is embedded in Current defaults and Deployment sections)`. It knew the content was there and was forbidden from counting it.

**Why it's a defect and not a strict reading.** The structure skill defines the stub gate as "not the unfilled template (placeholder text like 'Key feature 1'), not just a title and contact line" (line 23-24), and the published rubric says "gate (stub or unfilled template) is a gate failure, not a Minimal rating". This README is neither. The quality skill's stub trigger ("no prerequisites evidence") is a stricter definition than the structure skill's, and the pre-review heading matcher makes "evidence" mean "heading with a synonym". The three together turn a naming convention into a gate failure. A submitter who renames "Current defaults" to "Requirements" would flip this from blocking to accept-with-suggestions with no change to the documentation.

**Consequence for this submission.** The recommendation is still Request changes because of the missing LICENSE, so the verdict is right by accident. The draft feedback is wrong: item 2 is presented as blocking and cites "the formal documentation rung is a stub", which a submitter would reasonably dispute. The STR-01 gate table (line 14) shows README as PASS and the QUA-01 row shows it as a stub FAIL, in the same report.

**Suggested fix, in order of preference.**

1. Split the stub decision from the rung ladder. Stub is the structure gate: unfilled template, or title-and-contact only, decided from `readme.json` size and placeholder facts. Below-Minimal on the rungs is a QUA-01 `docs-minimal` FAIL at whatever severity the rubric assigns, not a gate failure. `check-rating.py` already has the `docs-minimal` path; the stub path should only be reachable when the structure gate fails.
2. Let the prerequisites rung be satisfied by content. Either widen RUNGS to include `defaults`, `setup`, `environment`, or (better) let the model cite a heading whose body delivers the rung even when the heading name doesn't match, with the citation required. The current "may never claim a rung readme.json shows no entry for" rule was written to stop the model inventing sections; requiring a `README.md:N` citation into a real heading's body achieves that without banning judgment.
3. At minimum, make the Signals table and the rating agree. A report that says High and stub about the same README will not survive a submitter reading it.

## 2. Draft feedback ordering follows the defect, not the rubric

Because item 1 produces a high-severity QUA-01, the feedback lists the missing prerequisites heading as the second **required** item, ahead of the real security observation (the `--offline` flag is claimed in a comment but never passed, script.sh.erb:91-97) which lands at item 7 under "suggested (low)". A submitter reads the top two items as the bar. Once the stub rule is fixed this reorders itself, but it's worth checking that the feedback floor orders by rubric severity rather than by the model's severity field, since the model's severity here was the checker's doing.

## 3. Catalog checks are not performed, and the report says so twice

Duplicate check, `software` match, and vocabulary checks are all NOT CHECKED / NOT APPLICABLE because the runner has no network to openondemand.connectci.org. The recommendation is worded as conditional on them, which is correct. Two notes:

- The "Duplicate-check rationale" paragraph is useful and specific (llama.cpp / llama-server apps as an emerging category; what would make this one meaningfully different). Keep that.
- The portal already knows whether a repo URL is on the catalog (node 12302 exists for this URL, unpublished). If the portal-side dispatch passed a `catalog_status` input, the duplicate row could be answered without giving the runner network access. Cheap to add on the portal side when D8-2788 lands.

## 4. Upkeep signals say "unavailable" for things that were available

`Contributors | Not checked | git log unavailable` and `Issues responsiveness | Not checked | Catalog query unavailable`. The clone succeeded and `git log` works in the checkout (the report cites the last commit date from it). If the skill wants contributor count, it can read it; if it deliberately doesn't (to keep the model off git history), the row should say "not assessed" rather than "unavailable". Issues responsiveness needs the GitHub API, which is a separate question from the catalog.

## 5. Things that worked and are worth keeping

- The `--offline` finding (OODT-08 additional observation) is a real, subtle, correct catch: the comment at script.sh.erb:91-97 says network isolation is provided by `--offline`, and the flag appears nowhere in the invocation. The security.json candidates didn't list it; the model found it in the additional-observations pass. That pass earned its keep.
- Every OODT-01 candidate site from security.json got an answer with a specific reason (auto-field, select-constrained, ternary to literals, base64 before shell, quoted printf). The `reviewed OK:` citations in findings.json are exactly the mechanism #56 promised.
- The duplicated README paragraph (lines 125-128 repeated at 130-133) is real.
- The `bc_num_hours` empty-value chain (no min/max, no presence check, `.to_f` to 0, `--time=0:00`) was traced across form.yml and submit.yml.erb and reported once per file with the cross-reference. That's the row discipline working.
- Capability profile is accurate and reads well; the "LLM tool use (filesystem/shell) | Yes | `--tools all`" line is the kind of thing a human reviewer wants surfaced.

## Verified against source

| Claim | Source | Result |
|---|---|---|
| No LICENSE | `ls` at root | Confirmed |
| `--offline` claimed, not passed | script.sh.erb:91-99 | Confirmed |
| Duplicate paragraph | README.md:125-133 | Confirmed |
| No prerequisites heading | README.md headings | Confirmed; content in lines 17-33 and 271-293 |
| 0.0.0.0 bind | proxy.py:52 | Not re-read; consistent with README "Reverse proxy behavior" |
