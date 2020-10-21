vault secrets enable -path=secrets kv
vault write secrets/creds/dev username=dev password=legos
cat <<EOF > jenkins-policy.hcl
path "secrets/creds/dev" {
 capabilities = ["read"]
}
EOF
vault policy write jenkins jenkins-policy.hcl
vault auth enable approle
vault write auth/approle/role/jenkins-role \
    secret_id_ttl=24h \
    token_num_uses=5 \
    token_ttl=20m \
    token_max_ttl=30m \
    secret_id_num_uses=40 \
    policies="jenkins"

# Use .data.role_id in role.json file as the ROLE_ID for Jenkins setup
vault read -format=json auth/approle/role/jenkins-role/role-id > role.json

# Use .data.secret_id in secretid.json file as the SECRET_ID for Jenkins credential
vault write -format=json -f auth/approle/role/jenkins-role/secret-id > secretid.json

