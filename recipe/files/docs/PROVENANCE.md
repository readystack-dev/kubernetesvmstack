# Provenance — Kubernetes VM Stack (`v1.36.6-kubevirt1.9.1-CE-scratch-r3`)

Every item below is copied from a record in this archive; the record is named in brackets.

## Source

- Upstream repository: https://github.com/kubernetes/kubernetes
- Upstream release the bundle installs: `v1.36.6` (commit `1b2171b110bb2a2542e1322035c6583ec86eb976`); the image is not built from it
- Contents: the stack's install bundle (the kit's `bundle/`, every file in its SHA256SUMS) and stack-bundle, compiled from the kit's `stack-bundle.go`
- Source tree: `803692e6a7661d2d72c4cdf0a2a2459bdf6646e2b6c955ed7362f279ee4fa004` over 29206 files [`docs/provenance/SOURCE_TREE_HASH.json`] — upstream's tree at that revision, cloned for the licence and Community Edition audit; the image is not built from it
- Community Edition only: enterprise code is removed or refused before the build (CE audit at acquire).

## Build

- Method: `source-rebuild-go`; base image `scratch`
- Compiled with `--network=none` from the kit's stack-bundle.go (the one program compiled) and the vendored install bundle (copied as is), dependencies and base images; BuildKit pinned to `moby/buildkit:v0.31.2` (shipped in `toolchain/`).
- SOURCE_DATE_EPOCH: `1793102572` [`SOURCE_DATE_EPOCH.txt`]
- Frozen inputs: [`docs/provenance/FREEZE_MANIFEST.json`], build recipe: [`docs/provenance/BUILD_RECIPE.json`].

## Output

- Published image: `readystack/kubernetesvmstack:v1.36.6-kubevirt1.9.1-CE-scratch-r3` — index digest `sha256:6afdf25922ad700086b1f94bab5423395a0c1f2d64e6016933e5b1559a022a9b` [`docs/provenance/LOCKED_DIGEST.txt`]
- linux/amd64 image digest `sha256:ec9e9b8a463dbe23ef50afe9b608db2b9ddc2e2a23367a6e6d788435e096b0b4` — reproduced from this archive before publishing [`docs/provenance/REPRO_VERIFICATION.json`].

## Attestations and signature

- SBOM + SLSA provenance attached to the image: attached: an SPDX SBOM and SLSA v1 provenance [`docs/provenance/SCOUT_VERDICT.json`]
- cosign signature by the ReadyStack release key: verified before publishing. Check it: `cosign verify --key https://readystack.dev/keys/cosign.pub readystack/kubernetesvmstack:v1.36.6-kubevirt1.9.1-CE-scratch-r3`

## Pinned inputs, and why

- 7 pinned inputs, each with where it came from, why this one, how it was checked and when it was decided: `docs/PINS.md` [`docs/provenance/PINS.json`] (upstream source 2, base and build images 1, image digests 1, pins in the kit's dockerfiles 1, readystack's build engine 1, dependencies upstream chose 1).

## Build trail

- How this release passed through the ReadyStack harness, record by record (every chain, drive, stage, review round, defect and check, each naming the record it is copied from): `ReadyStack-kubernetesvmstack-v1.36.6-kubevirt1.9.1-CE-scratch-r3.trail.json`, published beside this archive and signed with the release key (`ReadyStack-kubernetesvmstack-v1.36.6-kubevirt1.9.1-CE-scratch-r3.trail.json.sigstore`), and readable at https://readystack.dev/products/kubernetesvmstack/trail/v1.36.6-kubevirt1.9.1-CE-scratch-r3.

