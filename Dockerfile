FROM golang:1.19.9-alpine

RUN apk add --no-cache --virtual .build-deps bash curl \
    git jq musl-dev openssl

# TODO: Update binary to latest
COPY cyclonedx-linux-x64 /usr/bin/cyclonedx-cli
RUN chmod +x /usr/bin/cyclonedx-cli

# Copies shell script to container /
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]