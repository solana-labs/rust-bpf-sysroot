#!/usr/bin/env bash

mkdir -p "$(dirname "$0")"/dependencies
cd "$(dirname "$0")"/dependencies

if [[ "$(uname)" = Darwin ]]; then
  machine=osx
else
  machine=linux
fi

download() {
  declare url=$1
  declare filename=$2
  declare progress=$3

  declare args=(
    "$url" -O "$filename"
    "--progress=dot:$progress"
    "--retry-connrefused"
    "--read-timeout=30"
  )
  wget "${args[@]}"
}

if [[ "$(uname)" = Darwin ]]; then
  machine=osx
else
  machine=linux
fi

# Install xargo
if [[ ! -r xargo.md ]]; then
  cargo install xargo
  xargo --version > xargo.md 2>&1
fi

# Install LLVM
version=v0.0.10
if [[ ! -f llvm-native-$machine-$version.md ]]; then
  (
    filename=solana-llvm-$machine.tar.bz2

    set -ex
    rm -rf llvm-native*
    rm -rf xargo
    mkdir -p llvm-native
    cd llvm-native

    base=https://github.com/solana-labs/llvm-builder/releases
    download $base/download/$version/$filename $filename giga
    tar -jxf $filename
    rm -rf $filename

    echo "$base/tag/$version" > ../llvm-native-$machine-$version.md
  )
  exitcode=$?
  if [[ $exitcode -ne 0 ]]; then
    rm -rf llvm-native
    exit 1
  fi
fi

# Install Rust-BPF
version=v0.1.2
if [[ ! -f rust-bpf-$machine-$version.md ]]; then
  (
    filename=solana-rust-bpf-$machine.tar.bz2

    set -ex
    rm -rf rust-bpf
    rm -rf rust-bpf-$machine-*
    rm -rf xargo
    mkdir -p rust-bpf
    pushd rust-bpf

    base=https://github.com/solana-labs/rust-bpf-builder/releases
    download $base/download/$version/$filename $filename giga
    tar -jxf $filename
    rm -rf $filename
    popd

    set -ex
    ./rust-bpf/bin/rustc --print sysroot

    set +e
    rustup toolchain uninstall bpfsysroot
    set -e
    rustup toolchain link bpfsysroot rust-bpf

    echo "$base/tag/$version" > rust-bpf-$machine-$version.md
  )
  exitcode=$?
  if [[ $exitcode -ne 0 ]]; then
    rm -rf rust-bpf
    exit 1
  fi
fi

set -ex

cd ..

git submodule init
git submodule update

export RUSTFLAGS="
    -C lto=no \
    -C opt-level=2 \
    -C link-arg=-Tbpf.ld \
    -C link-arg=-z -C link-arg=notext \
    -C link-arg=--Bdynamic \
    -C link-arg=-shared \
    -C link-arg=--entry=entrypoint \
    -C linker=dependencies/llvm-native/bin/ld.lld"

export XARGO_HOME="$PWD/target/xargo"
export XARGO_RUST_SRC="$PWD/src"
export RUSTUP_TOOLCHAIN=bpfsysroot
xargo build --target bpfel-unknown-unknown --release

{ { set +x; } 2>/dev/null; echo Success; }