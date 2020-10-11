# Manage tokens
path "auth/token/*" {
  capabilities = [ "create", "read", "update", "delete", "sudo" ]
}

# Write ACL policies
path "sys/policies/acl/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Manage secret/dev secrets engine - for Verification test
path "secret/dev" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}
