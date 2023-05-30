FROM golang:1.20.4-alpine

RUN apk add --no-cache --virtual .build-deps bash binutils ca-certificates coreutils curl \
    findutils g++ gcc gcompat git grep jq libc6-compat libstdc++6 libgcc linux-headers make \
    musl-dev ncurses openssl python3 py3-pip util-linux

RUN ln -sf python3 /usr/bin/python

ENV GLIBC_REPO=https://github.com/sgerrand/alpine-pkg-glibc
ENV GLIBC_VERSION=2.35-r1

# glibc compatibility crap for nodejs
RUN set -ex && \
    apk --update add libstdc++ curl ca-certificates && \
    for pkg in glibc-${GLIBC_VERSION} glibc-bin-${GLIBC_VERSION}; \
        do curl -sSL ${GLIBC_REPO}/releases/download/${GLIBC_VERSION}/${pkg}.apk -o /tmp/${pkg}.apk; done && \
    apk add --allow-untrusted --force-overwrite /tmp/*.apk && \
    rm -v /tmp/*.apk && \
    /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc-compat/lib

# Copies shell script to container /
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]