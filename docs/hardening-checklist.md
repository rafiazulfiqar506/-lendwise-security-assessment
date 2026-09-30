# LendWise Microfinance Platform — Hardening Checklist

**Author:** Rafia Zulfiqar
**Task:** 3 of 5 — Hardening Linux host and automated compliance
**Scope:** The isolated lab (`lendwise-app`, `lendwise-proxy` containers)
defined in `docker-compose.yml` and `nginx/default.conf`.

## Why containers, not a bare Linux host
Our lab runs the "LendWise platform" as Docker containers rather than a
raw VM, so "hardening the host" here means hardening two layers:
1. **The container runtime configuration** (how Docker runs the
   container — privileges, capabilities, resource limits)
2. **The web server configuration** (Nginx settings that a real Linux
   sysadmin would also tune on a bare server)

Both layers map directly onto standard Linux/CIS hardening principles —
least privilege, minimal attack surface, no unnecessary information
disclosure.

## Checklist

| # | Item | Before | After | Why it matters |
|---|------|--------|-------|-----------------|
| 1 | Server version hidden from responses | ❌ `nginx/1.x` exposed in headers | ✅ `server_tokens off;` | Prevents attackers from targeting known version-specific exploits |
| 2 | Security headers present | ❌ none set | ✅ `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, `Content-Security-Policy` (basic) | Reduces clickjacking, MIME-sniffing, and info-leak risk |
| 3 | Strict-Transport-Security (HSTS) enabled | ❌ none | ✅ `Strict-Transport-Security` header | Forces HTTPS on repeat visits, reduces downgrade-attack risk |
| 4 | Container runs with no extra Linux capabilities | ❌ default (many capabilities) | ✅ `cap_drop: ALL`, with only 4 specific capabilities added back to the proxy (see testing notes below) | Limits what a compromised container process can do to the host |
| 5 | Privilege escalation disabled | ❌ default | ✅ `security_opt: no-new-privileges:true` | Stops a compromised process from gaining more privileges than it started with |
| 6 | Container filesystem read-only where possible | ❌ default (writable) | ⚠️ Not implemented — attempted but conflicts with Nginx needing writable cache/temp dirs at runtime; would need explicit tmpfs mounts for those paths, left as a follow-up | Limits an attacker's ability to plant files if they get code execution |
| 7 | Resource limits set (no unbounded resource use) | ❌ none | ✅ CPU/memory limits in compose file | Prevents one compromised/runaway container from starving the host |
| 8 | TLS version restricted to modern protocols | ❌ default (may allow old TLS) | ✅ `ssl_protocols TLSv1.2 TLSv1.3;` | Disables known-weak older TLS versions |
| 9 | Directory listing disabled | ✅ off by default in this image | ✅ confirmed off | Prevents attackers from browsing file structure if a path is misconfigured |
| 10 | Default/sample files removed or inaccessible | ✅ N/A for this app image | ✅ confirmed no default Nginx welcome page reachable | Avoids leaking that infrastructure is default/unconfigured |

## How to verify (automated)
Run:
```
bash scripts/check-hardening.sh
```
This script checks items 1, 2, 3, 8, 9 directly against the running site
(`https://staging.lendwise.test`), and items 4, 5 via
`docker inspect` against the running containers. It prints PASS/FAIL for
each item, so it's re-runnable every time the config changes — this is
the "automated compliance" part of the task, rather than manually
eyeballing config files each time.

## Notes / what I'd add with more time
- A real Linux host (not just containers) would also need: automatic
  security updates enabled, SSH hardening (key-only auth, no root login,
  fail2ban), a host firewall (ufw/iptables) restricting inbound ports,
  and file integrity monitoring (e.g. AIDE).
- A proper Content-Security-Policy would need to be tuned per-application
  rather than using a broad starter policy, to avoid breaking legitimate
  app functionality — I used a conservative baseline here.
- Item 6 (read-only filesystem) is an honest gap — I ran out of time to
  properly map tmpfs mounts for Nginx's cache/temp directories.

## What I found while testing (real debugging, not just config)
When I first applied `cap_drop: ALL` to the Nginx proxy container, it
went into a crash-loop instead of hardening cleanly. `docker compose
logs lendwise-proxy` showed:
```
nginx: [emerg] chown("/var/cache/nginx/client_temp", 101) failed (1: Operation not permitted)
```
Dropping every Linux capability removed the ones Nginx actually needs
just to start up — `CHOWN` (to set file ownership on its internal cache
folders), `SETUID`/`SETGID` (to drop from root down to its own
low-privilege user), and `NET_BIND_SERVICE` (to bind to port 443, a
privileged port). The fix was to drop everything by default and then
explicitly add back only those four capabilities:
```yaml
cap_drop:
  - ALL
cap_add:
  - CHOWN
  - SETUID
  - SETGID
  - NET_BIND_SERVICE
```
This is a better outcome than my first attempt — it's a concrete,
verified example of least-privilege hardening rather than an untested
"drop everything" config that happened to look secure on paper but
didn't actually run. It's also a good reminder that automated compliance
checks (like `check-hardening.sh`) need to be tested against a genuinely
running system, not just written and assumed correct — my first version
of the check script itself had a logic bug and a stale port number that
made it report false failures until I fixed those too.