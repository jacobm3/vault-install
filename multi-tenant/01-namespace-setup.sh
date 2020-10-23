
NAMESPACE_LIST="coreteam human-resources delivery hub feeder"

# Create namespaces
for NS in $NAMESPACE_LIST; do
  vault namespace create $NS
  vault policy write -namespace=$NS space-admin policies/space-admin.hcl
done

