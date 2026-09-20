#!/usr/bin/env bash
# Simulates a mix of normal browsing AND suspicious/attacker-style traffic
# against our OWN isolated lab (staging.lendwise.test), so the resulting
# Nginx logs have real patterns to analyze in Task 2.
#
# This only ever talks to our local lab (-k skips the self-signed cert
# warning) — it never touches any external system.
set -e

BASE="https://staging.lendwise.test:8443"

echo "== Generating normal-looking traffic =="
for path in "/" "/#/search" "/#/contact" "/rest/products/1/reviews" "/assets/public/images/products/apple_juice.jpg"; do
  curl -sk "$BASE$path" -o /dev/null
  sleep 0.2
done

echo "== Simulating brute-force login attempts (same IP, many failures) =="
for i in $(seq 1 15); do
  curl -sk -X POST "$BASE/rest/user/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"admin@lendwise.test\",\"password\":\"guess$i\"}" \
    -o /dev/null
done

echo "== Simulating directory/path scanning (looking for hidden admin pages) =="
for path in "/admin" "/administrator" "/wp-admin" "/.env" "/.git/config" "/config.php" "/backup.zip" "/phpmyadmin" "/.aws/credentials" "/server-status"; do
  curl -sk "$BASE$path" -o /dev/null
done

echo "== Simulating an ID-enumeration sweep (IDOR-style probing, feeds Task 4 too) =="
for id in $(seq 1 25); do
  curl -sk "$BASE/rest/products/$id/reviews" -o /dev/null
done

echo "== Simulating an injection attempt in a query string =="
curl -sk "$BASE/rest/products/search?q=apple' OR '1'='1" -o /dev/null
curl -sk "$BASE/rest/products/search?q=<script>alert(1)</script>" -o /dev/null

echo "== Done. Check ./logs/access.log for the results. =="
