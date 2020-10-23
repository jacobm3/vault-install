
NAMESPACE_LIST="coreteam human-resources delivery hub feeder"

# Create namespaces
for NS in $NAMESPACE_LIST; do
  vault namespace create $NS
  vault policy write -namespace=$NS space-admin policies/admin.hcl
  vault auth enable -namespace=$NS userpass
  vault write -namespace=$NS auth/userpass/users/admin password="pass"
done




