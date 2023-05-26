FROM golang:1.19.9-alpine

RUN apk add --no-cache --virtual .build-deps bash curl \
    git jq make musl-dev openssl python3

RUN ln -sf python3 /usr/bin/python

# Copies shell script to container /
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]