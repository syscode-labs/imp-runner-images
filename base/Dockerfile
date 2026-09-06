FROM debian:bookworm-slim

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
       bash \
       ca-certificates \
       curl \
       git \
       gzip \
       libicu72 \
       libkrb5-3 \
       liblttng-ust1 \
       libssl3 \
       tar \
       tzdata \
       zlib1g \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 10001 --shell /bin/bash runner

WORKDIR /home/runner
USER 10001

CMD ["/usr/local/bin/runner"]
