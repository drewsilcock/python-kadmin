FROM python:3.12 as app

RUN apt update \
    && apt install -y \
        bison \
    && rm -rf /var/lib/apt/lists/*

COPY . /app

WORKDIR /app

RUN pip install .

FROM python:3.11 as test

RUN apt-get update \
    && apt-get install -y \
        bison \
        krb5-kdc \
        krb5-admin-server \
        krb5-kdc-ldap \
        slapd \
        ldap-utils \
        policycoreutils \
        policycoreutils-python-utils \
        expect \
        selinux-basics \
        selinux-policy-default \
        auditd \
        tini \
    && rm -rf /var/lib/apt/lists/*

ADD ./test/ /app/test/
WORKDIR /app/test
RUN bash ./setup.bash

ADD . /app
WORKDIR /app
RUN pip install .

WORKDIR /app/test
ENTRYPOINT ["tini", "-v", "--", "/app/test/docker-entrypoint.sh"]
