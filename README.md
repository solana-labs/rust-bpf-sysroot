# rust-bpf-sysroot

[![Build Status](https://travis-ci.org/solana-labs/rust-bpf-sysroot.svg?branch=master)](https://travis-ci.org/solana-labs/rust-bpf-sysroot)

Building Rust modules require a collection of standard libraries that provide the fundamentals of the Rust language.  These standard libraries include things like types and trait definitions, arithmetic operations, formatting definitions, structure definitions (slice, vec) and operations.  Typically Rust modules link in the `std` libraries which exposes the underlying operating system features like threads, display and file io, networking, etc...  

Rust modules for Solana are built as [`#![no_std]`](https://doc.rust-lang.org/1.30.0/book/first-edition/using-rust-without-the-standard-library.html) modules using the Berkley Packet Filter (BPF) ABI and run within a limited virtual machine that will not provide most of the native os features.  One reason is that program state must be recordable in the ledger with known inputs and outputs.  Things like files provide an untraceable input to the ledger, multi-threading can lead to timing differences that may result in unpredictable program output based on the same inputs.  [Rust-cross](https://github.com/japaric/rust-cross) is a good overview of cross-compiling Rust.

This repo contains only the pieces of the Rust libraries required by Solana modules, and in some cases, these pieces might include customizations required by either Solana or to be compatible with the BPF ABI.  It is the goal of this repo to be temporary, as support is added to Solana and BPF for things like unsigned division, 128-bit types, etc... Solana should be able to refer to the libraries in the Rust mainline eventually

The Solana SDK pulls this repo in as source to make it available to [xargo](https://github.com/japaric/xargo).  Xargo then builds it and uses it as the cargo sysroot for Solana modules.

You can build this repo independently of the Solana SDK in the same way that CI ensures the repo stays healthy.  The build script download's Solana's custom [LLVM](https://github.com/solana-labs/llvm-builder) and [rustc](https://github.com/solana-labs/rust-bpf-builder) binaries and updates the forked submodules.  Take a look at `build.sh` for details.  If building on Linux, ensure you are using Ubuntu 16 or newer/compatible since Solana's custom rustc is not compatible with older versions.

To build:
```bash
./build.sh
```

Notes:
- If building on Linux, ensure you are using Ubuntu 16 or newer/compatible since Solana's custom rustc is not compatible with older versions.
- src/lib.rs is only provided to enable building this repo independently of the Solana SDK; it is not built as part of the sysroot by Xargo.

