# AppVerse Security Rubric

The canonical security criteria for AppVerse app review. Used by the
`review-security` skill today, and by the automated audit pipeline (see the
[security-audit proposal](https://github.com/Sweet-and-Fizzy/ood-appverse/blob/main/docs/appverse-security-audit-proposal.md))
later. Extracted from that proposal; the proposal covers the threat model, the
automated pipeline, numeric scoring, and catalog badges, while this file is the
shared rubric both consume.

Two complementary methods, both feeding the same threat classification:

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

## Capability baseline: Batch Connect apps

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

## Capability baseline: Passenger apps

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

## Pattern checks (all app types)

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
| `--disable-ssl` or security features turned off | Weakens security with no explanation | Insecure Configuration |
| Default or empty passwords | Predictable credentials on exposed services | Insecure Configuration |
| Framework security features disabled (CSP, host checking) | Removes built-in protections | Insecure Configuration |
| Debug output to world-readable locations | Leaks paths, usernames, system info | Insecure Configuration |
| Missing `--cleanenv` with sensitive host environment | Host variables leak into the container | Container Security |

## OODT — Open OnDemand App Threats

> **Not OWASP OAT.** These OODT codes are a taxonomy local to Appverse review,
> describing threats specific to the Open OnDemand execution model. They are
> unrelated to OWASP's OAT (Automated Threat) catalog — OWASP OAT-001 is
> "Carding", OAT-008 is "Credential Stuffing", neither of which applies here.
> Always write the codes as `OODT-NN` and expand the acronym on first use in a
> report so readers do not conflate the two.

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

## Rating findings

For on-demand review, rate each finding's severity qualitatively — **High / Medium /
Low** — based on blast radius (cross-user or cross-site outranks self-harm) and how
easily it is triggered. Tag each finding as **unintentional** or **potentially
malicious**.

A finding is a capability used *unsafely*, not a capability that is part of the app's
design. A job composer that runs shell commands is doing its job; running them with
CORS open to all origins is a finding. Report designed capabilities in the capability
profile; score only the unsafe usage.

Severity does not mechanically determine the review decision. A fixable
misconfiguration — even High severity, such as CORS open to all origins — points to
"request changes," not "reject." Reserve a reject recommendation for findings tagged
potentially malicious, or exposures that cannot be fixed without redesigning the app.

> The numeric severity/exploitability scoring, the commit-polling audit pipeline, and
> the catalog security badges live with the
> [security-audit proposal](https://github.com/Sweet-and-Fizzy/ood-appverse/blob/main/docs/appverse-security-audit-proposal.md),
> not in this rubric. Both the on-demand skill and that pipeline classify findings
> with the same OODT taxonomy and pattern checks above.
