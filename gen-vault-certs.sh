#!/bin/bash -x

DOMAIN=test.io

cat >csr.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
[req_distinguished_name]
C = US
ST = TX
L = Houston
O = Hashicorp POC
OU = Solution Engineering
CN = vault
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = vault1.${DOMAIN}
DNS.2 = vault2.${DOMAIN}
DNS.3 = vault3.${DOMAIN}
DNS.4 = localhost
IP.1 = 127.0.0.1
EOF

openssl req -out vault.req -newkey rsa:2048 -nodes -keyout vault.key -config csr.cnf

echo "Request Details:"
openssl req -noout -text -in vault.req


./easyrsa import-req vault.req vault

./easyrsa --subject-alt-name=DNS.1:vault1.test.io,DNS.2:vault2.test.io,DNS.3:vault3.test.io sign-req server vault

openssl x509 -in /home/jacob/CA/pki/issued/vault.crt -text

cp pki/ca.crt .
cp pki/issued/vault.crt .
tar zcf certs.tgz ca.crt vault.crt vault.key

echo 
echo "Certificates and key: certs.tgz"
