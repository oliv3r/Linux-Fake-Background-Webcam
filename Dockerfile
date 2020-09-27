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

ADD "https://deb.nodesource.com/gpgkey/nodesource.gpg.key" "/tmp/virtcam/nodesource.gpg.key"
ADD "https://developer.download.nvidia.com/compute/redist/nccl/v2.7/nccl_2.7.8-1+cuda11.0_x86_64.txz" "/tmp/virtcam/ncll.tar.xz"
ADD "https://developer.download.nvidia.com/compute/cuda/repos/debian10/x86_64/7fa2af80.pub" "/tmp/virtcam/nvidia.gpg.key"
ARG WITH_CUDA="false"
ENV NCCL_CHKSUM="34000cbe6a0118bfd4ad898ebc5f59bf5d532bbf2453793891fa3f1621e25653"
COPY "./fakecam/requirements.txt" "/tmp/virtcam/requirements.txt"

RUN \
    apt-get update && \
    apt-get install --no-install-recommends --yes \
            ca-certificates \
            dumb-init \
            gnupg2 \
    && \
    echo "With CUDA: ${WITH_CUDA}" && \
    if [ "${WITH_CUDA:-}" = "true" ]; then \
        cat "/tmp/virtcam/nvidia.gpg.key" | apt-key add - && \
        echo "deb https://developer.download.nvidia.com/compute/cuda/repos/debian10/x86_64 /" > "/etc/apt/sources.list.d/cuda.list" && \
        apt-get update && \
        apt-get install --no-install-recommends --yes \
                cuda-compat-11-1 \
                cuda-libraries-11-1 \
                xz-utils \
        && \
        mv \
           "/usr/local/cuda-"*"/targets/x86_64-linux/lib/"* \
           "/usr/local/cuda-"*"/compat/"* \
           "/usr/local/lib/" && \
        rm "/etc/ld.so.conf.d/"*"cuda"* && \
        rm -f -r "/usr/local/cuda"* && \
        mkdir -p "/usr/local/share/doc/cuda/" && \
        mv \
           "/usr/share/doc/cuda"* \
           "/usr/share/doc/libnv"* \
           "/usr/local/share/doc/cuda/" && \
        echo "${NCCL_CHKSUM} /tmp/virtcam/ncll.tar.xz" | sha256sum -c - && \
        tar \
            --directory "/usr/local/" \
            --extract \
            --file "/tmp/virtcam/ncll.tar.xz" \
            --keep-old-files \
            --no-same-owner \
            --strip-components=1 \
            --verbose \
            --wildcards '*/LICENSE.txt' \
            --wildcards '*/lib/libnccl.so.2*' \
            --xz \
        && \
        mv "/usr/local/LICENSE.txt" "/usr/local/share/doc/cuda/"; \
    fi && \
    cat "/tmp/virtcam/nodesource.gpg.key" | apt-key add - && \
    echo "deb https://deb.nodesource.com/node_12.x sid main" > "/etc/apt/sources.list.d/nodesource.list" && \
    apt-get update && \
    apt-get install --no-install-recommends --yes \
            netcat \
            nodejs \
            python3-numpy \
            python3-opencv \
            python3-pip \
            python3-requests \
    && \
    pip3 install --no-cache-dir -r "/tmp/virtcam/requirements.txt" && \
    rm -f -r \
        "/tmp/virtcam/" \
        "/var/lib/apt/lists/" \
        "/var/cache/apt/"

COPY --from=builder "/bodypix" "/bodypix"
COPY "./fakecam/akvcam/" "/etc/akvcam/"
COPY "./bodypix/app.js" "/bodypix/"
COPY "./dockerfiles/docker-entrypoint.sh" "/init.sh"
COPY "./fakecam" "/fakecam/"

ENTRYPOINT [ "/init.sh" ]
