#!/usr/bin/env bash
#
# Reference: https://github.com/koalaman/shellcheck/wiki/Directive
set -e

cd "$(dirname "$0")"

set -x
docker pull koalaman/shellcheck
find . -name "*.sh" \
       -not -regex ".*/target/.*" \
       -not -regex ".*/compiler-builtins/.*" \
       -not -regex ".*/stdsimd/.*" \
    -print0 \
  | xargs -0 \
      docker run --workdir /rust-bpf-sysroot --volume "$PWD:/rust-bpf-sysroot" --rm koalaman/shellcheck --color=always --external-sources --shell=bash

exit 0
