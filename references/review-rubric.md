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

A repo with a root `appverse.yml` is **declared**: the contributor states how their
app(s) appear in the catalog. A repo with only a root `manifest.yml` is **inferred**:
the catalog derives a single app from that file plus GitHub metadata.

A declared repo whose `appverse.yml` has an `apps:` list is a **Monorepo**. Review
every entry in `apps[]` as its own app — each gets its own structure, security, and
quality assessment, and its own decision. Per-app fields resolve with this precedence:

1. Inline in the root `appverse.yml` `apps[]` entry (highest)
2. `<subpath>/appverse.yml`
3. `<subpath>/manifest.yml` (name/description fallback only)

Directories listed in `shared_paths` are shared code: review them once at repo level
and include them in the security review. Decisions can differ per app — e.g., accept
three apps and request changes on a fourth.

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
| Repository is public and accessible | A private or inaccessible repo cannot be listed; the catalog links to it |

README and LICENSE are checked once at repo level. In a monorepo the apps share
them; an app-level README at a subpath is welcome but is not required by this
gate.

**Inferred repos** (root `manifest.yml`, no `appverse.yml`):

| Check | What to Look For |
|-------|------------------|
| `manifest.yml` required fields | `name`, `category`, `role`, `description` at minimum |

**Declared repos** (root `appverse.yml`), checked per app after field-precedence
resolution. The same fields are required whether the repo declares one app or
several:

| Check | What to Look For |
|-------|------------------|
| `description` | Present |
| `software` | Present (checked here). It must also match a catalog Software entry to be listed — see the Reviewer Process, Software entry check, for what to do when it doesn't |
| `app_type` | A known value in the catalog's app-type vocabulary; likewise every `implementation_tags` entry must be a known value (see the [appverse.yml reference](https://github.com/Sweet-and-Fizzy/ood-appverse/blob/main/docs/appverse.yml) and the Reviewer Process, "Reading the catalog without a login") |
| `maintainer.name` + `maintainer.support_url` | Both required and present. An app without a support URL gives deployers no one to contact — a missing one fails this gate |
| `manifest.yml` at the app's subpath | Required for the app to actually run inside OOD |

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

Two complementary methods feed the same classification:

- **Capability profiling** catalogs what an app does — what system access it needs,
  what network calls it makes, what files it reads and writes, what processes it
  spawns. For batch connect apps, with their narrow expected profile, unusual
  capabilities are a strong signal of malicious intent. For Passenger apps, with
  legitimately broad capabilities, the profile is a transparency tool — it tells
  reviewers and deployers exactly what they are putting on their system so they can
  make an informed decision. An app is never penalized for doing what it is designed
  to do.
- **Pattern checks** catch capabilities used unsafely, regardless of app type. Form
  values reaching shell commands without sanitization, `eval()` on config-supplied
  code, a service with `--no-auth`, credentials stored in plain text. Normal tools,
  unsafe usage.

### Capability baseline: Batch Connect apps

The expected profile is narrow. Anomalies are a strong signal.

| Capability | Expected in | Anomalous in |
|-----------|------------|-------------|
| `Net::HTTP`, `open-uri`, `TCPSocket` in Ruby | Never | Any ERB file |
| Outbound `curl`/`wget` | Rare in script.sh | form.yml.erb, submit.yml.erb, before.sh |
| Reading `~/.ssh/id_rsa` or similar keys | Never | Any file |
| base64 decode + execute | Never | Any file |
| Writes to shell init files, `~/.ssh/*` | Never | Any file |
| `crontab`, systemd user services | Never | Any file |
| Binary files in `template/` | Very rare | Most apps |
| Accessing other users' files | Never | Any file |
| Bind-mounting sensitive host paths | Never | Container configs |

### Capability baseline: Passenger apps

The expected profile is wide. The full profile is reported for transparency.
Capabilities in the "Flagged" column generate findings.

| Capability | Reported | Flagged |
|-----------|----------|---------|
| Handling HTTP requests, serving pages | Yes | — |
| Reading/writing files in user's space | Yes | — |
| Outbound HTTP to external APIs | Yes | — |
| Running shell commands (scheduler interaction) | Yes | — |
| `eval()` or `exec()` on user/config-supplied code | Yes | Yes |
| Accepting raw shell commands from browser requests | Yes | Yes |
| Dynamic module loading from user-writable paths (`importlib`, `require`) | Yes | Yes |
| Spawning detached background processes | Yes | With context |
| CORS open to all origins | Yes | Yes |
| Disabling framework security features (CSP, host checking) | Yes | Yes |
| Storing credentials in plain text files | Yes | Yes |
| Writes to shell init files, `~/.ssh/*`, cron | Yes | Yes |

