#!/usr/bin/env bash

set -x
set -e

rustup default bpf2
export XARGO_HOME=./target/rust-sysroot
export XARGO_RUST_SRC=/Users/jack/workbench/hack/rust_bpf_sysroot/rust-src
xargo build --target bpfel_unknown_unknown --release -v

cp -rf ./target/rust-sysroot ../../active/solana/sdk/bpf/

{ { set +x; } 2>/dev/null; echo Success; }