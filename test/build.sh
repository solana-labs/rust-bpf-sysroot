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
  declare url="$1/$2/$3"
  declare filename=$3
  declare wget_args=(
    "$url" -O "$filename"
    "--progress=dot:giga"
    "--retry-connrefused"
    "--read-timeout=30"
  )
  declare curl_args=(
    -L "$url" -o "$filename"
  )
  if hash wget 2>/dev/null; then
    wget_or_curl="wget ${wget_args[*]}"
  elif hash curl 2>/dev/null; then
    wget_or_curl="curl ${curl_args[*]}"
  else
    echo "Error: Neither curl nor wget were found" >&2
    return 1
  fi

  set -x
  if $wget_or_curl; then
    tar --strip-components 1 -jxf "$filename" || return 1
    { set +x; } 2>/dev/null
    rm -rf "$filename"
    return 0
  fi
  return 1
}

get() {
  declare version=$1
  declare dirname=$2
  declare job=$3
  declare cache_root=~/.cache/solana
  declare cache_dirname="$cache_root/$version/$dirname"
  declare cache_partial_dirname="$cache_dirname"_partial

  if [[ -r $cache_dirname ]]; then
    ln -sf "$cache_dirname" "$dirname" || return 1
    return 0
  fi

  rm -rf "$cache_partial_dirname" || return 1
  mkdir -p "$cache_partial_dirname" || return 1
  pushd "$cache_partial_dirname"

  if $job; then
    popd
    mv "$cache_partial_dirname" "$cache_dirname" || return 1
    ln -sf "$cache_dirname" "$dirname" || return 1
    return 0
  fi
  popd
  return 1
}

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

# Install or set up bpf-tools
version=v1.1
if [[ $# > 0 ]] && [[ -d ${1}/llvm ]] && [[ -d ${1}/stage1 ]]; then
    rm -rf bpf-tools
    mkdir bpf-tools
    ln -s ${1}/llvm bpf-tools/llvm
    ln -s ${1}/stage1 bpf-tools/rust
    touch bpf-tools-$version.md
fi
if [[ ! -e bpf-tools-$version.md || ! -e bpf-tools ]]; then
  (
    set -e
    rm -rf bpf-tools*
    rm -rf xargo
    job="download \
           https://github.com/solana-labs/bpf-tools/releases/download \
           $version \
           solana-bpf-tools-$machine.tar.bz2 \
           bpf-tools"
    get $version bpf-tools "$job"
  )
  exitcode=$?
  if [[ $exitcode -ne 0 ]]; then
    exit 1
  fi
  touch bpf-tools-$version.md
fi
set -ex
./bpf-tools/rust/bin/rustc --print sysroot
set +e
rustup toolchain uninstall bpf
set -e
rustup toolchain link bpf bpf-tools/rust

set -ex

cd ..

# Use the SDK's version of llvm to build the compiler-builtins for BPF
export CC="$PWD/dependencies/bpf-tools/llvm/bin/clang"
export AR="$PWD/dependencies/bpf-tools/llvm/bin/llvm-ar"
export OBJDUMP="$PWD/dependencies/bpf-tools/llvm/bin/llvm-objdump"
export OBJCOPY="$PWD/dependencies/bpf-tools/llvm/bin/llvm-objcopy"

# Use the SDK's version of Rust to build for BPF
export RUSTUP_TOOLCHAIN=bpf
export RUSTFLAGS="
    -C lto=no \
    -C opt-level=2 \
    -C link-arg=-z -C link-arg=notext \
    -C link-arg=-Tbpf.ld \
    -C link-arg=--Bdynamic \
    -C link-arg=-shared \
    -C link-arg=--threads=1 \
    -C link-arg=--entry=entrypoint \
    -C linker=dependencies/bpf-tools/llvm/bin/ld.lld"

# CARGO may be set if run from within cargo, causing
# incompatibilities between cargo and xargo versions
unset CARGO

export XARGO="$PWD/dependencies/bin/xargo"
export XARGO_TARGET=bpfel-unknown-unknown
export XARGO_HOME="$PWD/dependencies/xargo"
export XARGO_RUST_SRC="$PWD/../src"
export RUST_COMPILER_RT_ROOT="$PWD/../src/compiler-rt"

$PWD/dependencies/bin/xargo build --target bpfel-unknown-unknown --release

{ { set +x; } 2>/dev/null; echo Success; }
