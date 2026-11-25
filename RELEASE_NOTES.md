# Kubernetes VM Stack v1.36.6-kubevirt1.9.1 — ReadyStack release `v1.36.6-kubevirt1.9.1-CE-scratch-r3`

Generated 2026-11-09 from this release's build records and strategy. Statements that come from a single record name it in brackets; the others come from this release's strategy and build log.

## Release

- **Image:** `readystack/kubernetesvmstack:v1.36.6-kubevirt1.9.1-CE-scratch-r3` (linux/amd64). Index digest `sha256:6afdf25922ad700086b1f94bab5423395a0c1f2d64e6016933e5b1559a022a9b` [`docs/provenance/LOCKED_DIGEST.txt`].
- **Image manifest digest:** `sha256:ec9e9b8a463dbe23ef50afe9b608db2b9ddc2e2a23367a6e6d788435e096b0b4` [`TARGET_DIGEST.txt`].
- **Upstream:** Kubernetes VM Stack v1.36.6-kubevirt1.9.1, the install bundle of a cluster made of upstream's releases (`v1.36.6` of https://github.com/kubernetes/kubernetes and the component images in install/images.tsv, each its own ReadyStack release); this image compiles none of upstream's code: its one program, stack-bundle, is compiled from the kit's stack-bundle.go — upstream notes: https://github.com/kubernetes/kubernetes/releases/tag/v1.36.6 [`docs/provenance/BUILD_RECIPE.json`].
- **Build:** `source-rebuild-go`, compiled offline with `--network=none`.
- **Supersedes:** ReadyStack release `v1.36.6-kubevirt1.9.1-CE-scratch-r2`.

## What changed in this release

- Upstream version unchanged (v1.36.6-kubevirt1.9.1); ReadyStack rebuild.
- Kubernetes VM Stack v1.36.6-kubevirt1.9.1 is the same stack as the release this supersedes (v1.36.6-kubevirt1.9.1-CE-scratch-r2): Kubernetes v1.36.6 with KubeVirt v1.9.1, the same install steps, settings and operator runbook. Changes: the install bundle and the pin manifest now pin each component's newest published release, by its linux/amd64 image digest (install/images.tsv; the tags in install/controlplane/IMAGES.md, install/kubevirt/README.md and kubevirt-stack.json): kubernetesnode, kubeapiserver, kubecontrollermanager, kubescheduler and kubeproxy v1.36.6 from r1 to r2; etcd v3.7.3 from r1 to r2; coredns v1.14.2 from r1 to r2; kubevip v1.3.1 from r1 to r2; flannel v0.28.10 from r1 to r2; multuscni from v4.3.1-CE-ubuntu24.04-r1 to v4.3.2-CE-ubuntu24.04-r1 (Multus 4.3.2); virtoperator, virtapi, virtcontroller, virtexportproxy, virthandler and virtlauncher v1.9.1 from r1 to r2; virtctl v1.9.1 from r1 to r2. pause 3.10.2 and flannelcniplugin v1.9.1-flannel3 stay at r1, their newest releases. What the moves fix: golang.org/x/net v0.62.0 (GO-2026-6860, CVE-2026-78661, high; GO-2026-6866, CVE-2026-97045, medium) in kubernetesnode, the four control-plane images, coredns, kubevip, flannel, multuscni, the six KubeVirt images and virtctl; github.com/klauspost/compress v1.20.2 (GO-2026-6865, CVE-2026-116591, high) in kubernetesnode, etcd and coredns; Ubuntu's apt and libapt-pkg6.0t64 2.8.4ubuntu0.1 (CVE-2026-109518, high) in kube-apiserver, kube-controller-manager, kube-scheduler, kube-proxy and flannel, and libpcre2-8-0 10.42-4ubuntu2.2 (CVE-2026-86145, CVE-2026-89156, CVE-2026-89157, CVE-2026-89158 and three more, medium) in the four control-plane images; Multus 4.3.2 takes google.golang.org/grpc v1.83.2 (CVE-2026-84445, CVE-2026-84304). virtlauncher r2, like r1 not listed on readystack.dev, ships with glibc CVE-2026-86805 and CVE-2026-95818 disclosed in its release's scan record (docs/provenance/SCAN_GRADE.json): its glibc is 2.34-277.el9, the build KubeVirt's package lock pins, and CentOS Stream 9 fixed both in 2.34-286.el9 after that lock. Each component's own release notes say what else changed. etcd r2 runs on a chiselled Ubuntu 24.04 runtime: etcd, etcdctl and etcdutl are those of r1, and the image has no bash, curl, grep, ls or id (the runbook runs only etcdctl and etcdutl in it). install/network/multus-daemonset.yml is now Multus 4.3.2's manifest, which adds priorityClassName: system-node-critical to the DaemonSet. The operator runbook and the record of its integration-cluster run (runbook/RUNBOOK.md, runbook/RUNBOOK_EVIDENCE.json) are r2's, recorded on the integration cluster on 2026-10-29 with the component images of then: the image digests it shows are those. This release's bundle was installed and checked on the integration cluster on 2026-11-09 with exactly these images, pulled from Docker Hub through the local registry with the cluster's egress locked: three control-plane nodes, kube-vip failover, signatures and attestations of every image, KubeVirt with a VM running on KVM, its console and its bridge address; every check passed (test/evidence/2026-11-09/acceptance).

