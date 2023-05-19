# Container image
FROM ubuntu:latest

ENV DEBIAN_FRONTEND noninteractive

# using --no-install-recommends to reduce image size

RUN apt-get update \
    && apt-get install --no-install-recommends -y git npm golang \
    curl jq build-essential apt-transport-https unzip \
    libc6 libgcc1 libgssapi-krb5-2 zlib1g \
    && apt-get update

# TODO: Update binary to latest
COPY cyclonedx-linux-x64 /usr/bin/cyclonedx-cli
RUN chmod +x /usr/bin/cyclonedx-cli

# Copies shell script to container /
COPY entrypoint.sh /entrypoint.sh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]