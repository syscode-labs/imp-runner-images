#!/usr/bin/env bash
# Focused host-container smoke only. It does not boot a composite Imp rootfs or
# a Firecracker guest.
set -euo pipefail

BASE_IMAGE="${BASE_IMAGE:-}"
RUNNER_IMAGE="${RUNNER_IMAGE:-}"

usage() {
  echo "usage: BASE_IMAGE=<image> RUNNER_IMAGE=<image> $0" >&2
  exit 2
}

fail() {
  echo "smoke failure: $*" >&2
  exit 1
}

[[ -n "$BASE_IMAGE" && -n "$RUNNER_IMAGE" ]] || usage

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
wrapper="$repo_root/runner-layer/runner"

# Keep this check explicit: a JIT config is consumed by config.sh once, then
# removed before the long-running runner process starts. Do not expose it in
# trace output, image metadata, or wrapper output.
grep -Fqx './config.sh --jitconfig "$IMP_GITHUB_JITCONFIG" --unattended' "$wrapper" \
  || fail "wrapper does not configure from IMP_GITHUB_JITCONFIG"
grep -Fqx 'unset IMP_GITHUB_JITCONFIG' "$wrapper" \
  || fail "wrapper retains the JIT config after configuration"
grep -Fqx 'exec ./run.sh' "$wrapper" \
  || fail "wrapper does not exec the runner"
grep -Fqx 'export RUNNER_ALLOW_RUNASROOT=1' "$wrapper" \
  || fail "wrapper does not support root execution"
! grep -Eq '(^|[[:space:]])set[[:space:]].*x|echo.*IMP_GITHUB_JITCONFIG|printf.*IMP_GITHUB_JITCONFIG' "$wrapper" \
  || fail "wrapper could log the JIT config"

# The base image is the executable environment after Imp composes the runner
# layer. These checks prove the needed tools, CA trust, DNS, and HTTPS reach
# the host-container network; they are not a Firecracker boot assertion.
docker image inspect "$BASE_IMAGE" >/dev/null
docker run --rm --user 0:0 --entrypoint /bin/bash "$BASE_IMAGE" -ec '
  test -x /usr/bin/git
  test -r /etc/ssl/certs/ca-certificates.crt
  test -d /sys/class/net/eth0
  getent hosts github.com >/dev/null
  git ls-remote https://github.com/actions/runner.git HEAD >/dev/null
  curl --fail --silent --show-error --head https://github.com >/dev/null
'

# Inspect the OCI image contents rather than trusting its Dockerfile. The
# runner layer is scratch, so image save is used instead of docker run.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
docker image save "$RUNNER_IMAGE" -o "$tmp/runner-image.tar"
tar -xf "$tmp/runner-image.tar" -C "$tmp"
layer="$(python3 - "$tmp/manifest.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as manifest:
    print(json.load(manifest)[0]["Layers"][-1])
PY
)"
tar -tvf "$tmp/$layer" | grep -Eq '^-rwxr-xr-x .* usr/local/bin/runner$' \
  || fail "runner image lacks an executable /usr/local/bin/runner"
tar -xOf "$tmp/$layer" usr/local/bin/runner >"$tmp/image-runner"
cmp -s "$wrapper" "$tmp/image-runner" || fail "runner image wrapper differs from source"

# Exercise the wrapper as root with a harmless synthetic JIT value. The fake
# runner verifies argument order and that JIT data is absent from run.sh's env;
# no real registration payload is printed or persisted.
mkdir -p "$tmp/actions-runner"
cat >"$tmp/actions-runner/config.sh" <<'CONFIG'
#!/usr/bin/env bash
set -euo pipefail
[[ "${RUNNER_ALLOW_RUNASROOT:-}" == 1 ]]
[[ "$#" == 3 && "$1" == --jitconfig && "$2" == "$EXPECTED_JITCONFIG" && "$3" == --unattended ]]
printf 'config-ok\n'
CONFIG
cat >"$tmp/actions-runner/run.sh" <<'RUN'
#!/usr/bin/env bash
set -euo pipefail
[[ -z "${IMP_GITHUB_JITCONFIG+x}" ]]
[[ "${RUNNER_ALLOW_RUNASROOT:-}" == 1 ]]
printf 'run-ok\n'
RUN
chmod 0755 "$tmp/actions-runner/config.sh" "$tmp/actions-runner/run.sh"
output="$(docker run --rm --user 0:0 \
  --mount "type=bind,src=$tmp/actions-runner,dst=/home/runner/actions-runner,readonly" \
  --mount "type=bind,src=$wrapper,dst=/usr/local/bin/runner,readonly" \
  -e IMP_GITHUB_JITCONFIG=synthetic-jit-smoke-value \
  -e EXPECTED_JITCONFIG=synthetic-jit-smoke-value \
  --entrypoint /usr/local/bin/runner "$BASE_IMAGE")"
[[ "$output" == $'config-ok\nrun-ok' ]] || fail "wrapper root execution failed"

echo "smoke passed: wrapper/root execution, runner image executable, and base CA/git HTTPS/DNS/eth0 prerequisites"
