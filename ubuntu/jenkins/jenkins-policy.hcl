path "secrets/creds/dev" {
 capabilities = ["read"]
}

path "pki/issue/hashicorp-test-dot-com" {
 capabilities = ["read", "create", "update"]
}
