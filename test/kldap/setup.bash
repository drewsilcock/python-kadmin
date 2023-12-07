#!/bin/bash

export SHELL=/bin/bash

set -euxo pipefail

function mkpasswd {
    python -c "import string, random; print(''.join(random.choice(string.ascii_lowercase + string.digits) for _ in range(32)))"
}

# generate passwords 
MASTER_PASSWORD=`mkpasswd`
CONFIG_ROOT=`mkpasswd`
MDB_ROOT=`mkpasswd`

KRB5KDC_PASSWORD=`mkpasswd`
KADMIND_PASSWORD=`mkpasswd`

kdb5_ldap_util destroy -f 2> /dev/null || true

# load an updated krb5.conf with correct permissions
chown --reference=/etc/krb5.conf ./krb5.conf 
chmod --reference=/etc/krb5.conf ./krb5.conf 
cp ./krb5.conf /etc/krb5.conf
restorecon /etc/krb5.conf

chown --reference=/etc/ldap/ldap.conf ./ldap.conf 
chmod --reference=/etc/ldap/ldap.conf ./ldap.conf 
cp ./ldap.conf /etc/ldap/ldap.conf
restorecon /etc/ldap/ldap.conf

# setup database directory
mkdir -p /srv/ldap/example.com/

# make sure selinux is alright with our directory serving ldap data
semanage fcontext -ae /var/lib/ldap /srv/ldap/example.com
restorecon -Rv /srv/ldap

# halt any existing slapd server
service slapd stop 2> /dev/null || true
killall slapd 2> /dev/null || true

# purge old configurations and data
rm -rf /etc/ldap/slapd.d/*
rm -rf /srv/ldap/example.com/*

# load cn=config database
slapadd -n0 -F /etc/ldap/slapd.d/ -l ./cn_config.ldif

cat ./olcDatabase_0.ldif | sed -e "s#CONFIG_ROOT#$CONFIG_ROOT#g" > /tmp/olcDatabase_0.ldif

slapadd -n0 -F /etc/ldap/slapd.d/ -l /tmp/olcDatabase_0.ldif

# restore permissions before starting server
chown -R openldap:openldap /etc/ldap
chown -R openldap:openldap /srv/ldap/example.com

# start server
service slapd start

# add modules
ldapmodify -D "cn=config" -H ldapi:/// -x -w "$CONFIG_ROOT" -a -f ./cn_module.ldif

# add schemas (kerberos.ldif is added here)
bash ./schemas.bash

# configure a database (mdb) for use to store data
cat ./olcDatabase_mdb.ldif | sed -e "s#MDB_ROOT#$MDB_ROOT#g" > /tmp/olcDatabase_mdb.ldif

ldapmodify -D "cn=config" -H ldapi:/// -x -w "$CONFIG_ROOT" -a -f /tmp/olcDatabase_mdb.ldif || cat /var/log/openldap/slapd.log

# create our dit including the accounts for kerberos and test accounts for db_args 
ldapmodify -Q -H ldapi:/// -Y EXTERNAL -ac -f ./dit.ldif

# set the password so it hashes properly
ldappasswd -Q -s $KADMIND_PASSWORD uid=kadmin,ou=accounts,dc=example,dc=com
ldappasswd -Q -s $KRB5KDC_PASSWORD uid=krb5kdc,ou=accounts,dc=example,dc=com

# init kerberos realm inside the ldap database
cat ./kdb_create.expect | sed -e "s#MASTER_PASSWORD#$MASTER_PASSWORD#g" | sed -e "s#MDB_ROOT#$MDB_ROOT#g" > /tmp/kdb_create.expect
expect /tmp/kdb_create.expect

cat ./stash_kadmind.expect | sed -e "s#MDB_ROOT#$MDB_ROOT#g" | sed -e "s#KADMIND_PASSWORD#$KADMIND_PASSWORD#g" > /tmp/stash_kadmind.expect
expect /tmp/stash_kadmind.expect

cat ./stash_krb5kdc.expect | sed -e "s#MDB_ROOT#$MDB_ROOT#g" | sed -e "s#KRB5KDC_PASSWORD#$KRB5KDC_PASSWORD#g" > /tmp/stash_krb5kdc.expect
expect /tmp/stash_krb5kdc.expect


# create default accounts
kadmin.local -q "ank -randkey kadmin/admin"
kadmin.local -q "ank -randkey kadmin/changepw"

# restart kadmin and krb5kdc 
service krb5-admin-server restart
service krb5-kdc restart




