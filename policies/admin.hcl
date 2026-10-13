# Day-to-day administrators: full access.
# A new root token cannot come from this policy: generating one always needs
# the unseal key holders (README, "Getting a root token back").

path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
