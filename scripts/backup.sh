#!/usr/bin/env bash
# Takes a Raft snapshot (every secret, policy and setting) and keeps the last 14.
# Copy BACKUP_DIR off this host: a snapshot on the same disk does not survive the disk.
#
# Needs BAO_SNAPSHOT_TOKEN: a periodic token with the "snapshot" policy (README step 6).
# Cron, nightly at 02:30:
#   30 2 * * * BAO_SNAPSHOT_TOKEN=... /opt/openbao/scripts/backup.sh >> /var/log/openbao-backup.log 2>&1
set -euo pipefail

: "${BAO_SNAPSHOT_TOKEN:?set BAO_SNAPSHOT_TOKEN}"
ADDR="${BAO_ADDR:-https://127.0.0.1:8200}"
CACERT="$(dirname "$0")/../tls/ca.crt"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/openbao}"
KEEP=14

mkdir -p "$BACKUP_DIR"
FILE="$BACKUP_DIR/openbao-$(date +%Y%m%d-%H%M%S).snap"

curl --fail --silent --show-error --cacert "$CACERT" \
	-H "X-Vault-Token: $BAO_SNAPSHOT_TOKEN" \
	"$ADDR/v1/sys/storage/raft/snapshot" -o "$FILE"

# A periodic token expires if it is not renewed within its period.
# Renewing it on every run keeps the nightly job from dying silently.
curl --fail --silent --show-error --cacert "$CACERT" \
	-H "X-Vault-Token: $BAO_SNAPSHOT_TOKEN" -X POST \
	"$ADDR/v1/auth/token/renew-self" > /dev/null

ls -1t "$BACKUP_DIR"/openbao-*.snap | tail -n +$((KEEP + 1)) | xargs -r rm --
echo "$(date -Is) saved $FILE ($(du -h "$FILE" | cut -f1))"
