# LendWise Microfinance Platform — Security Test Plan

**Author:** Rafia Zulfiqar
**Date:** [fill in today's date]
**Engagement:** Security Assessment of Microfinance Lending Platform (Ezitech Intern Project)

## 1. Objective
Identify and document security weaknesses in the LendWise lending platform
(web portal + Android app) that could put borrower data, loan funds, or
platform integrity at risk, and provide actionable remediation guidance.

## 2. Scope

### In scope
- Staging environment only: `https://staging.lendwise.test`
- The isolated lab deployment described in this repository (Docker Compose,
  internal network, no route to production or the public internet)
- Web application layers: authentication, session management, loan
  application flow, user profile/account pages, payment/repayment pages
- Underlying host configuration (OS hardening — covered in Task 3)

### Out of scope
- Any real/production LendWise system
- Any real customer data
- Denial-of-service testing
- Physical security, social engineering, phishing of real staff
- Third-party services LendWise integrates with (unless separately authorized)

## 3. Rules of engagement
- All testing is performed **only** against the isolated lab described above.
- Written permission (see `docs/permission-statement.md`) must be signed
  before any testing begins.
- Snapshot the lab before each test session; restore after destructive tests.
- No testing against any system outside the isolated Docker network.

## 4. Modules to be tested

| # | Module | Why it matters |
|---|--------|-----------------|
| 1 | Authentication (login/logout/password reset) | Entry point for account takeover |
| 2 | Session management | Session fixation/hijacking risk |
| 3 | User registration & profile | PII exposure, input validation |
| 4 | Loan application flow | Business-logic abuse (e.g. fake loans) |
| 5 | Loan/account viewing (IDOR target — Task 4) | Access to other users' loan/financial data |
| 6 | Repayment / transaction pages | Financial data tampering |
| 7 | Admin/staff areas (if present) | Privilege escalation |
| 8 | API endpoints backing the Android app | Same web risks, often less protected |

## 5. Test approach by module

For each module above:
1. **Recon** — map all endpoints/pages and how they call the backend.
2. **Authentication & session checks** — test password policy, brute-force
   protection, session token strength/expiry.
3. **Authorization checks** — test whether one logged-in user can view/edit
   another user's data by changing an ID (IDOR — detailed test cases in
   Task 4 deliverable).
4. **Input validation** — test forms/API params for injection-style flaws.
5. **Logging** — confirm security-relevant events are logged (feeds Task 2).

## 6. Sample test cases (expand as testing progresses)

| ID | Module | Test case | Expected secure behavior |
|----|--------|-----------|---------------------------|
| TC-01 | Auth | Attempt login with wrong password 10x rapidly | Account lockout / rate-limit triggers |
| TC-02 | Auth | Inspect session cookie attributes | `HttpOnly`, `Secure`, `SameSite` set |
| TC-03 | Loan viewing | Log in as User A, change loan ID in URL/API to User B's | Access denied (403), not User B's data |
| TC-04 | Profile | Submit script tags in profile "name" field | Input rejected or safely encoded |
| TC-05 | Repayment | Attempt to submit negative repayment amount | Request rejected server-side |
| TC-06 | Admin/staff areas | Attempt to access admin URLs as a normal user | Access denied (403), not admin panel |
| TC-07 | API endpoints | Call loan API directly (bypassing UI) with another user's ID | Access denied, matching web behavior |
| TC-08 | Auth | Check if password reset tokens expire after use/time | Token invalid after single use or timeout |

## 7. Environment
- Lab defined in `docker-compose.yml`, isolated via a Docker `internal`
  network with no route to the real internet.
- Reachable at `https://staging.lendwise.test` via the Nginx reverse proxy.
- Snapshot/restore via `scripts/snapshot.sh` and `scripts/restore.sh`.

## 8. Deliverables from this testing effort
- This test plan
- Log analysis report (Task 2)
- Hardening checklist (Task 3)
- IDOR proof of concept (Task 4)
- Incident runbook and final report (Task 5)
