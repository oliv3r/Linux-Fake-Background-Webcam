# Build the tensorflow library from source
ARG TENSORFLOW_BUILD="false"

# CPU based tensorflow builder
# As buster is currently broken we use sid as bullseye is not supported (yet)
FROM debian:sid-slim AS builder

WORKDIR /bodypix

ADD "https://deb.nodesource.com/setup_12.x" "/nodejs/setup_12.x"
COPY "./bodypix/package.json" "/bodypix/"

RUN \
    bash "/nodejs/setup_12.x" && \
    apt-get install --no-install-recommends --yes \
            build-essential \
            nodejs \
            python3-dev \
    && \
    npm install

#
FROM debian:sid-slim

WORKDIR /fakecam

ADD "https://deb.nodesource.com/setup_12.x" "/nodejs/setup_12.x"
COPY "./fakecam/requirements.txt" "/tmp/requirements.txt"

RUN bash "/nodejs/setup_12.x" && \
    apt-get install --no-install-recommends --yes \
            dumb-init \
            netcat \
            nodejs \
            python3-numpy \
            python3-opencv \
            python3-pip \
            python3-requests \
      && \
      pip3 install --no-cache-dir -r "/tmp/requirements.txt" && \
      rm -f -r \
         "/tmp/requirements.txt" \
         "/var/lib/apt/lists/" \
         "/var/cache/apt/"

COPY --from=builder "/bodypix" "/bodypix"
COPY "./fakecam/akvcam/" "/etc/akvcam/"
COPY "./bodypix/app.js" "/bodypix/"
COPY "./dockerfiles/docker-entrypoint.sh" "/init.sh"
COPY "./fakecam" "/fakecam/"

ENTRYPOINT [ "/init.sh" ]
