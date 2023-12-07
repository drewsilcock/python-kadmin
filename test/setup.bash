#!/bin/bash
# This file prepares the test environment for the test suite. It runs the
# `stock/setup.bash`, `stock/schemas.bash` and `stock/setup.bash` scripts in the right
# order and makes sure the right files and services and there and running. You need to
# run this from the test directory.

set -euxo pipefail

echo "test/admin@EXAMPLE.COM *" >> /etc/krb5kdc/kadm5.acl
echo "loglevel -1" >> /etc/ldap/slapd.conf
touch /etc/ldap/ldap.conf
mkdir -p /etc/ldap/slapd.d /var/kerberos/krb5kdc /var/log/openldap # /var/run/openldap /etc/openldap

pushd ./stock
bash ./setup.bash
popd

pushd ./kldap
bash ./setup.bash
popd
