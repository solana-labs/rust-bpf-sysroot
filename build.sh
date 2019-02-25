#!/usr/bin/env bash

set -ex

if [[ "$(uname)" = Darwin ]]; then
  machine=osx
  triple=x86_64-apple-darwin
else
  machine=linux
  triple=x86_64-unknown-linux-gnu
fi

# Install Rust BPF
version=v0.0.1
if [[ ! -f rust-bpf-$machine-$version.md ]]; then
  (
    filename=solana-rust-bpf-$machine.tar.bz2

    set -ex
    rm -rf rust-bpf*
    mkdir -p rust-bpf
    pushd rust-bpf
    wget --progress=dot:giga https://github.com/solana-labs/rust-bpf-builder/releases/download/$version/$filename
    # cp ../../../hack/rust-bpf-builder/deploy/$filename .
    tar -jxf $filename
    rm -rf $filename
    echo "https://github.com/solana-labs/rust-bpf-builder/releases/tag/$version" > ../rust-bpf-$machine-$version.md
    popd
  )
  exitcode=$?
  if [[ $exitcode -ne 0 ]]; then
    rm -rf rust-bpf
    exit 1
  fi
fi

set +e
cargo install xargo
rustup toolchain uninstall bpfsysroot
set -e
rustup toolchain link bpfsysroot rust-bpf
rustup override set bpfsysroot

git submodule init
git submodule update

export XARGO_HOME="$PWD/target/rust-sysroot"
export XARGO_RUST_SRC="$PWD/src"
xargo build --target bpfel_unknown_unknown --release -v

# Don't need x86 stuff
rm -rf ./target/rust-sysroot/lib/rustlib/"$triple"

# Tar for release
pushd target
tar -C ./rust-sysroot -jcf solana-rust-bpf-sysroot.tar.bz2 .
popd

{ { set +x; } 2>/dev/null; echo Success; }