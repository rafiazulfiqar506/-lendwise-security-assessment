# LendWise Lab — IDOR Vulnerability Report (Task 4)

**Author:** Rafia Zulfiqar
**Task:** 4 of 5 — Identify and exploit broken authorisation (IDOR)
**Target:** `GET /rest/basket/{id}` on the isolated lab
(`https://staging.lendwise.test`), standing in for borrower-record
access on LendWise's real platform.

## Summary
The basket endpoint (standing in for a borrower record) checks that a
request carries a **valid** authentication token, but does not check
that the token's owner actually **owns** the specific resource being
requested. Any logged-in user can view any other user's basket simply
by changing the numeric ID in the URL — a textbook Insecure Direct
Object Reference (IDOR).

## Proof of Concept

### Setup
1. Registered two fresh accounts: User A and User B
2. Logged in as both, capturing each user's auth token and their own
   basket ID

### The exploit request
```
GET /rest/basket/<User B's basket ID> HTTP/1.1
Host: staging.lendwise.test
Authorization: Bearer <User A's token>
```

### Observed response

**Actual evidence from a real run:**
- User A: `poc-user-a-1791100565@lendwise.test` (own basket ID: 6)
- User B: `poc-user-b-1791100565@lendwise.test` (own basket ID: 7)
- Request: `GET /rest/basket/7` using **User A's** Authorization token
- Response: `HTTP 200`

```json
{"status":"success","data":{"id":7,"coupon":null,"UserId":26,"createdAt":"2026-10-04T07:56:06.376Z","updatedAt":"2026-10-04T07:56:06.376Z","Products":[]}}
```

This confirms User A received a fully valid response containing User B's
basket data (`UserId: 26`, which is User B's internal user ID, not User
A's) — proving the server authenticated the request but never checked
resource ownership.

A second, independent run via the automated test
(`scripts/test-idor.sh`) reproduced the identical pattern with a fresh
pair of users: `GET /rest/basket/9` via User A's token returned `HTTP
200` with `UserId: 28`'s basket data — confirming this isn't a one-off
fluke but a consistent, reproducible flaw. Full timestamped log:
`docs/idor-test-results.log`.

### What a correctly-authorized response should look like
```
HTTP/1.1 403 Forbidden
```
or
```
HTTP/1.1 401 Unauthorized
```
with no basket data in the body — because the server should check
"does this basket's owner match the requesting user's ID?" before
returning data, not just "is this a valid token?"

## Automated, reproducible test
`scripts/test-idor.sh` automates the entire exploit end-to-end: creates
two fresh users, logs in as both, performs the cross-user request, and
logs a timestamped result (`NOT-VULNERABLE` / `VULNERABLE`) to
`docs/idor-test-results.log`. It exits with a non-zero status when the
vulnerability is present, so it could be wired into a CI pipeline as a
regression gate once a fix is deployed — re-running it after any backend
change immediately shows whether the fix actually holds.

## Risk ranking

| Factor | Assessment |
|---|---|
| **Likelihood** | High — the attack requires no special tools, just a valid account (trivial to obtain) and incrementing a visible numeric ID. No rate limiting observed on the endpoint during testing. |
| **Impact** | High — for LendWise specifically, basket-equivalent data in the real platform would be **loan/borrower records**: balances, repayment schedules, personal and financial details. Exposure of this data is a direct privacy and regulatory risk for a microfinance lender handling 40,000 borrowers' financial data. |
| **Overall severity** | **High** (CVSS-style qualitative rating; a full CVSS score would need the real platform's exact data sensitivity to compute precisely) |
| **Ease of discovery** | High — found via basic manual inspection of the URL pattern (sequential/guessable IDs), no advanced tooling needed. |

## Recommendation
On every request for a specific resource (basket, order, loan record,
etc.), the server must verify that the **authenticated user's ID**
matches the **owner ID** stored on that resource, rejecting the request
with 403 if they don't match — regardless of whether the token itself is
valid. This check must happen server-side on every object-access
endpoint, not just at login.

## What I left out / limitations
- This PoC targets the basket endpoint specifically, since it's the
  clearest analog to a "borrower record" available in this lab (Juice
  Shop) without real loan data. A full assessment of the real LendWise
  platform would need to test every endpoint that accepts a
  user-supplied resource ID (orders, addresses, payment methods, etc.)
  for the same pattern.
- I did not attempt to modify or delete User B's data (e.g. via PUT/DELETE
  to the same endpoint) to keep the PoC strictly read-only and minimize
  any risk of corrupting lab state — this would be a reasonable follow-up
  to fully scope the vulnerability's write-access implications.