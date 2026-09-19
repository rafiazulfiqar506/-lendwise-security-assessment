# LendWise Microfinance — Isolated Security Testing Lab (Task 1)

**Intern:** Rafia Zulfiqar
**Project:** Security Assessment of Microfinance Lending Platform (Ezitech)
**Task:** 1 of 5 — Set up isolated lab environment and test plan

## What this is
A fully isolated, Docker-based lab standing in for LendWise's staging
platform, plus a written test plan and signed permission statement, so
later tasks (log analysis, hardening, IDOR testing, incident response)
can be carried out safely and legally.

The lab uses [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/)
as the target application — an industry-standard, deliberately vulnerable
web app used worldwide for security training, standing in for LendWise's
real (inaccessible) platform. It's fronted by an Nginx reverse proxy so it
behaves like a real staging site at `https://staging.lendwise.test`.

## Why it's isolated
- The app container (`lendwise-app`) sits on a Docker network created with
  `internal: true` — Docker gives this network **no route to the real
  internet or host network** at all.
- Only the proxy container has a second leg onto a normal network, purely
  so you (on your own machine) can reach it in a browser. The app itself
  never touches that network.
- Nothing here can reach or be reached by any real production system.

## Prerequisites
- Docker + Docker Compose installed
- OpenSSL (usually preinstalled on Linux/Mac; on Windows use WSL or Git Bash)
- Ability to edit your machine's hosts file (for the custom domain)

## Setup

1. **Generate the HTTPS certificate for the lab domain:**
   ```bash
   bash scripts/generate-cert.sh
   ```

2. **Point `staging.lendwise.test` at your machine.**
   Add this line to your hosts file
   (`/etc/hosts` on Mac/Linux, `C:\Windows\System32\drivers\etc\hosts` on Windows):
   ```
   127.0.0.1 staging.lendwise.test
   ```

3. **Start the lab:**
   ```bash
   docker compose up -d
   ```

4. **Visit the lab:**
   Open `https://staging.lendwise.test:8443` in your browser.
   (Your browser will warn about the self-signed certificate — that's
   expected in a lab; click through / accept it.)

## Snapshot & restore (resetting to a clean state)

Take a snapshot any time the app is in a state you want to preserve
(e.g. right after first startup, before you start breaking things):
```bash
bash scripts/snapshot.sh
```

Restore back to the latest snapshot at any time:
```bash
bash scripts/restore.sh
```

Restore a specific snapshot:
```bash
bash scripts/restore.sh 20260919-142301
```

## Stopping the lab
```bash
docker compose down
```

## Repository contents
```
docker-compose.yml          # defines the isolated lab
nginx/default.conf          # reverse proxy config for staging.lendwise.test
scripts/generate-cert.sh    # creates the self-signed HTTPS cert
scripts/snapshot.sh         # backs up app state
scripts/restore.sh          # restores app state to a snapshot
docs/test-plan.md           # scope, modules, and test cases
docs/permission-statement.md # signed authorization statement
```

## What I did and why
I built this lab so all later testing (log analysis, hardening, and the
IDOR proof-of-concept in Tasks 2–4) happens against a safe, disposable,
fully isolated copy rather than anything real. I chose OWASP Juice Shop
as the target because I don't have access to LendWise's actual codebase,
and Juice Shop deliberately contains the same categories of bugs
(broken authentication, IDOR, injection, etc.) that a real microfinance
platform could realistically have — so the skills and findings transfer
directly. I used Docker's `internal` network mode specifically so the
target app has zero route out, satisfying the "network isolation"
requirement, and I split the reverse proxy onto its own bridge network
so it's the only thing reachable from the host. Snapshots are done at
the Docker volume level with `tar`, which is simple, fast, and easy to
automate/version.
