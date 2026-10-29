# Appverse Review Rubric

> **Related Docs:**
> [Appverse Reviewer Process](https://openondemand.connectci.org/appverse-reviewer-checklist) |
> [Appverse Contributor Guide](https://openondemand.connectci.org/appverse-contributor-documentation) |
> [Appverse Best Practices](https://openondemand.connectci.org/appverse-best-practices) |
> [Appverse README Template](https://github.com/tamu-edu/appverse_readme_template)

This page sets out how Appverse apps are reviewed. Reviewers apply it, and
contributors can read it to see what their app is judged on. What the
catalog shows is explained under How to read this rubric. The automated
review and the human reviewer use the same criteria. The
[Reviewer Process](https://openondemand.connectci.org/appverse-reviewer-checklist)
says in what order to apply them.

## How to read this rubric

A review has four parts.

1. **Gates.** Pass/fail requirements in the Structure section.
2. **Signals.** A level on each of three axes that tells a deployer what to
   expect. The top levels are Portable, Complete or Well maintained.
3. **Findings.** Specific problems with file and line evidence.
4. **The decision.** Accept, Accept with suggestions, Request changes or
   Reject, set out in the [Decision rubric](#decision-rubric).

**Signals do not gate; the decision rubric does.** The levels, best first:

| Axis | Best | Middle | Needs most attention |
|------|------|--------|----------------------|
| Portability | Portable | Needs site config | Site-specific |
| Documentation | Complete | Adequate | Minimal |
| Upkeep | Well maintained | Active | Inactive |

The catalog shows each listed app's three levels: Upkeep, Documentation
and Portability. Beside them is a Security badge. It shows the number of
FAIL or WARN findings left after the reviewer's changes, or "No findings to
review". There is no security level, and the count is not a safety rating.

The README counts twice. A README that is missing or only a stub fails the
Structure gate. A real README is then rated for depth as the Documentation
signal.

Each finding has a rule code (STR, OODT, QUA or MNT), a severity from
Critical to Info (see [Rating findings](#rating-findings)), file and line
evidence, and one of four results:

- **FAIL:** the criterion is not met.
- **WARN:** the tool could not confirm the criterion, or the problem is
  advisory.
- **PASS:** the check ran and found nothing.
- **NOT CHECKED:** the check could not run.

On a gate, WARN and NOT CHECKED are not passes. The reviewer checks that
gate by hand, from the cited evidence, before deciding.

### Terms

- **Gate:** a Structure requirement every app must pass to be listed.
- **Finding:** one recorded problem, with a rule code, severity, result and
  evidence.
- **Level:** the reading on one signal axis, such as Needs site config.
- **Floor:** the mildest decision a reviewer can give, set by certain
  findings. See [Floors](#floors).
- **Fix-item:** something the feedback to the contributor names as needing
  a fix. Every gate FAIL is one, and so is every FAIL or WARN finding rated
  Low or above. An Info finding never is.
- **Brand-new app:** an app whose repo's first commit is less than six
  months old. It is too new to judge on releases, contributors or issues, so
  its Upkeep is Active at most and never counts against it.
- **Duplicate:** an app that repeats one already in the catalog, either the
  same app with a different site's configuration or a fork with minor
  changes. The same software run in a meaningfully different way, such as
  containerized instead of module-based, is not a duplicate. Nor is a
  maintained fork of an abandoned app in the catalog.
- **Decline:** the portal's word for Reject.

## Repo shapes

Your repo needs one of two files at its root. With an `appverse.yml`, you
describe how your app or apps appear in the catalog. This is a **declared**
repo. With only a `manifest.yml`, the catalog builds a single listing from
that file and GitHub. This is an **inferred** repo. A repo with neither
fails the Structure gate.

A declared repo whose `appverse.yml` has an `apps:` list is a
**monorepo**. Each entry in `apps[]` is reviewed as its own app, with its
own structure, security and quality assessment and its own decision.
Per-app fields resolve in this order:

1. Inline in the root `appverse.yml` `apps[]` entry (highest)
2. `<subpath>/appverse.yml`
3. `<subpath>/manifest.yml` (name and description only)

Directories listed in `shared_paths` are shared code. They are reviewed
once at repo level and included in the security review. `shared_paths` is
not a pass/fail criterion.

Installing any app from a monorepo clones the whole repo. So some problems
decide every app at once: a failed repo-level gate, an abandoned repo, or a
High or Critical security finding anywhere in the repo, even inside one
app's folder. After that, each app gets its own decision. Three apps can be
accepted while a fourth gets Request changes for missing metadata. The
overall recommendation is the strictest of the per-app decisions.

## Structure (gate criteria)

Every row below is a gate. A FAIL on any of them means at least Request
changes, and the feedback lists it as something to fix. Where the tool
could not confirm a row, the reviewer checks it by hand. Other structure
notes the review adds are not gates.

### Repository structure

Every repo, whatever its shape:

| Check | What to look for |
|-------|------------------|
| `README.md` exists and is substantive | Not the unfilled template (placeholder text like "Key feature 1"), and not just a title and contact line. Depth is rated separately as the Documentation signal |
| A license file exists (`LICENSE`, `LICENSE.txt`, `LICENSE.md`, `LICENSE.rst` or `COPYING`, any case) | An open source license (MIT recommended) |
| Repo shape is identifiable | A root `appverse.yml` (declared) or root `manifest.yml` (inferred). See Repo shapes |
| Repo is not archived on GitHub | An archived repo cannot be maintained |
| Repository is public and accessible | A private or unreachable repo cannot be listed, since the catalog links to it |

README and LICENSE are checked once at repo level. In a monorepo the apps
share them. An app-level README at a subpath is welcome but not required.

**Inferred repos** (root `manifest.yml`, no `appverse.yml`):

| Check | What to Look For |
|-------|------------------|
| `manifest.yml` required fields | `name`, `category`, `role`, `description` at minimum |

**Declared repos** (root `appverse.yml`), checked per app after the field
order above. The same fields are required for one app or several:

| Check | What to Look For |
|-------|------------------|
| `name` | Present (from `appverse.yml`, or a member app's `manifest.yml`) |
| `description` | Present |
| `software` | Present. It must also match a Software entry in the catalog. If it doesn't, the reviewer works that out with you |
| `app_type` | A term from the catalog's app-type list. A near miss, such as a misspelling, fails, and the review suggests the closest term. Each `implementation_tags` entry must also be on its list (see the [appverse.yml reference](https://github.com/Sweet-and-Fizzy/ood-appverse/blob/main/docs/appverse.yml)) |
| `maintainer.name` + `maintainer.support_url` | Both present. Without a support URL, deployers have no one to contact |
| `manifest.yml` at the app's subpath | Required for the app to run inside OOD |

### Batch Connect layout

The app's layout is a gate, recorded as STR-07.

A Batch Connect app has the standard OOD structure: `form.yml` or
`form.yml.erb`, `submit.yml.erb`, and a `template/` directory containing the
job script (`script.sh.erb`, or `script.sh` when nothing is templated). OOD
renders `form.yml.erb` at request time, so an app shipping only the `.erb`
variant is complete. Shipping both is unusual and worth a look.

Passenger and companion apps have their own layout check:

- An entry point that exists and parses (`config.ru` for Ruby/Rack,
  `passenger_wsgi.py` for Python/WSGI). Recorded as STR-07.
- A `manifest.yml` `role` that matches that layout. A missing `role` is a
  WARN.
- A dependency file (such as `requirements.txt`, `Gemfile.lock` or
  `package-lock.json`) that lists the packages the code imports. A missing
  or inconsistent one is STR-08.

### Validity

| Check | What to look for |
|-------|------------------|
| `manifest.yml` and `appverse.yml` are valid YAML | Parse without errors |
| `form.yml` is valid YAML; `form.yml.erb` has balanced ERB tags | `form.yml.erb` cannot be parsed as YAML before rendering, so its `<% %>` tags are checked for balance instead |
| Template scripts are syntactically correct | Shell scripts pass a syntax check (`bash -n`) and ERB templates render. Recorded as STR-06. Shellcheck warnings alone never fail this row. An error right next to a template's `<% if %>`, `<% else %>` or `<% end %>` tag may come from how the tool reads templates, so it is a WARN for the reviewer to check. An unclosed block, such as a missing `fi` or an unclosed quote, still fails |
| No obviously broken references | Module names, paths and variables used in `submit.yml.erb` and `template/` exist in `form.yml` or `form.yml.erb` |

## Security

Security is a list of findings, not a rating. When a review finds nothing,
the catalog shows "No findings to review". That means the checks found
nothing. It does not mean the app is safe. Each finding gets an OODT threat
type and a severity. How findings affect the decision is in the
[Decision rubric](#decision-rubric).

### How the automated review checks security

Every report names which of the three tiers ran and which it skipped:

- **Tier 1, static.** Reads the source. Runs everywhere, including CI on a
  submitted pull request.
- **Tier 2, tooling.** Runs static analysis tools such as shellcheck,
  bandit and semgrep when they are installed. The report's tool table lists
  what ran.
- **Tier 3, runtime.** Boots the app in an isolated, disposable
  environment, never on a reviewer's own machine or a shared host. It
  usually does not run, and the report marks it NOT CHECKED.

Tier 1 checks a fixed list of risky spots in every app. These include form
values passed into scripts, `eval` calls, credential-like strings,
permission changes, network calls, writes outside the job directory,
security-related flags, and binary files under `template/`. Each spot gets
its own row in the report. A reviewer then looks for problems the list
cannot catch, such as missing CSRF protection or partial authentication,
and records them in a second table. The report says
"No tool-detectable issues in the checked tiers" only when
no row in either table is FAIL or WARN.

### OODT — Open OnDemand App Threats

OODT is local to Appverse review and describes threats specific to the Open
OnDemand execution model. Every finding is classified under one of these
eight threat types.

The risk level is about blast radius. OOD runs each user's apps under their
own Per-User Nginx (PUN), which already contains a lot of single-user
damage. So threats that escape the user's own space (cross-user,
cross-site, cross-session) rank above self-harm.

| ID | Threat | Risk Level | What it is |
|----|--------|-----------|------------|
| OODT-01 | Shell Injection | Self-harm (Batch Connect) / Varies (Passenger) | User input reaching shell commands without sanitization. In Batch Connect apps under the PUN model, this only affects the submitting user's own jobs. In Passenger apps, the impact depends on what the app can reach from the web server. |
| OODT-02 | Credential Exposure | Cross-site | Hardcoded credentials in the repo, or secrets stored in plain text. Repos get cloned to every deploying site. |
| OODT-03 | Unauthorized Access | Mostly self-harm | Paths into other users' space, or wide-open file modes on shared filesystems. |
| OODT-04 | Data Exfiltration | Varies | Network calls in Batch Connect app ERB (no legitimate app does this), or any app sending user data to unexpected external servers. |
| OODT-05 | Network Exposure | Cross-user | Services other users on shared compute nodes can reach without authentication, or CORS misconfigurations that expose Passenger app endpoints. [GHSA-2cwp-8g29-9q32](https://github.com/OSC/ondemand/security/advisories/GHSA-2cwp-8g29-9q32) showed OOD's proxy leaking auth headers to app web servers. |
| OODT-06 | Container Security | Varies | Weakening Apptainer's default isolation. |
| OODT-07 | Persistence | Cross-session | Changes that outlive the job or session, such as dotfile writes, cron jobs, SSH keys, or executables in PATH. |
| OODT-08 | Insecure Configuration | Varies | Security features turned off, debug output exposed, overly permissive defaults, framework protections disabled. |

### Capabilities and patterns

**Capability profiling** lists what an app does: its system access,
network calls, file reads and writes, and processes. In a Batch Connect
app, an unusual capability is a strong sign of malicious intent. A
Passenger app legitimately does much more, so its profile is there to show
deployers what they are installing. An app is never penalized for doing
what it is designed to do.

**Pattern checks** catch capabilities used unsafely, in any app type.

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

The expected profile is wide. Every capability below is reported. Rows
marked Flagged also produce a finding.

| Capability | Flagged |
|-----------|---------|
| Handling HTTP requests, serving pages | No |
| Reading/writing files in user's space | No |
| Outbound HTTP to external APIs | No |
| Running shell commands (scheduler interaction) | No |
| `eval()` or `exec()` on user/config-supplied code | Yes |
| Accepting raw shell commands from browser requests | Yes |
| Dynamic module loading from user-writable paths (`importlib`, `require`) | Yes |
| Spawning detached background processes | With context |
| CORS open to all origins | Yes |
| Disabling framework security features (CSP, host checking) | Yes |
| Storing credentials in plain text files | Yes |
| Writes to shell init files, `~/.ssh/*`, cron | Yes |

**Dashboard apps and widgets** have no detailed baseline yet, because the
catalog has too few examples. Apply the pattern checks and report whatever
capabilities are found.

### Pattern checks (all app types)

| Pattern | What's wrong | Threat |
|---------|-------------|--------------|
| User input reaching shell commands without sanitization | Injection, which breaks things even without malice | OODT-01 Shell Injection |
| `eval()` or `exec()` on external input or config-supplied code | Arbitrary code execution | OODT-01 Shell Injection |
| Hardcoded strings matching key/token/password patterns | Credentials leak to every site that clones the repo | OODT-02 Credential Exposure |
| Credentials stored in plain text files (YAML, JSON, `.env`) | Readable by anyone with filesystem access | OODT-02 Credential Exposure |
| `chmod 777` or permissive modes on shared filesystems | Other users can read and write | OODT-03 Unauthorized Access |
| A network service with no password or token, or one started with `--no-auth` | Other users on the node can connect | OODT-05 Network Exposure |
| CORS open to all origins | Any site can make requests to the app | OODT-05 Network Exposure |
| State-changing endpoints with no CSRF defense | A page on another site can make writes as the logged-in user, because OOD's cookie auth sends the session automatically | OODT-05 Network Exposure |
| Authentication enforced on some routes but not all | Endpoints mounted outside the app's auth filter are served without authentication | OODT-05 Network Exposure |
| `--disable-ssl` or security features turned off | Weakens security with no explanation | OODT-08 Insecure Configuration |
| Default or empty passwords | Predictable credentials on exposed services | OODT-08 Insecure Configuration |
| Framework security features disabled (CSP, host checking) | Removes built-in protections | OODT-08 Insecure Configuration |
| Debug output to world-readable locations | Leaks paths, usernames, system info | OODT-08 Insecure Configuration |
| Missing `--cleanenv` with sensitive host environment | Host variables leak into the container | OODT-06 Container Security |
| A finding from a static-analysis tool such as shellcheck, semgrep or bandit (`check: sec-tool-finding`) | Judged on its own merits | Depends on the finding |

Binding to all interfaces (`0.0.0.0` or `::`) is not exposure by itself.
Open OnDemand's proxy reaches the service on the compute node, so the
service has to bind that way. The finding is a service anyone can reach
without a password or token. Authentication counts when the service
actually uses it. A password the app generates but never passes to the
service leaves it open.

### Rating findings

Each finding gets one of five severities:

- **Critical:** cannot be fixed without redesigning the feature, or tagged
  potentially malicious (for example, `curl|bash` on user-supplied URLs).
  Warrants Reject.
- **High:** a real vulnerability or gate failure that targeted changes can
  fix (for example, CORS open to all origins). Warrants Request changes.
- **Medium:** a genuine concern with a smaller blast radius, or harder to
  exploit.
- **Low:** a defensive-coding gap or minor hygiene issue.
- **Info:** suggestions, upkeep good-practice signals, positive
  observations. An Info finding is not something the contributor must fix.

Each check has a usual severity, and its findings take it. Where the
evidence calls for a different severity, the finding says why. Suggestions
are always Info. Findings no check covers are rated on the scale above.

Base the rating on blast radius (cross-user or cross-site outranks
self-harm) and on how easily the problem is triggered. Tag each finding as
**unintentional** or **potentially malicious**.

A finding is a capability used unsafely. A capability that is part of the
app's design is not a finding. A job composer that runs shell commands is
doing its job, but running them with CORS open to all origins is a finding.
Report designed capabilities in the capability profile, and rate only the
unsafe use.

## Portability

How much a deployer at another site has to change before the app runs.

A value is site-specific if it must change for the app to run at another
site. These are the cluster, partition, account, module, absolute paths and
container image. Portable means every such value is a form attribute. A
site then sets it in its own config file,
`/etc/ood/config/apps/<app>/<cluster>.yml`, without editing the repo.

**Portability signal:** the catalog shows the level. The report writes the
grade beside it.

| Level | Report grade | What it means |
|-------|--------------|---------------|
| **Portable** | Portable | Every site-specific value is a form attribute |
| **Needs site config** | Partially portable | Some hardcoding, but the main configuration is in `form.yml` attributes. A value the README documents but the repo hardcodes counts here, since a site still edits the repo to change it |
| **Site-specific** | Not portable | Hardcoded paths, cluster names and module versions throughout, or a form that only renders with Ruby or files from the author's site |

**Target for inclusion:** Needs site config or better. For an app below
it, the feedback suggests moving site-specific values into form attributes
so a site can set them in its own config.

Where to look: `submit.yml.erb`, `form.yml`, `form.yml.erb` and `template/`
scripts, for cluster names, partitions, accounts, absolute site paths,
module versions and container images.

**Named check**, recorded as QUA-02 findings with file and line evidence:

- `check: hardcoded-site-paths`: a scratch, project or home path, a cluster
  or partition name, or a module version written into a script or template
  instead of a `form.yml` attribute. A value listed in the README's
  configuration table passes this check and counts toward Needs site
  config. An undocumented one counts against it.

## Documentation

How well the README answers a deployer who has never seen the app. The
README should follow the
[Appverse README Template](https://github.com/tamu-edu/appverse_readme_template).

**Documentation signal:** the report rates the README on five grades, and
the catalog shows the level beside each. Each grade needs everything in the
grade below it.

| Report grade | Level | Adds |
|--------------|-------|------|
| **Exemplary** | Complete | A user-facing info panel and an architecture explanation |
| **Strong** | Complete | Troubleshooting, screenshots, environment variables |
| **Adequate** | Adequate | Installation, configuration, known limitations |
| **Minimal** | Minimal | What the app launches, and what must be installed on compute nodes |
| **Below minimal** | Minimal | Less than Minimal |

The template puts these in its Overview, Requirements (with Software
Installation under References), Installation and Configuration sections.

The review starts from what the README's sections cover. Its starting
grade is the highest one the sections support, with that grade and every
grade below it met. A heading with only template placeholder text under it
does not count. A heading with nothing under it does count, so when a
section doesn't really cover what its heading says, the review lowers the
grade and says why.

The review rates lower than the starting grade only with a stated reason.
A section is wrong, out of date, describes another site, or doesn't cover
what its heading suggests. A "Conda environment" section is not
environment variables, for example. A thin section with no such reason
keeps its grade.

The review rates higher only where the README delivers a missing
requirement somewhere else. Before rating a requirement as missing, the
reviewer checks other headings' content (configuration met by a line under Environment
Variables, for example). The report cites such a line as
`content: README.md:N`. The reviewer can still change the level.

**Target for inclusion:** Adequate or better. A README below Adequate,
including Below minimal, gets a QUA-01 FAIL finding.

A stub README is a Structure gate failure (STR-01), not a Minimal rating.
A README is a stub when it has fewer than 100 characters of content, or
when every section is still template placeholder text with no real text
above the first heading. The report's rating line then reads
"Minimal — not supported (stub README; see QUA-01)".

**Red flags** (recorded as QUA-01 findings):

- The README references a different institution's paths without noting
  they need to change
- No Configuration section, so deployers can't tell what to customize

## Code Quality

Findings about how the app is written, with file and line evidence. Error
handling and input validation are strong suggestions, worded in the
feedback as recommended. A script that keeps running after an error, or a
form that accepts any value, fails silently for deployers. The rest are
suggestions, rated Info.

| Check | Target |
|-------|--------|
| Error handling in job scripts (QUA-03, `check: error-handling`) | Strong suggestion |
| Input validation on form fields that reach the scheduler (QUA-07, `check: numeric-field-bounds`) | Strong suggestion |
| Numbers and literals such as resource limits, tunables, ports, hex colors and module versions have a comment saying what they are (QUA-08, `check: magic-numbers`) | Suggestion |
| No large blocks of duplicated code (QUA-09, `check: duplicated-blocks`) | Suggestion |
| No commented-out dead code (QUA-04, `check: dead-code`) | Suggestion |
| ERB templates handle missing or nil values (QUA-10, `check: erb-missing-value`) | Suggestion |
| Desktop or panel icon exists on the README's target OS (QUA-06, `check: icon-matches-target-os`) | Suggestion |

**Correctness and polish** defects are also Code Quality findings:
leftovers from the template an app was cloned from, such as a MATLAB
reference in a SAS app (QUA-05), and duplicate YAML keys, wrong help text
and README typos (QUA-06). A duplicate YAML key parses, but only the last
value counts, so it is almost always a mistake.

**Draft feedback guidance.** Never advise removing a comment or help text
that states a real constraint, such as a partition that requires a GPU.
Advise rewording it.

**Named checks:**

- `check: error-handling`: the job script handles failures of the
  commands that matter, such as `cd` into the work directory,
  `module load` or `mkdir`. A check such as `|| exit 1`, an `if` or a
  `trap` counts. `set -e` is not required, and it can break a script that
  runs background processes.
- `check: numeric-field-bounds`: a number field that reaches the scheduler
  needs a `min`, or must be `required`. A `min` of 0 where 0 makes no
  sense, such as 0 cores, is a finding. A `max` is good but is not
  required, since it can come from site config. A free-text field that
  reaches the scheduler needs a `pattern`. Making it `required` is not
  enough, since it still takes any text.
- `check: icon-matches-target-os`: icons named in desktop and panel
  configuration under `template/` (such as `xfce4-panel.xml` `button-icon`
  or `.desktop` `Icon=`) exist on the OS the README says the app was tested
  on. A Fedora icon in an app documented for Rocky Linux is a finding.

## Upkeep

Signals about the project's health.

| Signal | Good Sign | Concern |
|--------|-----------|---------|
| Last commit | Within 12 months | Over 12 months ago |
| Releases | Tagged releases with versioning | No releases |
| Issues | Responded to | Open issues with no response |
| Contributors | More than one | One, with no recent activity |
| CHANGELOG | Present and current | Missing |
| CI/CD | A CI workflow is present (ideally one that lints shell/ERB or validates the YAML) | None |

**Upkeep signal:**

| Level | When |
|-------|------|
| **Well maintained** | Active within 12 months, with two or more good-practice signals |
| **Active** | Active within 12 months, or a brand-new app |
| **Inactive** | No commit in over 12 months. This is an MNT-01 finding |

The good-practice signals are releases, a current CHANGELOG, CI, more than
one contributor, and answered issues. Each counts once. A repo with no open
issues is neutral on that last one. Good-practice signals are not
requirements. A missing one is an Info suggestion. It never fails the
review, never lowers the level, and is not something the contributor must
fix.

**Target for inclusion:** active within 12 months. A brand-new app (first
commit less than six months ago) is Active at most, and the evidence says
the waiver applies.

In a monorepo, each app also gets its own Upkeep level, based on changes by
people to its own folder. Releases, CI and issues come from the repo. Bot
commits do not count. The per-app level is shown to deployers but does not
affect the decision. Only the repo's Upkeep does.

**Decision role.** An abandoned repo is a reason to Reject. Whether a repo
is abandoned is the reviewer's judgment, for example a repo that is
inactive, leaves issues unanswered, and has no maintainer answering at the
support URL. Inactive is not the same as abandoned. Inactivity alone shows
as the Inactive level and sets no floor. An archived repo fails the
Structure gate instead.

## Decision rubric

The automated review suggests a decision, and the reviewer makes it. Gates
and findings decide whether an app can be accepted. Fix-items and levels
below target decide whether an Accept carries suggestions.

| Outcome | Criteria |
|---------|----------|
| **Accept** | Passes every gate. Documentation is Adequate or Complete, and Portability is Portable or Needs site config. No fix-item is left: every remaining finding is Info-level polish. The reviewer has recorded the duplicate check and settled the Software entry and vocabulary terms. |
| **Accept with suggestions** | Passes every gate, with at least one fix-item that sets no floor, or a level below target. Include specific feedback. Info-level polish alone is an Accept. |
| **Request changes** | A gate fails but can be fixed, or a finding sets this floor. List what to fix. A missing LICENSE is Request changes, since the contributor adds one file. |
| **Reject** (Decline on the portal) | A duplicate, an abandoned repo, an app that is not an OOD app, or a Critical security finding. |

Levels never force Request changes or Reject. A Documentation level below
Adequate, or a Portability level below Needs site config, means the most
the app gets is Accept with suggestions.

A fixable High security finding, such as CORS open to all origins, is
Request changes, not Reject. Reject is for findings tagged potentially
malicious, or ones that cannot be fixed without redesigning the app. A
duplicate the contributor can turn into a meaningfully different approach
is also Request changes.

### Floors

Some findings set a floor, the mildest decision the reviewer can give. The
review page does not offer a decision below it.

- A failed gate sets Request changes, whatever its severity. A gate failure
  can always be fixed, so it is never Critical.
- A security finding sets at least Request changes at High, and Reject at
  Critical.
- Inactivity (MNT-01) sets no floor. An abandoned repo is a Reject by the
  reviewer's judgment (see Upkeep).
- A structure note that isn't one of the gate checks is not a gate failure.
  Like a security finding, it sets a floor only at High or Critical.
- WARN results and dismissed findings set no floor. Documentation,
  portability and code-quality findings never set one.
- In a monorepo, repo-level gates and every High or Critical security
  finding apply to every app. The overall recommendation is the strictest
  per-app decision.

### Reviewer changes

A reviewer can give a finding a new severity or dismiss it as not a
finding, with a reason for the contributor. The tool's original values stay
on the record. Everything downstream uses the reviewer's values, including
the floors and the catalog's Security count. A dismissed finding counts as
no finding. A reviewer can also change a signal level, with a reason.

A finding that cites only demo, docs, example or test files is about code a
site does not install. It still counts until the reviewer dismisses it. The
reviewer decides whether it matters.

## Appendix: common issues in real apps

Examples of issues seen in submitted apps, and where this rubric rules on
each.

| Issue | Where it is covered |
|-------|---------------------|
| Missing or stub README | Structure gate (STR-01) |
| No error handling in scripts | Code Quality, strong suggestion |
| Hardcoded paths | Portability |
| No releases or versioning | Upkeep, good practice |
| Missing CHANGELOG | Upkeep, good practice |
| No troubleshooting docs | Documentation, needed for Complete |
| Dead or commented-out code | Code Quality, suggestion |
| Magic numbers without comments | Code Quality, suggestion |
| Security settings disabled without explanation | Security (OODT-08) |
