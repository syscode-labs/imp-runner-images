#!/usr/bin/env bash
set -euo pipefail

: "${RUNNER_VERSION:?set RUNNER_VERSION, for example 2.328.0}"
: "${RUNNER_ARCH:=x64}"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
context="$root/runner-layer"
rm -rf "$context/actions-runner"
mkdir -p "$context/actions-runner"

archive="$context/runner.tar.gz"
curl --fail --location --retry 3 \
  "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" \
  --output "$archive"
tar -xzf "$archive" -C "$context/actions-runner"
rm -f "$archive"
chmod -R a+rX "$context/actions-runner"
chmod 0755 "$context/runner"

echo "Prepared runner layer context for actions-runner ${RUNNER_VERSION} (${RUNNER_ARCH})"
