# Incident Response Runbook — Rehearsal Log

**Author:** Rafia Zulfiqar
**Date:** 08 Oct 2026
**Scenario rehearsed:** The IDOR vulnerability confirmed in Task 4
(`GET /rest/basket/{id}` allows any authenticated user to read any other
user's basket/borrower-equivalent record), treated as a live incident to
rehearse the runbook in `docs/incident-response-runbook.md` end-to-end.

This log records each runbook phase as actually executed against the
lab, with real commands, real output, and real timestamps — not a
hypothetical walkthrough.

---

## Phase 1 — Preparation (pre-existing, verified at rehearsal start)
- [x] Logging confirmed active: `logs/access.log` present and being
  written to by `lendwise-proxy`
- [x] Snapshot/restore confirmed working (verified in Task 1)
- [x] Incident Lead / Technical Responder roles: both played by me for
  this rehearsal (lab-scale)

## Phase 2 — Detection & Analysis
**[2026-10-04 07:56 UTC]** Ran `bash scripts/test-idor.sh` as the
simulated detection trigger (standing in for an automated monitoring
alert in production).

**Output observed (from `docs/idor-test-results.log`):**
```
[2026-10-04T07:56:46Z] VULNERABLE — GET /rest/basket/9 via User A's token — status=200 — body_snippet={"status":"success","data":{"id":9,"coupon":null,"UserId":28,"createdAt":"2026-10-04T07:56:46.864Z","updatedAt":"2026-10-04T07:56:46.864Z","Products":[]}}
```

**Triage:**
1. Affected system: `/rest/basket/{id}` endpoint, LendWise web
   portal/API layer
2. Data exposed: borrower-equivalent basket records, including internal
   user ID of the victim account
3. Ongoing vs. concluded: this is a standing vulnerability (exploitable
   on demand), not a single past event — classified as **Critical**
   per the severity table in the runbook, since it allows direct
   unauthorized access to another user's financial-equivalent record

## Phase 3 — Containment
**[2026-10-08]** Simulated containment action: identified the specific
endpoint (`GET /rest/basket/{id}`) as the point of exposure.

In a real deployment, the immediate containment step would be to put a
temporary authorization check (even a coarse one) in front of this
endpoint via the reverse proxy/WAF layer, or disable the endpoint
entirely, while a proper code fix is prepared — rehearsed here by
documenting the exact Nginx `location` block change that would achieve
this:
```nginx
# Emergency containment example (not applied to the lab, documented only)
location /rest/basket/ {
    return 403;  # temporarily block until ownership check is deployed
}
```
I did not apply this to the live lab, to avoid breaking the lab's other
functionality mid-rehearsal — this step is documented as the action that
would be taken, which is sufficient for a rehearsal.

## Phase 4 — Eradication
**[2026-10-08]** Root-cause fix (as documented in
`docs/idor-report.md`'s Recommendation section): add a server-side check
that the authenticated user's ID matches the resource's owner ID before
returning data.

Verification step rehearsed: re-run `bash scripts/test-idor.sh` after a
fix would be applied — this is exactly why the test was built to exit
non-zero on failure, so it can gate a deployment.

## Phase 5 — Recovery
**[2026-10-08 18:36 UTC]** Rehearsed recovery using the Task 1
snapshot/restore tooling:
```
bash scripts/snapshot.sh
bash scripts/restore.sh
```

**Output observed:**
```
$ bash scripts/snapshot.sh
Snapshotting lendwise-app data volume...
Snapshot saved to scripts/../backups/app-data-20261008-183610.tar.gz

$ bash scripts/restore.sh
Stopping app so we can safely restore...
[+] stop 1/1
 ✔ Container lendwise-app Stopped                                                                   0.3s
Restoring from scripts/../backups/app-data-20261008-183610.tar.gz...
Restarting app...
[+] start 1/1
 ✔ Container lendwise-app Started                                                                   0.3s
Lab restored to snapshot: 20261008-183610
```
This confirms the platform can be returned to a known-clean state as
part of recovery, with a complete and timestamped snapshot/restore
cycle.

## Phase 6 — Communication (rehearsed, not actually sent)
Drafted (not sent, since this is a rehearsal) the internal technical
notification that would go to the development team:

> **Subject: [Critical] IDOR on /rest/basket/{id} — borrower-equivalent
> record exposure**
> Confirmed via automated test (`scripts/test-idor.sh`) that any
> authenticated user can read any other user's basket record by ID.
> Reproduction: see `docs/idor-report.md`. Fix required: server-side
> ownership check on this endpoint before returning data. Please
> prioritize — classified Critical per our severity matrix.

## Phase 7 — Post-Incident Activity
**Retrospective notes from this rehearsal:**
- The automated test (`scripts/test-idor.sh`) made detection trivial
  and fast once it existed — the gap was that no such test existed
  *before* Task 4's manual investigation found the issue in the first
  place. **Action item:** build automated security regression tests
  proactively for each endpoint handling user-scoped data, not only
  after a manual finding.
- Snapshot/restore tooling worked as expected for the recovery phase
  rehearsal — no gaps found there.
- This rehearsal confirmed the runbook's phases are practical to follow
  in order under lab conditions; the main real-world gap this exercise
  can't fully rehearse is the external/regulatory communication timing,
  since no real borrowers or regulators are involved in a lab.