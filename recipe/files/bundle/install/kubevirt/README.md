# KubeVirt v1.9.1 install files (Kubernetes VM Stack)

These files install KubeVirt v1.9.1 from ReadyStack's own builds of KubeVirt. Every image comes from the local
registry, pinned by digest: the images and their digests are listed in `../images.tsv`, and the install order is in
`../README.md` (step 9).

| File | What it is |
|---|---|
| `kubevirt-operator.yaml` | KubeVirt's v1.9.1 release manifest. Only the virt-operator container is changed: its image, plus `VIRT_*_IMAGE` for each component it deploys, all `${LOCAL_REGISTRY}/kubevirt/<name>@${DIGEST_<slug>}`. |
| `kubevirt-cr.yaml` | KubeVirt's v1.9.1 KubeVirt CR, plus `spec.customizeComponents`, which gives virt-handler root, `useEmulation: false` and `virtTemplateDeployment.enabled: false`. |

## Images

| KubeVirt image | ReadyStack image | Release tag | Base OS |
|---|---|---|---|
| virt-operator | `readystack/virtoperator` | `v1.9.1-CE-debian12-r2` | Google distroless Debian 12 |
| virt-api | `readystack/virtapi` | `v1.9.1-CE-debian12-r2` | Google distroless Debian 12 |
| virt-controller | `readystack/virtcontroller` | `v1.9.1-CE-debian12-r2` | Google distroless Debian 12 |
| virt-exportproxy | `readystack/virtexportproxy` | `v1.9.1-CE-debian12-r2` | Google distroless Debian 12 |
| virt-handler | `readystack/virthandler` | `v1.9.1-CE-centos9-r2` | KubeVirt's CentOS Stream 9 RPMs on Google distroless Debian 12 |
| virt-launcher | `readystack/virtlauncher` | `v1.9.1-CE-centos9-r2` | KubeVirt's CentOS Stream 9 RPMs on Google distroless Debian 12 |
| virtctl (admin machine only) | `readystack/virtctl` | `v1.9.1-CE-scratch-r2` | none: a static binary and its tarball |

Each image carries its RPM database and one module SBOM per Go binary in `/usr/share/kubevirt/sbom/`, so a scanner
(Docker Scout, syft) counts the CentOS Stream packages and the linked Go modules.

Docker Scout finds no fixable critical or high vulnerability in virt-handler and virt-launcher. A scan against Red Hat's
RHEL 9 data (syft + grype) finds high vulnerabilities in KubeVirt's CentOS Stream 9 QEMU/libvirt package set that
CentOS Stream has not fixed yet. Most of the fixable ones it reports are false positives (Debian's libssl3 matched
against RHEL advisories, and CentOS Stream builds that already carry RHEL's fix); each release's residual list gives
every one its disposition. The real ones: libcap CVE-2026-4878, fixed in RHEL 9 but not yet in CentOS Stream 9, and
glibc CVE-2026-86805 and CVE-2026-95818, fixed in CentOS Stream 9's glibc 2.34-286.el9 after these builds.
virt-handler and virt-launcher are not listed on readystack.dev; each release publishes its scan and that list as its
disclosure record (`docs/provenance/SCAN_GRADE.json`). virt-launcher `v1.9.1-CE-centos9-r2` ships with glibc
CVE-2026-86805 and CVE-2026-95818 disclosed there: its glibc packages are 2.34-277.el9, the build KubeVirt's package
lock pins.

The tag token `centos9` means **CentOS Stream 9**. There is no CentOS Linux 9. virt-handler and virt-launcher carry
KubeVirt's own CentOS Stream 9 RPM set, with QEMU and libvirt as KubeVirt tests and ships them.

The mirror step (`../mirror-images.sh`) copies each release by digest into `${LOCAL_REGISTRY}` under KubeVirt's own
repository names (`kubevirt/virt-operator`, `kubevirt/virt-api`, ...), keeping its signature and attestations.
virt-operator reads its registry from its own image name (`^(.*)/(.*)virt-operator([@:].*)?$`), so these names must
keep KubeVirt's spelling. Fill `LOCAL_REGISTRY` and `DIGEST_<slug>` (the `sha256:...` of each release), then run
`envsubst`.

## virt-exportproxy is included

KubeVirt v1.9.1 always deploys it:
`pkg/virt-operator/resource/generate/install/strategy.go` adds the virt-exportproxy Deployment with no condition, and
`pkg/virt-operator/resource/apply/reconcile.go` syncs it with no feature gate. virt-operator reports KubeVirt
Available only after it is running. A cluster that pulls only from the local registry would never become ready
without it, so the stack ships it.

virt-exportserver is not shipped. It starts only when a VirtualMachineExport is created.

virt-template (virt-template-apiserver and virt-template-controller, v0.2.3) is not shipped either, and VM templates
are not part of this stack. Its `Template` feature gate is Beta in v1.9.1, so it is on by default, and virt-operator
would deploy both and wait for them: without an image for them, KubeVirt never reports Available. The CR therefore
sets `spec.configuration.virtTemplateDeployment.enabled: false`, the dedicated switch for that deployment.

The other components behind feature gates are not shipped. virt-operator deploys none of them unless their gate is
turned on, and none is on by default in v1.9.1:

- virt-synchronization-controller (DecentralizedLiveMigration, Alpha)
- pr-helper (PersistentReservation, only when `persistentReservationConfiguration.enabled` or the gate is listed)
- sidecar-shim (Sidecar, Alpha)

## Root

Every image defaults to a non-root user. The pod gives root to the containers that need it:

- **virt-handler.** virt-operator writes its container with `privileged: true` and no `runAsUser`. The CR's
  `customizeComponents` patch sets `runAsUser: 0`. Without the patch, virt-handler starts as uid 107 and fails at
  once with "permission denied".
- **virt-handler's node-labeller init container.** It is named `virt-launcher` and runs the virt-launcher image.
  virt-operator already sets `runAsUser: 0` on it, and the patch states it again so all of this pod's root settings
  are in one place.
- **VM pods.** virt-controller creates the virt-launcher pods with `runAsUser: 107` (KubeVirt's default non-root
  mode), which is also the image's default user.

## Emulation

`useEmulation` is off, as it is upstream: each node must provide `/dev/kvm` (nested virtualization works where the
host passes KVM through to the node). Turn emulation on (`spec.configuration.developerConfiguration.useEmulation:
true`) only on nodes that lack it. QEMU then runs in TCG mode, which is slow.
