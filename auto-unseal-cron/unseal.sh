#!/bin/bash

# This script is intended to run from cron to auto-unseal Vault if needed.
# Demo/test environments only. The unseal key should not be stored in cleartext
# like this in production.

# suggested cron entry:
# * * * * * ~/bin/unseal.sh

export PATH=/usr/local/bin:/usr/bin
export VAULT_SKIP_VERIFY=true

if [ "$(vault status -format=json | jq .sealed)" == "true" ]
then
  vault operator unseal `cat ~/.unseal-key`
fi
