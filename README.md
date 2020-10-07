This repository can be used to quickly and easily setup a Vault cluster with raft integrated storage. It assumes you're generating a signed TLS key/certificate pair for the nodes to use.

# Base Vault Install on Each Node

Copy the certificate/key tarball provided by your Hashicorp engineer to `~centos/certs.tgz` on each Vault server node. This can be generated with easy-rsa and the included `gen-vault-certs.sh` script. This will be used by the Vault listener and when nodes join the cluster.

    $ cd ~centos
    $ tar zxvf certs.tgz
    tls/ca.crt
    tls/vault.crt
    tls/vault.key


These commands will download and execute the install script, which will do a yum update, install dependencies, install Vault with raft integrated storage and a self-signed certificate. Do this on each Vault server node.

    sudo yum install -y git
    git clone https://github.com/jacobm3/vault-install.git
    sudo ./vault-install/centos/install-vault-centos7.sh `hostname`


&nbsp;  
&nbsp;  

# First Node Setup

## Initialize the First Vault Node

Initialization is the process of configuring Vault. This only happens once when the server is started against a new backend that has never been used with Vault before. When running in HA mode, this happens once per cluster, not per server.

During initialization, the encryption keys are generated, unseal keys are created, and the initial root token is setup. To initialize Vault use vault operator init. This is an unauthenticated request, but it only works on brand new Vaults with no data. The unseal key(s) and root token are a core part of Vault's security model and should be guarded closely. 

Decisions around the unseal process include whether to use Shamir unseal keys, auto-unseal with a cloud key management system, and whether to use PGP to securely deliver unseal keys to their intended recipients.

For more information see:

https://learn.hashicorp.com/tutorials/vault/getting-started-deploy#initializing-the-vault  
https://www.vaultproject.io/docs/commands/operator/init  
https://www.vaultproject.io/docs/concepts/seal  

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

This is often done for small development and testing environments that need persistence than Vault's dev mode provides. 

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

## First node is the only node in cluster

    $ vault operator raft list-peers
    Node      Address        State     Voter
    ----      -------        -----     -----
    vault1    vault1:8201    leader    true


&nbsp;  
&nbsp;  

# Setup Remaining Nodes

## Join Nodes to the Cluster

    $ vault operator raft join \
        -leader-ca-cert=@tls/ca.crt \
        -leader-client-cert=@tls/vault.crt \
        -leader-client-key=@tls/vault.key \
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

&nbsp;  
&nbsp;  

# Congratulations!

Your Vault cluster is now operational!


