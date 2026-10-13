#!/usr/bin/env bash
# Test VM only: makes a throwaway CA and a server certificate in ./tls.
# In production, issue the certificate from the company's internal CA instead,
# and put tls.crt, tls.key and ca.crt in ./tls the same way.
#
# Usage: ./scripts/gen-test-certs.sh [hostname] [server-ip]
set -euo pipefail

HOST="${1:-bao.teebatkarbala.local}"
IP="${2:-127.0.0.1}"
cd "$(dirname "$0")/../tls"

openssl req -x509 -newkey rsa:4096 -nodes -days 365 \
	-keyout ca.key -out ca.crt -subj "/CN=OpenBao Test CA"

openssl req -newkey rsa:2048 -nodes \
	-keyout tls.key -out tls.csr -subj "/CN=${HOST}"

# 127.0.0.1 is always included: the CLI inside the container and backup.sh use it.
printf 'subjectAltName=DNS:%s,DNS:localhost,IP:127.0.0.1,IP:%s\nextendedKeyUsage=serverAuth\n' \
	"$HOST" "$IP" > san.ext

openssl x509 -req -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
	-days 365 -out tls.crt -extfile san.ext

rm -f tls.csr san.ext ca.srl
# The container runs as a non-root user and must be able to read the key.
chmod 644 tls.crt ca.crt
chmod 640 tls.key
echo "Wrote ca.crt, tls.crt and tls.key to $(pwd). Keep ca.key off the server."
