#!/usr/bin/env bash
# Automated test for Task 2: asserts specific suspicious patterns are
# detected in the log, and logs each PASS/FAIL result with a timestamp
# to docs/automated-test-results.log — so this is re-runnable evidence,
# not just a one-off manual read of the output.
set -e

LOG="$(dirname "$0")/../logs/access.log"
RESULTS="$(dirname "$0")/../docs/automated-test-results.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

PASS=0
FAIL=0

record() {
  local test_name="$1"
  local result="$2"     # PASS or FAIL
  local detail="$3"
  echo "[$TIMESTAMP] $result — $test_name — $detail" >> "$RESULTS"
  if [ "$result" == "PASS" ]; then
    echo "✅ PASS — $test_name ($detail)"
    PASS=$((PASS+1))
  else
    echo "❌ FAIL — $test_name ($detail)"
    FAIL=$((FAIL+1))
  fi
}

if [ ! -f "$LOG" ]; then
  echo "No log file at $LOG — run scripts/generate-traffic.sh first."
  exit 1
fi

echo "=================================================="
echo " Automated Suspicious-Activity Test Suite"
echo " (results also appended to docs/automated-test-results.log)"
echo "=================================================="

# --- Test 1: Brute-force detection (>=5 failed logins from one IP) ---
BRUTE_COUNT=$(grep "POST /rest/user/login" "$LOG" | awk '{print $1}' | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')
BRUTE_COUNT=${BRUTE_COUNT:-0}
if [ "$BRUTE_COUNT" -ge 5 ]; then
  record "Brute-force login detection" "PASS" "top IP had $BRUTE_COUNT failed login attempts (threshold: 5)"
else
  record "Brute-force login detection" "FAIL" "top IP only had $BRUTE_COUNT attempts (threshold: 5)"
fi

# --- Test 2: Scanning detection (>=5 sensitive-path hits from one IP) ---
SCAN_COUNT=$(grep -E "(admin|wp-admin|\.env|\.git|config\.php|backup|phpmyadmin|credentials|server-status)" "$LOG" | wc -l)
if [ "$SCAN_COUNT" -ge 5 ]; then
  record "Directory scanning detection" "PASS" "$SCAN_COUNT sensitive-path requests found (threshold: 5)"
else
  record "Directory scanning detection" "FAIL" "$SCAN_COUNT sensitive-path requests found (threshold: 5)"
fi

# --- Test 3: ID enumeration detection (>=10 sequential product/review IDs from one IP) ---
ENUM_COUNT=$(grep -oE '"GET /rest/products/[0-9]+/reviews' "$LOG" | wc -l)
if [ "$ENUM_COUNT" -ge 10 ]; then
  record "ID enumeration detection" "PASS" "$ENUM_COUNT sequential product/review ID requests found (threshold: 10)"
else
  record "ID enumeration detection" "FAIL" "$ENUM_COUNT sequential product/review ID requests found (threshold: 10)"
fi

# --- Test 4: Non-browser User-Agent pattern (regex on user-agent field) ---
UA_COUNT=$(grep -icE '"curl/|"python-requests/|"wget/' "$LOG" || true)
if [ "$UA_COUNT" -ge 1 ]; then
  record "Non-browser User-Agent detection" "PASS" "$UA_COUNT requests from scripted clients (curl/wget/python-requests)"
else
  record "Non-browser User-Agent detection" "FAIL" "no scripted-client User-Agent patterns found"
fi

# --- Test 5: Elevated 4xx/5xx rate ---
ERROR_COUNT=$(awk '$9 ~ /^[45][0-9][0-9]$/' "$LOG" | wc -l)
TOTAL_COUNT=$(wc -l < "$LOG")
if [ "$ERROR_COUNT" -ge 5 ]; then
  record "Elevated 4xx/5xx status codes" "PASS" "$ERROR_COUNT of $TOTAL_COUNT requests returned 4xx/5xx (threshold: 5)"
else
  record "Elevated 4xx/5xx status codes" "FAIL" "$ERROR_COUNT of $TOTAL_COUNT requests returned 4xx/5xx (threshold: 5)"
fi

echo "=================================================="
echo " Result: $PASS passed, $FAIL failed"
echo " Full history: docs/automated-test-results.log"
echo "=================================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
