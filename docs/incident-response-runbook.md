# LendWise Microfinance — Incident Response Runbook

**Author:** Rafia Zulfiqar
**Task:** 5 of 5 — Incident runbook and final security report
**Framework:** Structured on NIST SP 800-61 (Computer Security Incident
Handling Guide): Preparation → Detection & Analysis → Containment,
Eradication & Recovery → Post-Incident Activity.
**Scope:** The LendWise lending platform (web portal + API), covering
incidents like unauthorized data access (e.g. the IDOR found in Task 4),
credential compromise, and suspicious access patterns (e.g. the
brute-force/scanning activity found in Task 2).

---

## 1. Preparation

Roles (lab-scale; a real org would name actual people):
- **Incident Lead** — coordinates response, makes containment decisions
- **Technical Responder** — executes containment/eradication steps
- **Communications Lead** — handles internal and external notifications

Pre-incident requirements:
- Logging enabled on all public-facing services (Nginx access/error logs
  — see Task 2), retained for at least 90 days
- A tested, working snapshot/restore process for the platform (see
  `scripts/snapshot.sh` / `scripts/restore.sh` from Task 1) so a clean
  state is always recoverable
- Contact list for Incident Lead, Communications Lead, and (for a real
  deployment) legal/compliance contacts, since LendWise handles
  financial data for 40,000 borrowers

---

## 2. Detection & Analysis

**Detection sources:**
- Automated log analysis (`scripts/analyze-logs.sh`,
  `scripts/test-suspicious-activity.sh` — Task 2) flagging brute-force
  attempts, scanning, or enumeration patterns
- Automated hardening/IDOR compliance tests failing unexpectedly
  (`scripts/check-hardening.sh`, `scripts/test-host-hardening.sh`,
  `scripts/test-idor.sh`)
- Manual reports (e.g. a borrower reporting they can see another
  borrower's loan details)

**Initial triage questions:**
1. What system/endpoint is affected?
2. Is borrower financial/personal data exposed?
3. Is the activity ongoing, or already concluded?
4. What is the earliest log evidence of the activity?

**Severity classification** (used to drive response speed):

| Severity | Criteria | Example from this project |
|---|---|---|
| Critical | Active unauthorized access to borrower financial data | IDOR allowing any user to read any other user's records (Task 4) |
| High | Vulnerability confirmed, not yet observed as actively exploited in production | Hardening gaps found in Task 3 before they were fixed |
| Medium | Suspicious activity detected, exploitation not confirmed | Brute-force login attempts detected in Task 2 |
| Low | Informational finding, no direct risk | Minor config inconsistency |

---

## 3. Containment, Eradication & Recovery

### Containment (stop the bleeding)
1. **Isolate**, don't immediately delete — preserve evidence first (see
   Section 4). For a confirmed active exploit (e.g. IDOR being actively
   abused), the fastest safe containment is to disable the affected
   endpoint or force-expire all active sessions, rather than taking the
   whole platform offline.
2. For credential-based incidents (e.g. brute-force success): force
   password resets for affected accounts, invalidate existing sessions/
   tokens.
3. For network-level incidents: use the host firewall (Task 3) to block
   the offending source IP(s) at `iptables` level.

### Eradication (fix the root cause)
1. Apply the actual code/config fix — e.g. add server-side ownership
   checks for the IDOR (Task 4's recommendation), apply the hardening
   checklist items (Task 3) if not already in place.
2. Re-run the relevant automated test (`scripts/test-idor.sh`,
   `scripts/check-hardening.sh`, etc.) to confirm the fix actually holds
   — this is why these tests were built to be rerunnable, not one-off.

### Recovery (return to normal operation)
1. Use `scripts/restore.sh` to return the lab/platform to a known-clean
   snapshot if the environment itself may have been tampered with.
2. Re-enable any endpoints/accounts disabled during containment, only
   after the fix is verified.
3. Monitor logs closely (`scripts/analyze-logs.sh`) for a defined period
   (e.g. 72 hours) after recovery for any recurrence.

---

## 4. Evidence Handling

- **Preserve before you fix.** Before any containment/eradication step,
  capture: relevant log excerpts (with exact timestamps), the exact
  request/response that demonstrated the issue (as done in
  `docs/idor-poc-evidence.log` and `docs/idor-test-results.log`), and a
  snapshot of the affected system state if feasible.
- **Chain of custody (lab-scale):** evidence files are committed to the
  GitHub repository with timestamped commits, which provides a basic,
  tamper-evident record of when evidence was captured relative to when
  fixes were applied. A real production incident would use a dedicated,
  access-controlled evidence store, not a general-purpose code repo.
- **Do not modify original evidence.** Copies are used for analysis;
  originals (e.g. raw log files) are kept unaltered.

---

## 5. Communication

| Audience | When | What |
|---|---|---|
| Incident Lead | Immediately on detection | Technical summary, severity, affected scope |
| Development team | Once triaged | What needs fixing, reproduction steps (test script), deadline |
| Management/board | For Critical/High severity, within 24h | Plain-language summary, business impact, containment status |
| Affected borrowers | If personal/financial data was actually exposed | Factual notice of what happened, what data was involved, what's being done — timing per applicable regulatory requirements |
| Regulators | If required by jurisdiction, for confirmed data exposure | Per local financial-data-breach notification law |

**Principle:** internal technical communication can happen immediately
and informally (e.g. a message with the failing test's output); external
communication (borrowers, regulators) must be accurate, reviewed, and
only sent once the facts are confirmed — an incorrect early disclosure
can be worse than a slightly delayed accurate one.

---

## 6. Post-Incident Activity

- Document a timeline: detection time → containment time → eradication
  time → recovery time
- Run a short retrospective: what worked, what was slow, what
  monitoring gap (if any) delayed detection
- Feed findings back into Preparation (Section 1) — e.g. if a vulnerability
  class was missed by existing tests, add a new automated check for it
  (this is exactly how `scripts/test-idor.sh` and
  `scripts/test-suspicious-activity.sh` should evolve over time)
