#!/bin/bash

systemctl stop vault
rm -fr /var/vault/data/* /etc/vault.d
