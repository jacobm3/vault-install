#!/bin/bash -x

if [ -z "$1" ]
  then
    echo "usage: $0 NODENAME IPADDR"
    exit 1
fi

if [ -z "$2" ]
  then
    echo "usage: $0 NODENAME IPADDR"
    exit 1
fi

NODENAME=$1
IPADDR=$2

openssl req -out ${NODENAME}.req -newkey rsa:2048 -nodes -keyout ${NODENAME}.key -config - << EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
C = US
ST = Texas
L = Houston
O = Hashicorp
OU = Engineering
CN = ${NODENAME}.test.io
[v3_req]
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${NODENAME}
DNS.2 = ${NODENAME}.test
DNS.2 = ${NODENAME}.test.io
IP.1 = 127.0.0.1
IP.2 = ${IPADDR}
EOF
