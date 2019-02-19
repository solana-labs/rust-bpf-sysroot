#!/usr/bin/env bash

set -x

cargo install xargo

set -e

rustup override set bpf

git submodule init
git submodule update

export XARGO_HOME="$PWD/target/rust-sysroot"
export XARGO_RUST_SRC="$PWD/src"
xargo build --target bpfel_unknown_unknown --release -v

# Don't need x86 stuff
rm -rf ./target/rust-sysroot/lib/rustlib/x86_64-apple-darwin

{ { set +x; } 2>/dev/null; echo Success; }