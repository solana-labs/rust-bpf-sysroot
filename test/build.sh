#!/usr/bin/env bash

cd "$(dirname "$0")"

rm -rf target
rm -rf dependencies
mkdir -p dependencies
cd dependencies

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
version=0.3.22
if [[ ! -e xargo-$version.md ]] || [[ ! -x bin/xargo ]]; then
  (
    args=()
    # shellcheck disable=SC2154
    if [[ -n $rust_stable ]]; then
      args+=(+"$rust_stable")
    fi
    args+=(install xargo --version "$version" --root .)
    set -ex
    cargo "${args[@]}"
  )
  exitcode=$?
  if [[ $exitcode -ne 0 ]]; then
    exit 1
  fi
  ./bin/xargo --version >xargo-$version.md 2>&1
fi

# Install LLVM
version=v0.0.15
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
version=v0.2.5
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

git submodule update --init --recursive

# Use the SDK's version of llvm to build the compiler-builtins for BPF
export CC="$PWD/dependencies/llvm-native/bin/clang"
export AR="$PWD/dependencies/llvm-native/bin/llvm-ar"
export OBJDUMP="$PWD/dependencies/llvm-native/bin/llvm-objdump"
export OBJCOPY="$PWD/dependencies/llvm-native/bin/llvm-objcopy"

# Use the SDK's version of Rust to build for BPF
export RUSTUP_TOOLCHAIN=bpfsysroot
export RUSTFLAGS="
    -C lto=no \
    -C opt-level=2 \
    -C link-arg=-z -C link-arg=notext \
    -C link-arg=-Tbpf.ld \
    -C link-arg=--Bdynamic \
    -C link-arg=-shared \
    -C link-arg=--entry=entrypoint \
    -C link-arg=-no-threads \
    -C linker=dependencies/llvm-native/bin/ld.lld"

# CARGO may be set if run from within cargo, causing
# incompatibilities between cargo and xargo versions
unset CARGO

export XARGO="$PWD/dependencies/bin/xargo"
export XARGO_TARGET=bpfel-unknown-unknown
export XARGO_HOME="$PWD/dependencies/xargo"
export XARGO_RUST_SRC="$PWD/../src"
export RUST_COMPILER_RT_ROOT="$PWD/../src/compiler-rt"


xargo build --target bpfel-unknown-unknown --release

{ { set +x; } 2>/dev/null; echo Success; }