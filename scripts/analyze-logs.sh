#!/usr/bin/env bash
# Analyzes ./logs/access.log for suspicious activity patterns.
# Run this AFTER scripts/generate-traffic.sh has produced some log data.
set -e

LOG="$(dirname "$0")/../logs/access.log"

if [ ! -f "$LOG" ]; then
  echo "No log file found at $LOG — run 'docker compose up -d' and generate"
  echo "some traffic first (e.g. scripts/generate-traffic.sh)."
  exit 1
fi

echo "=================================================="
echo " LendWise Lab — Log Analysis"
echo " Source: $LOG"
echo "=================================================="

echo
echo "--- 1. Top requesting IPs (volume) ---"
awk '{print $1}' "$LOG" | sort | uniq -c | sort -rn | head -10

echo
echo "--- 2. Repeated failed login attempts (possible brute force) ---"
echo "    Looking for POST /rest/user/login repeated from the same IP"
grep "POST /rest/user/login" "$LOG" | awk '{print $1}' | sort | uniq -c | sort -rn | \
  awk '{ if ($1 >= 5) print "  ⚠ " $2 " attempted login " $1 " times" }'

echo
echo "--- 3. Requests to sensitive/non-existent paths (possible scanning) ---"
echo "    Looking for common recon paths"
grep -E "(admin|wp-admin|\.env|\.git|config\.php|backup|phpmyadmin|credentials|server-status)" "$LOG" | \
  awk '{print $1, $7}' | sort -u

echo
echo "--- 4. Sequential numeric ID sweeps (possible IDOR enumeration) ---"
echo "    Looking for many different /rest/products/<id>/reviews hits from one IP"
grep -oE '^[0-9.]+ .*"GET /rest/products/[0-9]+/reviews' "$LOG" | \
  awk '{print $1}' | sort | uniq -c | sort -rn | \
  awk '{ if ($1 >= 10) print "  ⚠ " $2 " requested " $1 " different product/review IDs — possible enumeration" }'

echo
echo "--- 5. Possible injection attempts in query strings ---"
grep -iE "(<script|union select|or 1=1|or '1'='1|\.\./|drop table)" "$LOG" || echo "  (none found)"

echo
echo "--- 6. Requests resulting in 4xx/5xx (errors worth reviewing) ---"
awk '$9 ~ /^[45][0-9][0-9]$/ {print $9}' "$LOG" | sort | uniq -c | sort -rn

echo
echo "=================================================="
echo " Analysis complete. Copy relevant findings into"
echo " docs/log-analysis-report.md with reproduction steps."
echo "=================================================="
