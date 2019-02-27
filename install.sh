#!/usr/bin/env bash

set -x
set -e

rm -rf ../../active/solana/sdk/bpf/rust-sysroot
cp -rf ./target/rust-sysroot/ ../../active/solana/sdk/bpf/rust-bpf-sysroot

{ { set +x; } 2>/dev/null; echo Success; }