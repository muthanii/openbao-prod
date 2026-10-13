# Used only by scripts/backup.sh. Can take a Raft snapshot and nothing else.

path "sys/storage/raft/snapshot" {
  capabilities = ["read"]
}
