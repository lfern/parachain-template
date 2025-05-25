# Base stage
FROM rust:latest AS base

RUN rustup target add wasm32-unknown-unknown && \
    rustup component add rust-src && \
    rustup update nightly && \
    rustup target add wasm32-unknown-unknown --toolchain nightly && \
    rustup component add rust-src --toolchain nightly

RUN apt-get update && apt-get install -y --no-install-recommends \
    clang \
    curl \
    git \
    libssl-dev \
    llvm \
    libclang-dev \
    build-essential \
    pkg-config \
    cmake \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

RUN cargo install --locked staging-chain-spec-builder@10.0.0 && \
    cargo install --locked polkadot-omni-node@0.5.0

# Stage for development.
FROM base AS development
WORKDIR /usr/src/substrate-node-template
COPY . .

# Stage for building the wasm binary
FROM base AS builder
WORKDIR /usr/src/substrate-node-template
COPY . .
RUN cargo build --release --locked

# Stage to generate chainspec (only once and remove it).
FROM base AS chainspec
RUN cargo install --locked staging-chain-spec-builder@10.0.0
WORKDIR /chain
COPY --from=builder /usr/src/substrate-node-template/target /target

# Stage for produccion container.
FROM debian:bullseye-slim AS production
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl-dev \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

#RUN curl -sSfL https://github.com/polkadot-fellows/omni/releases/download/v0.5.0/polkadot-omni-node-linux-x86_64.tar.gz | \
#    tar -xz -C /usr/local/bin

COPY --from=builder /usr/src/substrate-node-template/target/release/substrate-node-template /usr/local/bin/substrate-node-template
# COPY ./chain_spec.json /usr/local/etc/chain_spec.json

CMD ["polkadot-omni-node", "--chain", "/usr/local/etc/chain_spec.json"]
