#!/bin/bash 

set -x

NODENAME=vault1

pkill vault
pkill -9 vault

if [ $EUID -ne 0 ]; then
    echo "This script should be run as root." > /dev/stderr
    exit 1
fi

# Install prerequisites
yum update -y
for cmd in unzip vim openssl tree curl; do
if ! command -v $cmd &> /dev/null
then
    yum install -y $cmd
fi
done

export PATH=${PATH}:/usr/local/bin

# Install latest Vault version if needed
tmpout=.vault.version.check.$$
curl -s -o $tmpout https://www.vaultproject.io/downloads
VAULT_VERSION=`egrep -o '"version":".\..\.."'  $tmpout | head -1  | cut -f4 -d'"'`
rm $tmpout

# Put binary in place
# https://releases.hashicorp.com/vault/1.5.4+ent/vault_1.5.4+ent_linux_amd64.zip
curl --silent  --remote-name -o vault_${VAULT_VERSION}_linux_amd64.zip "https://releases.hashicorp.com/vault/${VAULT_VERSION}+ent/vault_${VAULT_VERSION}+ent_linux_amd64.zip"
unzip vault_${VAULT_VERSION}+ent_linux_amd64.zip
chown root:root vault
mv vault /usr/local/bin/
/usr/local/bin/vault -version

# Shell auto-complete
vault -autocomplete-install
complete -C /usr/local/bin/vault vault

# Allow mlock without requiring root privs
setcap cap_ipc_lock=+ep /usr/local/bin/vault

# Vault user and homedir, if doesn't exist
if ! getent passwd vault &>/dev/null
then
  useradd --system --home /etc/vault.d --shell /bin/false vault
fi

# Setup Vault server config 
mkdir --parents /etc/vault.d
touch /etc/vault.d/vault.hcl
chown --recursive vault:vault /etc/vault.d
chmod 640 /etc/vault.d/vault.hcl

IPADDR=`ifconfig eth0 | grep 'inet ' | awk '{print $2}'`

# Generate Vault's client-facing key & certificate
SSLCONF=.ssl-req.conf
cat > $SSLCONF <<EOF
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
CN = *
[v3_req]
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = *
DNS.2 = *.*
DNS.3 = *.*.*
DNS.4 = *.*.*.*
DNS.5 = *.*.*.*.*
DNS.6 = *.*.*.*.*.*
DNS.7 = *.*.*.*.*.*.*
IP.1 = $IPADDR
IP.2 = 127.0.0.1
EOF

openssl req -days 730 -x509 -nodes -newkey rsa:2048 \
  -keyout  vault-key.${NODENAME}.pem \
  -out vault-cert.${NODENAME}.pem \
  -config $SSLCONF -extensions 'v3_req'

#cp vault-cert.${NODENAME}.pem /etc/pki/ca-trust/source/anchors
#update-ca-trust extract
cat vault-cert.vault1.pem >> /etc/pki/tls/certs/ca-bundle.crt

cp vault-cert.${NODENAME}.pem vault-key.${NODENAME}.pem /etc/vault.d

chown --recursive vault:vault /etc/vault.d
chmod 640 /etc/vault.d/*

# Setup raft data directory
DATA=/var/vault/data
mkdir -p $DATA
chown -R vault:vault $DATA
chmod -R 750 $DATA


# Setup server config 
cat > /etc/vault.d/vault.hcl <<EOF
storage "raft" {
  path    = "${DATA}"
  node_id = "${NODENAME}"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/etc/vault.d/vault-cert.${NODENAME}.pem"
  tls_key_file  = "/etc/vault.d/vault-key.${NODENAME}.pem"
}

cluster_addr = "https://127.0.0.1:8201"
api_addr = "https://${IPADDR}:8200"

ui = true
EOF

# TODO add systemd service file
# https://learn.hashicorp.com/tutorials/vault/raft-deployment-guide#configure-systemd
cat > /etc/systemd/system/vault.service <<EOF
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault.hcl
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Vault
systemctl enable vault
systemctl start vault
systemctl status vault





