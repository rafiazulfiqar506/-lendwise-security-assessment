# LendWise Lab — Linux Host Hardening Checklist (Task 3)

**Author:** Rafia Zulfiqar
**Task:** 3 of 5 — Hardening Linux host and automated compliance
**Scope:** `lendwise-host`, a dedicated Ubuntu 22.04 container standing
in for a real LendWise server, defined in `host/Dockerfile` and started
via `docker-compose.yml`. Reachable at `localhost:2222` for SSH.

## Why a dedicated host container
Our lab's `lendwise-app`/`lendwise-proxy` containers represent the *web
application*; this task is about hardening the *underlying host*. Rather
than harden Docker Desktop's own WSL2 VM (which isn't really "LendWise's
server" and isn't something I should be modifying), I added a purpose-built
container that behaves like a real Linux server — it runs its own SSH
daemon, manages its own firewall rules, and gets its own OS packages
patched — so all four required checks are genuinely testable.

## What was done

| Requirement | Implementation | Evidence |
|---|---|---|
| SSH only allows key authentication | `sshd_config`: `PasswordAuthentication no`, `PubkeyAuthentication yes`, `PermitEmptyPasswords no` | `scripts/test-host-hardening.sh` Tests 1–2 |
| Root login disabled | `sshd_config`: `PermitRootLogin no`; only `labadmin` (non-root, sudo-capable) may connect via `AllowUsers labadmin` | `scripts/test-host-hardening.sh` Test 3 |
| Firewall blocks all unused ports | `host/entrypoint.sh` sets `iptables -P INPUT DROP` by default, then explicitly allows only loopback, established/related connections, and inbound port 22 | `scripts/test-host-hardening.sh` Tests 4–6 |
| Host is fully patched and updated | `host/Dockerfile` runs `apt-get update && apt-get upgrade -y` at build time | `scripts/test-host-hardening.sh` Test 7 |
| Service reduction | Only `openssh-server`, `iptables`, `sudo`, and `iproute2` are installed — no cron, mail, ftp, telnet, or other default services added | Manually verified via `docker exec lendwise-host dpkg -l` |

## SSH key setup
A dedicated keypair is generated locally (never committed to the repo —
see `.gitignore`) via `scripts/generate-ssh-key.sh`. The **public** key
is baked into the container image at build time as
`labadmin`'s `authorized_keys`; the **private** key stays on my machine
and is the only way to connect:
```
ssh -i host/keys/lendwise_host_key -p 2222 labadmin@localhost
```
Attempting to connect with a password instead is rejected by the server
before a password prompt is even shown, because `PasswordAuthentication`
is fully disabled — not just deprioritized.

## Automated compliance testing
Run:
```
bash scripts/test-host-hardening.sh
```
This runs 7 automated checks directly against the running container
(via `docker exec`, checking real config files, real firewall rules, and
real installed-package state — not just reading source files), logs
every PASS/FAIL with a timestamp to
`docs/host-hardening-test-results.log`, and exits non-zero if anything
fails — so it's rerunnable after any future change, satisfying "automated
tests that verify each hardening step and can be rerun after any change."

## Notes / limitations
- Because this is a container rather than a bare-metal or VM host, some
  traditional host-hardening steps don't map directly (e.g. disk
  encryption, BIOS/UEFI settings) — I focused on the four items the task
  explicitly lists: SSH, firewall, service reduction, and patching.
- "Fully patched" is checked at test-run time via `apt list --upgradable`;
  since the image is rebuilt with `--no-cache` before testing in CI-like
  fashion, this reflects packages available at build time. In a real
  long-running server this check would need to run on a schedule
  (e.g. a cron job or systemd timer), not just once at container start.
- `iptables` (not `nftables`) was used since it's simpler to reason about
  and verify with a text-based diff in `iptables -L`; `nftables` would be
  the more modern choice for a production host.

## What I found while testing (real debugging, not just config)
My first run of `test-host-hardening.sh` showed 6/7 passing, with one
FAIL: "unexpected ports listening: 34815 59112". I checked with
`ss -tlnp` inside the container and found these were UDP sockets bound
to `127.0.0.11` — Docker's own internal per-container DNS resolver,
which every container gets automatically. It's bound to a loopback-only
address, invisible from outside the container, and unrelated to any
service I installed — a false positive caused by my test checking both
TCP and UDP sockets when only inbound TCP is actually relevant to the
firewall rules being verified. I narrowed the check to `ss -tln`
(TCP-only) and explicitly excluded `127.0.0.11`, after confirming with
`ss -tlnp` exactly what was listening rather than just suppressing the
warning blindly. The full before/after history is preserved with
timestamps in `docs/host-hardening-test-results.log` — the log shows two
honest FAILs before the fix, which I kept rather than deleting, since
that's a more accurate record of the actual testing process.