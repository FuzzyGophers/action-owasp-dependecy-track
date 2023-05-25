FROM golang:1.19.9-alpine

RUN apk add --no-cache --virtual .build-deps bash curl \
    git jq musl-dev openssl

# Copies shell script to container /
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]