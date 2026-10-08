# LendWise Microfinance — Final Security Assessment Report

**Author:** Rafia Zulfiqar
**Client (case study):** LendWise Microfinance Ltd.
**Engagement:** Security Assessment of Microfinance Lending Platform
**Scope:** Isolated lab environment standing in for LendWise's staging
platform (see `docs/permission-statement.md` for authorization and
scope boundaries)

## Executive Summary
Over this engagement, I built an isolated test lab and performed four
rounds of assessment: log-based detection of suspicious activity,
Linux host hardening with automated compliance testing, and discovery
plus exploitation of a Critical-severity authorization vulnerability
(IDOR). This report consolidates all findings into a single risk matrix
with prioritized, actionable remediation steps for LendWise's
development team.

## Methodology
1. **Task 1:** Built a fully isolated Docker-based lab with network
   isolation, snapshot/restore capability, and a written test plan
2. **Task 2:** Generated and analyzed traffic logs for suspicious
   patterns (brute force, scanning, enumeration), with automated,
   rerunnable detection tests
3. **Task 3:** Hardened the underlying Linux host (SSH key-only auth,
   default-deny firewall, full patching) with a 7-check automated
   compliance test suite
4. **Task 4:** Identified and exploited a real IDOR vulnerability on a
   user-data endpoint, with an automated, rerunnable reproduction test
5. **Task 5 (this report):** Consolidated findings, ran an incident
   response rehearsal, and produced this final report

## Consolidated Findings & Risk Matrix

| # | Finding | Source | Likelihood | Impact | Overall Risk |
|---|---|---|---|---|---|
| 1 | IDOR on basket/borrower-record endpoint — any user can read any other user's record | Task 4 | High | High | **Critical** |
| 2 | Brute-force login attempts possible with no observed rate-limiting | Task 2 | High | Medium–High | **High** |
| 3 | Directory/recon scanning reaches the application without being blocked | Task 2 | High | Low–Medium | **Medium** |
| 4 | Sequential ID enumeration possible across user-data endpoints | Task 2 / Task 4 | High | Medium | **High** |
| 5 | SSH/firewall/patching gaps on the host, prior to Task 3 hardening | Task 3 | Medium (pre-fix) | High | **High** (pre-fix) → **Low** (post-fix, verified) |
| 6 | Missing security headers (CSP, HSTS, X-Frame-Options) prior to hardening | Task 3 | Medium | Medium | **Medium** (pre-fix) → **Low** (post-fix, verified) |

*Risk = Likelihood × Impact, qualitatively assessed per standard
likelihood/impact matrix conventions; items 5–6 show risk reduction
achieved by in-engagement remediation, verified via the automated
compliance scripts built in Task 3.*

## Prioritized Remediation Plan

### Immediate (Critical/High — fix before any further feature work)
1. **Fix the IDOR (#1):** Add server-side ownership verification on
   every endpoint that returns user-scoped data (not just the basket
   endpoint — audit all similar endpoints, e.g. orders, addresses,
   payment methods, actual loan records on the real platform). Re-run
   `scripts/test-idor.sh` after the fix to confirm closure.
2. **Add login rate-limiting (#2):** Implement account lockout or
   progressive delay after N failed login attempts. Re-run
   `scripts/test-suspicious-activity.sh` to confirm the brute-force test
   now fails to succeed within the same attempt budget.
3. **Address enumeration risk (#4):** Move toward non-sequential
   (UUID-style) identifiers for user-owned resources where feasible, in
   addition to the ownership check in item 1 (defense in depth — even
   if ownership checks are correct, non-guessable IDs reduce blind
   probing).

### Near-term (Medium)
4. **Block/alert on scanning patterns (#3):** Add WAF-style rules or
   rate-limiting for repeated 404-generating requests to known
   recon-style paths; ensure no sensitive files (`.env`, `.git`, backups)
   are actually present in the real deployment's web root.

### Already remediated and verified in-engagement
5–6. SSH hardening, firewall default-deny, host patching, and security
headers were identified and fixed during this engagement (Task 3);
verified passing via `scripts/check-hardening.sh` (10/10) and
`scripts/test-host-hardening.sh` (7/7). These should be maintained via
the same automated scripts on an ongoing basis (e.g. in CI), not treated
as one-time fixes.

## Supporting Evidence
All raw evidence is version-controlled in this repository:
- `logs/access.log`, `docs/log-analysis-report.md`,
  `docs/automated-test-results.log` (Task 2)
- `docs/hardening-checklist.md`, `docs/host-hardening-checklist.md`,
  `docs/host-hardening-test-results.log` (Task 3)
- `docs/idor-report.md`, `docs/idor-poc-evidence.log`,
  `docs/idor-test-results.log` (Task 4)
- `docs/incident-response-runbook.md`,
  `docs/runbook-rehearsal-log.md` (Task 5)

## Overall Assessment
LendWise's platform (as represented by this lab) had one Critical
finding (IDOR) that would, on the real platform, directly expose
borrower financial data — this should be treated as the top priority.
Several Medium/High findings around authentication and reconnaissance
resistance should follow immediately after. Host-level hardening
(SSH, firewall, patching, security headers) was identified and fully
remediated during this engagement, with automated tests now in place to
prevent regression. I recommend LendWise adopt the automated test
scripts built during this engagement (`scripts/test-idor.sh`,
`scripts/test-suspicious-activity.sh`, `scripts/check-hardening.sh`,
`scripts/test-host-hardening.sh`) as ongoing CI checks, rather than
one-time assessment artifacts, so regressions are caught automatically
rather than requiring another manual engagement.

## What I left out / limitations
- This assessment covers the lab environment (Juice Shop standing in
  for LendWise's platform) since I did not have access to LendWise's
  actual codebase or production/staging systems.
- The Android app mentioned in the original brief was not assessed —
  this engagement covered only the web portal/API layer.
- A full penetration test would also cover business-logic abuse (e.g.
  fraudulent loan applications), third-party integration security, and
  physical/social-engineering vectors, none of which were in scope for
  this intern project.
