#!/usr/bin/env bash
# Generates a self-signed HTTPS certificate for staging.lendwise.test
# This is ONLY for the isolated lab — never do this for a real production domain.
set -e

CERT_DIR="$(dirname "$0")/../nginx/certs"
mkdir -p "$CERT_DIR"

openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout "$CERT_DIR/lendwise-test.key" \
  -out "$CERT_DIR/lendwise-test.crt" \
  -subj "/C=PK/ST=Punjab/L=Rawalpindi/O=LendWise Lab/CN=staging.lendwise.test"

echo "Certificate generated in $CERT_DIR"
