#!/usr/bin/env bash
# Automated compliance test for Task 3's actual requirements:
#   - SSH only allows key authentication
#   - Firewall blocks all unused ports
#   - Host is fully patched and updated
# Logs every result with a timestamp to docs/host-hardening-test-results.log
# so this is re-runnable evidence, not a one-off manual check.
set -e

RESULTS="$(dirname "$0")/../docs/host-hardening-test-results.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PASS=0
FAIL=0

record() {
  local test_name="$1"
  local result="$2"
  local detail="$3"
  echo "[$TIMESTAMP] $result — $test_name — $detail" >> "$RESULTS"
  if [ "$result" == "PASS" ]; then
    echo "  ✅ PASS — $test_name ($detail)"
    PASS=$((PASS+1))
  else
    echo "  ❌ FAIL — $test_name ($detail)"
    FAIL=$((FAIL+1))
  fi
}

echo "=================================================="
echo " LendWise Lab — Host Hardening Test Suite"
echo " (results also appended to docs/host-hardening-test-results.log)"
echo "=================================================="
echo

# --- Test 1: Password authentication disabled ---
if docker exec lendwise-host grep -qE "^PasswordAuthentication\s+no" /etc/ssh/sshd_config; then
  record "SSH password authentication disabled" "PASS" "PasswordAuthentication no found in sshd_config"
else
  record "SSH password authentication disabled" "FAIL" "directive not found or not set to no"
fi

# --- Test 2: Public key auth enabled ---
if docker exec lendwise-host grep -qE "^PubkeyAuthentication\s+yes" /etc/ssh/sshd_config; then
  record "SSH public key authentication enabled" "PASS" "PubkeyAuthentication yes found in sshd_config"
else
  record "SSH public key authentication enabled" "FAIL" "directive not found or not set to yes"
fi

# --- Test 3: Root login disabled ---
if docker exec lendwise-host grep -qE "^PermitRootLogin\s+no" /etc/ssh/sshd_config; then
  record "SSH root login disabled" "PASS" "PermitRootLogin no found in sshd_config"
else
  record "SSH root login disabled" "FAIL" "directive not found or not set to no"
fi

# --- Test 4: Firewall default-deny policy ---
POLICY=$(docker exec lendwise-host iptables -L INPUT | head -1)
if echo "$POLICY" | grep -qi "policy DROP"; then
  record "Firewall default INPUT policy is DROP" "PASS" "$POLICY"
else
  record "Firewall default INPUT policy is DROP" "FAIL" "$POLICY"
fi

# --- Test 5: Only port 22 explicitly allowed ---
OPEN_RULES=$(docker exec lendwise-host iptables -L INPUT -n | grep "^ACCEPT" | grep -c "dpt:22" || true)
TOTAL_ACCEPT_PORT_RULES=$(docker exec lendwise-host iptables -L INPUT -n | grep "^ACCEPT" | grep -c "dpt:" || true)
if [ "$OPEN_RULES" -ge 1 ] && [ "$TOTAL_ACCEPT_PORT_RULES" -eq "$OPEN_RULES" ]; then
  record "Firewall only allows port 22 inbound" "PASS" "only SSH (22) has an explicit ACCEPT rule"
else
  record "Firewall only allows port 22 inbound" "FAIL" "found $TOTAL_ACCEPT_PORT_RULES allowed port rule(s), expected exactly 1 (port 22)"
fi

# --- Test 6: No unexpected listening ports inside the host ---
LISTENING=$(docker exec lendwise-host ss -tln | awk 'NR>1 {print $4}' | grep -v "^127.0.0.11:" | sed -E 's/.*:([0-9]+)$/\1/' | sort -u)
UNEXPECTED=$(echo "$LISTENING" | grep -vE "^(22|0)$" || true)
if [ -z "$UNEXPECTED" ]; then
  record "No unexpected listening services" "PASS" "only port 22 listening"
else
  record "No unexpected listening services" "FAIL" "unexpected ports listening: $UNEXPECTED"
fi

# --- Test 7: Host fully patched (no pending upgrades) ---
UPGRADABLE=$(docker exec lendwise-host bash -c "apt list --upgradable 2>/dev/null | grep -v '^Listing' | wc -l")
if [ "$UPGRADABLE" -eq 0 ]; then
  record "Host is fully patched" "PASS" "0 packages pending upgrade"
else
  record "Host is fully patched" "FAIL" "$UPGRADABLE packages pending upgrade"
fi

echo
echo "=================================================="
echo " Result: $PASS passed, $FAIL failed"
echo " Full history: docs/host-hardening-test-results.log"
echo "=================================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
