[![ReadyStack](https://readystack.dev/logo.svg)](https://readystack.dev)

**Stable, Open-source Releases, Automated** · [readystack.dev](https://readystack.dev)

[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-readystack%2Fkubernetesvmstack-2496ED?logo=docker&logoColor=white)](https://hub.docker.com/r/readystack/kubernetesvmstack) [![Docker pulls](https://img.shields.io/docker/pulls/readystack/kubernetesvmstack)](https://hub.docker.com/r/readystack/kubernetesvmstack) [![Grade at release](https://img.shields.io/badge/grade%20at%20release-A%20%28100%25%29-2ea44f)](https://readystack.dev/products/kubernetesvmstack) [![Signed: cosign](https://img.shields.io/badge/signed-cosign-2ea44f)](https://readystack.dev/keys/cosign.pub) ![SBOM: SPDX](https://img.shields.io/badge/SBOM-SPDX-2ea44f) ![Provenance: SLSA v1](https://img.shields.io/badge/provenance-SLSA%20v1-2ea44f) ![Offline rebuild: verified](https://img.shields.io/badge/offline%20rebuild-verified-2ea44f)

# Kubernetes VM Stack: ReadyStack build kit

The offline build kit for the Docker image `readystack/kubernetesvmstack:v1.36.6-kubevirt1.9.1-CE-scratch-r3`. It holds what the image is built from (upstream source, base images, toolchain, pinned dependencies) and the documents, so the image can be rebuilt with no network access (`docker build --network=none`).

- Release: [v1.36.6-kubevirt1.9.1-CE-scratch-r3](https://github.com/readystack-dev/kubernetesvmstack/releases/tag/v1.36.6-kubevirt1.9.1-CE-scratch-r3)
- Image: [`docker.io/readystack/kubernetesvmstack:v1.36.6-kubevirt1.9.1-CE-scratch-r3`](https://hub.docker.com/r/readystack/kubernetesvmstack/tags), manifest digest `sha256:ec9e9b8a463dbe23ef50afe9b608db2b9ddc2e2a23367a6e6d788435e096b0b4`
- Product page: https://readystack.dev/products/kubernetesvmstack
- Source and build recipe: https://readystack.dev/products/kubernetesvmstack/recipe
- Build trail: https://readystack.dev/products/kubernetesvmstack/trail/v1.36.6-kubevirt1.9.1-CE-scratch-r3
- Defects: this repository's Issues (defects recorded from 25 November 2026 on) and https://readystack.dev/defects.html?product=kubernetesvmstack

## The image

Not a service: the image's filesystem is the bundle. Take it out with docker create and docker cp <container>:/kubernetesvmstack, then follow install/README.md; the operator runbook is runbook/RUNBOOK.md in the bundle, the same text as docs/admin-guide/ADMIN_HANDBOOK.md in the build kit; each image the stack installs is its own product.

## Who uses Kubernetes VM Stack and why

Teams that run a fleet of virtual machines on their own hardware and want them managed beside their containers.

Kubernetes with KubeVirt adds virtual machines to the Kubernetes API: one API and one set of manifests for virtual machines and containers, on the same cluster and nodes.

A typical use: A team has applications that still need full virtual machines and new services built as containers. On one Kubernetes cluster with KubeVirt they create, start, stop and migrate the virtual machines through the same Kubernetes API as their pods, and can move the VM workloads into containers over time.

From the upstream project's own description: https://kubevirt.io/, https://kubevirt.io/user-guide/, https://github.com/kubevirt/kubevirt, https://kubernetes.io/docs/concepts/overview/.

## This release

- Docker Scout policy grade at release: **A** (100%), graded 2026-11-09 with `docker scout policy` (CLI 1.26.0, docker-default configuration).
- Signed with ReadyStack's release key (fingerprint `04daa92344a52dbc`): https://readystack.dev/keys/cosign.pub.
- Runs as a non-root user (`65534:65534`).
- Attestations on the image: an SPDX SBOM and SLSA provenance v1.
- Rebuilt from this kit with network egress blocked on 2026-11-09; the rebuilt image digest is the published one.
- Base: scratch.

The current grade, measured again every day, is on https://readystack.dev/products/kubernetesvmstack.

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

`recipe/` holds the kit's recipe files (Dockerfiles, build scripts, pins) as published at https://readystack.dev/products/kubernetesvmstack/recipe. The complete kit is the release download. Each release is a tag here. How to report a vulnerability: [SECURITY.md](SECURITY.md).

## About ReadyStack

**Stable, Open-source Releases, Automated.** ReadyStack releases popular open-source apps every week with every available critical and high security fix applied, plus full documentation, reference data, tests and a build recipe that recreates each release bit-for-bit. Each release is rebuilt from its pinned inputs with the network off, checked against its published digest, signed, and scanned and graded again every day. The images and build kits are free, and ReadyStack is soon to be a nonprofit.

[readystack.dev](https://readystack.dev) · [All products](https://readystack.dev/products.html) · [Build kits on GitHub](https://github.com/readystack-dev) · [Defect log](https://readystack.dev/defects.html) · contact@readystack.dev

— ReadyStack · https://readystack.dev
