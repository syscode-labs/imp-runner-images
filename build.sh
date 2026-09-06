#!/usr/bin/env bash
set -euo pipefail
RUNNER_VERSION="${RUNNER_VERSION:?set RUNNER_VERSION}"
RUNNER_ARCH="${RUNNER_ARCH:-x64}"
./build-runner-layer.sh
