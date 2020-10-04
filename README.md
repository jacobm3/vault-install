# Base Vault Install

This will download the install script, which will do a yum update, install a couple dependencies, install Vault with raft integrated storage and a self-signed certificate. Do this on each Vault server node.

    sudo yum install -y git
    git clone https://github.com/jacobm3/vault-install.git
    cd vault-install/centos
    sudo ./install-vault-centos7.sh NODENAME

# Initialize Vault

Here I'm initializing with 1 recovery key and encrypting it using a PGP public key:



