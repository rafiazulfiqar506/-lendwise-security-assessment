#!/usr/bin/env bash
# Generates the SSH keypair used to connect to the hardened lab host.
# The PUBLIC key gets baked into the container image (Task 3 — key-only
# auth); the PRIVATE key stays on your machine and is used to connect.
set -e

KEY_DIR="$(dirname "$0")/../host/keys"
mkdir -p "$KEY_DIR"

if [ -f "$KEY_DIR/lendwise_host_key" ]; then
  echo "Key already exists at $KEY_DIR/lendwise_host_key — skipping."
  exit 0
fi

ssh-keygen -t ed25519 -f "$KEY_DIR/lendwise_host_key" -N "" -C "lendwise-lab-host-key"

echo "Keypair generated:"
echo "  Private key: $KEY_DIR/lendwise_host_key   (keep this, used to connect)"
echo "  Public key:  $KEY_DIR/lendwise_host_key.pub (baked into the container)"
