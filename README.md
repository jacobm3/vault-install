This repository can be used to quickly and easily setup a Vault cluster with raft integrated storage. It assumes you already have 3 VMs running, sudo access on each of them, and that you've generated a signed TLS key/certificate pair for the nodes to use. The `gen-vault-certs.sh` script can be used to in conjunction with `easy-rsa` to easily generate a CA and signed certs.

- [Base Vault Install on Each Node](#base-vault-install-on-each-node)
- [First Node Setup](#first-node-setup)
  * [Initialize the First Vault Node](#initialize-the-first-vault-node)
    + [Option 1 - Initializing with default 5 cleartext unseal keys](#option-1---initializing-with-default-5-cleartext-unseal-keys)
    + [Option 2 - Initializing with a single cleartext unseal key](#option-2---initializing-with-a-single-cleartext-unseal-key)
    + [Option 3 - Initializing with PGP unseal keys](#option-3---initializing-with-pgp-unseal-keys)
      - [Decrypting PGP Unseal Keys](#decrypting-pgp-unseal-keys)
  * [Unseal the First Node](#unseal-the-first-node)
  * [Login and Apply Enterprise License](#login-and-apply-enterprise-license)
  * [View Peer List](#view-peer-list)
  * [Write First Secret](#write-first-secret)
- [Setup Remaining Nodes](#setup-remaining-nodes)
  * [Join to Cluster](#join-to-cluster)
  * [View Status](#view-status)
  * [Verify Data Replicated Across Cluster](#verify-data-replicated-across-cluster)
- [Congratulations!](#congratulations-)

# Base Vault Install on Each Node

Copy the certificates/key tarball provided by your Hashicorp engineer (or your internal certificate authority) to `~centos/certs.tgz` on each Vault server node. This can be generated with easy-rsa and the included `gen-vault-certs.sh` script. This will be used by the Vault listeners and in the challenge/response when nodes join the cluster.

    $ cd ~centos
    $ tar ztf certs.tgz  # should look like this inside
    ca.crt
    vault.crt
    vault.key

Setup DNS so the Vault nodes can resolve each others names to IP addresses. If DNS isn't available, add enties to `/etc/hosts` on each node so they can all resolve each other locally instead. These hostnames are what you'll use when joining nodes to the cluster. Example:

    172.31.30.139 vault1.test.io vault1
    172.31.31.184 vault2.test.io vault2
    172.31.17.195 vault3.test.io vault3


These commands will download and execute the install script, which will do a yum update, install dependencies, install Vault with raft integrated storage and a self-signed certificate. Do this on each Vault server node.

    sudo yum install -y git
    git clone https://github.com/jacobm3/vault-install.git
    sudo ./vault-install/centos/install-vault-centos7.sh `hostname`

&nbsp;  

# First Node Setup

## Initialize the First Vault Node

Initialization is the process of configuring Vault. This only happens once when the server is started against a new backend that has never been used with Vault before. When running in HA mode, this happens once per cluster, not per server.

During initialization, the encryption keys are generated, unseal keys are created, and the initial root token is setup. To initialize Vault use vault operator init. This is an unauthenticated request, but it only works on brand new Vaults with no data. 

**The unseal key(s) and root token are a core part of Vault's security model. Guard them closely.**

Decisions around the unseal process include whether to use Shamir unseal keys, auto-unseal with a cloud key management system, and whether to use PGP to securely deliver unseal keys to their intended recipients.

For more information see:

https://learn.hashicorp.com/tutorials/vault/getting-started-deploy#initializing-the-vault  
https://www.vaultproject.io/docs/commands/operator/init  
https://www.vaultproject.io/docs/concepts/seal  
https://www.vaultproject.io/docs/internals/security  
https://www.vaultproject.io/docs/internals/architecture  
https://learn.hashicorp.com/tutorials/vault/production-hardening  

### Option 1 - Initializing with default 5 cleartext unseal keys

This is the default behavior, generating 5 unseal keys and requiring a quorum of 3 users to provide their unseal keys in order to perform sensitive operations like unsealing a Vault or generating a root token.

    $ vault operator init
    Unseal Key 1: jMIjMawbpKcJN1TVKCfd6/G6hiC/q+0FJkz5U7cx0jXs
    Unseal Key 2: FvABLzddGvWND9HiwhwtNbistudY4Wqfo78lOUxLR8Lg
    Unseal Key 3: yCZJ4XD77D800SeM80BYbcjXwP3dOuooU7ykcO1Awk6T
    Unseal Key 4: jHyIHaWSvm8ok366vtwXDZ5emVpiWGSh+MBFK4dZ1kfA
    Unseal Key 5: Vc/qDmtPBwkNnoau70+k/qGl5aqULpmz6Ye1xZGMS+EM

    Initial Root Token: s.QlSgkzZgXb3qBF27xxMego6B

    Vault initialized with 5 key shares and a key threshold of 3. Please securely
    distribute the key shares printed above. When the Vault is re-sealed,
    restarted, or stopped, you must supply at least 3 of these keys to unseal it
    before it can start servicing requests.

    Vault does not store the generated master key. Without at least 3 key to
    reconstruct the master key, Vault will remain permanently sealed!

    It is possible to generate new unseal keys, provided you have a quorum of
    existing unseal keys shares. See "vault operator rekey" for more information.

### Option 2 - Initializing with a single cleartext unseal key

This is often done for dev-test environments with lower security requirements, but that still require persistence that Vault's dev mode doesn't provide. 

    $ vault operator init -key-shares=1 -key-threshold=1
    Unseal Key 1: nP4Odrb6EuFgVsA/Q+YIcMHV3JwIPj8e8Wb64S6SPVE=

    Initial Root Token: s.aOJbmwLXoFR4JoEEMoaOCSMZ

    Vault initialized with 1 key shares and a key threshold of 1. Please securely
    distribute the key shares printed above. When the Vault is re-sealed,
    restarted, or stopped, you must supply at least 1 of these keys to unseal it
    before it can start servicing requests.

    Vault does not store the generated master key. Without at least 1 key to
    reconstruct the master key, Vault will remain permanently sealed!

    It is possible to generate new unseal keys, provided you have a quorum of
    existing unseal keys shares. See "vault operator rekey" for more information.


### Option 3 - Initializing with PGP unseal keys

Here I'm initializing with 1 recovery key and encrypting the recovery key with my PGP public key for safe delivery. PGP keys should be used to securely distribute key shards to Vault admins when using Shamir secret sharing to provide separation of duties. 

For more information on using Vault and PGP together, please see:  
https://www.vaultproject.io/docs/concepts/pgp-gpg-keybase

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

Example with 3 PGP recipients:

    $ vault operator init -key-shares=3 -key-threshold=3 -pgp-keys=jacobm.asc,user1.asc,user2.asc
    Unseal Key 1: wcDMA9FTNzae4vyUAQwADy...EWOgA=
    Unseal Key 2: wcDMA5WNvc4CPxe...EjfgA=
    Unseal Key 3: wcDMA7...Wjbg

#### Decrypting PGP Unseal Keys

PGP or GPG use varies by operating system. These instructions work in Linux/WSL:

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

In this case, the unseal key for this user is `9cb8ee50c4fe90b4e905b9be404c3384d4afa25377e1be25dfff0f5fed9c947e`

## Unseal the First Node

When a Vault server is started, it starts in a sealed state. In this state, Vault is configured to know where and how to access the physical storage, but doesn't know how to decrypt any of it. Unsealing is the process of obtaining the plaintext master key necessary to read the decryption key to decrypt the data, allowing access to the Vault.

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

## View Peer List
First node is the only node in cluster

    $ vault operator raft list-peers
    Node      Address        State     Voter
    ----      -------        -----     -----
    vault1    vault1:8201    leader    true

## Write First Secret

    $ vault secrets enable -version=2 kv
    Success! Enabled the kv secrets engine at: kv/

    $ vault kv put kv/my-secret my-value=s3cr3t
    Key              Value
    ---              -----
    created_time     2020-10-07T15:56:51.997241719Z
    deletion_time    n/a
    destroyed        false
    version          1

    $ vault kv get kv/my-secret
    ====== Metadata ======
    Key              Value
    ---              -----
    created_time     2020-10-07T15:56:51.997241719Z
    deletion_time    n/a
    destroyed        false
    version          1

    ====== Data ======
    Key         Value
    ---         -----
    my-value    s3cr3t


&nbsp;  

# Setup Remaining Nodes

Run these commands on each additional node you wish to join to the cluster. Hostname resolution must be working at this point and the nodes should all be able to reach each other on TCP/8200 and TCP/8201. The TLS certificates and private key must be available to the Vault command during the joining process.

## Join to Cluster

    $ vault operator raft join \
        -leader-ca-cert=@ca.crt \
        -leader-client-cert=@vault.crt \
        -leader-client-key=@vault.key \
        https://vault1.test.io:8200

    Key       Value
    ---       -----
    Joined    true

    $ vault operator unseal
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

## View Status

    $ vault status
    Key                     Value
    ---                     -----
    Seal Type               shamir
    Initialized             true
    Sealed                  false
    Total Shares            1
    Threshold               1
    Version                 1.5.4+ent
    Cluster Name            vault-cluster-567fb529
    Cluster ID              dfb2004a-7826-af15-ac79-d5b0c70294fd
    HA Enabled              true
    HA Cluster              https://vault1:8201
    HA Mode                 standby
    Active Node Address     https://vault1:8200
    Raft Committed Index    1490
    Raft Applied Index      1490

    $ vault login
    Token (will be hidden):
    Success! You are now authenticated. The token information displayed below
    is already stored in the token helper. You do NOT need to run "vault login"
    again. Future Vault requests will automatically use this token.

    Key                  Value
    ---                  -----
    token                s.xxxxxxxxxxxxxxxxxxxxxxxx
    token_accessor       kwFXtip8xr8yE6MESTbY3Dym
    token_duration       ∞
    token_renewable      false
    token_policies       ["root"]
    identity_policies    []
    policies             ["root"]

    $ vault operator raft list-peers
    Node      Address        State       Voter
    ----      -------        -----       -----
    vault1    vault1:8201    leader      true
    vault2    vault2:8201    follower    true
    vault3    vault3:8201    follower    true

## Verify Data Replicated Across Cluster

    $ vault kv get kv/my-secret
    ====== Metadata ======
    Key              Value
    ---              -----
    created_time     2020-10-07T15:56:51.997241719Z
    deletion_time    n/a
    destroyed        false
    version          1

    ====== Data ======
    Key         Value
    ---         -----
    my-value    s3cr3t

&nbsp;  

# Congratulations!

Your Vault cluster is now operational!


