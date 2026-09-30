#!/usr/bin/env bash
# Automated compliance check against docs/hardening-checklist.md.
# Run this any time after 'docker compose up -d' to verify the lab
# still meets the hardening baseline — this is what makes it
# "automated compliance" rather than a one-time manual check.

BASE="https://staging.lendwise.test"
PASS=0
FAIL=0

check() {
  local desc="$1"
  local result="$2"   # 0 = pass, 1 = fail
  if [ "$result" -eq 0 ]; then
    echo "  ✅ PASS — $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ FAIL — $desc"
    FAIL=$((FAIL+1))
  fi
}

echo "=================================================="
echo " LendWise Lab — Hardening Compliance Check"
echo "=================================================="

HEADERS=$(curl -sk -I "$BASE")

echo
echo "--- HTTP header checks ---"

echo "$HEADERS" | grep -qi "^Server: nginx/[0-9]"
if [ $? -eq 0 ]; then RESULT=1; else RESULT=0; fi
check "Server version hidden (server_tokens off)" $RESULT

echo "$HEADERS" | grep -qi "^Strict-Transport-Security:"; check "HSTS header present" $?
echo "$HEADERS" | grep -qi "^X-Frame-Options:"; check "X-Frame-Options header present" $?
echo "$HEADERS" | grep -qi "^X-Content-Type-Options:"; check "X-Content-Type-Options header present" $?
echo "$HEADERS" | grep -qi "^Content-Security-Policy:"; check "Content-Security-Policy header present" $?

echo
echo "--- TLS configuration check ---"
TLS_OLD=$(echo | openssl s_client -connect staging.lendwise.test:443 -tls1_1 2>&1 | grep -Eic "alert protocol version|unsupported protocol|wrong version number|no protocols available|handshake failure")
[ "$TLS_OLD" -gt 0 ]; check "Old TLS (1.1) is rejected" $?

echo
echo "--- Container hardening checks (docker inspect) ---"
for c in lendwise-app lendwise-proxy; do
  CAPS=$(docker inspect --format '{{.HostConfig.CapDrop}}' "$c" 2>/dev/null)
  echo "$CAPS" | grep -qi "ALL"; check "$c: all Linux capabilities dropped" $?

  PRIV=$(docker inspect --format '{{.HostConfig.SecurityOpt}}' "$c" 2>/dev/null)
  echo "$PRIV" | grep -qi "no-new-privileges"; check "$c: no-new-privileges enabled" $?
done

echo
echo "=================================================="
echo " Result: $PASS passed, $FAIL failed"
echo "=================================================="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi