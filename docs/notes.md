# Notes — What I Did, What Was Hard, What I Left Out

## What I did
I built a fully isolated Docker Compose lab standing in for LendWise's
staging platform, reachable at https://staging.lendwise.test via an Nginx
reverse proxy with a self-signed certificate. The target app runs on a
Docker network with `internal: true`, so it has no route to the real
internet — only the proxy container bridges out to my host machine. I
wrote a test plan covering the platform's core modules (auth, sessions,
loan viewing, repayments, etc.) with sample test cases, and a signed
scope/authorization statement confirming testing is limited to this lab.
I also wrote snapshot/restore scripts that back up and reset the app's
data volume, and verified both work end-to-end.

## What was hard
Getting Docker Desktop working on Windows took the most time — I hit a
"virtualization not detected" error that needed the Windows "Virtual
Machine Platform" feature enabled, which then triggered a WSL2 + Ubuntu
install. After that, Docker Desktop's WSL integration toggle wasn't on by
default, so commands weren't found inside my Ubuntu terminal until I
enabled it manually in Docker Desktop's settings. I also hit a Docker
credential-helper error when snapshotting (it tried to use a Windows-only
`desktop.exe` credential store from inside Linux), fixed by resetting
`~/.docker/config.json`. Authenticating `git push` to GitHub was the last
hurdle — GitHub no longer accepts account passwords for Git operations,
so I had to generate a Personal Access Token and use it instead.

## What I left out / would do differently with more time
- I used OWASP Juice Shop as a stand-in target app since I don't have
  access to LendWise's real codebase; a real engagement would test the
  actual staging build.
- I haven't yet load-tested the isolation itself (e.g. explicitly trying
  to reach the internet from inside the app container to confirm it's
  blocked) — I relied on Docker's documented `internal: true` behavior.
- Log forwarding/centralized logging isn't set up yet — that's planned
  for Task 2 (log analysis for suspicious activity).
