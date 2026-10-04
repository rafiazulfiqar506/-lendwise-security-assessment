#!/usr/bin/env bash
# Automated, rerunnable IDOR test (Task 4).
# Creates two fresh users every run (so it's always repeatable from a
# clean state), attempts the cross-user basket access, asserts the
# result, and logs it with a timestamp.
set -e

BASE="https://staging.lendwise.test"
RESULTS="$(dirname "$0")/../docs/idor-test-results.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TS=$(date +%s)
EMAIL_A="idor-test-a-$TS@lendwise.test"
EMAIL_B="idor-test-b-$TS@lendwise.test"
PASSWORD="TestPass123!"

echo "=================================================="
echo " Automated IDOR Test — LendWise Lab"
echo "=================================================="

curl -sk -X POST "$BASE/api/Users" -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL_A\",\"password\":\"$PASSWORD\",\"passwordRepeat\":\"$PASSWORD\",\"securityQuestion\":{\"id\":1},\"securityAnswer\":\"test\"}" -o /dev/null
curl -sk -X POST "$BASE/api/Users" -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL_B\",\"password\":\"$PASSWORD\",\"passwordRepeat\":\"$PASSWORD\",\"securityQuestion\":{\"id\":1},\"securityAnswer\":\"test\"}" -o /dev/null

TOKEN_A=$(curl -sk -X POST "$BASE/rest/user/login" -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL_A\",\"password\":\"$PASSWORD\"}" | grep -oE '"token":"[^"]+"' | cut -d'"' -f4)
LOGIN_B=$(curl -sk -X POST "$BASE/rest/user/login" -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL_B\",\"password\":\"$PASSWORD\"}")
BASKET_B=$(echo "$LOGIN_B" | grep -oE '"bid":[0-9]+' | grep -oE '[0-9]+')

RESPONSE=$(curl -sk -w "\nHTTP_STATUS:%{http_code}" "$BASE/rest/basket/$BASKET_B" \
  -H "Authorization: Bearer $TOKEN_A")
STATUS=$(echo "$RESPONSE" | grep -oE "HTTP_STATUS:[0-9]+" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d' | head -c 300)

echo
echo "Attempted: User A (token) -> GET /rest/basket/$BASKET_B (User B's basket)"
echo "Response status: $STATUS"

if [ "$STATUS" == "200" ]; then
  RESULT="VULNERABLE"
  echo "  🔴 RESULT: VULNERABLE — cross-user basket access succeeded (HTTP 200)"
else
  RESULT="NOT-VULNERABLE"
  echo "  ✅ RESULT: NOT VULNERABLE — access denied (HTTP $STATUS)"
fi

echo "[$TIMESTAMP] $RESULT — GET /rest/basket/$BASKET_B via User A's token — status=$STATUS — body_snippet=$(echo "$BODY" | tr '\n' ' ')" >> "$RESULTS"

echo
echo "Logged to docs/idor-test-results.log"
echo "=================================================="

# Exit 1 if vulnerable, so this can plug into a CI pipeline as a
# regression gate once the fix is applied.
if [ "$RESULT" == "VULNERABLE" ]; then
  exit 1
fi
