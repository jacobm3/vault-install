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

./easyrsa --subject-alt-name=DNS.1:vault1.${DOMAIN},DNS.2:vault2.${DOMAIN},DNS.3:vault3.${DOMAIN} sign-req server vault

openssl x509 -in /home/jacob/CA/pki/issued/vault.crt -text

dir=tls
mkdir -m 750 $dir
cp vault.key pki/ca.crt pki/issued/vault.crt $dir
tar zcf certs.tgz $dir

echo 
echo "Certificates and key: certs.tgz"
