# OOD Appverse Review - fasrc/ood-sas - 2026-09-30 - Bill's method, replayed (v2)

Reviewed:
- Automated report: CI run 36678163506 (2026-09-30), plugin branch `feat/facts-and-rows` at `e167db4` (reported as `appverse-review @ 0.7.0`), model `claude-sonnet-4-6`, target fasrc/ood-sas @ `462790a1` -> `review-fasrc-ood-sas-pr2-run1.md` (identical to the run's `review-fasrc-ood-sas.md`), plus its `.findings.json`, `.meta.json`, `.artifact.json`, `.html`, `.pdf`, and the pre-review facts it read (`pre-review/summary.json`, `syntax.json`, `tool-table.md`, `shellcheck.json`, `root/{readme,form,template,security}.json`). 36 records: 18 PASS, 17 WARN/FAIL, 1 NOT CHECKED. 64 turns, $3.17.
- The two sibling runs on the same commit and plugin SHA: 36678169915 ("run2", 36 records, 17 WARN/FAIL) and 36678176175 ("run3", 34 records, 19 WARN/FAIL), and `pr2m/table-3runs.md`.
- The 2026-09-25 replay (`bill-method-walkthrough.md`, "09-25" below) and its CI report.
- Reviewer docs on the branch the run used: Reviewer Process `references/review-checklist.md`, Review Rubric `references/review-rubric.md`, `finding-codes.md`, `checks.yml`, `artifact-envelope.md`, `skills/review-app/SKILL.md` (at `e167db4`; HEAD `c79435b` differs only in `pre-review.py` and one test). Published docs = `origin/main` `fff8361` (2026-09-29).
- Repo checked at `462790a1` (`ood-sas-full`, HEAD verified). All five plugin checkers re-run on run1 today: `check-feedback-floor.py` 15/15, `check-keys.py` 36/36, `check-rating.py` consistent, `check-rows.py` 18 required rows, 0 problems, `check-evidence.py` 36/36. All exit 0.

Line numbers: "report:N" is run1, "run2:N"/"run3:N" the siblings, "Process:N" and "Rubric:N" the branch docs, "SKILL:N" is `skills/review-app/SKILL.md` at `e167db4`, "sec-SKILL:N" is `skills/review-security/SKILL.md`. Repo paths are relative to ood-sas.

Tags as before: [tool] = automated review problem, [app] = app problem, [docs] = reviewer-doc problem.

---

## Summary of Suggestions

1. [tool] Stop printing "No tool-detectable issues in the checked tiers." when rows are WARN. report:80 prints it under two WARN rows (report:71 OODT-01, report:74 OODT-08). Rubric:185-186 reserves the sentence for "when neither produces a FAIL or WARN", and SKILL:194 says the same. All three runs do it (run2:90 under five WARNs, run3:82 under two). A reviewer skimming Security reads it as a clean bill.
2. [tool] Put the Tier-2 tool output into rows. The tool table reports "shellcheck ... 5 findings (SC2086, SC2148, SC2164)" (report:62), but no row cites a shellcheck code and "Additional observations" says "No findings." (report:78). sec-SKILL:142-146 says a tool finding at a candidate's line is cited in that row, and one at no candidate's line is an additional observation. From `shellcheck.json`: SC2086 at template/script.sh.erb:72 is the `eval` candidate's line (report:73 does not cite it). SC2164 `cd $WORKDIR` without `|| exit` at :25, SC2086 at :22 and :25, and SC2148 at template/before.sh.erb:1 are at no candidate line. SC2164 is a real error-handling defect. Only run3 used it, in its QUA-03 row (run3:127).
3. [tool] Tighten `check-feedback-floor.py` again. It reports 15/15, but two fix-items are not in the feedback prose. (a) OODT-08 `debug-tracing-enabled` (`set -x`, script.sh.erb:19,44,54) is never mentioned. It passes because the polish paragraph (report:167) names `script.sh.erb` and also contains "lines 44/45", which belongs to the form.yml duplicate-key sentence, and `line_named()` matches `lines?\s+44`. (b) MNT-02 `releases:no-releases` is never mentioned in the feedback. Its evidence is the pseudo-anchor `releases`, `PATH_PREFIX` (check-feedback-floor.py:77-80) does not match it, and the `if path:` branch (:294-303) is skipped. The key being present in the covers line is all the checker requires. Process:173-175 still tells the reviewer the covers line "is machine-checked".
4. [tool] Record a missing release as WARN, never FAIL. run1's findings JSON has MNT-02 `FAIL` low and MNT-04 `FAIL` info. Rubric:460-462 says "its absence is worth a suggestion, never a failure", and review-maintenance SKILL:53-55 repeats it. The FAIL low turns releases into a mandatory fix-item (see item 3). run2 and run3 record both as WARN info. The Markdown hides this, because the Upkeep table has no Result column (report:20-27).
5. [tool] Fix the Portability evidence. report:39, 86 and 91 say the cluster name "(`odyssey3`) ... documented in the README configuration table". README.md:115 documents `odyssey`, and form.yml:3 has `odyssey3` (verified). Bill found this on 08-27, the 09-23 local run found it, and 09-25 CI missed it. run1 misses it again and asserts the opposite. Only run3 records it (run3:138, QUA-06 info). The portability check's fact files do not compare README values against form.yml, so catching it depends on the run.
6. [tool] Correct three pieces of draft-feedback advice. (a) Duplicate keys: "Remove the first `help:` line in each case" (report:167). For `custom_num_gpus` that deletes "Available only on GPU enabled partitions" (form.yml:54), the only user-facing caveat, which the parser already drops. All three runs give this advice (run2:172, run3:174), so 09-25's point stands. (b) Unguarded ERB (report:159) says a blank field "becomes an empty string, which may be passed to sbatch as `--reservation=`". A blank ERB renders `reservation_id: `, which YAML loads as `nil` (verified: Ruby `YAML.load` gives `{"reservation_id"=>nil, "email"=>nil}`). run2 PASSed QUA-10 on exactly this point (run2:135). The real exposure is a value containing YAML syntax (`: `, `#`, a leading `*` or `&`), because the value is unquoted. (c) "the same `field.blank? ? nil : field` pattern that `custom_time` already uses at line 10": submit.yml.erb:10 falls back to `"04:00:00"`, not `nil`. Also, "`mkdir` at line 21" (report:155) should be :22 (`export WORKDIR` is :21). "the user sees a 502 proxy error" repeats the OOM comment at script.sh.erb:66-68 and is not something `set -e` addresses.
7. [tool] Fix the evidence anchors. The QUA-10 row cites `form.yml:27,65; reviewed OK: form.yml:15,30,38,47,72` (report:122; JSON `c71df289...`). Those are form definitions. The defect, the defect key `submit.yml.erb:erb-missing-value-unhandled` and the `form.json` `submit_lines` are submit.yml.erb:6,7. run3 cites it correctly (run3:132). `CHANGELOG.md:10` (report:124) is the `### Added` heading, and the MATLAB entry is :11 with the OSC links at :55-62. The first QUA-07 row (report:117) repeats the text-field clause of the second (report:118), which its JSON record (`d0c7b93f...`) does not contain, so the Markdown and the JSON disagree about the row.
8. [docs][tool] Settle the catalog checks, again. run1 performed all three (report:140-143, via WebFetch on the JSON:API). Process:135 still describes "Catalog checks the tool could not perform", Process:156 says "the review cannot see the catalog", and Rubric:471 and :476-478 say "the catalog checks the automated review cannot perform". `pre-review.py:195, 2793-2794` hard-codes the catalog check as "skipped: catalog reads land in a later PR". run3 shows the contradiction reaching the output: it performed the checks and then wrote "(which the automated review cannot perform)" (run3:156). Two accuracy gaps remain. run1 read only the first page (`page[limit]=100`). I queried the API on 2026-09-30: page 1 returns 91 apps and a `next` link, and offset 100 returns 16 more (nf-core pipelines, no SAS). run1 does not say it stopped at one page, and run2 does (run2:153). The app list was also read through WebFetch's model summary ("...and various Multitenant apps"), not as parsed JSON.
9. [docs] Document the check ids the report prints. Every dimension table carries `check: <id>` (report:46-50, 71-74, 90-91, 110, 116-123). `sec-interpolation`, `sec-eval-exec`, `sec-config-flag`, `str-02-metadata`, `str-03-yaml-valid`, `str-06-syntax`, `str-07-layout`, `str-04-references`, `portability-rating` and `documentation-rating` appear in neither the Rubric nor the Process (grep count 0). Only the code-quality ids (Rubric:409-414) and the named checks (Rubric:343, 424, 428) are in the Rubric. The published docs (`origin/main` `fff8361`) also lack the candidate loop (Rubric:170-186), the "Additional observations (review)" table (Process:129-133, 149-152), the per-rung Documentation evidence rule (Rubric:371-386) and any check ids. A reviewer holding the live Rubric sees report sections it does not describe.
10. [docs][tool] Decide whether a candidate gets its own row. Process:129-130 says "one row per candidate the pre-review facts enumerated", and Rubric:178-179 says each candidate gets "its own row". SKILL:170 says "One row per candidate". finding-codes.md:89-92 (branch only) says "One record per file per tag: candidates sharing a file and a tag share one record". SKILL:233-234 says "candidates with different results never share a row". run1 folds 14 candidates into 4 rows, with PASS lines inside a WARN row (report:71, "reviewed OK: submit.yml.erb:9,11,13"). run2 writes one row per candidate (run2:71-82). `check-rows.py` accepts both forms, so the docs name three different rules and the checker enforces none of them.
11. [tool] Reproducibility (Bill D2) is better but not there. Fix-item key Jaccard across the three runs is 0.65 to 0.80 (table-3runs.md). The fix-item set changes on severity alone. QUA-08 hex is low/info/info, OODT-08 is low/low/info, MNT-02 is FAIL low / WARN info / WARN info, QUA-10 at submit:6-7 is WARN/PASS/WARN, OODT-01 at submit:6 is low/medium/low and at :17 WARN/WARN/PASS, and QUA-03 is FAIL/WARN/WARN. The same defect also gets two keys: the Matlab help text is QUA-06 `form.yml:wrong-help-text` in run1 and run3 and QUA-05 `form.yml:wrong-app-reference` in run2. Candidate-anchored keys did hold: `duplicate-yaml-key:custom_num_*.help` is identical in all three runs, and 15 WARN/FAIL IDs are common to all three.
12. [tool] Four defects are still missed in all three runs. (a) `template/config/` is orphaned: `XDG_CONFIG_HOME` is commented out at script.sh.erb:40, so the panel file carrying the Fedora icon (xfce4-panel.xml:40) is never applied. The icon finding (report:123) needs that caveat, and the orphaning is itself dead code (QUA-04). (b) The memory fallback `2` at submit.yml.erb:9 is below the form's `min: 4` (form.yml:33). `template.json` scans only `template/` and its `numeric_literals` is empty, so no fact prompts it. (c) README typos at :125 ("notificationl") and :234 ("Univesity"). 09-25 CI caught :234, and run1 lost it. (d) README:201 says "Centos 7 and Rocky 8" against the tested Rocky 8.10 (README:182-184). The placeholder Troubleshooting (README:159-175) is rating evidence only (report:102) and has no QUA-05 `template-placeholder` finding. run1's feedback therefore omits it, and run2 (run2:182) and run3 (run3:199) put it in the feedback without a finding, which breaks the Derived-only rule (SKILL:325-331).
13. [tool] Security classification. The OODT-08 `set -x` row is WARN low while its own summary says the trace goes "to job's output.log, readable only by job owner under default umask" (report:74). The Rubric pattern is "Debug output to *world-readable* locations" (Rubric:262), so by the report's own reasoning it is a PASS or at most info. run3 says info (run3:74).
14. [tool] Minor template adherence. The Overall recommendation omits the template's opening paragraph separating signals from the decision (SKILL:284-287 vs report:145-147). The capability profile is prose where SKILL:196 asks for a table for Batch Connect (report:82). OODT is expanded but not linked (report:54 vs sec-SKILL:12-13). Security PASS rows show severity "—" (report:72-73) where sec-SKILL step 7 says `info`, and their JSON `tag` is "—" where it says `unintentional`. The gate table still has no "Repo shape is identifiable" row (Rubric:89) and still uses "—" as a rule code (report:13, 16; Rubric:45-46 says every finding carries a rule code). There is still no reader-facing "Low is the good end" legend (Process:138).
15. [docs] The Software entry check for inferred repos is unchanged. Process:101 says "The app's `software` value must match a Software entry ... or the app won't be listed", with no inferred-repo carve-out. Rubric:110 applies it only to declared repos. report:142 says "Not applicable (inferred repo)" and helpfully notes that a SAS Software entry exists. Process:63-65 still puts the duplicate-check rationale "under 'Not checked'", while the report has it under Catalog checks (report:141).

---

## Automated review review

### Header
**resolved.** report:3-5 has the repo URL, mode, date, full reviewed SHA with commit date, repo shape, `appverse-review @ 0.7.0 (\`e167db4\`, https://github.com/Sweet-and-Fizzy/appverse-review)`, model `claude-sonnet-4-6`, and the Rubric link. That is SKILL:80 exactly. All three 09-25 header gaps are closed: plugin version, repo URL and model. `artifact.json` `tool_version` = `appverse-review@0.7.0` and `run_meta.model` agree. Process:120-121 (commit, tool version, disclaimer) is met.

### Disclaimer
**resolved (partly as proposed).** report:7 is unchanged from 09-25. It still has no indemnification language and no legal input.

### Repo-level gate criteria
**matches except one row.** Public (report:13), README (:14), LICENSE (:15, "MIT license (Ohio Supercomputer Center / FAS-RC Harvard)", verified against LICENSE.txt:1-4) and not archived (:16, `gh api` returned `archived:false` in the run log) are present.
- The "Repo shape is identifiable" row is **still missing** (Rubric:89). The template has no slot for it (SKILL:86-91), so it appears only in the header.
- The "—" rule code on public and not-archived is still undocumented (Rubric:45-46, finding-codes.md).
- `artifact.json` `repo_level.criteria` = `{"license":"pass","readme_substantive":"pass","not_archived":"pass","public":"pass"}`, which agrees with the table. 09-25 item 1 is **resolved**.

### Upkeep
**resolved placement and reasoning; one result-code error.**
- It now sits directly after the gate table as "## Upkeep" (report:18), as Process:124 and the Rubric heading (Rubric:433) ask.
- The reasoning follows Rubric:447-452. "Issues responsiveness | 0 open issues | Neutral (no evidence either way)" (report:24) and "one good-practice signal (multiple contributors)" (report:31) give Medium. Verified: last commit 2026-07-08, 0 tags, no `.github/`, 4 GitHub logins (`gh api` in the log; `git shortlog` shows the same people under 5 name/email pairs).
- The JSON records MNT-02 FAIL low and MNT-04 FAIL info, against Rubric:462 (Summary 4). The Markdown table has no Result column, so the reader never sees the FAIL, while the feedback floor treats it as a fix-item.

### Signals
**documented and derived correctly.** Only Portability and Documentation appear (report:37-40). Process:125-126 and Rubric:23-25 now name only those two per app, plus Upkeep per repo, and Rubric:140-143 says security is "never a rating". 09-25's Security-signal discussion is moot. Portability Medium from Partially portable (Rubric:330) and Documentation Medium from Adequate (Rubric:368) both match. The one wrong input is the portability evidence phrase, "cluster name ... documented in README config table" (report:39). See Portability.

### Structure
**resolved on the gate that mattered.**
- STR-06 `check: str-06-syntax` PASS, "2 files pass, 0 fail (from pre-review syntax.json)" (report:48). `syntax.json` shows both files `ok: true` after ERB-strip with bash 5.2.21 (`summary.json`), which satisfies Rubric:135. There are two PASS records in the JSON (`5f251ca3...`, `0106ff5e...`). Bill's 08-27 item and 09-25 item 2 are **resolved**. report:147 "YAML/shell syntax is clean" is now supported.
- STR-02 `manifest.yml:1-10` (verified: 10 lines, all four fields), STR-03, STR-07 and STR-04 are present and PASS. STR-04 names `bc_email_on_started` as a built-in (report:50). That is correct, and it is the case the 09-23 run over-reported.
- STR-03 still claims "submit.yml.erb ERB tags balanced" (report:47). Rubric:134 defines balanced-tag checking only for `form.yml.erb`. It is harmless, but the report and the Rubric use different words.
- The PASS rows now carry severity `info` (report:46-50). 09-25's `high`/`medium`-on-PASS oddity is gone.

### Security
**structurally much improved. Two statements contradict the Rubric.**
- The "#### Findings" header is present (report:67). Tag column is present and populated `unintentional` (report:71, 74). OODT is expanded (report:54). The tier claim "Tiers 1-2" is now true, because shellcheck and semgrep both ran (report:62-63; `summary.json` exit codes 1 and 0). 09-25 item 9 is **resolved**, except that the OODT link is missing (sec-SKILL:12-13).
- All 14 `security.json` candidates are cited: 10 interpolation, 1 eval, 3 config_flag. I checked each: submit.yml.erb:6,7,9,10,11,13,17, script.sh.erb:11,12,64, :72 eval with `COMMAND` literal at :61, and `set -x` at :19,44,54. The OODT-01 WARN (report:71) and eval PASS (report:73) are accurate. 09-23's `eval-exec` over-report is gone.
- **Contradiction:** "No tool-detectable issues in the checked tiers." (report:80) under two WARN rows (Summary 1).
- **Dropped tool output:** 5 shellcheck results with no disposition (Summary 2).
- **Classification:** OODT-08 is WARN low while its own summary says the output is owner-readable (Summary 13).
- **Row granularity:** 4 rows for 14 candidates, with PASS lines inside a WARN row (Summary 10).
- The capability profile (report:82) is accurate: OOM score at :69/:71, `/scratch/$USER/$SLURM_JOBID` at :21, `--gres=gpu` at submit:13. It is prose, not the table SKILL:196 asks for.

### Portability
**rating right, evidence wrong.** "Partially portable" (report:86) with the undocumented `/scratch/` (script.sh.erb:21, verified; it is not in the README table at README:113-129) is right by Rubric:343-347. The claim that "cluster name (`odyssey3`) ... [is] documented in the README configuration table" is false: README.md:115 says `odyssey`. See Summary 5. `sas/9.4-fasrc01` is documented (README.md:124, verified).

### Documentation
**resolved.** "Adequate" (report:95), with evidence per rung (report:96-106). I checked every line cite against README.md: :21 "Appverse overview", :63 "Requirements", :84 "App Installation", :99 "2. Configure for your site", :196 "Known Limitations", :159 "Troubleshooting" (placeholder text at :163-170: `YOUR-APP`, `module load software/1.0`, `modules` attribute), and :37 "Screenshots" (images at :44 and :48). There are no environment-variable docs. All the cites are right. The rating matches Rubric:361-366 and the evidence rule at Rubric:371-386, and `check-rating.py` agrees. 09-25 item 4 is **resolved**. The one leftover is that the placeholder Troubleshooting is not a finding (Summary 12). The branch rule at Rubric:374-375 makes it `none`, which is correct for the rating, but nothing asks the contributor to fill it in.

### Code Quality
**every checkbox now has a row.** report:116-123 carries one row for each code-quality manifest id (error-handling, numeric-field-bounds, magic-numbers, duplicated-blocks, dead-code, erb-missing-value, icon-matches-target-os), and `check-rows.py` reports 18 required rows and 0 problems.

| Rubric check | run1 | Status |
|---|---|---|
| Error handling (target) | QUA-03 FAIL low, script.sh.erb:1 (report:116) | present. FAIL is right by Rubric:48. SC2164 at :25 is not used (Summary 2) |
| Input validation, `numeric-field-bounds` | QUA-07 WARN on form.yml:30,38 (no `max`) and on :15,27,65,72 (no `pattern`) (report:117-118) | **resolved**. Verified: `custom_memory_per_node` min 4 with no max (:30-35), `custom_num_cores` min 1 with no max (:38-43), `custom_num_gpus` 0..8 (:47-53). The four text fields have no `pattern`. Row 117 duplicates row 118's text-field clause |
| Magic numbers incl. hex colors | QUA-08 WARN low, `#D3D3D3` at script.sh.erb:46 (report:119) | **resolved** for the hex. The `2`G fallback (submit.yml.erb:9 vs form.yml:33) is still missed |
| Duplicated blocks | QUA-09 PASS (report:120) | present (previously unstated) |
| Dead code | QUA-04 WARN low, :33,39,78 (report:121) | **resolved**. The ranges 33-37, 39-42, 78-94 match `template.json` and the file. `#) &` at :57 is omitted, which is trivial |
| ERB missing/empty (QUA-10) | WARN low (report:122) | present, but the evidence is anchored on form.yml (Summary 7) and the stated consequence is wrong (Summary 6b) |
| `icon-matches-target-os` | QUA-06 WARN low, xfce4-panel.xml:40 `fedora-logo-icon` vs README.md:183 Rocky 8.10 (report:123) | **resolved** (verified). It lacks the not-applied caveat (Summary 12a) |
| Correctness & polish | CHANGELOG (report:124, `CHANGELOG.md:10`, entry is :11), Matlab help form.yml:61 (verified), duplicate `help:` at form.yml:44/45 and 54/55 (verified), `forml.yml` at README.md:136 (verified) | partly. odyssey/odyssey3 (README:115), :125, :234 and :201 are missed |

The table has a Severity column (report:114), and "INFO" is gone as a result, so 09-25 item 10's table-shape part is **resolved**.

### Review scope
**good, and now consistent with the checks.** report:132 lists `template/config/` as examined, which fixes the 09-25 scope error that had excluded the icon check's target. report:136 lists the tools, including bash syntax on 2 files. The tiers are still under Security, not here (Process:134), which is minor. Issues history is listed as not examined because there are 0 open issues, which is right by Rubric:450-452.

### Catalog checks
**performed. The docs still say it cannot be, and the result rests on one page.** Duplicate: "No duplicate found" (report:140). Software: N/A for an inferred repo, and a SAS entry exists (report:142; confirmed in the run log, WebFetch "Count: 1 ... Title Found: SAS"). app_type: N/A (report:143). The 09-25 regression (not attempted) is **resolved** in the report. What remains:
- Page 1 only, and the report does not say so (Summary 8). Today's verification finds no SAS on either page, so the conclusion holds.
- The Process and Rubric still say the review cannot do this (Summary 8).
- The duplicate-check rationale is pre-filled by the model (report:141). SKILL:273-275 marks it "_<reviewer fills in ...>_". The report's text is reasonable ("Reviewer should verify there is no in-progress submission"), but a reviewer may take it as settled.

### Overall recommendation
**consistent.** "Accept with suggestions (pending the duplicate-check confirmation noted above)" (report:147) follows Rubric:471-472. "All gate criteria pass" is now supported by STR-06. Every numbered item is a recorded finding. The template's opening paragraph is still omitted (SKILL:284-287). "No CI ... no tagged releases ... good-practice suggestions" is right in prose and contradicted by the JSON's FAIL on MNT-02 and MNT-04.

### Draft feedback
It is well written, file- and line-specific, and links the Best Practices guide (report:155). 13 of 15 fix-items are in the prose, and the covers line claims 15. Three pieces of advice are wrong (Summary 6). See the section below.

---

## Reviewer Process walk (as a reviewer holding this report)

### Before you start
Process:29-32: the reviewed SHA `462790a1` and its date are at report:4, so I can compare against HEAD. Not stuck.

### Step 1: Gate the app
- The four questions (Process:48-53). Public: report:13. License: report:15. Maintainer: now answerable from the Upkeep block right below the gates (report:22-27: 4 contributors, 0 open issues, neutral). Not stuck.
- Duplicate check (Process:55-65): the report gives an answer and a rationale (report:140-141). **Stuck point:** Process:156 says "the review cannot see the catalog, so this is the reviewer's to confirm". Do I re-run it? If I do, I find the report only read page 1.
- Software entry check (Process:99-112): **still stuck.** The report says N/A for an inferred repo and that a SAS entry exists. Process:101 has no inferred-repo rule, so I cannot tell whether "N/A" is the right answer or whether the catalog node must reference the SAS Software entry at creation (run3:151 says it should).

### Step 2: Open the review report
| Process:124-136 says | Report has | Status |
|---|---|---|
| Repo-level gate criteria and the repo's Upkeep signal | gates (report:9-16), then Upkeep (report:18-31) | matches |
| Per app: Signals (Portability, Documentation), Structure, Security, Portability, Documentation, Code Quality, "each with a rule code, severity, and `file:line`" | all present, with a Severity column in every table | matches. The `check:` ids are unexplained (Summary 9) |
| Security "one row per candidate ... including PASS rows", then "Additional observations (review)" | 4 grouped rows for 14 candidates; observations "No findings." | partly (Summary 10) |
| Review scope: which security tiers ran and what was not checked | examined, not examined, tools (report:130-136); tiers under Security | minor |
| Catalog checks "the tool could not perform" | checks performed with results | the doc is out of date (Summary 8) |
| Recommendation and draft feedback | present | matches |

Process:138, "Low is the good end", is still only in the Process doc. It matters less now, because every Signals row pairs the level with its rating word ("Medium | Adequate").

### Step 3: Verify the findings
- 3.1: I confirmed manifest.yml:1-10, README.md, LICENSE.txt and the layout. I also re-ran `bash -n` via `syntax.json`, and both files pass. Not stuck.
- 3.2: The security rows check out line by line. **Stuck point:** "No tool-detectable issues" (report:80) contradicts the two WARNs above it, and the "5 findings" in the tool table (report:62) lead nowhere. Process:148-152 tells me to read "Additional observations" as the open-ended pass. It says "No findings.", yet shellcheck flagged `cd` without `|| exit`.
- 3.3: The Documentation rating holds rung by rung. **Portability will be overturned in part.** Checking the README table against form.yml, as Process:153-154 asks, finds `odyssey` (README:115) vs `odyssey3` (form.yml:3), which contradicts report:86. The duplicate-key finding is right, and its feedback advice is wrong.
- 3.4: Upkeep values are current and the reasoning follows the Rubric.
- 3.5: See Step 1.
- Doc gap (carried from 09-25, now smaller): Step 3 still does not ask the reviewer to confirm every Code Quality check has a row. The report now makes that visible because the checks have ids, but Process:141-160 does not mention it.

### Step 4: Curate the feedback
- Process:169-170: fix-items (Low and above) belong in the feedback. `set -x` (OODT-08 low) and releases (MNT-02 FAIL low) are fix-items and are absent from the prose, while the covers line lists both (report:169). A reviewer who trusts "It is machine-checked" (Process:174) will not notice.
- Process:171, "Be specific": the feedback is specific. Three items are specifically wrong (Summary 6), and a reviewer has to know OOD's YAML handling to catch the QUA-10 one.

### Step 5: Decide
- Accept with suggestions follows from Rubric:472 and agrees with the report.
- Process:194-195: the catalog checks ran, so there is nothing to add to the feedback, except that the duplicate check covered page 1 only.
- "Record the decision in the catalog": `artifact.json` criteria now all say pass and `decision` is `accept_with_suggestions`, so the catalog ingests a consistent envelope.

### Rubric walk, H2 by H2

| Rubric section | Report section applying it | Exactly those criteria? |
|---|---|---|
| How to read this rubric (Rubric:15-50) | whole report | Mostly. Gates, signals and decision are separate, with a severity on every row. The result vocabulary conflicts on MNT-02/04 (FAIL for a good-practice signal) |
| Repo shapes (Rubric:52-75) | header "Repo shape" | Yes for an inferred single app |
| Structure (Rubric:77-136) | gates + Structure | Yes except the missing "Repo shape is identifiable" row. STR-06 is present. STR-03 extends balanced-tag checking to submit.yml.erb |
| Security (Rubric:138-318) | Security | Partly. The candidate loop is covered, and tag and tiers are right. It prints "No tool-detectable issues" under WARNs (Rubric:185-186), drops Tier-2 findings, gives OODT-08 WARN against the "world-readable" pattern (Rubric:262), and groups candidates against "its own row" (Rubric:178-179) |
| Portability (Rubric:320-347) | Portability | The rating rule is applied. The evidence claim about the README cluster value is false |
| Documentation (Rubric:349-399) | Documentation | Yes. The rating and per-rung evidence follow Rubric:361-386. Red flags (Rubric:396-399) are not explicitly answered |
| Code Quality (Rubric:401-431) | Code Quality | Yes for rows. Polish recall is partial: odyssey/odyssey3, two typos, the memory fallback and the orphaned config are missed |
| Upkeep (Rubric:433-462) | Upkeep | The level, placement and reasoning are right. JSON FAIL on MNT-02/04 contradicts Rubric:460-462 |
| Decision rubric (Rubric:464-478) | Overall recommendation | Yes. Rubric:471/476 "cannot perform" is contradicted by the report doing it |
| Appendix | n/a | n/a |

---

## Comparison with the 2026-09-25 CI report and with the other two 09-30 runs

### Against the 2026-09-25 CI report (same commit, same model id; plugin `2f7ef26` -> `e167db4`)
09-25 had 22 records (8 PASS, 14 WARN/FAIL). run1 has 36 (18 PASS, 17 WARN/FAIL, 1 NOT CHECKED).

Newly found in run1, all of which 09-25 missed and the 09-23 local run or Bill had:
- QUA-10 unguarded `reservation_id`/`email` (submit.yml.erb:6-7)
- QUA-08 `#D3D3D3` (script.sh.erb:46)
- QUA-06 Fedora icon (xfce4-panel.xml:40)
- QUA-07 `missing-pattern` for the four text fields
- STR-06 rows
- Documentation rated Adequate (09-25 said Strong)

Fixed in run1:
- `eval-exec` is now a reasoned PASS (09-23 over-reported it).
- Upkeep reasoning.
- The QUA-04 range (09-25 said :80-94; run1 says :33,39,78 with the right ranges).
- The CHANGELOG double-coding. MNT-03 is now PASS, "exists (content is a QUA-05 wrong-app issue)", which is cleaner.

Lost since 09-25:
- The README.md:234 "Univesity" typo.
- 09-25 recorded no OODT-08. run1 records `set -x` as WARN low, which 09-25 judged an over-report against Rubric:262. See Summary 13.

Still missed by both: odyssey/odyssey3 (README:115), the orphaned `template/config/` (script.sh.erb:40), the memory fallback `2` (submit.yml.erb:9), and the placeholder Troubleshooting as a finding.

### Across the three 09-30 runs (same commit, plugin SHA, model and pre-review facts)
**The same in all three:** decision Accept with suggestions; Portability Medium / Partially portable; Documentation Medium / Adequate with identical rung cites (README:21, 63, 84, 99, 196, 159 placeholder, 37); Upkeep Medium; STR-06 PASS; the 14 security candidates all answered. These recorded fix-items appear in all three, with the same key: QUA-02 `/scratch` (W medium), QUA-04 dead code (W low), QUA-06 icon (W low), QUA-07 `missing-min-max` and `missing-pattern` (W low), QUA-06 duplicate `help` x2 (W low), QUA-05 CHANGELOG (W low/low/medium), and OODT-01 `submit.yml.erb:unsanitized-user-input`. All three print "No tool-detectable issues" under WARNs, and all three give the duplicate-key advice that deletes form.yml:54.

**Different (table-3runs.md and findings JSON):**
| Candidate / defect | run1 | run2 | run3 | Effect |
|---|---|---|---|---|
| QUA-10 submit.yml.erb:6,7 | W low | **P** (YAML null) | W low | fix-item in 2 of 3 |
| QUA-08 script.sh.erb:46 | W **low** | W info | W info | fix-item in 1 of 3 |
| OODT-08 `set -x` :19,44,54 | W **low** | W **low** | W info | fix-item in 2 of 3 |
| OODT-01 submit:6 | W low | W **medium** | W low | severity only |
| OODT-01 submit:17 (`extra_slurm`) | W low | W medium | **P** | run3 moved it to "Additional observations" as a PASS (run3:80), which is not what that table is for (SKILL:187-188) |
| QUA-07 form.yml:72 (`extra_slurm` pattern) | W | W | **P** | |
| QUA-03 no `set -e` | **FAIL** low | WARN low | WARN low | result drift on a target-for-inclusion check (Rubric:48 says FAIL) |
| MNT-02 releases | **FAIL low** | WARN info | WARN info | fix-item in 1 of 3; FAIL contradicts Rubric:462 |
| Matlab help text | QUA-06 `wrong-help-text` | QUA-05 `wrong-app-reference` | QUA-06 `wrong-help-text` | key drift, different stable ID |
| odyssey/odyssey3 | missed, and asserted documented | missed | **found** (QUA-06 info, run3:138) | |
| OODT-06 on the commented Singularity binds | — | W low (run2:88) | — | run2 over-reports: the code at :78-94 is commented out and cannot run |
| GitHub metadata | `gh api` succeeded | "not queried" (run2:24-25) | "unavailable", not-archived NOT CHECKED (run3:16) | contributors signal known in 1 of 3; run3's gate table has a NOT CHECKED row |
| Catalog page 2 | not mentioned | flagged (run2:153) | not mentioned | |
| Security row layout | 4 grouped rows | 12 rows, one per candidate | 4 grouped rows | Summary 10 |

Pairwise fix-item Jaccard is 0.65 (run1/run2), 0.80 (run1/run3) and 0.67 (run2/run3). 15 WARN/FAIL stable IDs are shared by all three. The **decision and all three signal levels are now stable.** What still varies is whether a given defect becomes a fix-item, and that is set by severity (low vs info) and result (PASS vs WARN), both model judgment. The candidate enumeration fixed which sites get asked about, but not how they get answered.

---

## Draft Feedback vs findings

The tool's claim: the covers line (report:169) lists 16 keys, and `check-feedback-floor.py` reports "15/15 fix-items covered" (re-run 2026-09-30, exit 0). Checked against the prose (report:153-167):

| Fix-item (Low+ WARN/FAIL) | In covers line | Named in prose, with file and line or what is wrong | Where |
|---|---|---|---|
| OODT-01 `submit.yml.erb:unsanitized-user-input` (W low) | yes | partly. The remedy (patterns on the four text fields) is at report:157 under form.yml, and submit.yml.erb:6/7 are named at report:159 under QUA-10. The security point, that `extra_slurm` tokens pass straight into `native:` (submit.yml.erb:15-17), is never stated | report:157, 159 |
| OODT-08 `template/script.sh.erb:debug-tracing-enabled` (W low) | yes | **no**. `set -x` and lines 19/44/54 are never mentioned. It passes the checker on "lines 44/45" from the form.yml sentence | — |
| QUA-02 `template/script.sh.erb:hardcoded-path` (W medium) | yes | yes | report:165 |
| QUA-03 `template/script.sh.erb:no-set-e` (FAIL low) | yes | yes (mkdir line mis-cited as 21) | report:155 |
| QUA-07 `form.yml:missing-min-max` | yes | yes | report:157 |
| QUA-07 `form.yml:missing-pattern` | yes | yes | report:157 |
| QUA-08 `template/script.sh.erb:undocumented-hex-color` | yes | yes | report:167 |
| QUA-04 `template/script.sh.erb:commented-out-code` | yes | yes | report:167 |
| QUA-10 `submit.yml.erb:erb-missing-value-unhandled` | yes | yes (consequence misstated) | report:159 |
| QUA-06 `xfce4-panel.xml:icon-os-mismatch` | yes | yes (file, no line) | report:167 |
| QUA-05 `CHANGELOG.md:wrong-app-changelog` | yes | yes | report:161 |
| QUA-06 `form.yml:wrong-help-text` | yes | yes | report:163 |
| QUA-06 `form.yml:duplicate-yaml-key:custom_num_cores.help` | yes | yes | report:167 |
| QUA-06 `form.yml:duplicate-yaml-key:custom_num_gpus.help` | yes | yes (advice deletes the caveat at form.yml:54) | report:167 |
| MNT-02 `releases:no-releases` (FAIL low) | yes | **no**. Releases appear only in the Overall recommendation (report:147) | — |

Result: 13 of 15 fix-items are in the prose, one of them (OODT-01) only through its QUA-07 remedy. The covers line overstates by 2. 09-25 had 8 of 10 with an overstatement of 2, so the ratio is better, the overstatement is the same, and the checker mechanism behind it has changed. The MNT-02 case would disappear if Summary 4 were fixed, since at WARN info it is not a fix-item.

Info items: the README typo is included (report:167) and MNT-04 no-CI is omitted. Process:169-170 allows both.

Feedback items with no finding: none. The Derived-only rule holds for run1. It does not hold for run2 and run3, which both tell the contributor to fix the placeholder Troubleshooting (run2:182, run3:199) with no finding recorded.

The feedback is silent on catalog checks. That is allowed by Process:194-195 because they were run, but the page-1 limit is not disclosed.

---

## Where the 2026-09-25 suggestions stand

| # | 09-25 suggestion | Status | Evidence |
|---|---|---|---|
| 1 | `assemble-artifact.py` marks criteria "fail" on PASS rows | **resolved** | run1 `artifact.json`: `repo_level.criteria` all `pass`, `apps[0].criteria` = `metadata/yaml_valid/structure/references: pass`. artifact-envelope.md:288 (1.0.1): "PASS records no longer flip a criterion to fail" |
| 2 | STR-06 row in template; `bash` runnable in CI | **resolved** | Template row SKILL:153. Pre-review runs `bash -n` on ERB-stripped copies (`summary.json` "syntax", bash 5.2.21). report:48, two PASS records |
| 3 | Settle whether the tool does catalog checks | **partly** | The tool does them (report:140-143; WebFetch in the run log). Process:135, 156 and Rubric:471, 476-478 still say it cannot. `pre-review.py:195, 2793-2794` still skips "catalog". run3:156 repeats "cannot perform". Page 2 is unread (Summary 8) |
| 4 | Documentation rating shows evidence per level | **resolved** | report:95-106 per-rung cites, all verified. Rubric:371-386. `check-rating.py` consistent. All three runs say Adequate |
| 5 | Every checkbox and named check produces a row | **resolved** | report:116-123. `check-rows.py` 18 required rows, 0 problems. QUA-08 (:119), QUA-10 (:122) and the icon check (:123) are present. The remaining silent drop is tool output, not checkboxes (new Summary 2) |
| 6 | Tighten `check-feedback-floor.py` | **partly** | It now requires the file in a paragraph plus a line from the evidence or a defect-key word (SKILL:344-350). It still passes OODT-08 on another finding's line numbers and MNT-02 with no prose at all (Summary 3) |
| 7 | Reproducibility: pin/record model, run more than once, freeze key forms | **partly** | The model is in the header (report:5) and `run_meta`. Three runs exist. Candidate-anchored keys are stable, including `duplicate-yaml-key:custom_num_*.help`. Severity and result drift still change the fix-item set, and the Matlab-help key drifts (Summary 11) |
| 8 | Derive Upkeep from counted signals | **resolved** | report:24 "Neutral", report:31 "one good-practice signal". SKILL:108-114 derivation comment. `meta.json` signals match |
| 9 | Security: Findings header, intent tag, expand OODT, honest tier claim | **resolved** (link missing) | report:67 header, report:71/74 tag, report:54 expansion, report:56 with shellcheck/semgrep "Run" (report:62-63). No link (sec-SKILL:12-13) |
| 10 | Unify vocabulary: Severity column, no "INFO" result, unmet target = FAIL | **partly** | A Severity column is in every table and "INFO" as a result is gone. QUA-03 is FAIL in run1 but WARN in run2/run3. MNT-02/04 are FAIL for good-practice signals (Rubric:462). Security PASS rows show "—" severity (report:72-73) |
| 11 | Upkeep placement and naming | **resolved** | report:18 "## Upkeep" directly after the gates, matching Process:124 and Rubric:433 |
| 12 | Software entry / vocabulary for inferred repos | **open** | Process:101 is unchanged. report:142 "Not applicable (inferred repo)". Process:63-65 still says "under 'Not checked'" |
| 13 | Header provenance: plugin version, repo URL | **resolved** | report:5 `0.7.0 (\`e167db4\`, https://github.com/Sweet-and-Fizzy/appverse-review)`. `tool_version` `appverse-review@0.7.0` |
| 14 | Evidence-line accuracy | **partly** | The 09-25 three are fixed: dead code :33,39,78 correct, and the memory field is cited as form.yml:30, the attribute line. `CHANGELOG.md:10` is one line early (entry :11). New errors: the QUA-10 evidence is on form.yml rather than submit.yml.erb (report:122), "mkdir at line 21" (:22), the custom_time "nil" pattern at :10 (report:159), and "odyssey3 documented" (report:86) |
| 15 | PDF and HTML disagree on the raw JSON block | **resolved** | Neither contains a findings block (`defect_key` count is 0 in both). The HTML keeps the covers HTML comment, which does not render |

Count: 9 resolved, 5 partly, 1 open.

---

## Where Bill's 2026-08-27 items stand

### His Summary of Suggestions
| # | Bill's suggestion | Status | Evidence |
|---|---|---|---|
| 1 | Resolve "Required" vs "Quality" drift | **resolved** | Rubric:15-43 (gate / signal / decision / Code Quality). Rubric:388-394 retires "Documentation Minimum" |
| 2 | Re-order the Checklist top-to-bottom | **resolved** | Process:25-198: Before you start, then Steps 1-5 |
| 3 | Other Checklist cleanup | **resolved** | appverse.yml optional (Rubric:73-75). Same fields for single and multi (Rubric:103-105). Follow-up handled by the catalog (Rubric:454-457) |
| 4 | Add a Disclaimer | **resolved (partly as proposed)** | report:7. No indemnification clause |
| 5 | Report organization, headings | **resolved** | Findings header (report:67), Upkeep after the gates (report:18), Severity column in every table, "Additional observations (review)" (report:76). The remaining vocabulary issue, undocumented check ids, is under #6 |
| 6 | Report and Checklist check the same things with the same criteria | **partly** | Closed: template syntax (report:48), Documentation rating (report:95), QUA-08, QUA-10 and the icon check (report:119, 122, 123). Open: catalog checks vs Process:135/156 and Rubric:471/476, "No tool-detectable issues" under WARNs vs Rubric:185, one row per candidate vs grouped rows, MNT-02 FAIL vs Rubric:462, check ids absent from the docs, and published docs lagging the branch (Summary 1, 4, 8, 9, 10) |
| 7 | Items from 1st report omitted in 2nd: add to rubric? | **resolved** | The Rubric names free-text input validation (Rubric:424-427) and hardcoded site paths (Rubric:343-347), and run1 applies both (report:118, 90) |
| 8 | Ensure all problematic findings reach Draft Feedback | **partly** | ERB-empty and the hex color now reach the feedback (report:159, 167). `set -x` and releases do not, although the floor checker passes them (Summary 3) |

Count: 6 resolved, 2 partly, 0 open.

### His per-section notes
| Bill's note | Status | Evidence |
|---|---|---|
| Disclaimer missing | resolved | report:7 |
| Header: add appverse-review URL + commit | **resolved** | report:5 |
| `shared_paths` undocumented, move to Security | resolved | Not in the gates. Rubric:70-71 |
| README/LICENSE per app in a monorepo? | resolved | Rubric:93-95 |
| YAML validity undocumented | resolved | Rubric:133-134 |
| Works for yml.erb? | resolved | Rubric:134 |
| "Standard OOD structure" incongruous | resolved | Rubric:117-121, report:49 |
| "Template scripts syntactically correct" missing as Required | **resolved** | Rubric:135, report:48, `syntax.json` |
| "Check tiers" unexplained | resolved | Rubric:154-186. The report's claim is now accurate (report:56, 62-63) |
| "Capability Profile" unexplained | resolved | Rubric:188-201, report:82 |
| Missing "Findings" header | **resolved** | report:67, template SKILL:168 |
| "Four questions" unexplained | resolved | Rubric:354-359, 390-391 |
| Code Quality: error handling | resolved | report:116 |
| Code Quality: ERB missing/empty values (submit.yml.erb:6-7) | **partly** | Found (report:122), but the evidence is anchored on form.yml, the feedback's consequence is wrong (blank renders YAML null), and run2 PASSed it |
| Code Quality: magic numbers `#D3D3D3` (:46), `2GB` fallback | **partly** | Hex found (report:119). The fallback `2` at submit.yml.erb:9 vs `min: 4` at form.yml:33 is missed in all three runs |
| Code Quality: commented-out Singularity code | resolved | report:121, ranges correct |
| CHANGELOG copy-paste | resolved | report:124 (cite one line early) |
| "Matlab" in sas_version help | resolved | report:125. The key drifts across runs |
| Duplicate help keys | resolved as findings, **advice still wrong** | report:126-127. The feedback at report:167 deletes form.yml:54's caveat in all three runs |
| README typos :136, :234 | **partly** | :136 found (report:128). :234 missed (09-25 CI had it) |
| README :115 `odyssey` vs `odyssey3` | **not resolved** | Missed in run1, which asserts the opposite (report:86). Found only in run3 (run3:138) |
| XFCE panel Fedora icon | **resolved** | report:123. It needs the not-applied caveat (script.sh.erb:40) |
| Maintenance: no releases, CHANGELOG | resolved | report:23, 26. JSON FAIL on MNT-02 is Summary 4 |
| Review Scope useful; duplicate/software check passed manually | **resolved** | Scope report:130-136. Catalog performed (report:140-143). Page-1 caveat |
| Overall Recommendation agrees with report | resolved | report:147 |
| Draft Feedback omits ERB-empty and magic numbers | **resolved** | report:159, 167 |
| 1st-vs-2nd: input validation (`custom_time`, `extra_slurm`) | **resolved** | report:118, 157 |
| 1st-vs-2nd: hardcoded `/scratch` | resolved | report:90 |
| md vs pdf identical | **resolved** | Neither rendering carries the raw JSON block |
| Checklist: appverse.yml optional? | resolved | Rubric:73-75 |
| Checklist: Declared-repo fields required too? | resolved | Rubric:103-105 |
| Checklist: 6-month flag mechanism | resolved (deferred to catalog) | Rubric:454-457 |
| Security categorized consistently | resolved | Rubric:140-150: findings only, no rating. No Security signal in report:37-40 |
| Some Quality criteria de facto required? | resolved | Rubric:32-39, 405. Target-for-inclusion rows (Rubric:409-410) |

### New since 09-25 (not in Bill's list)
- "No tool-detectable issues" under WARN rows (Summary 1).
- Tier-2 tool findings read and silently dropped (Summary 2).
- The feedback-floor checker satisfied by another finding's line numbers, or by a path-less key (Summary 3).
- The docs name three incompatible rules for candidate rows (Summary 10).
- Check ids and the candidate/rung machinery are absent from the published docs (Summary 9).

---

## Verdict

This report now matches the Reviewer Process and the Rubric on almost everything Bill raised. The header names the tool version, its repository and the model. The syntax gate has a row. Upkeep sits where the Process says and is reasoned the way the Rubric counts it. The Documentation rating is Adequate, with a README line for every rung. Every code-quality check has a row, including the magic number, the unguarded ERB values and the Fedora icon he found by hand. The catalog checks were actually run, and the decision and all signal levels agree across three runs of the same commit. Bill would still flag six things. The Security section says "No tool-detectable issues in the checked tiers" directly under two WARN rows and never accounts for the five shellcheck findings it reports. The Portability section says the README documents `odyssey3` when it says `odyssey`, the same mismatch he caught in August. The feedback checker passes the `set -x` and releases items that the feedback never mentions, and releases should not be a FAIL at all under the Upkeep rules. The draft feedback tells the contributor to delete the only GPU-partition caveat and misdescribes what a blank reservation field does. The docs still say in three places that the tool cannot see the catalog it just queried, and the check ids and candidate-row rules the report is built on appear nowhere in the published Rubric.
