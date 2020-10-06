# Base Vault Install on Each Node

Copy the certificate/key tarball provided by your Hashicorp engineer to `~centos/certs.tgz` on each Vault server node. This can be generated with easy-rsa and the included `gen-vault-certs.sh` script.

    # tar ztf ~centos/certs.tgz
    ca.crt
    vault.crt
    vault.key


These commands will download and execute the install script, which will do a yum update, install dependencies, install Vault with raft integrated storage and a self-signed certificate. Do this on each Vault server node.

    sudo yum install -y git
    git clone https://github.com/jacobm3/vault-install.git
    sudo ./vault-install/centos/install-vault-centos7.sh `hostname`

# First Node Setup

## Initialize the First Vault Node

Here I'm initializing with 1 recovery key and encrypting the recovery key with my PGP public key for safe delivery. PGP keys should be used to securely distribute key shards to Vault admins when using Shamir secret sharing to provide separation of duties. 


    $ vault operator init -key-shares=1 -key-threshold=1 -pgp-keys=jacob.asc
    Unseal Key 1: wcDMA9FTNzae4vyUA...</snip> iAcBx2g6n3iIJiUF+ZWCGXd0XagSZ8kgEeF

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

## Each Vault Admin Decrypts their Unseal Key

    # Save unseal key output to unseal.enc on the machine where you have your PGP key 
    # (run this command, paste the value, then hit enter, ctrl-d)
    cat > unseal.enc

    # Convert to a binary file
    base64 -d < unseal.enc > unseal.bin

    # Decrypt with pgp/gpg
    $ gpg -d unseal.bin
    gpg: encrypted with 3072-bit RSA key, ID D15337369EE2FC94, created 2020-10-03
      "Jacob Martinson <jacob@gmail.com>"
    9cb8ee50c4fe90b4e905b9be404c3384d4afa25377e1be25dfff0f5fed9c947e

## Unseal the First Node

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

## Login and Apply Enterprise License

Vault Enterprise will seal itself after 30 minutes without a license. You must restart the Vault process 
if this happens before you have an opportunity to enter it again.

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
    features                     [HSM Performance Replication DR Replication MFA Sentinel 
                                  Seal Wrapping Control Groups Performance Standby Namespaces 
                                  KMIP Entropy Augmentation Transform Secrets Engine 
                                  Lease Count Quotas]
    license_id                   00693ae5-7278-408f-84a1-0f86d87476ba
    performance_standby_count    9999
    start_time                   2020-10-01T00:00:00Z

## First node is the only node in cluster

    $ vault operator raft list-peers
    Node      Address        State     Voter
    ----      -------        -----     -----
    vault1    vault1:8201    leader    true

# Setup Remaining Nodes

## Update vault.hcl with leader info

Edit `/etc/vault.d/vault.hcl` on the remaining two nodes and add the hostnames of the other 
two nodes in the retry_join sections. For example, the `vault2` node storage block should
look like this:

    storage "raft" {
        path    = "/var/vault/data"
        node_id = "vault2"
        retry_join {
            leader_api_addr = "https://vault1.test.io:8200"
            leader_ca_cert_file = "/etc/vault.d/tls/ca.crt"
            leader_client_cert_file = "/etc/vault.d/tls/vault.crt"
            leader_client_key_file = "/etc/vault.d/tls/vault.key"
        }
        retry_join {
            leader_api_addr = "https://vault3.test.io:8200"
            leader_ca_cert_file = "/etc/vault.d/tls/ca.crt"
            leader_client_cert_file = "/etc/vault.d/tls/vault.crt"
            leader_client_key_file = "/etc/vault.d/tls/vault.key"
        }
    }

The `vault3` node storage block should look like this:

    storage "raft" {
        path    = "/var/vault/data"
        node_id = "vault3"
        retry_join {
            leader_api_addr = "https://vault1.test.io:8200"
            leader_ca_cert_file = "/etc/vault.d/tls/ca.crt"
            leader_client_cert_file = "/etc/vault.d/tls/vault.crt"
            leader_client_key_file = "/etc/vault.d/tls/vault.key"
        }
        retry_join {
            leader_api_addr = "https://vault2.test.io:8200"
            leader_ca_cert_file = "/etc/vault.d/tls/ca.crt"
            leader_client_cert_file = "/etc/vault.d/tls/vault.crt"
            leader_client_key_file = "/etc/vault.d/tls/vault.key"
        }
    }

Restart vault to make the changes take effect.

    $ sudo systemctl stop vault; sudo systemctl start vault

## Unseal and Login

On each of the remaining nodes (vault2 and vault3), unseal the storage layer and
login with the root roken.

    $  vault operator unseal
    Unseal Key (will be hidden):
    Key                Value
    ---                -----
    Seal Type          shamir
    Initialized        true
    Sealed             true
    Total Shares       1
    Threshold          1
    Unseal Progress    0/1
    Unseal Nonce       n/a
    Version            1.5.4+ent
    HA Enabled         true

It takes a moment for the challenge/response to complete, then it will show unsealed
and part of an HA cluster.

    $ vault status
    Key                                    Value
    ---                                    -----
    Seal Type                              shamir
    Initialized                            true
    Sealed                                 false
    Total Shares                           1
    Threshold                              1
    Version                                1.5.4+ent
    Cluster Name                           vault-cluster-4df4ca03
    Cluster ID                             aa77c290-5671-c093-8f92-a83375313de1
    HA Enabled                             true
    HA Cluster                             https://vault1:8201
    HA Mode                                standby
    Active Node Address                    https://vault1:8200
    Performance Standby Node               true
    Performance Standby Last Remote WAL    0
    Raft Committed Index                   335
    Raft Applied Index                     335

    $ vault login 
    Token (will be hidden):
    Success! You are now authenticated. The token information displayed below
    is already stored in the token helper. You do NOT need to run "vault login"
    again. Future Vault requests will automatically use this token.

    Key                  Value
    ---                  -----
    token                s.Pw0Iksoxir25l3bZGHZbtknK
    token_accessor       F8giRJ0OPjIn36GVP2ri8YV0
    token_duration       ∞
    token_renewable      false
    token_policies       ["root"]
    identity_policies    []
    policies             ["root"]

    $ vault operator raft list-peers
    Node      Address        State       Voter
    ----      -------        -----       -----
    vault1    vault1:8201    leader      true
    vault3    vault3:8201    follower    true

Doing the same thing on vault2 yields similar results.

    $ vault operator raft list-peers
    Node      Address        State       Voter
    ----      -------        -----       -----
    vault1    vault1:8201    leader      true
    vault3    vault3:8201    follower    true
    vault2    vault2:8201    follower    true

# Congratulations!

Your Vault cluster is now operational!