**Dashboard apps and widgets** — no detailed baseline yet; there are not enough
examples in the catalog. Apply the pattern checks and report whatever capabilities
are found. Baselines will be built out as more of these enter the catalog.

### Pattern checks (all app types)

These catch capabilities used unsafely, across all app types.

| Pattern | What's wrong | Threat (OODT) |
|---------|-------------|--------------|
| User input reaching shell commands without sanitization | Injection — breaks things even without malice | Shell Injection |
| `eval()` or `exec()` on external input or config-supplied code | Arbitrary code execution | Shell Injection |
| Hardcoded strings matching key/token/password patterns | Credentials leak to every site that clones the repo | Credential Exposure |
| Credentials stored in plain text files (YAML, JSON, `.env`) | Readable by anyone with filesystem access | Credential Exposure |
| `chmod 777` or permissive modes on shared filesystems | Other users can read/write | Unauthorized Access |
| Services bound to `0.0.0.0` or `::` | Accessible to other users on shared nodes | Network Exposure |
| `--no-auth` or missing authentication on network services | Other users can connect | Network Exposure |
| CORS open to all origins | Any site can make requests to the app | Network Exposure |
| State-changing endpoints with no CSRF defense | A cross-origin page can drive writes as a logged-in user; OOD's default cookie auth attaches the session automatically | Network Exposure |
| Authentication enforced on some routes but not all | A surface mounted outside the app's auth filter serves endpoints unauthenticated | Network Exposure |
| `--disable-ssl` or security features turned off | Weakens security with no explanation | Insecure Configuration |
| Default or empty passwords | Predictable credentials on exposed services | Insecure Configuration |
| Framework security features disabled (CSP, host checking) | Removes built-in protections | Insecure Configuration |
| Debug output to world-readable locations | Leaks paths, usernames, system info | Insecure Configuration |
| Missing `--cleanenv` with sensitive host environment | Host variables leak into the container | Container Security |

### OODT — Open OnDemand App Threats

> OODT is local to Appverse review and describes threats specific to the Open
> OnDemand execution model. It is not related to OWASP's separate OAT catalog.

Every finding is classified under one of these eight threat types. The risk level is
about blast radius, not raw severity: the Per-User Nginx (PUN) architecture already
contains a lot of single-user damage, so threats that escape the user's own sandbox
(cross-user, cross-site, cross-session) rank above self-harm.

