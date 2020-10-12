#!/bin/bash -x

DOMAIN=test.io

rm -f certs.tgz vault.req vault.key vault.crt pki/issued/vault.crt private/vault* ./pki/reqs/vault*

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
DNS.4 = vault1
DNS.5 = vault2
DNS.6 = vault3
DNS.7 = localhost
IP.1 = 127.0.0.1
EOF

openssl req -out vault.req -newkey rsa:2048 -nodes -keyout vault.key -config csr.cnf

echo "Request Details:"
openssl req -noout -text -in vault.req

./easyrsa import-req vault.req vault

./easyrsa --subject-alt-name=DNS.1:vault1.${DOMAIN},DNS.2:vault2.${DOMAIN},DNS.3:vault3.${DOMAIN},DNS.4:vault1,DNS.5:vault2,DNS.6:vault3,IP.1:127.0.0.1 sign-req server vault

openssl x509 -in /home/jacob/CA/pki/issued/vault.crt -text

cp pki/ca.crt pki/issued/vault.crt .
tar zcf certs.tgz vault.key vault.crt ca.crt

echo 
echo "Certificates and key: certs.tgz"