## Security status at release (measured 2026-11-09)

- **Docker Scout:** 0 fixable critical/high vulnerabilities; runs as `65534:65534` (non-root); SBOM + provenance attestations present (SPDX SBOM + SLSA v1) [`docs/provenance/SCOUT_VERDICT.json`].
- **OSV cross-check:** no fixable critical/high vulnerability beyond Docker Scout's findings.
- **Signature:** cosign signature verified by ReadyStack's release gate before publishing; check it yourself with `cosign verify --key https://readystack.dev/keys/cosign.pub readystack/kubernetesvmstack:v1.36.6-kubevirt1.9.1-CE-scratch-r3` (signatures are recorded in the public Sigstore transparency log).
- **ReadyStack release check at release:** passed (ReadyStack's own test, not a Docker Scout grade). Vulnerabilities are disclosed every day and the image never changes, so it is re-checked daily, beside Docker Scout's own dated grade, at https://readystack.dev/queue.
- **Before installing the stack:** The registry credential, the bootstrap token and the certificate key live in root-only files on the admin machine and the nodes; the runbook's commands name those files and redact the secrets in the outputs shown, but kubeadm init and kubeadm init phase upload-certs print the certificate key (and init the join command with the token) to the terminal, so run them where no one else can read the output.
- **Before installing the stack:** An etcd snapshot holds every Secret of the cluster: keep it root-only wherever it is copied.

## Reproducibility

Rebuilds offline from this archive to the identical image digest `sha256:ec9e9b8a463dbe23ef50afe9b608db2b9ddc2e2a23367a6e6d788435e096b0b4`: run `./BUILD_OFFLINE.sh`, then `./VERIFY_OFFLINE.sh` (add `--online` to confirm the Docker Hub tag holds the same digest). Before publishing, ReadyStack rebuilt the kit with `./BUILD_OFFLINE.sh` and compared the result with the published digest [`docs/provenance/REPRO_VERIFICATION.json`], then ran `./BUILD_OFFLINE.sh` and `./VERIFY_OFFLINE.sh` from this archive (without `--online`).

## Validation

- 69 of 69 runbook checks passed (69 authored) on the stack's integration cluster, recorded 2026-10-29T02:34:55Z [`docs/validation/test-results.json`, from the run's record `docs/stack/RUNBOOK_EVIDENCE.json`]. They are the checks of the stack's operator runbook that name this component; no container of this image was started on its own for them. The record does not show this release's image (`sha256:ec9e9b8a463dbe23ef50afe9b608db2b9ddc2e2a23367a6e6d788435e096b0b4`) in that run: it lists the component's images as they were then, an earlier build or a tag, so the checks describe the component, not this digest.
- Failed cases are listed in `docs/validation/FAILED_TESTS.md`.

## Known issues

- **low** (ReadyStack package): Admin handbook: The kubeadm template comment (also in install/controlplane/kubeadm-config.yaml in the image) says every image runs as kube (999:999); the handbook's own measured output in the same document shows… [`RSD-kubernetesvmstack-812dfef80f`] (carried from `v1.36.6-kubevirt1.9.1-CE-scratch-r2`, recorded there as `RSD-kubernetesvmstack-2ac9db5b55`)

## Defects fixed

- 1 problem found before release and fixed before it shipped (1 by review); each is listed in `docs/defects/defects.json`.

## Verify this archive

```
sha256sum -c CHECKSUMS.sha256
./BUILD_OFFLINE.sh && ./VERIFY_OFFLINE.sh --online
cosign verify --key https://readystack.dev/keys/cosign.pub readystack/kubernetesvmstack:v1.36.6-kubevirt1.9.1-CE-scratch-r3
```

ReadyStack records every signature in the public Sigstore transparency log (Rekor), so the command needs no extra flags.

