**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 22 findings (SC2054, SC2317, SC2148, SC2154, SC2086), 4 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Run | 3 findings (B110, B104) |
| trivy | Not run (no applicable files) | — |
