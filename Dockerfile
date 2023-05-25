FROM alpine:latest

RUN apk add --no-cache --virtual .build-deps bash gcc musl-dev openssl git

# TODO: Update binary to latest
COPY cyclonedx-linux-x64 /usr/bin/cyclonedx-cli
RUN chmod +x /usr/bin/cyclonedx-cli

# Copies shell script to container /
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]