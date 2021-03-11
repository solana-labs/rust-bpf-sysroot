# rust-bpf-sysroot

[![Build Status](https://travis-ci.org/solana-labs/rust-bpf-sysroot.svg?branch=master)](https://travis-ci.org/solana-labs/rust-bpf-sysroot)

Rust sysroot source for Berkley Packet Filter Rust programs

Contains submodules, to sync use:

``` bash
git clone --recurse-submodules
```

---

Building Rust modules require a collection of standard libraries that
provide the fundamentals of the Rust language.  These standard
libraries include things like types and trait definitions, arithmetic
operations, formatting definitions, structure definitions (slice, vec)
and operations.  Typically Rust modules link in the `std` libraries
which expose the underlying operating system features like threads,
display and file io, networking, etc.

Rust modules for Solana are built using the Berkley Packet Filter
(BPF) ABI and run within a limited virtual machine that will not
provide most of the native OS features.  One reason is that program
state must be recordable in the ledger with known inputs and outputs.
Things like files provide an untraceable input to the ledger,
multi-threading can lead to timing differences that may result in
unpredictable program output based on the same inputs.
[Rust-cross](https://github.com/japaric/rust-cross) is a good overview
of cross-compiling Rust.

This repo contains only the pieces of the Rust libraries required by
Solana modules, and in some cases, these pieces might include
customizations required by either Solana or to be compatible with the
BPF ABI.  It is the goal of this repo to be temporary, as support is
added to Solana and BPF for things like unsigned division, 128-bit
types, etc. Solana should be able to refer to the libraries in the
Rust mainline eventually.

The Solana SDK pulls this repo in as source to make it available to
[xargo](https://github.com/japaric/xargo).  Xargo then builds and uses
it as the cargo sysroot for Solana modules.

You can build this repo independently of the Solana SDK in the same
way that CI ensures the repo stays healthy.  The build script
downloads Solana's custom [rustc and
clang](https://github.com/solana-labs/bpf-tools) binaries and updates
the forked submodules.  Take a look at
[`test/build.sh`](https://github.com/dmakarov/rust-bpf-sysroot/blob/master/test/build.sh)
for details.

To build the test:
``` bash
./test/build.sh
```

Notes:
- If building on Linux, ensure you are using Ubuntu 18 or newer since
  Solana's custom rustc is not compatible with older versions.
- `src/lib.rs` is only provided to enable building this repo
  independently of the Solana SDK; it is not built as part of the
  sysroot by Xargo.

Upgrading Solana BPF toolchain
------------------------------

Rust-bpf-sysroot is an essential part of Solana Rust/Clang/LLVM BPF
toolchain. Whenever the toolchain is upraded to a new version of
rust/clang/llvm, rust-bpf-sysroot must be upgraded to match the
changes in the Rust/Clang/LLVM compilers. The following is an outline
and checklist of the upgrade process

1. Upgrade the compilers

    - choose the version of
      [rust-lang/rust](https://github.com/rust-lang/rust/tags) to upgrade
      the toolchain to.
    - upgrade
      [solana-labs/llvm-project](https://github.com/solana-labs/llvm-project)
      to the version of
      [rust-lang/llvm-project](https://github.com/rust-lang/llvm-project)
      that corresponds to the selected rust-lang/rust version.
    - upgrade [solana-labs/rust](https://github.com/solana-labs/rust) to
      the chosen version of
      [rust-lang/rust](https://github.com/rust-lang/rust).
    - build the compiler binaries and keep them available.

2. Upgrade rust-bpf-sysroot submodules

    rust-bpf-sysroot includes 4 submodules
    - Solana forks
      - [solana-labs/cfg-if](https://github.com/solana-labs/cfg-if) of [alexcrichton/cfg-if](https://github.com/alexcrichton/cfg-if)
      - [solana-labs/compiler-builtins](https://github.com/solana-labs/compiler-builtins)
        of [rust-lang/compiler-builtins](https://github.com/rust-lang/compiler-builtins)
      - [solana-labs/hashbrown](https://github.com/solana-labs/hashbrown)
        of [rust-lang/hashbrown](https://github.com/rust-lang/hashbrown)
    - [rust-lang/stdarch](https://github.com/rust-lang/stdarch)

    Check which version of each submodule is used by the chosen
    version of [rust-lang/rust](https://github.com/rust-lang/rust) and
    update Solana's forks and bump the version of
    [rust-lang/stdarch](https://github.com/rust-lang/stdarch) in
    [`src`](https://github.com/solana-labs/rust-bpf-sysroot/tree/master/src)
    subdirectory. The versions required by rust-lang/rust can be
    checked in
    [rust-lang/rust/libraries/std/Cargo.toml](https://github.com/rust-lang/rust/blob/master/library/std/Cargo.toml).

    If a Solana fork submodule is updated it is better to postpone
    committing the updated submodule to its Solana repository until
    the upgrade of
    [solana-labs/rust-bpf-sysroot](https://github.com/solana-labs/rust-bpf-sysroot)
    is finalized. In `solana-labs/rust-bpf-sysroot/src/<submodule>`
    pull from your fork of the submodule the branch that contains the
    version of the submodule with the Solana specific changes. When
    the updates to rust-bpf-sysroot are finalized the changes to the
    submodules must be committed to their corresponding solana-labs
    repositories.

3. Upgrade rust-bpf-sysroot

   - pull the latest master of
     [solana-labs/rust-bpf-sysroot](https://github.com/solana-labs/rust-bpf-sysroot)
   - copy the subdirectories of `solana-labs/rust-bpf-sysroot/src`
     which are not submodules from the corresponding subidrectories of
     updated `solana-labs/rust/libraries`, overwriting the contents of
     these subdirectories. The directories are
     - `alloc`
     - `core`
     - `panic_abort`
     - `rustc-std-workspace-alloc`
     - `rustc-std-workspace-core`
     - `std`
     - `unwind`
     - `compiler-rt` is copied from `solana-labs/llvm-project/compiler-rt`.
   - commit the changes with the commit message "_Pull in Rust 1.XX
     changes_" where _XX_ is the chosen version of rust-lang/rust. Note
     the committed changes should be only what was copied from
     `solana-labs/rust/libraries` and
     `solana-labs/llvm-project/compiler-rt`. Thus we can keep the
     local changes in separate commits, which should make subsequents
     upgrades manageable.
   - cherry-pick the commits starting from the commit following the
     previous commit with the commit message "_Pull in Rust 1.XX
     changes_" and reapply them on top of the just committed new _Pull
     in Rust 1.XX changes_ commit. Note, that some commits in the
     history will not have changes in the libraries source files. Such
     commits must not be cherry-picked and applied. To make this
     process manageable, commits must never mix changes to files in
     libraries with any other changes. The description line of commits
     that modify libraries files should have the prefix _[SOL]_ and
     other commits should not have such prefix to clearly distinguish
     betweeen the commits that need to be cherry-picked.
   - after reapplying all Solana specific changes on top of the
     updated libraries source files, start building the source tree,
     by running the script `./test/build.sh`. Make sure to build the
     tree using the updated compiler binaries from the step 1. An easy
     way to use a custom compiler binaries is to create a subdirectory
     `bpf-tools` in the directory `rust-bpf-sysroot/test/dependencies`
     and in `bpf-tools` create two symbolic links, e.g.
     ``` bash
     ln -s <path to solana-labs/rust>/build/x86_64-apple-darwin/llvm llvm
     ln -s <path to solana-labs/rust>/build/x86_64-apple-darwin/stage1 rust
     ```
     Fix any build errors, and compiler warnings.
   - build and run `solana-labs/solana/programs/bpf` using the new
     rust-bpf-sysroot and the new rust/clang compilers. To use the new
     rust-bpf-sysroot redirect the symbolic link `rust-bpf-sysroot` in
     `<path to solana-labs/solana>/sdk/bpf/dependencies/` to `<path to
     solana-labs/rust-bpf-sysroot>`. When all tests build and run
     successfully
        - commit updated submodules to their corresponding repositories,
        - commit changes that had to be done in libraries source files
          with the description line prefixed with _[SOL]_ tag,
        - make a new release branch of rust-bpf-sysroot,
        - make a new release of
          [solana-labs/bpf-tools](https://github.com/solana-labs/bpf-tools)
          that contains the tarball packages with the new compiler binaries.
   - update
     [`solana-labs/solana/sdk/bpf/scripts/install.sh`](https://github.com/solana-labs/solana/blob/master/sdk/bpf/scripts/install.sh)
     to install the new version of compiler binaries and
     rust-bpf-sysroot source tree for the Solana SDK. Other files that
     may have to be updated are
     - `solana-labs/solana/sdk/bpf/env.sh`
     - `solana-labs/solana/sdk/bpf/scripts/{dump.sh,objcopy.sh,strip.sh}`
     - `solana-labs/solana/sdk/bpd/c/{bpf.ld,bpf.mk}`
     - `solana-labs/solana/sdk/bpd/rust/bpf.ld`
   - update this file with any corrections and changes to the upgrade
     process.
