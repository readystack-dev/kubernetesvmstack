# Kubernetes VM Stack: ReadyStack build kit

The offline build kit for the Docker image `readystack/kubernetesvmstack:v1.36.6-kubevirt1.9.1-CE-scratch-r3`. It holds what the image is built from (upstream source, base images, toolchain, pinned dependencies) and the documents, so the image can be rebuilt with no network access (`docker build --network=none`).

- Release: [v1.36.6-kubevirt1.9.1-CE-scratch-r3](https://github.com/readystack-dev/kubernetesvmstack/releases/tag/v1.36.6-kubevirt1.9.1-CE-scratch-r3)
- Image: [`docker.io/readystack/kubernetesvmstack:v1.36.6-kubevirt1.9.1-CE-scratch-r3`](https://hub.docker.com/r/readystack/kubernetesvmstack/tags), manifest digest `sha256:ec9e9b8a463dbe23ef50afe9b608db2b9ddc2e2a23367a6e6d788435e096b0b4`
- Product page: https://readystack.dev/products/kubernetesvmstack
- Defects: this repository's Issues (defects recorded from 25 November 2026 on) and https://readystack.dev/defects.html?product=kubernetesvmstack

Kubernetes VM Stack is distributed under its upstream licence (Apache-2.0); the kit contains upstream's source under that licence, and each vendored component under its own.

## Download

From the [v1.36.6-kubevirt1.9.1-CE-scratch-r3 release](https://github.com/readystack-dev/kubernetesvmstack/releases/tag/v1.36.6-kubevirt1.9.1-CE-scratch-r3): `ReadyStack-kubernetesvmstack-v1.36.6-kubevirt1.9.1-CE-scratch-r3.tar.gz` (427.0 MB), SHA-256 `2f26ed35b1711f1f9918cacdd5962f4235c6e11d01db12944aad8c733357caed`.

```sh
sha256sum --check --ignore-missing SHA256SUMS
```

## Verify and rebuild

The rebuild statement is signed with the ReadyStack release key. Check the signature before you rely on it:

```sh
cosign verify-blob --key https://readystack.dev/keys/cosign.pub \
  --bundle ReadyStack-kubernetesvmstack-v1.36.6-kubevirt1.9.1-CE-scratch-r3.rebuild.json.sigstore ReadyStack-kubernetesvmstack-v1.36.6-kubevirt1.9.1-CE-scratch-r3.rebuild.json
```

Unpack with `-p` so file modes are kept, then follow the kit's own README.md and docs/REBUILD.md:

```sh
tar -xpzf ReadyStack-kubernetesvmstack-v1.36.6-kubevirt1.9.1-CE-scratch-r3.tar.gz
cd v1.36.6-kubevirt1.9.1-CE-scratch-r3
less README.md docs/REBUILD.md
```

The build trail (`ReadyStack-kubernetesvmstack-v1.36.6-kubevirt1.9.1-CE-scratch-r3.trail.json`, signed the same way, and its Markdown copy) records how this release was built and checked.

## This repository

`recipe/` holds the kit's recipe files (Dockerfiles, build scripts, pins) as published at https://readystack.dev/products/kubernetesvmstack/recipe. The complete kit is the release download. Each release is a tag here.
