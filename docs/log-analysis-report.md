# LendWise Microfinance Platform — Log Analysis Report

**Author:** Rafia Zulfiqar
**Date:** 20 Sep 2026
**Task:** 2 of 5 — Log analysis for suspicious activity
**Source logs:** `logs/access.log` (Nginx access log from the isolated lab,
generated via `scripts/generate-traffic.sh` against `staging.lendwise.test`)

## 1. Method
Traffic (a mix of normal browsing and simulated suspicious activity) was
generated against the isolated lab using `scripts/generate-traffic.sh`.
The resulting Nginx access log was then analyzed using
`scripts/analyze-logs.sh`, which flags:
- Repeated failed logins from a single IP (brute force)
- Requests to sensitive/common recon paths (scanning)
- Sequential ID sweeps across an endpoint (enumeration / IDOR probing)
- Injection-style patterns in query strings
- Elevated 4xx/5xx response rates

## 2. Findings

### Finding 1: Brute-force login attempts
- **What was seen:** IP 172.18.0.1 sent 15 consecutive POST requests to
  /rest/user/login within a 2-second window (12:53:19–12:53:20), every
  one returning HTTP 401 (Unauthorized). The User-Agent was
  "curl/8.18.0" rather than a browser, consistent with automated/scripted
  login attempts rather than a real user mistyping their password.
- **Why it matters:** Repeated rapid login failures from one source
  indicate a credential-guessing / brute-force attempt, which could lead
  to account takeover if not rate-limited.
- **How to reproduce:**
  1. `docker compose up -d`
  2. `bash scripts/generate-traffic.sh`
  3. `bash scripts/analyze-logs.sh` → see section "2. Repeated failed
     login attempts"
- **Recommendation:** Implement account lockout / rate-limiting on the
  login endpoint after N failed attempts (see hardening checklist, Task 3).

### Finding 2: Directory/path scanning
- **What was seen:** The same IP (172.18.0.1) requested 9
  sensitive/common recon paths within the same second (12:53:20):
  /admin, /administrator, /wp-admin, /.env, /.git/config, /config.php,
  /backup.zip, /phpmyadmin, /.aws/credentials, and /server-status. All
  returned HTTP 200, meaning the requests reached the app rather than
  being blocked outright — though in this lab (Juice Shop) these
  particular paths simply route to the single-page app rather than
  exposing real files.
- **Why it matters:** This pattern is characteristic of automated recon
  tools probing for exposed config files, credentials, or unintended
  admin panels.
- **How to reproduce:** same steps as above → see analysis section "3."
- **Recommendation:** Ensure no sensitive files (.env, .git, backups) are
  served by the web root; return generic 404s; consider a WAF rule to
  flag repeated scanning patterns.

### Finding 3: Sequential ID enumeration
- **What was seen:** IP 172.18.0.1 requested /rest/products/1/reviews
  through /rest/products/26/reviews in strict sequential order, seconds
  apart, using the same automated User-Agent — a textbook
  ID-enumeration sweep that would be used to probe for an IDOR
  vulnerability (see Task 4).
- **Why it matters:** Sequential enumeration of numeric IDs is often the
  first step toward an IDOR (Insecure Direct Object Reference) attack —
  directly relevant to Task 4's IDOR testing.
- **How to reproduce:** see analysis section "4."
- **Recommendation:** Use non-sequential (UUID) identifiers where
  feasible, and enforce per-object authorization checks server-side
  regardless of ID guessability.

### Finding 4: Injection attempt patterns
- **What was seen:** The analysis script's pattern match did not flag
  the injection attempts in this run, because curl URL-encodes special
  characters (e.g. spaces and quotes) before sending them, so the raw
  text pattern the script searches for didn't appear verbatim in the log
  line. The requests were still sent and logged (visible as GET requests
  to /rest/products/search with an encoded query string). This is a
  useful, honest finding in itself: simple text-pattern matching against
  raw logs can miss encoded payloads, which is why real-world log
  analysis tools normalize/decode fields before pattern matching.
- **Why it matters:** Indicates probing for SQL injection and
  cross-site scripting (XSS) vulnerabilities, and separately shows a gap
  in naive log-scanning approaches.
- **How to reproduce:** see analysis section "5"; to see the raw
  (encoded) requests directly, run `grep "products/search" logs/access.log`.
- **Recommendation:** Parameterized queries / ORM usage server-side;
  output encoding for any reflected user input; input validation at the
  API boundary. For log analysis tooling, decode/normalize query strings
  before pattern matching so encoded payloads aren't missed.

## 3. Summary table

| # | Finding | Severity (est.) | Reproducible? |
|---|---------|------------------|----------------|
| 1 | Brute-force login attempts | Medium–High | Yes |
| 2 | Directory/path scanning | Low–Medium | Yes |
| 3 | Sequential ID enumeration | Medium | Yes |
| 4 | Injection attempt patterns (log-scanning gap found) | Medium | Yes |

## 4. Notes
This analysis used simulated traffic against our own isolated lab (see
`docs/permission-statement.md` — same scope applies to this task). In a
real engagement, this same method would be applied to real (authorized)
staging logs, ideally with a longer collection window and a proper log
aggregation tool (e.g. the ELK stack or Grafana Loki) rather than a
single flat file.