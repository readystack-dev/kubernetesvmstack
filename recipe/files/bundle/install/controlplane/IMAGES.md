# Control-plane images under kubeadm's names

The Kubernetes VM Stack pulls only from the local registry. The install bundle's mirror script (`../mirror-images.sh`)
copies each of our images by digest (with its signatures and attestations) into `${LOCAL_REGISTRY}` under the name and
tag kubeadm v1.36.6 asks for. `kubeadm-config.yaml` sets `imageRepository: ${LOCAL_REGISTRY}`, so kubeadm composes
every name below itself; kube-proxy is the exception, because our DaemonSet (`kube-proxy.yaml`) names its image, pinned
by digest. Each image's digest is in `../images.tsv`.

| kubeadm's image (`kubeadm config images list`) | Our image on Docker Hub | Root from |
|---|---|---|
| `${LOCAL_REGISTRY}/kube-apiserver:v1.36.6` | `readystack/kubeapiserver:v1.36.6-CE-ubuntu24.04-r2` @ `${DIGEST_kubeapiserver}` | `patches/kube-apiserver+strategic.yaml` |
| `${LOCAL_REGISTRY}/kube-controller-manager:v1.36.6` | `readystack/kubecontrollermanager:v1.36.6-CE-ubuntu24.04-r2` @ `${DIGEST_kubecontrollermanager}` | `patches/kube-controller-manager+strategic.yaml` |
| `${LOCAL_REGISTRY}/kube-scheduler:v1.36.6` | `readystack/kubescheduler:v1.36.6-CE-ubuntu24.04-r2` @ `${DIGEST_kubescheduler}` | `patches/kube-scheduler+strategic.yaml` |
| `${LOCAL_REGISTRY}/kube-proxy:v1.36.6` | `readystack/kubeproxy:v1.36.6-CE-ubuntu24.04-r2` @ `${DIGEST_kubeproxy}` | `kube-proxy.yaml` (runAsUser: 0) |
| `${LOCAL_REGISTRY}/pause:3.10.2` | `readystack/pause:3.10.2-CE-scratch-r1` @ `${DIGEST_pause}` | none needed (65535:65535, FROM scratch) |
| `${LOCAL_REGISTRY}/etcd:${TAG_etcd}` (`v3.7.3`) | `readystack/etcd:v3.7.3-CE-ubuntu24.04-r2` @ `sha256:9a7eeb94…` (published, signed) | `patches/etcd+strategic.yaml` |
| `${LOCAL_REGISTRY}/coredns:v1.14.2` | `readystack/coredns:v1.14.2-CE-ubuntu24.04-r2` @ `${DIGEST_coredns}` | none (CoreDNS runs non-root) |

The release tags follow `<upstream-version>-CE-<base-os>-r<N>`; pause is FROM scratch, as upstream's, so its base-OS
token is `scratch`.

kubeadm's own image names differ from ours only in the hyphens (`kube-apiserver` here, `readystack/kubeapiserver` on
Docker Hub). CoreDNS: with a custom `imageRepository` kubeadm uses `<repo>/coredns`, not `<repo>/coredns/coredns`.

## Placeholders

| Placeholder | Used in | Value |
|---|---|---|
| `${LOCAL_REGISTRY}` | kubeadm-config.yaml, kube-proxy.yaml | the local registry's `host[:port]`, e.g. `10.77.0.1:5000` (the registry root, the same value as install-node.sh's `REGISTRY_HOST`: the node's containerd config names the sandbox image `<REGISTRY_HOST>/pause:3.10.2`, so kubeadm's `imageRepository` must be the root too) |
| `${KUBE_VIP}` | kubeadm-config.yaml, kube-proxy.yaml | kube-vip's control-plane address (API on 6443) |
| `${NODE_IP}` | kubeadm-config.yaml | the node's own address (each control-plane node) |
| `${TAG_etcd}` | kubeadm-config.yaml | the tag the mirror gives etcd v3.7.3: `v3.7.3`. kubeadm's static Pod runs `command: [etcd, ...]`, which bypasses the image's single-member entrypoint, and etcd 3.7.3 accepts every flag kubeadm v1.36.6 passes. CoreDNS has no tag override: it is kubeadm's own `v1.14.2`, because kubeadm v1.36.6's Corefile migration knows CoreDNS only up to 1.14.2, so `kubeadm upgrade` fails its preflight on a later one |
| `${BOOTSTRAP_TOKEN}`, `${CERTIFICATE_KEY}`, `${CA_CERT_HASH}` | kubeadm-config.yaml | `kubeadm token generate`, `kubeadm certs certificate-key`, the hash kubeadm init prints |
| `${DIGEST_<slug>}` | kube-proxy.yaml (`kubeproxy`), the mirror script | `sha256:…` of the image, from `../images.tsv` |

