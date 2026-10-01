**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 9 findings (SC2155, SC2086, SC2154, SC1091, SC2034), 3 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |
