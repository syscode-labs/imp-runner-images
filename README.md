# Imp runner images

This repository publishes the two OCI inputs used to build an Imp
Firecracker runner rootfs:

- `base`: Debian slim with the runtime packages and `/usr/local/bin/runner`
  as its container command.
- `runner-layer`: the official GitHub Actions runner release plus the
  `/usr/local/bin/runner` wrapper.

Imp composes the filesystem layers before creating the ext4 guest rootfs. The
base image must remain a normal distro rootfs with `/sbin/init`; the runner
layer is filesystem content only.

## Build locally

```sh
RUNNER_VERSION=<actions-runner-version> ./build-runner-layer.sh

docker buildx build --platform linux/amd64 \
  -t ghcr.io/syscode-labs/imp-runner-base:<tag> base/ \
  --load

docker buildx build --platform linux/amd64 \
  -t ghcr.io/syscode-labs/imp-runner-layer:<tag> runner-layer/ \
  --load
```

The JIT payload is supplied by Imp through `IMP_GITHUB_JITCONFIG` at guest
runtime. It is not part of either image and must not be put in a Dockerfile,
image label, command line, or log.

The first production target is amd64. Add arm64 only after the runner release
and the composite Firecracker rootfs pass the same boot and registration smoke
tests.