## How root is applied

Every image's default user is non-root: `kube` (999:999) for the four kube images, 65535:65535 for pause, `etcd` (999)
for etcd. The Pod supplies root where the component needs it:

- kube-apiserver, kube-controller-manager, kube-scheduler and etcd: kubeadm's static Pods, through the patch files in
  `patches/`, which kubeadm reads from `/etc/kubernetes/patches` (`patches.directory` in the InitConfiguration,
  JoinConfiguration and UpgradeConfiguration of `kubeadm-config.yaml`; the same as `--patches`). Each sets
  `spec.securityContext.runAsUser: 0` and `runAsGroup: 0` (strategic merge; kubeadm's `seccompProfile: RuntimeDefault`
  stays).
- kube-proxy: kubeadm's addon phase, which `--patches` cannot reach, is skipped (`skipPhases: [addon/kube-proxy]` in
  the InitConfiguration and in `UpgradeConfiguration.apply`). `kube-proxy.yaml` is kubeadm's own ServiceAccount, RBAC,
  ConfigMap and DaemonSet (rendered with `kubeadm init phase addon kube-proxy --print-manifest`) plus `runAsUser: 0` /
  `runAsGroup: 0` next to kubeadm's `privileged: true`. Apply it after `kubeadm init`.

Without those files each component starts as its non-root user and stops at once: kube-apiserver on
`/etc/kubernetes/pki/*.key` (mode 0600 root), kube-controller-manager and kube-scheduler on their kubeconfigs, etcd on
`/var/lib/etcd`, kube-proxy on the conntrack sysctls (a non-root process has no capabilities even in a privileged
container).

## Verification

With `LOCAL_REGISTRY=10.77.0.1:5000`, `kubeadm config images pull --config kubeadm-config.yaml` pulls exactly these
names:

```
10.77.0.1:5000/kube-apiserver:v1.36.6
10.77.0.1:5000/kube-controller-manager:v1.36.6
10.77.0.1:5000/kube-scheduler:v1.36.6
10.77.0.1:5000/kube-proxy:v1.36.6
10.77.0.1:5000/coredns:v1.14.2
10.77.0.1:5000/pause:3.10.2
10.77.0.1:5000/etcd:v3.7.3
```

`kubeadm init` and `kubeadm join --control-plane` apply the four patches (`[patches] Applied patch of type
"application/strategic-merge-patch+json" to target "kube-apiserver"`, and the same for kube-controller-manager,
kube-scheduler and etcd), and all four static Pod manifests carry
`securityContext: {runAsGroup: 0, runAsUser: 0, seccompProfile: {type: RuntimeDefault}}`. On a three-node cluster
installed in the order of `../README.md`, every kube-apiserver, kube-controller-manager, kube-scheduler and etcd
process runs as uid 0, and no image on the nodes defaults to root.

Each image's own default user fails at once against kubeadm's files, as above:

- kube-apiserver: `failed to parse service-account-issuer-key-file: open /etc/kubernetes/pki/sa.key: permission denied`.
- kube-scheduler: `open /etc/kubernetes/scheduler.conf: permission denied` (kube-controller-manager stops the same way
  on its root-only kubeconfig).
- kube-proxy, privileged: `could not set conntrack parameters from kube-proxy configuration: open
  /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established: permission denied`.
- pause: `-v` prints `pause.c v3.10.2-`; it runs as uid 65535 as the container's only process and exits 0 on SIGTERM.

## Operating notes

- `kubeadm upgrade apply` must keep `addon/kube-proxy` skipped (the UpgradeConfiguration here does): otherwise kubeadm
  replaces our DaemonSet with its own, which has no `runAsUser: 0`.
- `kube-proxy.yaml`'s ConfigMap is kubeadm's `--print-manifest` output, which carries no
  `kubeadm.kubernetes.io/component-config.hash` annotation (kubeadm adds one only when it creates the ConfigMap
  itself); kubeadm therefore treats the kube-proxy configuration as user-supplied, which it is.
- `podSubnet` (10.244.0.0/16, kube-proxy's `clusterCIDR`) must equal flannel's `net-conf.json` Network
  (`../network/kube-flannel.yml`).
- kube-proxy's mode is kubeadm's default (iptables); set `mode: nftables` in the ConfigMap's `config.conf` to use nft.
  The image's iptables commands are iptables-wrappers' wrapper: the first call picks legacy or nft from the rules the
  node's kubelet already wrote.
