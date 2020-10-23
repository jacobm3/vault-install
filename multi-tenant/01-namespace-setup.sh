# Begin working in the root namespace
export VAULT_NAMESPACE=root

# List of namespaces to create
NAMESPACE_LIST="coreteam human-resources delivery hub feeder"

# Create namespaces and populate with some initial secrets
for NS in $NAMESPACE_LIST; do

    # Create the namespace
    vault namespace create $NS

    # Create an admin policy with full control over the namespace
    vault policy write -namespace=$NS admin policies/admin.hcl

    # Unable userpass auth method
    vault auth enable -namespace=$NS userpass

    # Create an admin user with the space admin policy attached
    vault write -namespace=$NS auth/userpass/users/admin password="pass" policies="admin"

done


# Create 3 projects with kv and transit enable under coreteam's namespace
export VAULT_NAMESPACE=coreteam
#export VAULT_NAMESPACE=delivery

# Put some initial secret engines and secrets in place
PROJECTS="goldfish turtle monkey unicorn aardvark centaur"
#PROJECTS="west east central"

for PROJECT in $PROJECTS; do

    # Enable KV and Transit secrets engines
    vault secrets enable -version=2 -path=$PROJECT/kv kv
    vault kv put ${PROJECT}/kv/first-${PROJECT}-secret something="something to look at"

    vault secrets enable -path=${PROJECT}/transit transit

    # Create a pii keyring
    vault write -f ${PROJECT}/transit/keys/pii

    # Create a credit card keyring
    vault write -f ${PROJECT}/transit/keys/card
done

# Setup policies for each project
for PROJECT in $PROJECTS; do

    # Create a policy giving full control over this project's engines
    vault policy write ${PROJECT}-admin - <<EOF
        path "${PROJECT}/*" {
            capabilities = ["create", "read", "update", "delete", "list"]
        }
EOF

    # Create a policy that can only read kv paths
    vault policy write ${PROJECT}-kv-reader - <<EOF
        path "${PROJECT}/kv/*" {
            capabilities = ["read", "list"]
        }
EOF

    # Create a policy that can read and write kv paths
    vault policy write ${PROJECT}-kv-writer - <<EOF
        path "${PROJECT}/kv/*" {
            capabilities = ["create", "read", "update", "delete", "list"]
        }
EOF

    # Create a policy with access to the pii keyring
    # for example path use, see https://learn.hashicorp.com/tutorials/vault/eaas-transit#step-2-encrypt-secrets
    vault policy write ${PROJECT}-pii - <<EOF
        path "${PROJECT}/transit/+/pii" {
            capabilities = ["create", "read", "update", "delete", "list"]
        }
        path "${PROJECT}/transit/*" {
            capabilities = ["list"]
        }
EOF

    # Create a policy with access to the card keyring
    vault policy write ${PROJECT}-card - <<EOF
        path "${PROJECT}/transit/+/card" {
            capabilities = ["create", "read", "update", "delete", "list"]
        }
        path "${PROJECT}/transit/*" {
            capabilities = ["list"]
        }
EOF
done

# Create a test user associated with each policy
for PROJECT in $PROJECTS; do

    vault write auth/userpass/users/${PROJECT}-admin password="pass" policies="${PROJECT}-admin"
    vault write auth/userpass/users/${PROJECT}-kv-reader password="pass" policies="${PROJECT}-kv-reader"
    vault write auth/userpass/users/${PROJECT}-kv-writer password="pass" policies="${PROJECT}-kv-writer"
    vault write auth/userpass/users/${PROJECT}-pii password="pass" policies="${PROJECT}-pii"
    vault write auth/userpass/users/${PROJECT}-card password="pass" policies="${PROJECT}-card"

done

# Create user that can read from each of the KV paths in the coreteam namespace
vault write auth/userpass/users/super-reader password="pass" \
    policies=goldfish-kv-reader,turtle-kv-reader,monkey-kv-reader

vault secrets list
vault policy list
vault policy read 