| ID | Threat | Risk Level | What it is |
|----|--------|-----------|------------|
| OODT-01 | Shell Injection | Self-harm (BC) / Varies (Passenger) | User input reaching shell commands without sanitization. In BC apps under the PUN model, this only affects the submitting user's own jobs. In Passenger apps, the impact depends on what the app can reach from the web server. |
| OODT-02 | Credential Exposure | Cross-site | Hardcoded credentials in the repo, or secrets stored in plain text. Repos get cloned to every deploying site. |
| OODT-03 | Unauthorized Access | Mostly self-harm | Paths into other users' space, or wide-open file modes on shared filesystems. |
| OODT-04 | Data Exfiltration | Varies | Network calls in BC app ERB (no legitimate app does this), or any app sending user data to unexpected external servers. |
| OODT-05 | Network Exposure | Cross-user | Services reachable by other users on shared compute nodes, or CORS misconfigurations that expose Passenger app endpoints. [GHSA-2cwp-8g29-9q32](https://github.com/OSC/ondemand/security/advisories/GHSA-2cwp-8g29-9q32) showed OOD's proxy leaking auth headers to app web servers. |
| OODT-06 | Container Security | Varies | Weakening Apptainer's default isolation. (`--fakeroot` is fake root inside the container only, not real root on the host.) |
| OODT-07 | Persistence | Cross-session | Changes that outlive the job or session — dotfile writes, cron jobs, SSH keys, executables in PATH. |
| OODT-08 | Insecure Configuration | Varies | Security features turned off, debug output exposed, overly permissive defaults, framework protections disabled. |

### Rating findings

For on-demand review, rate each finding's severity using the five-level scale defined
in `finding-codes.md`:

- **Critical** — unfixable without redesigning the feature, or tagged potentially
  malicious (e.g., `curl|bash` on user-supplied URLs). Warrants a Reject
  recommendation.
- **High** — a real vulnerability, fixable with targeted changes (e.g., CORS open to
  all origins). Warrants Request changes.
- **Medium** — a genuine concern but lower blast radius or harder to exploit.
- **Low** — defensive-coding gap or minor hygiene issue.
- **Info** — positive observations or context (not used for security findings in
  practice; available for completeness).

Base the rating on blast radius (cross-user or cross-site outranks self-harm) and how
easily it is triggered. Tag each finding as **unintentional** or **potentially
malicious**.

A finding is a capability used *unsafely*, not a capability that is part of the app's
design. A job composer that runs shell commands is doing its job; running them with
CORS open to all origins is a finding. Report designed capabilities in the capability
profile; score only the unsafe usage.

Severity does not mechanically determine the review decision. A fixable
misconfiguration — even High severity, such as CORS open to all origins — points to
"request changes," not "reject." Reserve Critical and Reject for findings tagged
potentially malicious, or exposures that cannot be fixed without redesigning the app.

> The numeric severity/exploitability scoring, the commit-polling audit pipeline, and
> the catalog security badges are defined separately, not in this rubric. Both the
> on-demand skill and that pipeline classify findings with the same OODT taxonomy and
> pattern checks above.

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

| Question | Where to Find It |
|----------|-----------------|
| What does this app launch? | Overview section |
| What needs to be installed on compute nodes? | Requirements section and Software Installation in References section |
| How do I deploy it? | Installation section |
| What do I need to customize? | Configuration section |

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

- README references a different institution's paths without noting they need to change
- No Configuration section — deployers can't tell what to customize

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

| Signal | Good Sign | Concern |
|--------|-----------|---------|
| Last commit | Within 12 months | Over 12 months ago |
| Releases | Tagged releases with versioning | No releases |
| Issues | Responded to | Open issues with no response |
| Contributors | Multiple | Single contributor with no activity |
| CHANGELOG | Present and current | Missing |
| CI/CD | A workflow that lints shell/ERB or validates the YAML (`.github/workflows/` or equivalent) | None |

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

The other signals — tagged releases, issue responsiveness, contributors, CHANGELOG, CI — are good-practice indicators, not requirements. There is no requirement to cut releases or use versioning; a release is a positive signal that the team follows good practices, and its absence is worth a suggestion, never a failure. CI is the weakest of these for an app repo: most Appverse apps are config-and-template repos with little to test beyond YAML validity and shell/ERB lint, which Appverse Review already checks — so weight a missing CI workflow low.

## Decision rubric

The reviewer's decision. Derived from the gate criteria and from properties of
individual findings, never from the signal levels.

| Outcome | Criteria |
|---------|----------|
| **Accept** | Passes all gate criteria, adequate+ documentation, partially portable+ config. Always conditional on the duplicate/catalog checks the review cannot perform — word any Accept as pending those. |
| **Accept with suggestions** | Passes gate criteria but has clear improvement areas — include specific feedback. Below-target docs or portability belongs here, not Request changes, when the gate criteria are otherwise met. |
| **Request changes** | Missing a gate criterion but fixable — provide specific list of what to address. A fixable security misconfiguration, even High severity (e.g. CORS open to all origins), is Request changes, not Reject. |
| **Reject** | Duplicate app, no license, abandoned/unmaintained, not an OOD app, or a Critical-severity security finding (tagged potentially malicious or unfixable without redesigning the app — see the severity scale in `finding-codes.md`). |

Any Accept is conditional on the catalog checks the automated review cannot
perform (duplicate check, Software entry, vocabulary terms); the Reviewer
Process says how to run them.

## Appendix: common issues in real apps

Based on analysis of apps currently in the Appverse:

| Issue | Frequency | Severity |
|-------|-----------|----------|
| Missing or stub README | Common | High — blocks deployment |
| No error handling in scripts | Very common | Low — causes silent failures |
| Hardcoded paths | Common | Medium — blocks portability |
| No releases or versioning | Common | Low — but makes updates risky |
| Missing CHANGELOG | Common | Low — but reduces trust |
| No troubleshooting docs | Very common | Low — but increases support burden |
| Dead/commented-out code | Occasional | Low — but confusing |
| Magic numbers without comments | Occasional | Low — but hinders maintenance |
| Security settings disabled without explanation | Rare | High — potential vulnerability |
