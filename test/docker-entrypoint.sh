#!/bin/bash

set -e

service slapd start
service krb5-admin-server start
service krb5-kdc start

cd /app/test
python unittests.py
