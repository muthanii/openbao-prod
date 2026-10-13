# OpenBao server configuration, single node.

ui           = true
cluster_name = "tk-openbao"

# Integrated (Raft) storage keeps its data in memory-mapped files, which mlock
# would pin in RAM in full. OpenBao recommends disabling mlock with Raft and
# disabling swap on the host instead.
disable_mlock = true

storage "raft" {
  path    = "/openbao/file"
  node_id = "bao-1"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_cert_file   = "/openbao/tls/tls.crt"
  tls_key_file    = "/openbao/tls/tls.key"
  tls_min_version = "tls12"
}

# Every request and response is logged here, with secret values hashed.
# OpenBao 2.x accepts audit devices only from this file, not from the CLI.
audit "file" "file" {
  options {
    file_path = "/openbao/logs/audit.log"
  }
}

# The address clients use. Must match a name in the TLS certificate.
api_addr     = "https://bao.teebatkarbala.local:8200"
cluster_addr = "https://127.0.0.1:8201"
