#!/bin/bash
# Applies firewall rules (deliverable: "Firewall blocks all unused
# ports"), then starts sshd in the foreground.
set -e

echo "[entrypoint] Applying firewall rules..."

# Default-deny on inbound traffic
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Always allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow already-established connections (so replies work)
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Only allow inbound SSH (port 22) — every other port stays blocked
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

echo "[entrypoint] Firewall applied. Current rules:"
iptables -L INPUT -v

echo "[entrypoint] Starting sshd..."
exec /usr/sbin/sshd -D
