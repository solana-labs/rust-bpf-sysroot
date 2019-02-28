#!/usr/bin/env bash

set -ex

if [[ "$(uname)" = Darwin ]]; then
  machine=osx
  triple=x86_64-apple-darwin
else
  machine=linux
  triple=x86_64-unknown-linux-gnu
fi

# Install LLVM
version=v0.0.8
if [[ ! -f deps/llvm-native-$machine-$version.md ]]; then
  (
    filename=solana-llvm-$machine.tar.bz2

    set -ex
    rm -rf deps/llvm-native*
    mkdir -p deps/llvm-native
    cd deps/llvm-native
    wget --progress=dot:giga https://github.com/solana-labs/llvm-builder/releases/download/$version/$filename
    tar -jxf $filename
    rm -rf $filename

    echo "https://github.com/solana-labs/llvm-builder/releases/tag/$version" > ../llvm-native-$machine-$version.md
  )
  exitcode=$?
  if [[ $exitcode -ne 0 ]]; then
    rm -rf llvm-native
    exit 1
  fi
fi

# Install Rust BPF
version=v0.0.2
if [[ ! -f deps/rust-bpf-$machine-$version.md ]]; then
  (
    filename=solana-rust-bpf-$machine.tar.bz2

    set -ex
    rm -rf deps/rust-bpf
    rm -rf deps/rust-bpf-$machine-*
    mkdir -p deps/rust-bpf
    pushd deps/rust-bpf
    wget --progress=dot:giga https://github.com/solana-labs/rust-bpf-builder/releases/download/$version/$filename
    tar -jxf $filename
    rm -rf $filename

    set +e
    rustup toolchain uninstall bpfsysroot
    set -e
    rustup toolchain link bpfsysroot ../rust-bpf
    rustup override set bpfsysroot

    echo "https://github.com/solana-labs/rust-bpf-builder/releases/tag/$version" > ../rust-bpf-$machine-$version.md
  )
  exitcode=$?
  if [[ $exitcode -ne 0 ]]; then
    rm -rf rust-bpf
    exit 1
  fi  
fi

set +e
cargo install xargo
set -e

git submodule init
git submodule update

export RUSTFLAGS="$RUSTFLAGS \
    -C lto=no -C opt-level=2 \
    -C link-arg=-Tbpf.ld \
    -C link-arg=-z -C link-arg=notext \
    -C link-arg=--Bdynamic \
    -C link-arg=-shared \
    -C link-arg=--entry=entrypoint \
    -C linker=deps/llvm-native/bin/ld.lld"

export XARGO_HOME="$PWD/target/xargo"
export XARGO_RUST_SRC="$PWD/src"
xargo build --target bpfel-unknown-unknown --release -v

{ { set +x; } 2>/dev/null; echo Success; }