# Base Vault Install

This will download the install script, which will do a yum update, install a couple dependencies, install Vault with raft integrated storage and a self-signed certificate. Do this on each Vault server node.

    sudo yum install -y git
    git clone https://github.com/jacobm3/vault-install.git
    cd vault-install/centos
    sudo ./install-vault-centos7.sh NODENAME

# Initialize Vault

Here I'm initializing with 1 recovery key and encrypting the recovery with my PGP public key. PGP keys should be used to securely distribute key shards to Vault admins when using Shamir secret sharing. 


    $ vault operator init -n 1 -t 1 -pgp-keys=jacob.asc
    Unseal Key 1: wcDMA9FTNzae4vyUAQwAiBSHW/AUPnmfP/plFgUsZfNT3oXKrIc1Z7WI1n1pNX+qfpsQ/wTMWG87v50MBOV1P6N95gK+MHO4ZGWsrQSlB5bVdiqiAcBx2g6n3iIJiUF+ZWCGXd0XagSZ8kgEeF8blWG7emZVEFfl6+pd9ClrX9dUw/yyTLjZ4VBmVlkYPGqTB8ne5Gjxx8aJbAvdhJZttvtuvg+FbBhE1V++m04iMK0TQcjTl8s+jLR/23CmfJYR0m3q8SvNkNpzQ4GYpbU

    Initial Root Token: s.PCrv6L7che3Yg7ruBpxltZCc

    Vault initialized with 1 key shares and a key threshold of 1. Please securely
    distribute the key shares printed above. When the Vault is re-sealed,
    restarted, or stopped, you must supply at least 1 of these keys to unseal it
    before it can start servicing requests.

    Vault does not store the generated master key. Without at least 1 key to
    reconstruct the master key, Vault will remain permanently sealed!

    It is possible to generate new unseal keys, provided you have a quorum of
    existing unseal keys shares. See "vault operator rekey" for more information.

Save the encrypted unseal key and the root token somewhere safe.

For more information on `operator init` options, see:
https://learn.hashicorp.com/tutorials/vault/getting-started-deploy#initializing-the-vault
https://www.vaultproject.io/docs/commands/operator/init

# Each Vault admin decrypts their unseal key

    # Save unseal key output as a binary file
    base64 -d < unseal.enc > unseal.bin

    # Decrypt with pgp/gpg
    $ gpg -d unseal.bin
    gpg: encrypted with 3072-bit RSA key, ID D15337369EE2FC94, created 2020-10-03
      "Jacob Martinson <jacob7719@gmail.com>"
    9cb8ee50c4fe90b4e905b9be404c3384d4afa25377e1be25dfff0f5fed9c947e

# Unseal the first node

    $ vault operator unseal
    Unseal Key (will be hidden): <provide decrypted key here>
    Key                     Value
    ---                     -----
    Seal Type               shamir
    Initialized             true
    Sealed                  false
    Total Shares            1
    Threshold               1
    Version                 1.5.4+ent
    Cluster Name            vault-cluster-fbc60f3e
    Cluster ID              89ac2672-e1ae-1d57-8c40-a6fb5417a688
    HA Enabled              true
    HA Cluster              n/a
    HA Mode                 standby
    Active Node Address     <none>
    Raft Committed Index    51
    Raft Applied Index      51

# Login and Apply Enterprise License

    $ vault login
    Token (will be hidden): <provide root token>
    Success! You are now authenticated. The token information displayed below
    is already stored in the token helper. You do NOT need to run "vault login"
    again. Future Vault requests will automatically use this token.

    Key                  Value
    ---                  -----
    token                s.PCrv6L7che3XXXXXXXXXXXXX
    token_accessor       G2GHJtrFxWhWHlpZmdx0XagB
    token_duration       ∞
    token_renewable      false
    token_policies       ["root"]
    identity_policies    []
    policies             ["root"]


    $ vault write sys/license text="02MV4UU43BK5HGYYTOJZWFQMT... </snip>... HU6Q"
    Success! Data written to: sys/license

    $ vault read sys/license
    Key                          Value
    ---                          -----
    expiration_time              2021-10-01T23:59:59.999Z
    features                     [HSM Performance Replication DR Replication MFA Sentinel Seal Wrapping Control Groups Performance Standby Namespaces KMIP Entropy Augmentation Transform Secrets Engine Lease Count Quotas]
    license_id                   00693ae5-7278-408f-84a1-0f86d87476ba
    performance_standby_count    9999
    start_time                   2020-10-01T00:00:00Z

# First node is the only node in cluster

    $ vault operator raft list-peers
    Node      Address           State     Voter
    ----      -------           -----     -----
    vault1    127.0.0.1:8201    leader    true

# Final Goal

    root@vault1:/etc/vault.d (05:27 AM - Mon Oct 05) v
    # cat vault.hcl
    storage "raft" {
    path    = "/var/vault/data"
    node_id = "vault1"
        retry_join {
        leader_api_addr = "https://vault2.test.io:8200"
        leader_ca_cert_file = "/etc/vault.d/tls/ca.crt"
        leader_client_cert_file = "/etc/vault.d/tls/vault1.crt"
        leader_client_key_file = "/etc/vault.d/tls/vault1.key"
        }
        retry_join {
        leader_api_addr = "https://vault3.test.io:8200"
        leader_ca_cert_file = "/etc/vault.d/tls/ca.crt"
        leader_client_cert_file = "/etc/vault.d/tls/vault1.crt"
        leader_client_key_file = "/etc/vault.d/tls/vault1.key"
        }
    }

    listener "tcp" {
    address       = "0.0.0.0:8200"
    cluster_address = "0.0.0.0:8201"
    tls_cert_file = "/etc/vault.d/tls/vault1.crt"
    tls_key_file  = "/etc/vault.d/tls/vault1.key"
    ca_cert_file = "/etc/vault.d/tls/ca.crt"
    }

    cluster_addr = "https://vault1.test.io:8201"
    api_addr = "https://vault1.test.io:8200"

    ui = true

    root@vault1:/etc/vault.d (05:27 AM - Mon Oct 05) v
    # vault operator raft list-peers
    Node      Address                State       Voter
    ----      -------                -----       -----
    vault2    vault2.test.io:8201    leader      true
    vault3    vault3.test.io:8201    follower    true
    vault1    vault1.test.io:8201    follower    true
