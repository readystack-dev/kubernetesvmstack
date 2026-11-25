# Kubernetes VM Stack: operator runbook

Kubernetes v1.36.6 and KubeVirt v1.9.1 on 3 nodes, with every
image pulled from your own registry. This runbook was checked against the stack's integration cluster
(kvs-cp1, kvs-cp2, kvs-cp3: Ubuntu 24.04.5 LTS, kernel 6.8.0-147-generic, containerd 2.3.7) on
2026-10-29. A command shown with its output ran there, and that output is printed after it. A step that the check
does not run again (a `kubeadm init`, a join) is one the integration test ran; where its record holds the step's output,
the line that shows the result is printed after it. The full record of the check, `RUNBOOK_EVIDENCE.json`, ships with this
runbook.

## How to read this runbook

Commands run in one of two places:

- **The admin machine**: a host with `kubectl` and `virtctl`, where `KUBECONFIG` points at a root-only copy of the
  first node's `/etc/kubernetes/admin.conf`. A block with no other label runs there.
- **A node**: a shell on a cluster node as an administrator user. Each command carries its own `sudo`, as you would
  type it. A block labelled "On each node" ran on every node.

Placeholders such as `${LOCAL_REGISTRY}`, `${KUBE_VIP}` and `${NODE_IP}` are the install files' own; each install file
lists what it expects. Secrets (the registry password, the bootstrap token, the certificate key) stay in root-only
files, and commands name those files. In the outputs below every secret is replaced by `<redacted>`.

The install bundle is the `/kubernetesvmstack/install/` directory of the `readystack/kubernetesvmstack` image, and the
stack's pin manifest is that image's `/kubernetesvmstack/kubevirt-stack.json`. A path such as `node/install-node.sh` is
relative to the install bundle.

The image holds no shell: it is the bundle and one program, `stack-bundle`, and it runs as user
`65534:65534`. Run with no arguments, the image
checks every file under `/kubernetesvmstack` against the `SHA256SUMS` beside them and prints
`<name> <version>: <n> files verified`, or names each problem and exits 1. `docker create` makes a container without starting it, so `docker cp` can copy the
bundle out of it; `sha256sum` then checks the copy on your machine:

```sh
IMAGE=readystack/kubernetesvmstack:<release tag>@sha256:<its index digest>
docker run --rm "$IMAGE"
docker create --name kvs-bundle "$IMAGE"
docker cp kvs-bundle:/kubernetesvmstack .
docker rm kvs-bundle
(cd kubernetesvmstack && sha256sum --quiet -c SHA256SUMS) && echo "every file matches SHA256SUMS"
```

This step is not re-run by the runbook check. The integration test ran it on 2026-10-29; its record shows:

```text
Kubernetes VM Stack v1.36.6-kubevirt1.9.1: 26 files verified
```

The admin kubeconfig, copied from the first node into a file only you can read:

```sh
(umask 077; ssh <first node> 'sudo cat /etc/kubernetes/admin.conf' > admin.conf)
export KUBECONFIG=$PWD/admin.conf
```

This step is not re-run by the runbook check; the integration test does the same.

```sh
kubectl get --raw=/readyz; echo
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}{"\n"}'
```

Output on the integration cluster (2026-10-29):

```text
ok
https://10.77.0.10:6443
```

## What the stack installs

The install bundle's image list, `images.tsv`, names each image by its product slug (`readystack/<slug>` on Docker
Hub), its release tag, its linux/amd64 manifest digest, and the other names the mirror gives it in your registry (the
names kubeadm and KubeVirt look for). Mirror from the `images.tsv` of the bundle you install: it carries the digests of
the releases you received.

**The image digests in the outputs below are the ones the integration cluster ran on 2026-10-29**: the proof builds
of each kit, mirrored from OCI archives, and etcd's published release.
A release whose linux/amd64 manifest digest (or index digest) is among them is the image that ran; any other release is
a later build of the same component. Each image's archive states its own digest (`docs/REBUILD.md`), and the handbook
of each image documented from this runbook (`docs/admin-guide/ADMIN_HANDBOOK.md`) compares the two at its start.

The images the cluster's pods run (every container and init container):

```sh
kubectl get pods -A -o jsonpath='{range .items[*]}{range .spec.initContainers[*]}{.image}{"\n"}{end}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u
```

Output on the integration cluster (2026-10-29):

```text
10.77.0.1:5000/coredns:v1.14.2
10.77.0.1:5000/etcd:v3.7.3
10.77.0.1:5000/kube-apiserver:v1.36.6
10.77.0.1:5000/kube-controller-manager:v1.36.6
10.77.0.1:5000/kube-proxy:v1.36.6@sha256:690fd8d24cd4ffbf70dbe1ba26ac48ce80a972d7183cf691948ff5ff8ca8d56c
10.77.0.1:5000/kube-scheduler:v1.36.6
10.77.0.1:5000/kubevirt/virt-api@sha256:3b9821f4de2decd949a4e7fba4bdf724226c652544384195ac534b9daf03947a
10.77.0.1:5000/kubevirt/virt-controller@sha256:e3b93539f7842851fb18c45508542f5c842280e30a9f9a35aee15ad8a43ac6af
10.77.0.1:5000/kubevirt/virt-exportproxy@sha256:08ae58dc5e2f7d70df82e138252444bb59bd1929758ba6a293c72e564efd6649
10.77.0.1:5000/kubevirt/virt-handler@sha256:6136df8f03ae550fa9b376e0ca210f14be9f2b876c0cd90e44fec40965bff824
10.77.0.1:5000/kubevirt/virt-launcher@sha256:ae22cd3068d148beaef04c912cecab732bedac61a7ac538f6fbee8cb1d884904
10.77.0.1:5000/kubevirt/virt-operator@sha256:7e27c9489846f1328ecba4006654c2938a4596ea1c7a6e0cef45287f4abfa078
10.77.0.1:5000/readystack/flannel@sha256:97cef957da7a851cdb96fbd19da105a6870ddfc111e450b16537cea83f3b1db5
10.77.0.1:5000/readystack/flannelcniplugin@sha256:4511acd7413d1e6fd78d3d712921d794cb820a3b62973512532d7b64f2cc4e8a
10.77.0.1:5000/readystack/kubeapiserver@sha256:49c4d7708668d7ab42ae0d1d3d584063f67ef87f2d746e21d6709288afdb997e
10.77.0.1:5000/readystack/kubevip@sha256:74dd28c7b8af69cd7cf4684338b782d1fbf939a1dbfabeb1545d70b077cf934b
10.77.0.1:5000/readystack/multuscni@sha256:f90014221243e98cf21d56dc66e3f53bf386c1c1484a633e550dadf4e39f324e
```

Every image's default user is non-root. Where a component needs root, its pod definition sets it, and the section
about the component shows how. The default user of each image on a node, read from the image itself:

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
out=$(for i in $(sudo crictl images -q); do sudo crictl inspecti -o json "$i" | python3 -c 'import json, sys; d = json.load(sys.stdin); print(d["status"]["repoDigests"][0], " user=" + (d["info"]["imageSpec"]["config"].get("User") or "(none: root)"))'; done | sort)
echo "$out"
! echo "$out" | grep -qE 'user=(0|0:0|root|\(none: root\))$'
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
10.77.0.1:5000/coredns@sha256:faf5d9691f306d7f318377a2db731aa843ef8ed23866e7c410cdbc001dda2c4b  user=65532:65532
10.77.0.1:5000/etcd@sha256:b86345e29e39a9d41a26af8d79b9e784c26fb9c6b4614340e6ce663f12fe8f1b  user=etcd
10.77.0.1:5000/kube-apiserver@sha256:49c4d7708668d7ab42ae0d1d3d584063f67ef87f2d746e21d6709288afdb997e  user=999:999
10.77.0.1:5000/kube-controller-manager@sha256:f832d6d6174e904cb86f178379571f02421cd5e056f112da12062aec8d2f93a2  user=999:999
10.77.0.1:5000/kube-proxy@sha256:690fd8d24cd4ffbf70dbe1ba26ac48ce80a972d7183cf691948ff5ff8ca8d56c  user=999:999
10.77.0.1:5000/kube-scheduler@sha256:db92258d58a8e98424edd20418624e6625c4360acedd4dd919443a3e538c9ef8  user=999:999
10.77.0.1:5000/kubevirt/virt-api@sha256:3b9821f4de2decd949a4e7fba4bdf724226c652544384195ac534b9daf03947a  user=1001
10.77.0.1:5000/kubevirt/virt-controller@sha256:e3b93539f7842851fb18c45508542f5c842280e30a9f9a35aee15ad8a43ac6af  user=1001
10.77.0.1:5000/kubevirt/virt-handler@sha256:6136df8f03ae550fa9b376e0ca210f14be9f2b876c0cd90e44fec40965bff824  user=107
10.77.0.1:5000/kubevirt/virt-launcher@sha256:ae22cd3068d148beaef04c912cecab732bedac61a7ac538f6fbee8cb1d884904  user=107
10.77.0.1:5000/kubevirt/virt-operator@sha256:7e27c9489846f1328ecba4006654c2938a4596ea1c7a6e0cef45287f4abfa078  user=1001
10.77.0.1:5000/pause@sha256:3f755e85d22288dbb1ae6595ea088b6f1a9271a4185fe9d5edae7fbb9f599b3e  user=65535:65535
10.77.0.1:5000/readystack/flannel@sha256:97cef957da7a851cdb96fbd19da105a6870ddfc111e450b16537cea83f3b1db5  user=flannel
10.77.0.1:5000/readystack/flannelcniplugin@sha256:4511acd7413d1e6fd78d3d712921d794cb820a3b62973512532d7b64f2cc4e8a  user=flannelcniplugin
10.77.0.1:5000/readystack/kubevip@sha256:74dd28c7b8af69cd7cf4684338b782d1fbf939a1dbfabeb1545d70b077cf934b  user=kubevip
10.77.0.1:5000/readystack/multuscni@sha256:f90014221243e98cf21d56dc66e3f53bf386c1c1484a633e550dadf4e39f324e  user=multuscni
== kvs-cp2
10.77.0.1:5000/coredns@sha256:faf5d9691f306d7f318377a2db731aa843ef8ed23866e7c410cdbc001dda2c4b  user=65532:65532
10.77.0.1:5000/etcd@sha256:b86345e29e39a9d41a26af8d79b9e784c26fb9c6b4614340e6ce663f12fe8f1b  user=etcd
10.77.0.1:5000/kube-apiserver@sha256:49c4d7708668d7ab42ae0d1d3d584063f67ef87f2d746e21d6709288afdb997e  user=999:999
10.77.0.1:5000/kube-controller-manager@sha256:f832d6d6174e904cb86f178379571f02421cd5e056f112da12062aec8d2f93a2  user=999:999
10.77.0.1:5000/kube-proxy@sha256:690fd8d24cd4ffbf70dbe1ba26ac48ce80a972d7183cf691948ff5ff8ca8d56c  user=999:999
10.77.0.1:5000/kube-scheduler@sha256:db92258d58a8e98424edd20418624e6625c4360acedd4dd919443a3e538c9ef8  user=999:999
10.77.0.1:5000/kubevirt/virt-controller@sha256:e3b93539f7842851fb18c45508542f5c842280e30a9f9a35aee15ad8a43ac6af  user=1001
10.77.0.1:5000/kubevirt/virt-exportproxy@sha256:08ae58dc5e2f7d70df82e138252444bb59bd1929758ba6a293c72e564efd6649  user=1001
10.77.0.1:5000/kubevirt/virt-handler@sha256:6136df8f03ae550fa9b376e0ca210f14be9f2b876c0cd90e44fec40965bff824  user=107
10.77.0.1:5000/kubevirt/virt-launcher@sha256:ae22cd3068d148beaef04c912cecab732bedac61a7ac538f6fbee8cb1d884904  user=107
10.77.0.1:5000/pause@sha256:3f755e85d22288dbb1ae6595ea088b6f1a9271a4185fe9d5edae7fbb9f599b3e  user=65535:65535
10.77.0.1:5000/readystack/flannel@sha256:97cef957da7a851cdb96fbd19da105a6870ddfc111e450b16537cea83f3b1db5  user=flannel
10.77.0.1:5000/readystack/flannelcniplugin@sha256:4511acd7413d1e6fd78d3d712921d794cb820a3b62973512532d7b64f2cc4e8a  user=flannelcniplugin
10.77.0.1:5000/readystack/kubevip@sha256:74dd28c7b8af69cd7cf4684338b782d1fbf939a1dbfabeb1545d70b077cf934b  user=kubevip
10.77.0.1:5000/readystack/multuscni@sha256:f90014221243e98cf21d56dc66e3f53bf386c1c1484a633e550dadf4e39f324e  user=multuscni
== kvs-cp3
10.77.0.1:5000/coredns@sha256:faf5d9691f306d7f318377a2db731aa843ef8ed23866e7c410cdbc001dda2c4b  user=65532:65532
10.77.0.1:5000/etcd@sha256:b86345e29e39a9d41a26af8d79b9e784c26fb9c6b4614340e6ce663f12fe8f1b  user=etcd
10.77.0.1:5000/kube-apiserver@sha256:49c4d7708668d7ab42ae0d1d3d584063f67ef87f2d746e21d6709288afdb997e  user=999:999
10.77.0.1:5000/kube-controller-manager@sha256:f832d6d6174e904cb86f178379571f02421cd5e056f112da12062aec8d2f93a2  user=999:999
10.77.0.1:5000/kube-proxy@sha256:690fd8d24cd4ffbf70dbe1ba26ac48ce80a972d7183cf691948ff5ff8ca8d56c  user=999:999
10.77.0.1:5000/kube-scheduler@sha256:db92258d58a8e98424edd20418624e6625c4360acedd4dd919443a3e538c9ef8  user=999:999
10.77.0.1:5000/kubevirt/virt-api@sha256:3b9821f4de2decd949a4e7fba4bdf724226c652544384195ac534b9daf03947a  user=1001
10.77.0.1:5000/kubevirt/virt-handler@sha256:6136df8f03ae550fa9b376e0ca210f14be9f2b876c0cd90e44fec40965bff824  user=107
10.77.0.1:5000/kubevirt/virt-launcher@sha256:ae22cd3068d148beaef04c912cecab732bedac61a7ac538f6fbee8cb1d884904  user=107
10.77.0.1:5000/kubevirt/virt-operator@sha256:7e27c9489846f1328ecba4006654c2938a4596ea1c7a6e0cef45287f4abfa078  user=1001
10.77.0.1:5000/pause@sha256:3f755e85d22288dbb1ae6595ea088b6f1a9271a4185fe9d5edae7fbb9f599b3e  user=65535:65535
10.77.0.1:5000/readystack/flannel@sha256:97cef957da7a851cdb96fbd19da105a6870ddfc111e450b16537cea83f3b1db5  user=flannel
10.77.0.1:5000/readystack/flannelcniplugin@sha256:4511acd7413d1e6fd78d3d712921d794cb820a3b62973512532d7b64f2cc4e8a  user=flannelcniplugin
10.77.0.1:5000/readystack/kubevip@sha256:74dd28c7b8af69cd7cf4684338b782d1fbf939a1dbfabeb1545d70b077cf934b  user=kubevip
10.77.0.1:5000/readystack/multuscni@sha256:f90014221243e98cf21d56dc66e3f53bf386c1c1484a633e550dadf4e39f324e  user=multuscni
```

## Install order

1. The local registry: `readystack/registry` over TLS, with authentication.
2. The registry configuration file, root-only, on every node.
3. The host bridge on every node: the uplink is enslaved to `br0` and the node's address moves onto it.
4. The mirror: every image of `images.tsv` into your registry, by digest.
5. Every node: `install-node.sh` (binaries, systemd units, a containerd configuration that pulls only from your
   registry).
6. The first node: the kubeadm patch files, kube-vip's static pod (`first-node`), `kubeadm init`, then kube-vip's
   `after-init`.
7. The other two nodes: the patch files, kube-vip's static pod (`join`), then `kubeadm join` as control-plane nodes.
8. kube-proxy, flannel and Multus; then CoreDNS spread over the nodes.
9. KubeVirt: its operator, then its custom resource; wait until it reports Available.
10. Virtual machines on static local disks.

The bundle's `README.md` gives each step's commands
(`/kubernetesvmstack/install/README.md`).
The integration test ran them in this order from a torn-down cluster on 2026-10-29, up to a virtual machine that took
an address from the LAN through the host bridge.

## The local registry and mirroring

The nodes pull every image from one registry of yours: the integration cluster's is `10.77.0.1:5000`, a
`readystack/registry` serving TLS with an htpasswd user. Its address, CA and credentials live in one root-only file
that `install-node.sh` and `mirror-images.sh` both read as data (never sourced):

`/kubernetesvmstack/install/node/registry.env.example`:

```ini
# install-node.sh --registry-config FILE: copy to /root/registry.env, fill in, then
#   chown root:root /root/registry.env && chmod 0600 /root/registry.env
# KEY=VALUE lines, read as data (never sourced): no quotes, no spaces around '=', values taken literally.
REGISTRY_HOST=10.77.0.1:5000
REGISTRY_CA_FILE=/root/registry-ca.crt
REGISTRY_USERNAME=docker
REGISTRY_PASSWORD=change-me
```

On each node that file and the containerd configuration that carries the credential are root-only:

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
sudo stat -c '%a %U:%G %n' /root/registry.env /etc/containerd/config.toml
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
600 root:root /root/registry.env
600 root:root /etc/containerd/config.toml
== kvs-cp2
600 root:root /root/registry.env
600 root:root /etc/containerd/config.toml
== kvs-cp3
600 root:root /root/registry.env
600 root:root /etc/containerd/config.toml
```

`mirror-images.sh` copies each image of `images.tsv` into the registry by digest, with its signatures and
attestations, under its `readystack/<slug>` name and the names kubeadm and KubeVirt use. It refuses a source whose
linux/amd64 manifest is not the listed digest, and it runs only the regctl build whose sha256 it pins. Fetch that
regctl once on a connected machine and carry it with the bundle:

```sh
./mirror-images.sh --fetch-regctl                                     # on a connected machine, once
./mirror-images.sh --registry-config /root/registry.env --from-archives ./archives
./mirror-images.sh --registry-config /root/registry.env --from-hub    # or from Docker Hub
```

This step is not re-run by the runbook check. The integration test ran it on 2026-10-29; its record shows:

```text
mirror-images: all 16 images mirrored into 10.77.0.1:5000 by digest
mirror-images: all 1 images mirrored into 10.77.0.1:5000 by digest
```

A signature copied this way verifies against the copy in your registry, under every name the mirror gives the image
(cosign needs the registry's CA and a login to it). In the integration test only etcd, the published release, was
mirrored from Docker Hub with its signatures, and it verified under each of its names; the other images came from
OCI archives, which carry no signature:

```sh
cosign verify --key https://readystack.dev/keys/cosign.pub ${LOCAL_REGISTRY}/etcd:v3.7.3
```

This step is not re-run by the runbook check. The integration test ran it on 2026-10-29; its record shows:

```text
VERIFIED 10.77.0.1:5000/etcd:v3.7.3: 3 checks (claims, transparency log, key)
```

containerd sends every pull of docker.io, registry.k8s.io and quay.io to your registry, with no public fallback:

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
sudo grep -H '^server' /etc/containerd/certs.d/*/hosts.toml
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
/etc/containerd/certs.d/10.77.0.1:5000/hosts.toml:server = 'https://10.77.0.1:5000'
/etc/containerd/certs.d/docker.io/hosts.toml:server = 'https://10.77.0.1:5000'
/etc/containerd/certs.d/quay.io/hosts.toml:server = 'https://10.77.0.1:5000'
/etc/containerd/certs.d/registry.k8s.io/hosts.toml:server = 'https://10.77.0.1:5000'
== kvs-cp2
/etc/containerd/certs.d/10.77.0.1:5000/hosts.toml:server = 'https://10.77.0.1:5000'
/etc/containerd/certs.d/docker.io/hosts.toml:server = 'https://10.77.0.1:5000'
/etc/containerd/certs.d/quay.io/hosts.toml:server = 'https://10.77.0.1:5000'
/etc/containerd/certs.d/registry.k8s.io/hosts.toml:server = 'https://10.77.0.1:5000'
== kvs-cp3
/etc/containerd/certs.d/10.77.0.1:5000/hosts.toml:server = 'https://10.77.0.1:5000'
/etc/containerd/certs.d/docker.io/hosts.toml:server = 'https://10.77.0.1:5000'
/etc/containerd/certs.d/quay.io/hosts.toml:server = 'https://10.77.0.1:5000'
/etc/containerd/certs.d/registry.k8s.io/hosts.toml:server = 'https://10.77.0.1:5000'
```

Every image on every node came from it:

```sh
REG=$(kubectl -n kube-system get cm kubeadm-config -o jsonpath='{.data.ClusterConfiguration}' | awk '$1 == "imageRepository:" {print $2}')
echo "registry: $REG"
names=$(kubectl get nodes -o jsonpath='{range .items[*].status.images[*]}{.names[*]}{"\n"}{end}' | tr ' ' '\n' | grep . | sort -u)
echo "$names" | sed 's/@sha256:.*//; s/:[^:/]*$//' | sort -u
other=$(echo "$names" | grep -v "^$REG/" || true)
[ -z "$other" ] || { echo "not from $REG:"; echo "$other"; exit 1; }
```

Output on the integration cluster (2026-10-29):

```text
registry: 10.77.0.1:5000
10.77.0.1:5000/coredns
10.77.0.1:5000/etcd
10.77.0.1:5000/kube-apiserver
10.77.0.1:5000/kube-controller-manager
10.77.0.1:5000/kube-proxy
10.77.0.1:5000/kube-scheduler
10.77.0.1:5000/kubevirt/virt-api
10.77.0.1:5000/kubevirt/virt-controller
10.77.0.1:5000/kubevirt/virt-exportproxy
10.77.0.1:5000/kubevirt/virt-handler
10.77.0.1:5000/kubevirt/virt-launcher
10.77.0.1:5000/kubevirt/virt-operator
10.77.0.1:5000/pause
10.77.0.1:5000/readystack/flannel
10.77.0.1:5000/readystack/flannelcniplugin
10.77.0.1:5000/readystack/kubeapiserver
10.77.0.1:5000/readystack/kubevip
10.77.0.1:5000/readystack/multuscni
```

## Nodes

Each node is an Ubuntu 24.04 x86-64 host. Virtual machines need hardware virtualisation (`/dev/kvm`) on every node
that runs them; kubelet needs swap off:

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
uname -m
. /etc/os-release && echo "$PRETTY_NAME"
echo "swap devices: $(swapon --noheadings | wc -l)"
test -c /dev/kvm && echo "/dev/kvm: present"
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
x86_64
Ubuntu 24.04.5 LTS
swap devices: 0
/dev/kvm: present
== kvs-cp2
x86_64
Ubuntu 24.04.5 LTS
swap devices: 0
/dev/kvm: present
== kvs-cp3
x86_64
Ubuntu 24.04.5 LTS
swap devices: 0
/dev/kvm: present
```

`install-node.sh` installs the Kubernetes Node bundle (`readystack/kubernetesnode`'s tarball): kubelet, kubeadm,
kubectl, containerd, runc, crictl, the CNI plugins, their systemd units and the containerd configuration. It checks the
tarball against its sha256 and every file against the bundle's own list, downloads nothing, and reads the registry
configuration file (`/root/registry.env`). Its own header lists what it writes
(`/kubernetesvmstack/install/node/install-node.sh`).

```sh
sudo ./install-node.sh --tarball kubernetesnode-v1.36.6-linux-amd64.tar.gz \
  --sha256 "$(cut -c1-64 kubernetesnode-v1.36.6-linux-amd64.tar.gz.sha256)" --registry-config /root/registry.env
```

This step is not re-run by the runbook check. The integration test ran it on 2026-10-29; its record shows:

```text
install-node: installed: kubelet v1.36.6, containerd v2.3.7, runc version 1.5.2
```

What each node runs:

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
kubelet --version
kubeadm version -o short
containerd --version
runc --version | head -n 1
crictl --version
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
Kubernetes v1.36.6
v1.36.6
containerd github.com/containerd/containerd/v2 v2.3.7 6f589cf13dc01a5b493911355427e05b2ff005d7
runc version 1.5.2
crictl version v1.36.0
== kvs-cp2
Kubernetes v1.36.6
v1.36.6
containerd github.com/containerd/containerd/v2 v2.3.7 6f589cf13dc01a5b493911355427e05b2ff005d7
runc version 1.5.2
crictl version v1.36.0
== kvs-cp3
Kubernetes v1.36.6
v1.36.6
containerd github.com/containerd/containerd/v2 v2.3.7 6f589cf13dc01a5b493911355427e05b2ff005d7
runc version 1.5.2
crictl version v1.36.0
```

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
systemctl is-active containerd kubelet
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
active
active
== kvs-cp2
active
active
== kvs-cp3
active
active
```

The pod sandbox (pause) image is `10.77.0.1:5000/pause:3.10.2`, named in containerd's configuration. pause has no shell, and
the sandbox is not a container of any pod's spec, so it is read on the node: the users the sandboxes run as follow each
pod's own settings (uid 0 for the static pods that set it, the image's own user otherwise).

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
sudo grep -E '^\s*sandbox\s*=' /etc/containerd/config.toml
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
    sandbox = '10.77.0.1:5000/pause:3.10.2'
== kvs-cp2
    sandbox = '10.77.0.1:5000/pause:3.10.2'
== kvs-cp3
    sandbox = '10.77.0.1:5000/pause:3.10.2'
```

On a node (kvs-cp1):

```sh
ps -eo uid,comm | awk '$2 == "pause" {print $1}' | sort -n | uniq -c
```

Output on the integration cluster (2026-10-29):

```text
      4 0
      9 65535
```

## The control-plane address: kube-vip

kube-vip holds the cluster's control-plane address, `10.77.0.10:6443`, on one node at a time (ARP,
leader election through the lease `plndr-cp-lock`); at the time of the check `kvs-cp2` held it. It runs as
a static pod that `kube-vip-static-pod.sh` writes from the bundle's `network/kube-vip.yaml`, with root and the
`NET_ADMIN` and `NET_RAW` capabilities set in that pod.

On the first node the pod reads `super-admin.conf` while `kubeadm init` runs, because the RBAC binding of `admin.conf`
exists only once the API server is up; `after-init` switches it to `admin.conf`. The joining nodes use `admin.conf`
from the start. The script's header explains the order (`/kubernetesvmstack/install/network/kube-vip-static-pod.sh`):

```sh
# on the first node, as root, before kubeadm init; then after-init once it has finished
sudo env LOCAL_REGISTRY=${LOCAL_REGISTRY} DIGEST_kubevip=${DIGEST_kubevip} \
  KUBE_VIP_ADDRESS=${KUBE_VIP} KUBE_VIP_INTERFACE=${KUBE_VIP_INTERFACE} sh kube-vip-static-pod.sh first-node
sudo sh kube-vip-static-pod.sh after-init
# on each joining node, before kubeadm join
sudo env LOCAL_REGISTRY=${LOCAL_REGISTRY} DIGEST_kubevip=${DIGEST_kubevip} \
  KUBE_VIP_ADDRESS=${KUBE_VIP} KUBE_VIP_INTERFACE=${KUBE_VIP_INTERFACE} sh kube-vip-static-pod.sh join
```

This step is not re-run by the runbook check. The integration test ran it on 2026-10-29; its record shows:

```text
wrote /etc/kubernetes/manifests/kube-vip.yaml (kubeconfig /etc/kubernetes/super-admin.conf)
```

```sh
kubectl -n kube-system get pods -o wide | awk 'NR == 1 || /^kube-vip-/'
kubectl -n kube-system get lease plndr-cp-lock -o jsonpath='{"lease holder: "}{.spec.holderIdentity}{"\n"}'
```

Output on the integration cluster (2026-10-29):

```text
NAME                              READY   STATUS    RESTARTS      AGE   IP           NODE      NOMINATED NODE   READINESS GATES
kube-vip-kvs-cp1                  1/1     Running   1 (64m ago)   71m   10.77.0.11   kvs-cp1   <none>           <none>
kube-vip-kvs-cp2                  1/1     Running   0             70m   10.77.0.12   kvs-cp2   <none>           <none>
kube-vip-kvs-cp3                  1/1     Running   0             69m   10.77.0.13   kvs-cp3   <none>           <none>
lease holder: kvs-cp2
```

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
sudo grep -A1 -E 'name: (vip_interface|address)$' /etc/kubernetes/manifests/kube-vip.yaml | grep -v '^--'
sudo grep -E '^\s+path: /etc/kubernetes/[a-z-]+\.conf$' /etc/kubernetes/manifests/kube-vip.yaml
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
    - name: vip_interface
      value: br0
    - name: address
      value: 10.77.0.10
      path: /etc/kubernetes/admin.conf
== kvs-cp2
    - name: vip_interface
      value: br0
    - name: address
      value: 10.77.0.10
      path: /etc/kubernetes/admin.conf
== kvs-cp3
    - name: vip_interface
      value: br0
    - name: address
      value: 10.77.0.10
      path: /etc/kubernetes/admin.conf
```

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
ps -eo uid,comm | awk '$2 == "kube-vip"'
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
    0 kube-vip
== kvs-cp2
    0 kube-vip
== kvs-cp3
    0 kube-vip
```

The integration test recorded the switch back to `admin.conf` on the first node.
When it destroyed the node that held the address, the API answered on the address again from another node, 32 seconds
later, and etcd kept its quorum.

## kubeadm: the first node and the joins

`kubeadm-config.yaml` holds the documents kubeadm reads (InitConfiguration, ClusterConfiguration, KubeletConfiguration,
JoinConfiguration and UpgradeConfiguration); its header lists the placeholders:

`/kubernetesvmstack/install/controlplane/kubeadm-config.yaml`:

```yaml
# kubeadm configuration template for the Kubernetes VM Stack (its versions are pinned in the stack's pin manifest,
# kubevirt-stack.json beside this bundle): kubeadm v1.36.6, config API kubeadm.k8s.io/v1beta4.
#
# Placeholders (the install bundle substitutes them, e.g. with envsubst; every one must be set):
#   ${LOCAL_REGISTRY}    the local registry's host[:port], e.g. 10.77.0.1:5000: the registry ROOT, where the mirror
#                        script (mirror-images.sh) copies our images under kubeadm's names (IMAGES.md). It must be the
#                        same value as install-node.sh's REGISTRY_HOST: the node's containerd config names the sandbox
#                        image <REGISTRY_HOST>/pause:3.10.2, so a path below the root (e.g. host:5000/k8s) would make
#                        kubeadm and containerd name two different pause images
#   ${KUBE_VIP}          the control-plane virtual IP kube-vip holds (port 6443)
#   ${NODE_IP}           this node's own address (the API server advertises it; etcd peers use it)
#   ${TAG_etcd}          the tag the mirror gives our etcd image: v3.7.3 (readystack/etcd:v3.7.3-CE-ubuntu24.04-r1)
#   ${BOOTSTRAP_TOKEN}   a bootstrap token (kubeadm token generate), shared by init and the joins
#   ${CERTIFICATE_KEY}   the key that encrypts the uploaded control-plane certificates (kubeadm certs certificate-key)
#   ${CA_CERT_HASH}      sha256:<hex> of the cluster CA's public key, printed by kubeadm init (joins only)
#
# Use:
#   first node:  kubeadm init --config kubeadm-config.yaml --upload-certs
#   other control-plane nodes: kubeadm join --config kubeadm-config.yaml
#   after the last join: kubectl -n kube-system rollout restart deployment/coredns
#     (kubeadm init schedules both CoreDNS replicas on the first node, the only node then, and their anti-affinity is
#     only preferred, so nothing moves them: without the restart, losing the first node stops cluster DNS)
# Each command reads its own document (init: InitConfiguration + ClusterConfiguration + KubeletConfiguration; join:
# JoinConfiguration; upgrade: UpgradeConfiguration) and ignores the others with a warning.
#
# Root for the control plane: every image runs as the non-root user kube (999:999) by default, and root is set by the
# Pod: the patch files in /etc/kubernetes/patches (patches/ here) give the static Pods of kube-apiserver,
# kube-controller-manager, kube-scheduler and etcd runAsUser: 0 / runAsGroup: 0. kube-proxy is not deployed by kubeadm
# (skipPhases addon/kube-proxy): apply kube-proxy.yaml, kubeadm's own DaemonSet plus runAsUser: 0, after init.
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
bootstrapTokens:
- token: "${BOOTSTRAP_TOKEN}"
  description: "kubeadm bootstrap token for the Kubernetes VM Stack joins"
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
  groups:
  - system:bootstrappers:kubeadm:default-node-token
certificateKey: "${CERTIFICATE_KEY}"
localAPIEndpoint:
  advertiseAddress: "${NODE_IP}"
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  # The stack is three control-plane nodes and nothing else, so its workloads (KubeVirt's virt-handler, every VM's
  # virt-launcher Pod) run on them: no node-role.kubernetes.io/control-plane:NoSchedule taint.
  taints: []
skipPhases:
- addon/kube-proxy
patches:
  directory: /etc/kubernetes/patches
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v1.36.6
clusterName: kubernetes
controlPlaneEndpoint: "${KUBE_VIP}:6443"
imageRepository: "${LOCAL_REGISTRY}"
apiServer:
  certSANs:
  - "${KUBE_VIP}"
etcd:
  local:
    imageTag: "${TAG_etcd}"
    dataDir: /var/lib/etcd
# dns: no imageTag override: kubeadm's own CoreDNS v1.14.2 (<imageRepository>/coredns:v1.14.2), the version its
# corefile migration knows, so `kubeadm upgrade` can migrate the Corefile (a later CoreDNS fails its preflight).
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
  podSubnet: 10.244.0.0/16
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: "${KUBE_VIP}:6443"
    token: "${BOOTSTRAP_TOKEN}"
    caCertHashes:
    - "${CA_CERT_HASH}"
controlPlane:
  localAPIEndpoint:
    advertiseAddress: "${NODE_IP}"
    bindPort: 6443
  certificateKey: "${CERTIFICATE_KEY}"
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  taints: []
patches:
  directory: /etc/kubernetes/patches
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: UpgradeConfiguration
apply:
  kubernetesVersion: v1.36.6
  skipPhases:
  - addon/kube-proxy
  patches:
    directory: /etc/kubernetes/patches
node:
  patches:
    directory: /etc/kubernetes/patches
```

On the integration cluster kubeadm recorded control-plane endpoint `10.77.0.10:6443`, image repository
`10.77.0.1:5000` (your registry's root: kubeadm composes `<root>/kube-apiserver:<tag>` and the others
itself), pod subnet `10.244.0.0/16` and service subnet `10.96.0.0/12`:

```sh
kubectl -n kube-system get cm kubeadm-config -o jsonpath='{.data.ClusterConfiguration}'
```

Output on the integration cluster (2026-10-29):

```text
apiServer:
  certSANs:
  - 10.77.0.10
apiVersion: kubeadm.k8s.io/v1beta4
caCertificateValidityPeriod: 87600h0m0s
certificateValidityPeriod: 8760h0m0s
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controlPlaneEndpoint: 10.77.0.10:6443
controllerManager: {}
dns: {}
encryptionAlgorithm: RSA-2048
etcd:
  local:
    dataDir: /var/lib/etcd
    imageTag: v3.7.3
imageRepository: 10.77.0.1:5000
kind: ClusterConfiguration
kubernetesVersion: v1.36.6
networking:
  dnsDomain: cluster.local
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
proxy:
  disabled: true
scheduler: {}
```

The bootstrap token and the certificate key are generated once, kept in a root-only file, and reach each node's copy of
the configuration through standard input, so neither appears on a command line. `kubeadm` for this comes from the node
tarball:

```sh
umask 077
tar -xzf kubernetesnode-v1.36.6-linux-amd64.tar.gz --strip-components=3 usr/local/bin/kubeadm
{ echo "BOOTSTRAP_TOKEN=$(./kubeadm token generate)"; echo "CERTIFICATE_KEY=$(./kubeadm certs certificate-key)"; } > cluster.env
set -a; . ./cluster.env; set +a
export LOCAL_REGISTRY KUBE_VIP NODE_IP CA_CERT_HASH TAG_etcd
envsubst '${LOCAL_REGISTRY} ${KUBE_VIP} ${NODE_IP} ${TAG_etcd} ${BOOTSTRAP_TOKEN} ${CERTIFICATE_KEY} ${CA_CERT_HASH}' \
  < kubeadm-config.yaml | ssh <node> 'sudo sh -c "umask 077; cat > /root/kubeadm-config.yaml"'
```

This step is not re-run by the runbook check; the integration test does the same.

Every image of the stack runs as a non-root user by default, so the static pods of kube-apiserver,
kube-controller-manager, kube-scheduler and etcd get root from four kubeadm patch files in `/etc/kubernetes/patches`
(`patches.directory` in each kubeadm document). One of them:

`/kubernetesvmstack/install/controlplane/patches/kube-apiserver+strategic.yaml`:

```yaml
# kubeadm patch file (kubeadm's naming: <target>[suffix][+patchtype].yaml; target kube-apiserver, strategic merge),
# read from /etc/kubernetes/patches by kubeadm init, join and upgrade (patches.directory in kubeadm-config.yaml).
# Our kube-apiserver image runs as the non-root user kube (999:999) by default (root is set by the
# Pod). kube-apiserver reads the root-only keys kubeadm writes under /etc/kubernetes/pki (ca.key, sa.key,
# apiserver.key, ...): without this patch it exits at start with "permission denied".
spec:
  securityContext:
    runAsUser: 0
    runAsGroup: 0
```

On every node, before `kubeadm init` or `kubeadm join`:

```sh
sudo mkdir -p /etc/kubernetes/patches
sudo install -m 0644 controlplane/patches/*.yaml /etc/kubernetes/patches/
```

This step is not re-run by the runbook check; the integration test does the same.

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
sudo ls /etc/kubernetes/patches
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
etcd+strategic.yaml
kube-apiserver+strategic.yaml
kube-controller-manager+strategic.yaml
kube-scheduler+strategic.yaml
== kvs-cp2
etcd+strategic.yaml
kube-apiserver+strategic.yaml
kube-controller-manager+strategic.yaml
kube-scheduler+strategic.yaml
== kvs-cp3
etcd+strategic.yaml
kube-apiserver+strategic.yaml
kube-controller-manager+strategic.yaml
kube-scheduler+strategic.yaml
```

The first node pulls kubeadm's images from your registry, then initialises the cluster:

```sh
sudo kubeadm config images pull --config /root/kubeadm-config.yaml
```

This step is not re-run by the runbook check. The integration test ran it on 2026-10-29; its record shows:

```text
[config/images] Pulled 10.77.0.1:5000/kube-apiserver:v1.36.6
[config/images] Pulled 10.77.0.1:5000/kube-controller-manager:v1.36.6
[config/images] Pulled 10.77.0.1:5000/kube-scheduler:v1.36.6
[config/images] Pulled 10.77.0.1:5000/kube-proxy:v1.36.6
[config/images] Pulled 10.77.0.1:5000/coredns:v1.14.2
[config/images] Pulled 10.77.0.1:5000/pause:3.10.2
[config/images] Pulled 10.77.0.1:5000/etcd:v3.7.3
```

```sh
sudo kubeadm init --config /root/kubeadm-config.yaml --upload-certs
```

This step is not re-run by the runbook check. The integration test ran it on 2026-10-29; its record shows:

```text
Your Kubernetes control-plane has initialized successfully!
```

A join needs the hash of the cluster CA's public key (`CA_CERT_HASH`, as `sha256:<hash>`), which is not secret:

On a node (kvs-cp1):

```sh
sudo openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl pkey -pubin -outform der | sha256sum | cut -c1-64
```

Output on the integration cluster (2026-10-29):

```text
edcfcb0d1bafaa3530adf87ab80b4511f46da42fe4790720aa0e60509eb52493
```

Then each other node joins as a control-plane node:

```sh
sudo kubeadm join --config /root/kubeadm-config.yaml
```

This step is not re-run by the runbook check. The integration test ran it on 2026-10-29; its record shows:

```text
* A new etcd member was added to the local/stacked etcd cluster.
```

The control-plane processes run as uid 0 on every node, through the patches:

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
ps -eo uid,comm | awk '$2 ~ /^(kube-apiserver|kube-controller|kube-scheduler|etcd)$/'
c=$(ps -eo uid,comm | awk '$1 == 0 && $2 ~ /^(kube-apiserver|kube-controller|kube-scheduler|etcd)$/' | wc -l)
echo "$c of 4 control-plane processes as uid 0"
[ "$c" = 4 ]
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
    0 kube-controller
    0 etcd
    0 kube-scheduler
    0 kube-apiserver
4 of 4 control-plane processes as uid 0
== kvs-cp2
    0 kube-apiserver
    0 kube-controller
    0 kube-scheduler
    0 etcd
4 of 4 control-plane processes as uid 0
== kvs-cp3
    0 kube-controller
    0 kube-apiserver
    0 etcd
    0 kube-scheduler
4 of 4 control-plane processes as uid 0
```

```sh
for c in kube-apiserver kube-controller-manager kube-scheduler etcd; do
  kubectl -n kube-system get pods -l component=$c -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.securityContext} {.spec.containers[0].image}{"\n"}{end}'
done
```

Output on the integration cluster (2026-10-29):

```text
kube-apiserver-kvs-cp1: {"runAsGroup":0,"runAsUser":0,"seccompProfile":{"type":"RuntimeDefault"}} 10.77.0.1:5000/kube-apiserver:v1.36.6
kube-apiserver-kvs-cp2: {"runAsGroup":0,"runAsUser":0,"seccompProfile":{"type":"RuntimeDefault"}} 10.77.0.1:5000/kube-apiserver:v1.36.6
kube-apiserver-kvs-cp3: {"runAsGroup":0,"runAsUser":0,"seccompProfile":{"type":"RuntimeDefault"}} 10.77.0.1:5000/kube-apiserver:v1.36.6
kube-controller-manager-kvs-cp1: {"runAsGroup":0,"runAsUser":0,"seccompProfile":{"type":"RuntimeDefault"}} 10.77.0.1:5000/kube-controller-manager:v1.36.6
kube-controller-manager-kvs-cp2: {"runAsGroup":0,"runAsUser":0,"seccompProfile":{"type":"RuntimeDefault"}} 10.77.0.1:5000/kube-controller-manager:v1.36.6
kube-controller-manager-kvs-cp3: {"runAsGroup":0,"runAsUser":0,"seccompProfile":{"type":"RuntimeDefault"}} 10.77.0.1:5000/kube-controller-manager:v1.36.6
kube-scheduler-kvs-cp1: {"runAsGroup":0,"runAsUser":0,"seccompProfile":{"type":"RuntimeDefault"}} 10.77.0.1:5000/kube-scheduler:v1.36.6
kube-scheduler-kvs-cp2: {"runAsGroup":0,"runAsUser":0,"seccompProfile":{"type":"RuntimeDefault"}} 10.77.0.1:5000/kube-scheduler:v1.36.6
kube-scheduler-kvs-cp3: {"runAsGroup":0,"runAsUser":0,"seccompProfile":{"type":"RuntimeDefault"}} 10.77.0.1:5000/kube-scheduler:v1.36.6
etcd-kvs-cp1: {"runAsGroup":0,"runAsUser":0,"seccompProfile":{"type":"RuntimeDefault"}} 10.77.0.1:5000/etcd:v3.7.3
etcd-kvs-cp2: {"runAsGroup":0,"runAsUser":0,"seccompProfile":{"type":"RuntimeDefault"}} 10.77.0.1:5000/etcd:v3.7.3
etcd-kvs-cp3: {"runAsGroup":0,"runAsUser":0,"seccompProfile":{"type":"RuntimeDefault"}} 10.77.0.1:5000/etcd:v3.7.3
```

The stack is three control-plane nodes and nothing else, so `kubeadm-config.yaml` sets `taints: []` and every node runs
workloads (virt-handler and the virtual machines among them):

```sh
kubectl get nodes -o wide
[ -z "$(kubectl get nodes -o jsonpath='{.items[*].spec.taints}')" ] && echo "no node taints"
```

Output on the integration cluster (2026-10-29):

```text
NAME      STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION              CONTAINER-RUNTIME
kvs-cp1   Ready    control-plane   72m   v1.36.6   10.77.0.11    <none>        Ubuntu 24.04.5 LTS   6.8.0-147-generic (amd64)   containerd://2.3.7
kvs-cp2   Ready    control-plane   70m   v1.36.6   10.77.0.12    <none>        Ubuntu 24.04.5 LTS   6.8.0-147-generic (amd64)   containerd://2.3.7
kvs-cp3   Ready    control-plane   69m   v1.36.6   10.77.0.13    <none>        Ubuntu 24.04.5 LTS   6.8.0-147-generic (amd64)   containerd://2.3.7
no node taints
```

## Joining a node more than two hours after kubeadm init

kubeadm keeps the uploaded control-plane certificates for two hours (its own output at the integration test's
`kubeadm init` says so);
a join after that needs them uploaded again on the first node, with the same key from the configuration (the key stays
in the root-only file; kubeadm prints it, and the output below has it redacted):

On a node (kvs-cp1):

```sh
sudo kubeadm init phase upload-certs --upload-certs --config /root/kubeadm-config.yaml
```

Output on the integration cluster (2026-10-29):

```text
W1029 02:36:19.485419   22680 initconfiguration.go:363] [config] WARNING: Ignored configuration document with GroupVersionKind kubeadm.k8s.io/v1beta4, Kind=JoinConfiguration
W1029 02:36:19.486328   22680 initconfiguration.go:363] [config] WARNING: Ignored configuration document with GroupVersionKind kubeadm.k8s.io/v1beta4, Kind=UpgradeConfiguration
[upload-certs] Storing the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
[upload-certs] Using certificate key:
<redacted>
```

## The pod network: kube-proxy, flannel and Multus

kubeadm skips its own kube-proxy add-on (`skipPhases: [addon/kube-proxy]`): the bundle's `controlplane/kube-proxy.yaml`
is kubeadm's DaemonSet with `runAsUser: 0` and our image pinned by digest. flannel (`network/kube-flannel.yml`) runs
the `vxlan` backend over `10.244.0.0/16`, the same range as kubeadm's pod subnet
`10.244.0.0/16`. Multus (`network/multus-daemonset.yml`, thin plugin) adds further interfaces to a pod from a
NetworkAttachmentDefinition. All three are rendered with `envsubst` and applied from the admin machine:

```sh
export LOCAL_REGISTRY KUBE_VIP POD_CIDR DIGEST_kubeproxy DIGEST_flannel DIGEST_flannelcniplugin DIGEST_multuscni
for f in controlplane/kube-proxy.yaml network/kube-flannel.yml network/multus-daemonset.yml; do
  envsubst '${LOCAL_REGISTRY} ${KUBE_VIP} ${POD_CIDR} ${DIGEST_kubeproxy} ${DIGEST_flannel} ${DIGEST_flannelcniplugin} ${DIGEST_multuscni}' < "$f" | kubectl apply -f -
done
```

This step is not re-run by the runbook check. The integration test ran it on 2026-10-29; its record shows:

```text
daemonset.apps/kube-multus-ds created
```

```sh
kubectl -n kube-system rollout status ds/kube-proxy --timeout=60s
kubectl -n kube-system get ds kube-proxy -o jsonpath='{.spec.template.spec.containers[0].securityContext}{" "}{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n kube-system get cm kube-proxy -o jsonpath='{.data.config\.conf}' | grep -E '^mode:'
```

Output on the integration cluster (2026-10-29):

```text
daemon set "kube-proxy" successfully rolled out
{"privileged":true,"runAsGroup":0,"runAsUser":0} 10.77.0.1:5000/kube-proxy:v1.36.6@sha256:690fd8d24cd4ffbf70dbe1ba26ac48ce80a972d7183cf691948ff5ff8ca8d56c
mode: ""
```

```sh
kubectl -n kube-flannel rollout status ds/kube-flannel-ds --timeout=60s
kubectl -n kube-flannel get pods -o wide
```

Output on the integration cluster (2026-10-29):

```text
daemon set "kube-flannel-ds" successfully rolled out
NAME                    READY   STATUS    RESTARTS      AGE   IP           NODE      NOMINATED NODE   READINESS GATES
kube-flannel-ds-586mr   1/1     Running   0             69m   10.77.0.13   kvs-cp3   <none>           <none>
kube-flannel-ds-hnxsb   1/1     Running   2 (64m ago)   69m   10.77.0.11   kvs-cp1   <none>           <none>
kube-flannel-ds-tfl6p   1/1     Running   0             69m   10.77.0.12   kvs-cp2   <none>           <none>
```

The flannel CNI binary that the `install-cni-plugin` init container copies onto each node, and the CNI configuration
flannel writes:

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
ls -l /opt/cni/bin/flannel
sudo ls /etc/cni/net.d
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
-rwxr-xr-x 1 root root 3127742 Oct 29 01:31 /opt/cni/bin/flannel
00-multus.conflist
10-flannel.conflist
multus.d
== kvs-cp2
-rwxr-xr-x 1 root root 3127742 Oct 29 01:27 /opt/cni/bin/flannel
00-multus.conflist
10-flannel.conflist
multus.d
== kvs-cp3
-rwxr-xr-x 1 root root 3127742 Oct 29 01:27 /opt/cni/bin/flannel
00-multus.conflist
10-flannel.conflist
multus.d
```

```sh
kubectl -n kube-system rollout status ds/kube-multus-ds --timeout=60s
kubectl get crd network-attachment-definitions.k8s.cni.cncf.io -o name
```

Output on the integration cluster (2026-10-29):

```text
daemon set "kube-multus-ds" successfully rolled out
customresourcedefinition.apiextensions.k8s.io/network-attachment-definitions.k8s.cni.cncf.io
```

Cluster DNS answers through the `kube-dns` Service, with CoreDNS pods behind it:

```sh
kubectl -n kube-system get svc kube-dns
kubectl -n kube-system get endpointslices -l kubernetes.io/service-name=kube-dns
```

Output on the integration cluster (2026-10-29):

```text
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   72m
NAME             ADDRESSTYPE   PORTS        ENDPOINTS               AGE
kube-dns-q4nnn   IPv4          53,53,9153   10.244.1.2,10.244.1.3   72m
```

The integration test also sent traffic from a pod on one node to a pod on another, directly and through a
Service.

## Spreading CoreDNS over the nodes

`kubeadm init` schedules both CoreDNS replicas while the first node is the only one, and their anti-affinity is only
preferred, so nothing moves them later: losing the node that holds both stops cluster DNS
(`/kubernetesvmstack/install/README.md`). After the
last join, restart the deployment once; the integration test did so.
Check the spread again after a node has been down: on the integration cluster, after that run's failover
test, the check found both
replicas on one node again, and the same restart spread them (the first line of its output is where they were):

```sh
echo "before: $(kubectl -n kube-system get pods -l k8s-app=kube-dns -o jsonpath='{range .items[*]}{.spec.nodeName}{" "}{end}')"
kubectl -n kube-system rollout restart deployment/coredns
kubectl -n kube-system rollout status deployment/coredns --timeout=300s
echo "after: restarted"
```

Output on the integration cluster (2026-10-29):

```text
before: kvs-cp2 kvs-cp2 
deployment.apps/coredns restarted
Waiting for deployment spec update to be observed...
Waiting for deployment "coredns" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "coredns" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "coredns" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "coredns" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "coredns" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "coredns" rollout to finish: 1 of 2 updated replicas are available...
Waiting for deployment "coredns" rollout to finish: 1 of 2 updated replicas are available...
Waiting for deployment "coredns" rollout to finish: 1 of 2 updated replicas are available...
deployment "coredns" successfully rolled out
after: restarted
```

```sh
want=$(kubectl -n kube-system get deployment coredns -o jsonpath='{.spec.replicas}')
for i in $(seq 1 30); do [ "$(kubectl -n kube-system get pods -l k8s-app=kube-dns --no-headers | wc -l)" = "$want" ] && break; sleep 2; done
kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
n=$(kubectl -n kube-system get pods -l k8s-app=kube-dns -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l)
echo "CoreDNS on $n node(s)"
[ "$n" -ge 2 ]
```

Output on the integration cluster (2026-10-29):

```text
NAME                       READY   STATUS    RESTARTS   AGE   IP            NODE      NOMINATED NODE   READINESS GATES
coredns-7898b9657f-mcbs7   1/1     Running   0          14s   10.244.0.10   kvs-cp1   <none>           <none>
coredns-7898b9657f-xzhb8   1/1     Running   0          15s   10.244.2.11   kvs-cp3   <none>           <none>
CoreDNS on 2 node(s)
```

The CoreDNS image the cluster runs is `10.77.0.1:5000/coredns:v1.14.2`.

## The host bridge

A virtual machine reaches the hosts' LAN through a Linux bridge on each node's uplink: the uplink is enslaved to the
bridge (`br0` on every node) and the node's address moves onto it. Multus attaches a VM's second NIC to the bridge, and
kube-vip holds the control-plane address on it (`KUBE_VIP_INTERFACE=br0`). The bundle's netplan configuration, filled in
per node:

`/kubernetesvmstack/install/network/bridge-netplan.example.yaml`:

```yaml
# A Linux bridge on the host uplink, for the Kubernetes VM Stack: the uplink is enslaved to the
# bridge and the host's address moves onto the bridge, so a VM NIC that Multus attaches to the bridge
# (nad-host-bridge.yaml, HOST_BRIDGE=${BRIDGE}) sits on the hosts' LAN, next to the hosts themselves, and takes its
# address there (the LAN's DHCP or a static one). Proven on the integration test's three nodes.
#
# With the bridge in place, kube-vip's interface is the bridge, not the uplink: KUBE_VIP_INTERFACE=${BRIDGE} for
# kube-vip-static-pod.sh (an existing kube-vip.yaml must be rendered again), and flannel follows the default route
# onto the bridge by itself.
#
# Placeholders (envsubst), per host:
#   ${UPLINK}       the uplink NIC (e.g. enp1s0)
#   ${UPLINK_MAC}   its MAC address (ip -br link show ${UPLINK}); the bridge takes the same MAC, so a DHCP reservation
#                   or ARP cache for the host keeps working
#   ${BRIDGE}       the bridge's name (br0)
#   ${HOST_CIDR}    the host's address, e.g. 10.77.0.11/24 (static: a cluster node keeps one address)
#   ${GATEWAY}      the default gateway
#   ${DNS}          the DNS server(s), comma-separated
#
# Apply it without locking yourself out (from the host's console if you can; over ssh the session survives when the
# address and MAC stay the same):
#   install -m 0600 bridge.yaml /etc/netplan/60-bridge.yaml   # netplan wants its files root-only
#   netplan generate                                         # parse and render; stops on a syntax error
#   netplan try --timeout 120                                # applies, and rolls back after 120 s unless you press ENTER
# A cloud image's 50-cloud-init.yaml still configures ${UPLINK} with DHCP; this file overrides that (later files win),
# and /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with "network: {config: disabled}" keeps cloud-init from
# writing it again.
network:
  version: 2
  renderer: networkd
  ethernets:
    ${UPLINK}:
      match:
        macaddress: "${UPLINK_MAC}"
      set-name: ${UPLINK}
      dhcp4: false
      dhcp6: false
  bridges:
    ${BRIDGE}:
      interfaces: [${UPLINK}]
      macaddress: "${UPLINK_MAC}"
      addresses: [${HOST_CIDR}]
      routes:
        - to: default
          via: ${GATEWAY}
      nameservers:
        addresses: [${DNS}]
      dhcp4: false
      dhcp6: false
      parameters:
        stp: false
        forward-delay: 0
```

```sh
envsubst < bridge-netplan.example.yaml > bridge.yaml        # UPLINK UPLINK_MAC BRIDGE HOST_CIDR GATEWAY DNS
sudo install -m 0600 bridge.yaml /etc/netplan/60-bridge.yaml
sudo netplan generate
sudo netplan try --timeout 120
```

This step is not re-run by the runbook check. The integration test ran it on 2026-10-29; its record shows:

```text
netplan generate: OK
```

Each node's address on `br0`, the uplink enslaved to it, and the default route through it:

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
ip -br addr show br0
ip -br link show master br0
ip route show default
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
br0              UP             10.77.0.11/24 fe80::5054:ff:fe77:b/64 
enp1s0           UP             52:54:00:77:00:0b <BROADCAST,MULTICAST,UP,LOWER_UP> 
vethbc466fa2@if3 UP             aa:ec:a0:e7:6b:67 <BROADCAST,MULTICAST,UP,LOWER_UP> 
default via 10.77.0.1 dev br0 proto static 
== kvs-cp2
br0              UP             10.77.0.12/24 10.77.0.10/32 fe80::5054:ff:fe77:c/64 
enp1s0           UP             52:54:00:77:00:0c <BROADCAST,MULTICAST,UP,LOWER_UP> 
veth6c6c498d@if3 UP             f2:e1:4d:11:7a:1b <BROADCAST,MULTICAST,UP,LOWER_UP> 
default via 10.77.0.1 dev br0 proto static 
== kvs-cp3
br0              UP             10.77.0.13/24 fe80::5054:ff:fe77:d/64 
enp1s0           UP             52:54:00:77:00:0d <BROADCAST,MULTICAST,UP,LOWER_UP> 
default via 10.77.0.1 dev br0 proto static 
```

Pods and virtual machines attach to the bridge through a NetworkAttachmentDefinition (`network/nad-host-bridge.yaml`,
`${HOST_BRIDGE}` the bridge's name). `"ipam": {}` leaves the link without an address on the pod side: the virtual
machine takes its address from the LAN.

`/kubernetesvmstack/install/network/nad-host-bridge.yaml` (part):

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: host-bridge
  namespace: default
spec:
  config: |
    {
      "cniVersion": "1.0.0",
      "name": "host-bridge",
      "plugins": [
        {
          "type": "bridge",
          "bridge": "${HOST_BRIDGE}",
          "ipam": {}
        }
      ]
    }
```

```sh
kubectl get network-attachment-definitions -A
```

Output on the integration cluster (2026-10-29):

```text
NAMESPACE   NAME          AGE
default     host-bridge   67m
```

## KubeVirt

KubeVirt v1.9.1 comes from the bundle's `kubevirt/kubevirt-operator.yaml` (KubeVirt's release
manifest with every image `${LOCAL_REGISTRY}/kubevirt/<name>@<digest>`) and `kubevirt/kubevirt-cr.yaml`. The mirror
copies the six images under KubeVirt's own names, because virt-operator derives the registry of the others from its own
image name:

```sh
./mirror-images.sh --registry-config /root/registry.env --from-archives ./archives \
  --only virtoperator,virtapi,virtcontroller,virthandler,virtlauncher,virtexportproxy
```

This step is not re-run by the runbook check. The integration test ran it on 2026-10-29; its record shows:

```text
mirror-images: all 6 images mirrored into 10.77.0.1:5000 by digest
```

The custom resource gives virt-handler root through `customizeComponents`, keeps hardware virtualisation required
(`useEmulation: false`) and turns off the virt-template deployment, whose images the stack does not ship:

`/kubernetesvmstack/install/kubevirt/kubevirt-cr.yaml`:

```yaml
# The KubeVirt custom resource for the Kubernetes VM Stack.
# Source: https://github.com/kubevirt/kubevirt/releases/download/v1.9.1/kubevirt-cr.yaml
#   (sha256 43106136dbce3312bdbfdeae612aacafc6c12da518d233f90645b4685d84a2af), plus spec.customizeComponents
#   (virt-handler's root), an explicit useEmulation: false and virtTemplateDeployment.enabled: false. Images come
#   from virt-operator's environment (kubevirt-operator.yaml), so the CR names none.
---
apiVersion: kubevirt.io/v1
kind: KubeVirt
metadata:
  name: kubevirt
  namespace: kubevirt
spec:
  certificateRotateStrategy: {}
  configuration:
    developerConfiguration:
      featureGates: []
      # useEmulation (off, the default): VMs need hardware virtualization (/dev/kvm) on the node, which nested
      # virtualization provides; set useEmulation: true only where a node has none (QEMU TCG, slow).
      useEmulation: false
    imagePullPolicy: IfNotPresent
    # The Template feature gate is Beta in v1.9.1, so it is on by default (pkg/virt-config/featuregate/active.go), and
    # virt-operator would then deploy virt-template-apiserver and virt-template-controller (v0.2.3), which the stack
    # does not ship, and wait for them: without this switch KubeVirt never reports Available. The
    # dedicated switch turns only that deployment off (pkg/virt-operator/util/config.go reads
    # virtTemplateDeployment.enabled).
    virtTemplateDeployment:
      enabled: false
  customizeComponents:
    patches:
    # ReadyStack images default to a non-root user; virt-handler needs root, which the pod sets (never the image).
    # virt-operator writes the virt-handler DaemonSet with privileged: true but no runAsUser on its main
    # container (pkg/virt-operator/resource/generate/components/daemonsets.go), so this patch sets runAsUser: 0
    # there. Its node-labeller init container (named virt-launcher, from the virt-launcher image) already gets
    # runAsUser: 0 from virt-operator; the patch states it too, so the root this pod needs is all in one place.
    # Without this patch virt-handler starts as uid 107 and fails at once with "permission denied".
    - resourceType: DaemonSet
      resourceName: virt-handler
      type: strategic
      patch: '{"spec":{"template":{"spec":{"containers":[{"name":"virt-handler","securityContext":{"runAsUser":0}}],"initContainers":[{"name":"virt-launcher","securityContext":{"runAsUser":0}}]}}}}'
  imagePullPolicy: IfNotPresent
  workloadUpdateStrategy: {}
```

```sh
kubectl apply -f kubevirt-operator.yaml            # rendered: LOCAL_REGISTRY and each DIGEST_<slug>
kubectl -n kubevirt rollout status deployment/virt-operator --timeout=600s
kubectl apply -f kubevirt-cr.yaml
kubectl -n kubevirt wait kv kubevirt --for condition=Available --timeout=1200s
```

This step is not re-run by the runbook check. The integration test ran it on 2026-10-29; its record shows:

```text
kubevirt.kubevirt.io/kubevirt created
```

KubeVirt's phase read `Deployed` (`.status.phase` of the KubeVirt resource). Its conditions, as the
check printed them (it passes on `Available=True`), and the pods it runs:

```sh
kubectl -n kubevirt get kv kubevirt -o jsonpath='{range .status.conditions[*]}{.type}={.status} ({.reason}){"\n"}{end}'
kubectl -n kubevirt get pods -o wide
```

Output on the integration cluster (2026-10-29):

```text
Available=True (AllComponentsReady)
Progressing=False (AllComponentsReady)
Degraded=False (AllComponentsReady)
Created=True (AllResourcesCreated)
NAME                                READY   STATUS    RESTARTS   AGE   IP           NODE      NOMINATED NODE   READINESS GATES
virt-api-b7d659dff-hf7tj            1/1     Running   0          62m   10.244.0.6   kvs-cp1   <none>           <none>
virt-api-b7d659dff-n7dgk            1/1     Running   0          60m   10.244.2.8   kvs-cp3   <none>           <none>
virt-controller-6f48497865-qqw6d    1/1     Running   0          61m   10.244.1.5   kvs-cp2   <none>           <none>
virt-controller-6f48497865-t9w6v    1/1     Running   0          61m   10.244.0.7   kvs-cp1   <none>           <none>
virt-exportproxy-75fbd54d97-24z8t   1/1     Running   0          61m   10.244.1.6   kvs-cp2   <none>           <none>
virt-exportproxy-75fbd54d97-v2m2j   1/1     Running   0          61m   10.244.1.7   kvs-cp2   <none>           <none>
virt-handler-f4fgr                  1/1     Running   0          61m   10.244.0.8   kvs-cp1   <none>           <none>
virt-handler-j9xsd                  1/1     Running   0          61m   10.244.1.8   kvs-cp2   <none>           <none>
virt-handler-jkl6x                  1/1     Running   0          61m   10.244.2.7   kvs-cp3   <none>           <none>
virt-operator-6b7f7b7588-rhffw      1/1     Running   0          63m   10.244.2.5   kvs-cp3   <none>           <none>
virt-operator-6b7f7b7588-wf9t5      1/1     Running   0          63m   10.244.0.4   kvs-cp1   <none>           <none>
```

```sh
kubectl -n kubevirt get deploy,ds -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image'
```

Output on the integration cluster (2026-10-29):

```text
NAME               READY    IMAGE
virt-api           2        10.77.0.1:5000/kubevirt/virt-api@sha256:3b9821f4de2decd949a4e7fba4bdf724226c652544384195ac534b9daf03947a
virt-controller    2        10.77.0.1:5000/kubevirt/virt-controller@sha256:e3b93539f7842851fb18c45508542f5c842280e30a9f9a35aee15ad8a43ac6af
virt-exportproxy   2        10.77.0.1:5000/kubevirt/virt-exportproxy@sha256:08ae58dc5e2f7d70df82e138252444bb59bd1929758ba6a293c72e564efd6649
virt-operator      2        10.77.0.1:5000/kubevirt/virt-operator@sha256:7e27c9489846f1328ecba4006654c2938a4596ea1c7a6e0cef45287f4abfa078
virt-handler       <none>   10.77.0.1:5000/kubevirt/virt-handler@sha256:6136df8f03ae550fa9b376e0ca210f14be9f2b876c0cd90e44fec40965bff824
```

virt-handler runs as uid 0 on every node through the custom resource's patch, while its image's own user is not root:

```sh
kubectl -n kubevirt get ds virt-handler -o jsonpath='{range .spec.template.spec.initContainers[*]}init {.name}: {.securityContext}{"\n"}{end}{range .spec.template.spec.containers[*]}{.name}: {.securityContext}{"\n"}{end}'
```

Output on the integration cluster (2026-10-29):

```text
init virt-launcher: {"privileged":true,"runAsUser":0}
virt-handler: {"privileged":true,"runAsUser":0,"seLinuxOptions":{"level":"s0"}}
```

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
ps -eo uid,args | grep -E '[v]irt-handler( |$)' | head -n 1 | awk '{print $1, $2}'
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
0 virt-handler
== kvs-cp2
0 virt-handler
== kvs-cp3
0 virt-handler
```

virt-operator, virt-api, virt-controller and virt-exportproxy have no shell. The user each process runs as, read from an
ephemeral debug container that shares its process namespace:

From an ephemeral debug container that shares the target's process namespace (the image has no shell; `DEBUG_IMAGE` is any image of your registry with a shell and grep):

```sh
kubectl debug -n kubevirt "$(kubectl get pods -n kubevirt -l kubevirt.io=virt-operator -o name | head -n 1)" -it --image="${DEBUG_IMAGE}" --target=virt-operator \
  --profile=general -- grep -E '^(Uid|Gid):' /proc/1/status
```

Output on the integration cluster (2026-10-29):

```text
Uid:	1001	1001	1001	1001
Gid:	1001	1001	1001	1001
```

From an ephemeral debug container that shares the target's process namespace (the image has no shell; `DEBUG_IMAGE` is any image of your registry with a shell and grep):

```sh
kubectl debug -n kubevirt "$(kubectl get pods -n kubevirt -l kubevirt.io=virt-api -o name | head -n 1)" -it --image="${DEBUG_IMAGE}" --target=virt-api \
  --profile=general -- grep -E '^(Uid|Gid):' /proc/1/status
```

Output on the integration cluster (2026-10-29):

```text
Uid:	1001	1001	1001	1001
Gid:	1001	1001	1001	1001
```

From an ephemeral debug container that shares the target's process namespace (the image has no shell; `DEBUG_IMAGE` is any image of your registry with a shell and grep):

```sh
kubectl debug -n kubevirt "$(kubectl get pods -n kubevirt -l kubevirt.io=virt-controller -o name | head -n 1)" -it --image="${DEBUG_IMAGE}" --target=virt-controller \
  --profile=general -- grep -E '^(Uid|Gid):' /proc/1/status
```

Output on the integration cluster (2026-10-29):

```text
Uid:	1001	1001	1001	1001
Gid:	1001	1001	1001	1001
```

From an ephemeral debug container that shares the target's process namespace (the image has no shell; `DEBUG_IMAGE` is any image of your registry with a shell and grep):

```sh
kubectl debug -n kubevirt "$(kubectl get pods -n kubevirt -l kubevirt.io=virt-exportproxy -o name | head -n 1)" -it --image="${DEBUG_IMAGE}" --target=exportproxy \
  --profile=general -- grep -E '^(Uid|Gid):' /proc/1/status
```

Output on the integration cluster (2026-10-29):

```text
Uid:	1001	1001	1001	1001
Gid:	1001	1001	1001	1001
```

An ephemeral debug container stays in its pod's spec, terminated, until the pod is replaced; Kubernetes cannot remove
one.

virt-exportproxy is part of the stack although nothing here exports a VM: virt-operator v1.9.1 deploys it
unconditionally and reports Available only once it runs
(`/kubernetesvmstack/install/kubevirt/README.md`). virt-template
was found missing on the integration cluster, where KubeVirt stayed in phase Deploying until the custom resource set
`virtTemplateDeployment.enabled: false`.

## A virtual machine from an existing disk

An existing disk image becomes a static local volume: the raw image as `disk.img` in a directory on one node, owned by
uid 107 (the user virt-launcher runs QEMU as), a PersistentVolume that names the directory and pins the node, a claim
bound to it, and a VirtualMachine that boots from the claim, with one NIC on the pod network and one on the host bridge.
The bundle's manifest, with what to do on the node first:

`/kubernetesvmstack/install/vm/local-disk-vm.yaml`:

```yaml
# A KubeVirt VM from an existing disk on a static local volume, for the Kubernetes VM Stack: the stack's VM disks are
# static local volumes that you fill yourself. One NIC on the pod network (masquerade) and one on a host bridge through
# Multus (network/nad-host-bridge.yaml in this bundle, bridge binding). Proven by the integration test, which renders
# this file.
#
# Before applying, on the node ${VM_NODE}:
#   1. the disk as a RAW image named disk.img in ${VM_DISK_DIR} (qemu-img convert -O raw <image> disk.img), owned by
#      107:107 (KubeVirt's virt-launcher runs the VM as uid 107) and mode 0660:
#        mkdir -p ${VM_DISK_DIR} && mv disk.img ${VM_DISK_DIR}/ && chown -R 107:107 ${VM_DISK_DIR} && chmod 0660 ${VM_DISK_DIR}/disk.img
#   2. the host bridge the NetworkAttachmentDefinition names (on every node the VM may run on; a local volume pins it
#      to ${VM_NODE}).
# The local PersistentVolume pins the VM to ${VM_NODE}: it cannot live-migrate, and it stops while that node is down.
#
# Placeholders (envsubst):
#   ${VM_NAME}        the VM's name (also names its PV/PVC: ${VM_NAME}-disk)
#   ${VM_NAMESPACE}   its namespace (the NetworkAttachmentDefinition must be in the same one)
#   ${VM_NODE}        the node holding the disk (kubernetes.io/hostname)
#   ${VM_DISK_DIR}    the directory holding disk.img on that node
#   ${VM_DISK_SIZE}   the PV/PVC size (at least the disk's virtual size), e.g. 1Gi
#   ${VM_CPUS}        vCPU cores
#   ${VM_MEMORY}      guest memory, e.g. 256Mi
#   ${NAD_NAME}       the NetworkAttachmentDefinition of the host bridge (host-bridge in nad-host-bridge.yaml)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-static
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${VM_NAME}-disk
spec:
  capacity: {storage: ${VM_DISK_SIZE}}
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-static
  volumeMode: Filesystem
  local: {path: ${VM_DISK_DIR}}
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions: [{key: kubernetes.io/hostname, operator: In, values: [${VM_NODE}]}]
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${VM_NAME}-disk
  namespace: ${VM_NAMESPACE}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-static
  volumeName: ${VM_NAME}-disk
  resources: {requests: {storage: ${VM_DISK_SIZE}}}
---
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: ${VM_NAME}
  namespace: ${VM_NAMESPACE}
spec:
  runStrategy: Always
  template:
    metadata:
      labels: {kubevirt.io/vm: ${VM_NAME}}
    spec:
      domain:
        cpu: {cores: ${VM_CPUS}}
        memory: {guest: ${VM_MEMORY}}
        devices:
          disks:
          - {name: rootdisk, disk: {bus: virtio}}
          - {name: cloudinit, disk: {bus: virtio}}
          interfaces:
          - {name: default, masquerade: {}}
          - {name: hostnet, bridge: {}}
      networks:
      - {name: default, pod: {}}
      - {name: hostnet, multus: {networkName: ${NAD_NAME}}}
      volumes:
      - {name: rootdisk, persistentVolumeClaim: {claimName: ${VM_NAME}-disk}}
      - name: cloudinit
        cloudInitNoCloud:
          userData: |
            #!/bin/sh
            # eth0 (pod network, masquerade) takes KubeVirt's DHCP at boot; eth1 (the host bridge) asks the bridge's
            # DHCP server for a lease, with whichever client the guest has. Replace with the guest's own cloud-config.
            ip link set eth1 up
            udhcpc -i eth1 -n -q -t 10 -T 3 2>/dev/null || dhclient -1 eth1 2>/dev/null || dhcpcd -1 eth1 2>/dev/null || true
```

The integration test placed CirrOS's disk on one node:

```sh
qemu-img convert -O raw cirros-0.6.3-x86_64-disk.img disk.img       # then copy disk.img to the node
sudo mkdir -p /var/lib/kvs-vm-disks/cirros
sudo mv disk.img /var/lib/kvs-vm-disks/cirros/disk.img
sudo chown -R 107:107 /var/lib/kvs-vm-disks/cirros
sudo chmod 0660 /var/lib/kvs-vm-disks/cirros/disk.img
```

This step is not re-run by the runbook check. The integration test ran it on 2026-10-29; its record shows:

```text
file format: raw
```

Filled in with sample values, the API server accepts the manifest (a server-side dry run: KubeVirt's admission checks
run, nothing is created):

In a directory that holds a copy of `/kubernetesvmstack/install/vm/local-disk-vm.yaml`:

```sh
export VM_NAME=runbook-example VM_NAMESPACE=default VM_DISK_DIR=/var/lib/vm-disks/runbook-example VM_DISK_SIZE=1Gi
export VM_CPUS=1 VM_MEMORY=256Mi NAD_NAME=host-bridge VM_NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
envsubst '${VM_NAME} ${VM_NAMESPACE} ${VM_NODE} ${VM_DISK_DIR} ${VM_DISK_SIZE} ${VM_CPUS} ${VM_MEMORY} ${NAD_NAME}' \
  < local-disk-vm.yaml | kubectl apply --dry-run=server -f -
```

Output on the integration cluster (2026-10-29):

```text
storageclass.storage.k8s.io/local-static unchanged (server dry run)
persistentvolume/runbook-example-disk created (server dry run)
persistentvolumeclaim/runbook-example-disk created (server dry run)
virtualmachine.kubevirt.io/runbook-example created (server dry run)
```

On the integration cluster the VM ran under KVM,
its console reached the guest's login prompt,
and its bridge NIC took an address from the LAN's DHCP server.
The virtual machines on the cluster at the time of the check:

```sh
kubectl get vm,vmi -A -o wide
```

Output on the integration cluster (2026-10-29):

```text
NAMESPACE   NAME                                    AGE   STATUS    READY
default     virtualmachine.kubevirt.io/kvs-cirros   58m   Running   True

NAMESPACE   NAME                                            AGE   PHASE     IP           NODENAME   READY   LIVE-MIGRATABLE   PAUSED
default     virtualmachineinstance.kubevirt.io/kvs-cirros   58m   Running   10.244.1.9   kvs-cp2    True    False             
```

A VM runs in a virt-launcher pod as uid 107, under KVM:

```sh
set -- $(kubectl get pods -A -l kubevirt.io=virt-launcher -o jsonpath='{.items[0].metadata.namespace} {.items[0].metadata.name}')
kubectl get pod -n "$1" "$2" -o jsonpath='{.spec.securityContext}{"\n"}{range .spec.containers[*]}{.name} {.image}{"\n"}{end}'
kubectl exec -n "$1" "$2" -c compute -- virsh -c 'qemu+unix:///session?socket=/var/run/libvirt/virtqemud-sock' dumpxml 1 | grep -m 1 '<domain type'
```

Output on the integration cluster (2026-10-29):

```text
{"fsGroup":107,"runAsGroup":107,"runAsNonRoot":true,"runAsUser":107}
compute 10.77.0.1:5000/kubevirt/virt-launcher@sha256:ae22cd3068d148beaef04c912cecab732bedac61a7ac538f6fbee8cb1d884904
<domain type='kvm' id='1'>
```

The stack's `virtctl` (v1.9.1) opens a VM's serial console with `virtctl console <vm>`, and starts and
stops a VM with `virtctl start <vm>` and `virtctl stop <vm>`:

```sh
virtctl version --client
```

Output on the integration cluster (2026-10-29):

```text
Client Version: version.Info{GitVersion:"v1.9.1", GitCommit:"c3d19093f9c7b843b3879b18dc088911c081c39e", GitTreeState:"clean", BuildDate:"2026-10-09T05:21:13Z", GoVersion:"go1.26.10", Compiler:"gc", Platform:"linux/amd64"}
```

A VM on a local volume cannot move to another node: when its node is down, the VM stays down until the node returns
(`/kubernetesvmstack/install/README.md`).

## Where the cluster keeps its state

- etcd holds the cluster's API objects, Secrets included, in `/var/lib/etcd` on each node. Only root can read that
  directory (`drwx------` in the output below).
- `/etc/kubernetes/pki` holds the cluster's certificate authorities and their keys. The directory itself is readable by
  every user (`drwxr-xr-x` below), so each private key is guarded by its own file's mode;
  `sudo ls -l /etc/kubernetes/pki /etc/kubernetes/pki/etcd` lists them.
- Virtual machine disks on local volumes live in their PersistentVolume's directory on one node.

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
sudo ls -ld /var/lib/etcd /etc/kubernetes/pki /var/lib/kubelet
sudo du -sh /var/lib/etcd
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
drwxr-xr-x  3 root root 4096 Oct 29 01:23 /etc/kubernetes/pki
drwx------  3 root root 4096 Oct 29 01:31 /var/lib/etcd
drwxr-xr-x 11 root root 4096 Oct 29 02:36 /var/lib/kubelet
137M	/var/lib/etcd
== kvs-cp2
drwxr-xr-x  3 root root 4096 Oct 29 01:25 /etc/kubernetes/pki
drwx------  3 root root 4096 Oct 29 01:25 /var/lib/etcd
drwxr-xr-x 11 root root 4096 Oct 29 02:36 /var/lib/kubelet
136M	/var/lib/etcd
== kvs-cp3
drwxr-xr-x  3 root root 4096 Oct 29 01:26 /etc/kubernetes/pki
drwx------  3 root root 4096 Oct 29 01:26 /var/lib/etcd
drwxr-xr-x 11 root root 4096 Oct 29 02:36 /var/lib/kubelet
137M	/var/lib/etcd
```

```sh
kubectl get pv -o wide
```

Output on the integration cluster (2026-10-29):

```text
NAME              CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                     STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE   VOLUMEMODE
kvs-cirros-disk   1Gi        RWO            Retain           Bound    default/kvs-cirros-disk   local-static   <unset>                          58m   Filesystem
```

## Backing up etcd

etcd runs as a static pod on every node, as root through its patch file; `etcdctl` and `etcdutl` are in its image
(etcd 3.7.3), so `crictl exec` reaches them on any node. The members and their health:

On a node (kvs-cp1):

```sh
ETCD=$(sudo crictl ps -q --name '^etcd$' | head -n 1)
sudo crictl exec "$ETCD" etcdctl --endpoints=https://127.0.0.1:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt \
  --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key member list -w table
sudo crictl exec "$ETCD" etcdctl --endpoints=https://127.0.0.1:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt \
  --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key endpoint health --cluster -w table
```

Output on the integration cluster (2026-10-29):

```text
┌──────────────────┬─────────┬─────────┬─────────────────────────┬─────────────────────────┬────────────┐
│        ID        │ STATUS  │  NAME   │       PEER ADDRS        │      CLIENT ADDRS       │ IS LEARNER │
├──────────────────┼─────────┼─────────┼─────────────────────────┼─────────────────────────┼────────────┤
│ 252902638f78db76 │ started │ kvs-cp1 │ https://10.77.0.11:2380 │ https://10.77.0.11:2379 │      false │
│ 66ceab29ada86722 │ started │ kvs-cp3 │ https://10.77.0.13:2380 │ https://10.77.0.13:2379 │      false │
│ 7bb4b24ed6c43083 │ started │ kvs-cp2 │ https://10.77.0.12:2380 │ https://10.77.0.12:2379 │      false │
└──────────────────┴─────────┴─────────┴─────────────────────────┴─────────────────────────┴────────────┘
┌─────────────────────────┬────────┬─────────────┬───────┐
│        ENDPOINT         │ HEALTH │    TOOK     │ ERROR │
├─────────────────────────┼────────┼─────────────┼───────┤
│ https://10.77.0.12:2379 │   true │ 31.595648ms │       │
│ https://10.77.0.11:2379 │   true │ 39.049244ms │       │
│ https://10.77.0.13:2379 │   true │ 43.425303ms │       │
└─────────────────────────┴────────┴─────────────┴───────┘
```

A snapshot is written into the data directory's mount (the host directory the etcd container writes to), checked,
restored into a scratch directory beside it to prove it restores (the running member reads only its own `member`
directory), and moved to a root-only backup directory on the node. A snapshot holds every Secret of the cluster: keep its copies root-only, off the node too.

On a node (kvs-cp1):

```sh
ETCD=$(sudo crictl ps -q --name '^etcd$' | head -n 1)
snap=snapshot-$(date -u +%Y%m%dT%H%M%SZ).db
sudo crictl exec "$ETCD" etcdctl --endpoints=https://127.0.0.1:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt \
  --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key snapshot save "/var/lib/etcd/$snap"
sudo crictl exec "$ETCD" etcdutl snapshot status "/var/lib/etcd/$snap" -w table
sudo crictl exec "$ETCD" etcdutl snapshot restore "/var/lib/etcd/$snap" --data-dir /var/lib/etcd/restore-check \
  && echo "Snapshot restored into a scratch directory"
sudo rm -rf /var/lib/etcd/restore-check
sudo install -d -m 700 /var/backups/etcd
sudo mv "/var/lib/etcd/$snap" /var/backups/etcd/
sudo ls -l /var/backups/etcd
```

Output on the integration cluster (2026-10-29):

```text
{"level":"info","ts":"2026-10-29T02:37:14.336682Z","caller":"snapshot/v3_snapshot.go:83","msg":"created temporary db file","path":"/var/lib/etcd/snapshot-20261029T023714Z.db.part"}
{"level":"info","ts":"2026-10-29T02:37:14.359232Z","logger":"client","caller":"v3@v3.7.3/maintenance.go:236","msg":"opened snapshot stream; downloading"}
{"level":"info","ts":"2026-10-29T02:37:14.371846Z","caller":"snapshot/v3_snapshot.go:96","msg":"fetching snapshot","endpoint":"https://127.0.0.1:2379"}
{"level":"info","ts":"2026-10-29T02:37:15.580201Z","logger":"client","caller":"v3@v3.7.3/maintenance.go:302","msg":"completed snapshot read; closing"}
{"level":"info","ts":"2026-10-29T02:37:15.661772Z","caller":"snapshot/v3_snapshot.go:111","msg":"fetched snapshot","endpoint":"https://127.0.0.1:2379","size":"15 MB","took":"1.323587161s","etcd-version":"3.7.0"}
{"level":"info","ts":"2026-10-29T02:37:15.662484Z","caller":"snapshot/v3_snapshot.go:121","msg":"saved","path":"/var/lib/etcd/snapshot-20261029T023714Z.db"}
Snapshot saved at /var/lib/etcd/snapshot-20261029T023714Z.db
Server version 3.7.0
┌──────────┬──────────┬────────────┬────────────┬─────────┐
│   HASH   │ REVISION │ TOTAL KEYS │ TOTAL SIZE │ VERSION │
├──────────┼──────────┼────────────┼────────────┼─────────┤
│ c68a9619 │    17359 │        671 │      15 MB │   3.7.0 │
└──────────┴──────────┴────────────┴────────────┴─────────┘
2026-10-29T02:37:16Z	info	snapshot/v3_snapshot.go:306	restoring snapshot	{"path": "/var/lib/etcd/snapshot-20261029T023714Z.db", "wal-dir": "/var/lib/etcd/restore-check/member/wal", "data-dir": "/var/lib/etcd/restore-check", "snap-dir": "/var/lib/etcd/restore-check/member/snap", "initial-memory-map-size": 10737418240}
2026-10-29T02:37:16Z	info	bbolt	backend/backend.go:213	Opening db file (/var/lib/etcd/restore-check/member/snap/db) with mode -rw------- and with options: {Timeout: 0s, NoGrowSync: false, NoFreelistSync: true, PreLoadFreelist: false, FreelistType: , ReadOnly: false, MmapFlags: 8000, InitialMmapSize: 10737418240, PageSize: 0, MaxSize: 0, NoSync: false, OpenFile: 0x0, Mlock: false, Logger: 0xb5cf8906a8, NoStatistics: false}
2026-10-29T02:37:16Z	info	bbolt	bbolt@v1.5.0/db.go:327	Opening bbolt db (/var/lib/etcd/restore-check/member/snap/db) successfully
2026-10-29T02:37:16Z	info	schema/membership.go:125	Trimming membership information from the backend...
2026-10-29T02:37:16Z	info	bbolt	backend/backend.go:213	Opening db file (/var/lib/etcd/restore-check/member/snap/db) with mode -rw------- and with options: {Timeout: 0s, NoGrowSync: false, NoFreelistSync: true, PreLoadFreelist: false, FreelistType: , ReadOnly: false, MmapFlags: 8000, InitialMmapSize: 10737418240, PageSize: 0, MaxSize: 0, NoSync: false, OpenFile: 0x0, Mlock: false, Logger: 0xb5cf890470, NoStatistics: false}
2026-10-29T02:37:16Z	info	bbolt	bbolt@v1.5.0/db.go:327	Opening bbolt db (/var/lib/etcd/restore-check/member/snap/db) successfully
2026-10-29T02:37:16Z	info	membership/cluster.go:408	added member	{"cluster-id": "cdf818194e3a8c32", "local-member-id": "0", "added-peer-id": "8e9e05c52164694d", "added-peer-peer-urls": ["http://localhost:2380"], "added-peer-is-learner": false}
2026-10-29T02:37:17Z	info	bbolt	backend/backend.go:213	Opening db file (/var/lib/etcd/restore-check/member/snap/db) with mode -rw------- and with options: {Timeout: 0s, NoGrowSync: false, NoFreelistSync: true, PreLoadFreelist: false, FreelistType: , ReadOnly: false, MmapFlags: 8000, InitialMmapSize: 10737418240, PageSize: 0, MaxSize: 0, NoSync: false, OpenFile: 0x0, Mlock: false, Logger: 0xb5cf58a068, NoStatistics: false}
2026-10-29T02:37:17Z	info	bbolt	bbolt@v1.5.0/db.go:327	Opening bbolt db (/var/lib/etcd/restore-check/member/snap/db) successfully
2026-10-29T02:37:17Z	info	snapshot/v3_snapshot.go:334	restored snapshot	{"path": "/var/lib/etcd/snapshot-20261029T023714Z.db", "wal-dir": "/var/lib/etcd/restore-check/member/wal", "data-dir": "/var/lib/etcd/restore-check", "snap-dir": "/var/lib/etcd/restore-check/member/snap", "initial-memory-map-size": 10737418240}
Snapshot restored into a scratch directory
total 14396
-rw------- 1 root root 14737440 Oct 29 02:37 snapshot-20261029T023714Z.db
```

## Restoring the whole cluster from a snapshot

Every step runs only if the one before it passed. The restore needs etcd running on every node: each node's step runs
`etcdutl` inside that node's etcd container and reads the cluster's members from it. This runbook does not cover
restoring a cluster in which etcd does not run on some node.

Every member is restored from one backup, kept as section "Backing up etcd" keeps it: each member gets a new data directory
written from it, then the control plane stops on every node, each member's data directory is swapped for its restored
one, and etcd, then the rest of the control plane, starts again. The cluster's state goes back to the moment of the
backup. The integration cluster ran this as a drill: it takes a fresh backup, then restores the newest kept backup,
which is that one, and a ConfigMap written before the backup and one written after it show which state came back. To
restore a backup you already keep, leave out the drill's own steps: the two markers, the drill's backup, and the marker
lines of the last step.

A marker before the backup:

```sh
kubectl delete configmap kf-restore-before --ignore-not-found
kubectl create configmap kf-restore-before --from-literal=at="$(date -u +%FT%TZ)"
```

Output on the integration cluster (2026-10-29):

```text
configmap/kf-restore-before created
```

The drill's backup, on the first node, taken as section "Backing up etcd" takes one and kept in the root-only
`/var/backups/etcd`:

On a node (kvs-cp1):

```sh
ETCD=$(sudo crictl ps -q --name '^etcd$' | head -n 1)
snap=snapshot-$(date -u +%Y%m%dT%H%M%SZ).db
sudo crictl exec "$ETCD" etcdctl --endpoints=https://127.0.0.1:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt \
  --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key snapshot save "/var/lib/etcd/$snap"
sudo install -d -m 700 /var/backups/etcd
sudo mv "/var/lib/etcd/$snap" /var/backups/etcd/ && sudo ls -l /var/backups/etcd
```

Output on the integration cluster (2026-10-29):

```text
{"level":"info","ts":"2026-10-29T13:41:51.106241Z","caller":"snapshot/v3_snapshot.go:83","msg":"created temporary db file","path":"/var/lib/etcd/snapshot-20261029T134149Z.db.part"}
{"level":"info","ts":"2026-10-29T13:41:51.186970Z","logger":"client","caller":"v3@v3.7.3/maintenance.go:236","msg":"opened snapshot stream; downloading"}
{"level":"info","ts":"2026-10-29T13:41:51.202651Z","caller":"snapshot/v3_snapshot.go:96","msg":"fetching snapshot","endpoint":"https://127.0.0.1:2379"}
{"level":"info","ts":"2026-10-29T13:41:52.118431Z","logger":"client","caller":"v3@v3.7.3/maintenance.go:302","msg":"completed snapshot read; closing"}
{"level":"info","ts":"2026-10-29T13:41:52.187534Z","caller":"snapshot/v3_snapshot.go:111","msg":"fetched snapshot","endpoint":"https://127.0.0.1:2379","size":"14 MB","took":"1.078762988s","etcd-version":"3.7.0"}
{"level":"info","ts":"2026-10-29T13:41:52.188241Z","caller":"snapshot/v3_snapshot.go:121","msg":"saved","path":"/var/lib/etcd/snapshot-20261029T134149Z.db"}
Snapshot saved at /var/lib/etcd/snapshot-20261029T134149Z.db
Server version 3.7.0
total 27912
-rw------- 1 root root 14737440 Oct 29 02:37 snapshot-20261029T023714Z.db
-rw------- 1 root root 13836320 Oct 29 13:41 snapshot-20261029T134149Z.db
```

A marker after the backup, which the restore must remove:

```sh
kubectl delete configmap kf-restore-after --ignore-not-found
kubectl create configmap kf-restore-after --from-literal=at="$(date -u +%FT%TZ)"
```

Output on the integration cluster (2026-10-29):

```text
configmap/kf-restore-after created
```

The backup to restore, copied on the node that keeps it into the data directory's mount as `restore.db`: `etcdutl`
runs inside the etcd container, which sees `/var/lib/etcd` and not `/var/backups/etcd`. The newest backup is taken (in
the drill, the one it has just taken); to restore another, set `b` to its file name. Its status shows the revision and
the number of keys it holds:

On a node (kvs-cp1):

```sh
b=$(sudo ls -1t /var/backups/etcd | grep '\.db$' | head -n 1)
[ -n "$b" ] || { echo "no backup in /var/backups/etcd"; exit 1; }
echo "the newest kept backup: /var/backups/etcd/$b"
sudo install -m 600 "/var/backups/etcd/$b" /var/lib/etcd/restore.db
sudo sha256sum "/var/backups/etcd/$b" /var/lib/etcd/restore.db
[ "$(sudo sha256sum "/var/backups/etcd/$b" /var/lib/etcd/restore.db | cut -c1-64 | sort -u | wc -l)" = 1 ] || exit 1
ETCD=$(sudo crictl ps -q --name '^etcd$' | head -n 1)
sudo crictl exec "$ETCD" etcdutl snapshot status /var/lib/etcd/restore.db -w table && echo "restore.db: the kept backup $b"
```

Output on the integration cluster (2026-10-29):

```text
the newest kept backup: /var/backups/etcd/snapshot-20261029T134149Z.db
7bd9bfe9975e07f6e5e8bd33752358fe7c5db5304b2c7166e8da80f20a8d5ab9  /var/backups/etcd/snapshot-20261029T134149Z.db
7bd9bfe9975e07f6e5e8bd33752358fe7c5db5304b2c7166e8da80f20a8d5ab9  /var/lib/etcd/restore.db
┌──────────┬──────────┬────────────┬────────────┬─────────┐
│   HASH   │ REVISION │ TOTAL KEYS │ TOTAL SIZE │ VERSION │
├──────────┼──────────┼────────────┼────────────┼─────────┤
│ ecefb3d3 │    33785 │        616 │      14 MB │   3.7.0 │
└──────────┴──────────┴────────────┴────────────┴─────────┘
restore.db: the kept backup snapshot-20261029T134149Z.db
```

`restore.db` to the other members, through the admin machine (it reaches each node as `ssh <node>`; these are the
integration cluster's node names). The snapshot holds every Secret of the cluster, so its copies stay root-only:

```sh
umask 077; d=$(mktemp -d)
ssh kvs-cp1 'sudo cat /var/lib/etcd/restore.db' > "$d/restore.db"
sha256sum "$d/restore.db" | cut -c1-64
for n in kvs-cp2 kvs-cp3; do
  ssh "$n" 'sudo sh -c "umask 077; cat > /var/lib/etcd/restore.db"' < "$d/restore.db"
  ssh "$n" 'sudo sha256sum /var/lib/etcd/restore.db' | cut -c1-64
done
rm -rf "$d"
echo "restore.db: copied to 2 nodes"
```

Output on the integration cluster (2026-10-29):

```text
7bd9bfe9975e07f6e5e8bd33752358fe7c5db5304b2c7166e8da80f20a8d5ab9
7bd9bfe9975e07f6e5e8bd33752358fe7c5db5304b2c7166e8da80f20a8d5ab9
7bd9bfe9975e07f6e5e8bd33752358fe7c5db5304b2c7166e8da80f20a8d5ab9
restore.db: copied to 2 nodes
```

On every node, while etcd still runs, a new data directory restored from the snapshot, with that member's own name and
peer address and the cluster's members (read from etcd and from the node's own etcd manifest). The restore raises the
revision and marks the old ones compacted, so a client still holding a revision from before the restore lists again
instead of watching from it:

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
ETCD=$(sudo crictl ps -q --name '^etcd$' | head -n 1)
C="--endpoints=https://127.0.0.1:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key"
CLUSTER=$(sudo crictl exec "$ETCD" etcdctl $C member list -w simple | awk -F', ' '{print $3 "=" $4}' | paste -sd, -)
NAME=$(sudo sed -n 's/.*--name=//p' /etc/kubernetes/manifests/etcd.yaml)
PEER=$(sudo sed -n 's/.*--initial-advertise-peer-urls=//p' /etc/kubernetes/manifests/etcd.yaml)
echo "member $NAME at $PEER; cluster $CLUSTER"
sudo rm -rf /var/lib/etcd/restored
sudo crictl exec "$ETCD" etcdutl snapshot restore /var/lib/etcd/restore.db --name "$NAME" --initial-cluster "$CLUSTER" \
  --initial-cluster-token kf-restore --initial-advertise-peer-urls "$PEER" --data-dir /var/lib/etcd/restored \
  --bump-revision 1000000000 --mark-compacted
sudo test -d /var/lib/etcd/restored/member && echo "restored: member $NAME"
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
member kvs-cp1 at https://10.77.0.11:2380; cluster kvs-cp1=https://10.77.0.11:2380,kvs-cp3=https://10.77.0.13:2380,kvs-cp2=https://10.77.0.12:2380
2026-10-29T13:42:06Z	info	snapshot/v3_snapshot.go:306	restoring snapshot	{"path": "/var/lib/etcd/restore.db", "wal-dir": "/var/lib/etcd/restored/member/wal", "data-dir": "/var/lib/etcd/restored", "snap-dir": "/var/lib/etcd/restored/member/snap", "initial-memory-map-size": 10737418240}
2026-10-29T13:42:07Z	info	bbolt	backend/backend.go:213	Opening db file (/var/lib/etcd/restored/member/snap/db) with mode -rw------- and with options: {Timeout: 0s, NoGrowSync: false, NoFreelistSync: true, PreLoadFreelist: false, FreelistType: , ReadOnly: false, MmapFlags: 8000, InitialMmapSize: 10737418240, PageSize: 0, MaxSize: 0, NoSync: false, OpenFile: 0x0, Mlock: false, Logger: 0x3d486531e9b0, NoStatistics: false}
2026-10-29T13:42:07Z	info	bbolt	bbolt@v1.5.0/db.go:327	Opening bbolt db (/var/lib/etcd/restored/member/snap/db) successfully
2026-10-29T13:42:07Z	info	schema/membership.go:125	Trimming membership information from the backend...
2026-10-29T13:42:07Z	info	bbolt	backend/backend.go:213	Opening db file (/var/lib/etcd/restored/member/snap/db) with mode -rw------- and with options: {Timeout: 0s, NoGrowSync: false, NoFreelistSync: true, PreLoadFreelist: false, FreelistType: , ReadOnly: false, MmapFlags: 8000, InitialMmapSize: 10737418240, PageSize: 0, MaxSize: 0, NoSync: false, OpenFile: 0x0, Mlock: false, Logger: 0x3d486531e048, NoStatistics: false}
2026-10-29T13:42:07Z	info	bbolt	bbolt@v1.5.0/db.go:327	Opening bbolt db (/var/lib/etcd/restored/member/snap/db) successfully
2026-10-29T13:42:07Z	info	snapshot/v3_snapshot.go:397	bumping latest revision	{"latest-revision": 33785, "bump-amount": 1000000000, "new-latest-revision": 1000033785}
2026-10-29T13:42:07Z	info	snapshot/v3_snapshot.go:414	marking revision compacted	{"revision": 1000033785}
2026-10-29T13:42:07Z	info	bbolt	backend/backend.go:213	Opening db file (/var/lib/etcd/restored/member/snap/db) with mode -rw------- and with options: {Timeout: 0s, NoGrowSync: false, NoFreelistSync: true, PreLoadFreelist: false, FreelistType: , ReadOnly: false, MmapFlags: 8000, InitialMmapSize: 10737418240, PageSize: 0, MaxSize: 0, NoSync: false, OpenFile: 0x0, Mlock: false, Logger: 0x3d486531e168, NoStatistics: false}
2026-10-29T13:42:07Z	info	bbolt	bbolt@v1.5.0/db.go:327	Opening bbolt db (/var/lib/etcd/restored/member/snap/db) successfully
2026-10-29T13:42:07Z	info	membership/cluster.go:408	added member	{"cluster-id": "b042fcc30528c9b4", "local-member-id": "0", "added-peer-id": "373bcc9e961d6a95", "added-peer-peer-urls": ["https://10.77.0.12:2380"], "added-peer-is-learner": false}
2026-10-29T13:42:07Z	info	membership/cluster.go:408	added member	{"cluster-id": "b042fcc30528c9b4", "local-member-id": "0", "added-peer-id": "e552263647e9824c", "added-peer-peer-urls": ["https://10.77.0.13:2380"], "added-peer-is-learner": false}
2026-10-29T13:42:07Z	info	membership/cluster.go:408	added member	{"cluster-id": "b042fcc30528c9b4", "local-member-id": "0", "added-peer-id": "f47aa0c9c58efe1a", "added-peer-peer-urls": ["https://10.77.0.11:2380"], "added-peer-is-learner": false}
2026-10-29T13:42:07Z	info	bbolt	backend/backend.go:213	Opening db file (/var/lib/etcd/restored/member/snap/db) with mode -rw------- and with options: {Timeout: 0s, NoGrowSync: false, NoFreelistSync: true, PreLoadFreelist: false, FreelistType: , ReadOnly: false, MmapFlags: 8000, InitialMmapSize: 10737418240, PageSize: 0, MaxSize: 0, NoSync: false, OpenFile: 0x0, Mlock: false, Logger: 0x3d486531e128, NoStatistics: false}
2026-10-29T13:42:07Z	info	bbolt	bbolt@v1.5.0/db.go:327	Opening bbolt db (/var/lib/etcd/restored/member/snap/db) successfully
2026-10-29T13:42:07Z	info	snapshot/v3_snapshot.go:334	restored snapshot	{"path": "/var/lib/etcd/restore.db", "wal-dir": "/var/lib/etcd/restored/member/wal", "data-dir": "/var/lib/etcd/restored", "snap-dir": "/var/lib/etcd/restored/member/snap", "initial-memory-map-size": 10737418240}
restored: member kvs-cp1
== kvs-cp2
member kvs-cp2 at https://10.77.0.12:2380; cluster kvs-cp1=https://10.77.0.11:2380,kvs-cp3=https://10.77.0.13:2380,kvs-cp2=https://10.77.0.12:2380
2026-10-29T13:42:09Z	info	snapshot/v3_snapshot.go:306	restoring snapshot	{"path": "/var/lib/etcd/restore.db", "wal-dir": "/var/lib/etcd/restored/member/wal", "data-dir": "/var/lib/etcd/restored", "snap-dir": "/var/lib/etcd/restored/member/snap", "initial-memory-map-size": 10737418240}
2026-10-29T13:42:09Z	info	bbolt	backend/backend.go:213	Opening db file (/var/lib/etcd/restored/member/snap/db) with mode -rw------- and with options: {Timeout: 0s, NoGrowSync: false, NoFreelistSync: true, PreLoadFreelist: false, FreelistType: , ReadOnly: false, MmapFlags: 8000, InitialMmapSize: 10737418240, PageSize: 0, MaxSize: 0, NoSync: false, OpenFile: 0x0, Mlock: false, Logger: 0xfa9364a6048, NoStatistics: false}
2026-10-29T13:42:09Z	info	bbolt	bbolt@v1.5.0/db.go:327	Opening bbolt db (/var/lib/etcd/restored/member/snap/db) successfully
2026-10-29T13:42:09Z	info	schema/membership.go:125	Trimming membership information from the backend...
2026-10-29T13:42:09Z	info	bbolt	backend/backend.go:213	Opening db file (/var/lib/etcd/restored/member/snap/db) with mode -rw------- and with options: {Timeout: 0s, NoGrowSync: false, NoFreelistSync: true, PreLoadFreelist: false, FreelistType: , ReadOnly: false, MmapFlags: 8000, InitialMmapSize: 10737418240, PageSize: 0, MaxSize: 0, NoSync: false, OpenFile: 0x0, Mlock: false, Logger: 0xfa9364a6100, NoStatistics: false}
2026-10-29T13:42:09Z	info	bbolt	bbolt@v1.5.0/db.go:327	Opening bbolt db (/var/lib/etcd/restored/member/snap/db) successfully
2026-10-29T13:42:09Z	info	snapshot/v3_snapshot.go:397	bumping latest revision	{"latest-revision": 33785, "bump-amount": 1000000000, "new-latest-revision": 1000033785}
2026-10-29T13:42:09Z	info	snapshot/v3_snapshot.go:414	marking revision compacted	{"revision": 1000033785}
2026-10-29T13:42:09Z	info	bbolt	backend/backend.go:213	Opening db file (/var/lib/etcd/restored/member/snap/db) with mode -rw------- and with options: {Timeout: 0s, NoGrowSync: false, NoFreelistSync: true, PreLoadFreelist: false, FreelistType: , ReadOnly: false, MmapFlags: 8000, InitialMmapSize: 10737418240, PageSize: 0, MaxSize: 0, NoSync: false, OpenFile: 0x0, Mlock: false, Logger: 0xfa9364a61a0, NoStatistics: false}
2026-10-29T13:42:09Z	info	bbolt	bbolt@v1.5.0/db.go:327	Opening bbolt db (/var/lib/etcd/restored/member/snap/db) successfully
2026-10-29T13:42:09Z	info	membership/cluster.go:408	added member	{"cluster-id": "b042fcc30528c9b4", "local-member-id": "0", "added-peer-id": "373bcc9e961d6a95", "added-peer-peer-urls": ["https://10.77.0.12:2380"], "added-peer-is-learner": false}
2026-10-29T13:42:09Z	info	membership/cluster.go:408	added member	{"cluster-id": "b042fcc30528c9b4", "local-member-id": "0", "added-peer-id": "e552263647e9824c", "added-peer-peer-urls": ["https://10.77.0.13:2380"], "added-peer-is-learner": false}
2026-10-29T13:42:09Z	info	membership/cluster.go:408	added member	{"cluster-id": "b042fcc30528c9b4", "local-member-id": "0", "added-peer-id": "f47aa0c9c58efe1a", "added-peer-peer-urls": ["https://10.77.0.11:2380"], "added-peer-is-learner": false}
2026-10-29T13:42:09Z	info	bbolt	backend/backend.go:213	Opening db file (/var/lib/etcd/restored/member/snap/db) with mode -rw------- and with options: {Timeout: 0s, NoGrowSync: false, NoFreelistSync: true, PreLoadFreelist: false, FreelistType: , ReadOnly: false, MmapFlags: 8000, InitialMmapSize: 10737418240, PageSize: 0, MaxSize: 0, NoSync: false, OpenFile: 0x0, Mlock: false, Logger: 0xfa9363ea0a0, NoStatistics: false}
2026-10-29T13:42:09Z	info	bbolt	bbolt@v1.5.0/db.go:327	Opening bbolt db (/var/lib/etcd/restored/member/snap/db) successfully
2026-10-29T13:42:09Z	info	snapshot/v3_snapshot.go:334	restored snapshot	{"path": "/var/lib/etcd/restore.db", "wal-dir": "/var/lib/etcd/restored/member/wal", "data-dir": "/var/lib/etcd/restored", "snap-dir": "/var/lib/etcd/restored/member/snap", "initial-memory-map-size": 10737418240}
restored: member kvs-cp2
== kvs-cp3
member kvs-cp3 at https://10.77.0.13:2380; cluster kvs-cp1=https://10.77.0.11:2380,kvs-cp3=https://10.77.0.13:2380,kvs-cp2=https://10.77.0.12:2380
2026-10-29T13:42:12Z	info	snapshot/v3_snapshot.go:306	restoring snapshot	{"path": "/var/lib/etcd/restore.db", "wal-dir": "/var/lib/etcd/restored/member/wal", "data-dir": "/var/lib/etcd/restored", "snap-dir": "/var/lib/etcd/restored/member/snap", "initial-memory-map-size": 10737418240}
2026-10-29T13:42:12Z	info	bbolt	backend/backend.go:213	Opening db file (/var/lib/etcd/restored/member/snap/db) with mode -rw------- and with options: {Timeout: 0s, NoGrowSync: false, NoFreelistSync: true, PreLoadFreelist: false, FreelistType: , ReadOnly: false, MmapFlags: 8000, InitialMmapSize: 10737418240, PageSize: 0, MaxSize: 0, NoSync: false, OpenFile: 0x0, Mlock: false, Logger: 0x23ee45b2c1f8, NoStatistics: false}
2026-10-29T13:42:12Z	info	bbolt	bbolt@v1.5.0/db.go:327	Opening bbolt db (/var/lib/etcd/restored/member/snap/db) successfully
2026-10-29T13:42:12Z	info	schema/membership.go:125	Trimming membership information from the backend...
2026-10-29T13:42:12Z	info	bbolt	backend/backend.go:213	Opening db file (/var/lib/etcd/restored/member/snap/db) with mode -rw------- and with options: {Timeout: 0s, NoGrowSync: false, NoFreelistSync: true, PreLoadFreelist: false, FreelistType: , ReadOnly: false, MmapFlags: 8000, InitialMmapSize: 10737418240, PageSize: 0, MaxSize: 0, NoSync: false, OpenFile: 0x0, Mlock: false, Logger: 0x23ee45b2c180, NoStatistics: false}
2026-10-29T13:42:12Z	info	bbolt	bbolt@v1.5.0/db.go:327	Opening bbolt db (/var/lib/etcd/restored/member/snap/db) successfully
2026-10-29T13:42:12Z	info	snapshot/v3_snapshot.go:397	bumping latest revision	{"latest-revision": 33785, "bump-amount": 1000000000, "new-latest-revision": 1000033785}
2026-10-29T13:42:12Z	info	snapshot/v3_snapshot.go:414	marking revision compacted	{"revision": 1000033785}
2026-10-29T13:42:12Z	info	bbolt	backend/backend.go:213	Opening db file (/var/lib/etcd/restored/member/snap/db) with mode -rw------- and with options: {Timeout: 0s, NoGrowSync: false, NoFreelistSync: true, PreLoadFreelist: false, FreelistType: , ReadOnly: false, MmapFlags: 8000, InitialMmapSize: 10737418240, PageSize: 0, MaxSize: 0, NoSync: false, OpenFile: 0x0, Mlock: false, Logger: 0x23ee45b2c218, NoStatistics: false}
2026-10-29T13:42:12Z	info	bbolt	bbolt@v1.5.0/db.go:327	Opening bbolt db (/var/lib/etcd/restored/member/snap/db) successfully
2026-10-29T13:42:12Z	info	membership/cluster.go:408	added member	{"cluster-id": "b042fcc30528c9b4", "local-member-id": "0", "added-peer-id": "373bcc9e961d6a95", "added-peer-peer-urls": ["https://10.77.0.12:2380"], "added-peer-is-learner": false}
2026-10-29T13:42:12Z	info	membership/cluster.go:408	added member	{"cluster-id": "b042fcc30528c9b4", "local-member-id": "0", "added-peer-id": "e552263647e9824c", "added-peer-peer-urls": ["https://10.77.0.13:2380"], "added-peer-is-learner": false}
2026-10-29T13:42:12Z	info	membership/cluster.go:408	added member	{"cluster-id": "b042fcc30528c9b4", "local-member-id": "0", "added-peer-id": "f47aa0c9c58efe1a", "added-peer-peer-urls": ["https://10.77.0.11:2380"], "added-peer-is-learner": false}
2026-10-29T13:42:12Z	info	bbolt	backend/backend.go:213	Opening db file (/var/lib/etcd/restored/member/snap/db) with mode -rw------- and with options: {Timeout: 0s, NoGrowSync: false, NoFreelistSync: true, PreLoadFreelist: false, FreelistType: , ReadOnly: false, MmapFlags: 8000, InitialMmapSize: 10737418240, PageSize: 0, MaxSize: 0, NoSync: false, OpenFile: 0x0, Mlock: false, Logger: 0x23ee45c00120, NoStatistics: false}
2026-10-29T13:42:12Z	info	bbolt	bbolt@v1.5.0/db.go:327	Opening bbolt db (/var/lib/etcd/restored/member/snap/db) successfully
2026-10-29T13:42:12Z	info	snapshot/v3_snapshot.go:334	restored snapshot	{"path": "/var/lib/etcd/restore.db", "wal-dir": "/var/lib/etcd/restored/member/wal", "data-dir": "/var/lib/etcd/restored", "snap-dir": "/var/lib/etcd/restored/member/snap", "initial-memory-map-size": 10737418240}
restored: member kvs-cp3
```

The control plane stops on every node (kubelet stops a static pod whose manifest leaves its directory):

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
sudo install -d -m 700 /etc/kubernetes/restore-stopped
for m in kube-apiserver kube-controller-manager kube-scheduler etcd; do sudo mv /etc/kubernetes/manifests/$m.yaml /etc/kubernetes/restore-stopped/; done
for i in $(seq 1 60); do [ -z "$(sudo crictl ps -q --name '^(etcd|kube-apiserver|kube-controller-manager|kube-scheduler)$')" ] && break; sleep 5; done
[ -z "$(sudo crictl ps -q --name '^(etcd|kube-apiserver|kube-controller-manager|kube-scheduler)$')" ] && echo "control plane stopped"
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
control plane stopped
== kvs-cp2
control plane stopped
== kvs-cp3
control plane stopped
```

On every node, the restored data directory replaces the member's own, which is kept aside; `restore.db` is removed,
and the backup stays in `/var/backups/etcd`:

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
sudo test -d /var/lib/etcd/restored/member || { echo "no restored data directory: nothing swapped"; exit 1; }
old=/var/lib/etcd-pre-restore-$(date -u +%Y%m%dT%H%M%SZ)
sudo install -d -m 700 "$old"
sudo mv /var/lib/etcd/member "$old/"
sudo mv /var/lib/etcd/restored/member /var/lib/etcd/member
sudo rmdir /var/lib/etcd/restored
sudo rm -f /var/lib/etcd/restore.db
sudo ls -ld /var/lib/etcd/member "$old/member" && echo "data directory: restored"
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
drwx------ 4 root root 4096 Oct 29 11:17 /var/lib/etcd-pre-restore-20261029T134355Z/member
drwx------ 4 root root 4096 Oct 29 13:42 /var/lib/etcd/member
data directory: restored
== kvs-cp2
drwx------ 4 root root 4096 Oct 29 11:09 /var/lib/etcd-pre-restore-20261029T134357Z/member
drwx------ 4 root root 4096 Oct 29 13:42 /var/lib/etcd/member
data directory: restored
== kvs-cp3
drwx------ 4 root root 4096 Oct 29 11:11 /var/lib/etcd-pre-restore-20261029T134359Z/member
drwx------ 4 root root 4096 Oct 29 13:42 /var/lib/etcd/member
data directory: restored
```

etcd starts again on every node, and the three members form the restored cluster:

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
sudo mv /etc/kubernetes/restore-stopped/etcd.yaml /etc/kubernetes/manifests/ && echo "etcd manifest back"
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
etcd manifest back
== kvs-cp2
etcd manifest back
== kvs-cp3
etcd manifest back
```

On a node (kvs-cp1):

```sh
C="--endpoints=https://127.0.0.1:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key"
for i in $(seq 1 120); do
  ETCD=$(sudo crictl ps -q --name '^etcd$' | head -n 1)
  [ -n "$ETCD" ] && sudo crictl exec "$ETCD" etcdctl $C endpoint health --cluster >/dev/null 2>&1 && break
  sleep 5
done
sudo crictl exec "$ETCD" etcdctl $C member list -w table
sudo crictl exec "$ETCD" etcdctl $C endpoint health --cluster -w table
```

Output on the integration cluster (2026-10-29):

```text
┌──────────────────┬─────────┬─────────┬─────────────────────────┬─────────────────────────┬────────────┐
│        ID        │ STATUS  │  NAME   │       PEER ADDRS        │      CLIENT ADDRS       │ IS LEARNER │
├──────────────────┼─────────┼─────────┼─────────────────────────┼─────────────────────────┼────────────┤
│ 373bcc9e961d6a95 │ started │ kvs-cp2 │ https://10.77.0.12:2380 │ https://10.77.0.12:2379 │      false │
│ e552263647e9824c │ started │ kvs-cp3 │ https://10.77.0.13:2380 │ https://10.77.0.13:2379 │      false │
│ f47aa0c9c58efe1a │ started │ kvs-cp1 │ https://10.77.0.11:2380 │ https://10.77.0.11:2379 │      false │
└──────────────────┴─────────┴─────────┴─────────────────────────┴─────────────────────────┴────────────┘
┌─────────────────────────┬────────┬─────────────┬───────┐
│        ENDPOINT         │ HEALTH │    TOOK     │ ERROR │
├─────────────────────────┼────────┼─────────────┼───────┤
│ https://10.77.0.11:2379 │   true │ 24.909651ms │       │
│ https://10.77.0.12:2379 │   true │ 36.703051ms │       │
│ https://10.77.0.13:2379 │   true │ 50.017505ms │       │
└─────────────────────────┴────────┴─────────────┴───────┘
```

Then the rest of the control plane, and kubelet restarted so that nothing keeps state from before the restore:

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
for m in kube-apiserver kube-controller-manager kube-scheduler; do sudo mv /etc/kubernetes/restore-stopped/$m.yaml /etc/kubernetes/manifests/; done
sudo rmdir /etc/kubernetes/restore-stopped
sudo systemctl restart kubelet
echo "control plane back"
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
control plane back
== kvs-cp2
control plane back
== kvs-cp3
control plane back
```

The API answers on the control-plane address again, every node is Ready, the marker from before the snapshot is there
and the one from after it is gone, and the virtual machines run:

```sh
for i in $(seq 1 120); do kubectl get --raw=/readyz >/dev/null 2>&1 && break; sleep 5; done
kubectl get --raw=/readyz; echo
kubectl wait --for=condition=Ready node --all --timeout=600s
kubectl get nodes
```

Output on the integration cluster (2026-10-29):

```text
ok
node/kvs-cp1 condition met
node/kvs-cp2 condition met
node/kvs-cp3 condition met
NAME      STATUS   ROLES           AGE    VERSION
kvs-cp1   Ready    control-plane   156m   v1.36.6
kvs-cp2   Ready    control-plane   154m   v1.36.6
kvs-cp3   Ready    control-plane   152m   v1.36.6
```

```sh
kubectl get configmap kf-restore-before -o jsonpath='{.metadata.name}: written {.data.at}{"\n"}'
if kubectl get configmap kf-restore-after >/dev/null 2>&1; then echo "kf-restore-after: present, the restore did not take"; exit 1; fi
echo "kf-restore-after: absent (written after the snapshot)"
for i in $(seq 1 120); do
  p=$(kubectl get vmi -A -o jsonpath='{.items[*].status.phase}')
  [ -n "$p" ] && [ -z "$(echo "$p" | tr ' ' '\n' | grep -vx Running)" ] && break; sleep 5
done
kubectl get vmi -A
[ -n "$p" ] && [ -z "$(echo "$p" | tr ' ' '\n' | grep -vx Running)" ] && echo "virtual machines: all Running"
```

Output on the integration cluster (2026-10-29):

```text
kf-restore-before: written 2026-10-29T13:41:47Z
kf-restore-after: absent (written after the snapshot)
NAMESPACE   NAME         AGE    PHASE     IP           NODENAME   READY
default     kvs-cirros   118m   Running   10.244.1.9   kvs-cp2    True
virtual machines: all Running
```

## Certificates

kubeadm's certificates on each node, and when they expire:

On each node, as the administrator user (kvs-cp1, kvs-cp2, kvs-cp3):

```sh
sudo kubeadm certs check-expiration
```

Output on the integration cluster (2026-10-29):

```text
== kvs-cp1
[check-expiration] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[check-expiration] Use 'kubeadm init phase upload-config kubeadm --config your-config-file' to re-upload it.

CERTIFICATE                EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                 Oct 29, 2027 01:23 UTC   364d            ca                      no      
apiserver                  Oct 29, 2027 01:23 UTC   364d            ca                      no      
apiserver-etcd-client      Oct 29, 2027 01:23 UTC   364d            etcd-ca                 no      
apiserver-kubelet-client   Oct 29, 2027 01:23 UTC   364d            ca                      no      
controller-manager.conf    Oct 29, 2027 01:23 UTC   364d            ca                      no      
etcd-healthcheck-client    Oct 29, 2027 01:23 UTC   364d            etcd-ca                 no      
etcd-peer                  Oct 29, 2027 01:23 UTC   364d            etcd-ca                 no      
etcd-server                Oct 29, 2027 01:23 UTC   364d            etcd-ca                 no      
front-proxy-client         Oct 29, 2027 01:23 UTC   364d            front-proxy-ca          no      
scheduler.conf             Oct 29, 2027 01:23 UTC   364d            ca                      no      
super-admin.conf           Oct 29, 2027 01:23 UTC   364d            ca                      no      

CERTIFICATE AUTHORITY   EXPIRES                  RESIDUAL TIME   EXTERNALLY MANAGED
ca                      Oct 26, 2036 01:23 UTC   9y              no      
etcd-ca                 Oct 26, 2036 01:23 UTC   9y              no      
front-proxy-ca          Oct 26, 2036 01:23 UTC   9y              no      
== kvs-cp2
[check-expiration] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[check-expiration] Use 'kubeadm init phase upload-config kubeadm --config your-config-file' to re-upload it.

CERTIFICATE                  EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                   Oct 29, 2027 01:24 UTC   364d            ca                      no      
apiserver                    Oct 29, 2027 01:24 UTC   364d            ca                      no      
apiserver-etcd-client        Oct 29, 2027 01:24 UTC   364d            etcd-ca                 no      
apiserver-kubelet-client     Oct 29, 2027 01:24 UTC   364d            ca                      no      
controller-manager.conf      Oct 29, 2027 01:24 UTC   364d            ca                      no      
etcd-healthcheck-client      Oct 29, 2027 01:24 UTC   364d            etcd-ca                 no      
etcd-peer                    Oct 29, 2027 01:24 UTC   364d            etcd-ca                 no      
etcd-server                  Oct 29, 2027 01:24 UTC   364d            etcd-ca                 no      
front-proxy-client           Oct 29, 2027 01:24 UTC   364d            front-proxy-ca          no      
scheduler.conf               Oct 29, 2027 01:24 UTC   364d            ca                      no      
!MISSING! super-admin.conf                                                                    

CERTIFICATE AUTHORITY   EXPIRES                  RESIDUAL TIME   EXTERNALLY MANAGED
ca                      Oct 26, 2036 01:23 UTC   9y              no      
etcd-ca                 Oct 26, 2036 01:23 UTC   9y              no      
front-proxy-ca          Oct 26, 2036 01:23 UTC   9y              no      
== kvs-cp3
[check-expiration] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[check-expiration] Use 'kubeadm init phase upload-config kubeadm --config your-config-file' to re-upload it.

CERTIFICATE                  EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                   Oct 29, 2027 01:25 UTC   364d            ca                      no      
apiserver                    Oct 29, 2027 01:25 UTC   364d            ca                      no      
apiserver-etcd-client        Oct 29, 2027 01:25 UTC   364d            etcd-ca                 no      
apiserver-kubelet-client     Oct 29, 2027 01:25 UTC   364d            ca                      no      
controller-manager.conf      Oct 29, 2027 01:25 UTC   364d            ca                      no      
etcd-healthcheck-client      Oct 29, 2027 01:25 UTC   364d            etcd-ca                 no      
etcd-peer                    Oct 29, 2027 01:25 UTC   364d            etcd-ca                 no      
etcd-server                  Oct 29, 2027 01:25 UTC   364d            etcd-ca                 no      
front-proxy-client           Oct 29, 2027 01:25 UTC   364d            front-proxy-ca          no      
scheduler.conf               Oct 29, 2027 01:25 UTC   364d            ca                      no      
!MISSING! super-admin.conf                                                                    

CERTIFICATE AUTHORITY   EXPIRES                  RESIDUAL TIME   EXTERNALLY MANAGED
ca                      Oct 26, 2036 01:23 UTC   9y              no      
etcd-ca                 Oct 26, 2036 01:23 UTC   9y              no      
front-proxy-ca          Oct 26, 2036 01:23 UTC   9y              no      
```

`/etc/kubernetes/super-admin.conf` exists only on the node where `kubeadm init` ran (here kvs-cp1): `kubeadm init` writes
it and `kubeadm join` does not. So on every other node `kubeadm certs check-expiration` lists
`!MISSING! super-admin.conf`, as kvs-cp2 and kvs-cp3 do above, and `kubeadm certs renew all` prints
`MISSING! certificate embedded in the kubeconfig file for the super-admin`. Both are expected and need nothing done.

kubelet renews its own client certificate:

On a node (kvs-cp1):

```sh
sudo grep -E '^(rotateCertificates|serverTLSBootstrap):' /var/lib/kubelet/config.yaml
```

Output on the integration cluster (2026-10-29):

```text
rotateCertificates: true
```

## Renewing the control-plane certificates

Renew on one node at a time. `kubeadm certs renew all` writes new certificates and kubeconfig files; the static pods
read them only when they restart, so their manifests are moved out and back (kubelet stops the pods, then starts them
again), and the node's API server is checked before the next node. The run below is on kvs-cp3, which has no
`super-admin.conf`, so the renewal reports that kubeconfig as missing; that is expected (section "Certificates"):

On a node (kvs-cp3):

```sh
ip=$(sudo sed -n 's/.*--advertise-address=//p' /etc/kubernetes/manifests/kube-apiserver.yaml)
sudo kubeadm certs renew all
for m in kube-apiserver kube-controller-manager kube-scheduler etcd; do sudo mv /etc/kubernetes/manifests/$m.yaml /etc/kubernetes/$m.yaml.renew; done
sleep 30
for m in kube-apiserver kube-controller-manager kube-scheduler etcd; do sudo mv /etc/kubernetes/$m.yaml.renew /etc/kubernetes/manifests/$m.yaml; done
ready=
for i in $(seq 1 60); do sudo kubectl --kubeconfig /etc/kubernetes/admin.conf --server "https://$ip:6443" get --raw=/readyz >/dev/null 2>&1 && { ready=1; break; }; sleep 5; done
[ -n "$ready" ] || { echo "API server on $ip not ready after the restart"; exit 1; }
echo "API server on $ip ready"
sudo kubeadm certs check-expiration | head -n 12
```

Output on the integration cluster (2026-10-29):

```text
[renew] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[renew] Use 'kubeadm init phase upload-config kubeadm --config your-config-file' to re-upload it.

certificate embedded in the kubeconfig file for the admin to use and for kubeadm itself renewed
certificate for serving the Kubernetes API renewed
certificate the apiserver uses to access etcd renewed
certificate for the API server to connect to kubelet renewed
certificate embedded in the kubeconfig file for the controller manager to use renewed
certificate for liveness probes to healthcheck etcd renewed
certificate for etcd nodes to communicate with each other renewed
certificate for serving etcd renewed
certificate for the front proxy client renewed
certificate embedded in the kubeconfig file for the scheduler manager to use renewed
MISSING! certificate embedded in the kubeconfig file for the super-admin

Done renewing certificates. You must restart the kube-apiserver, kube-controller-manager, kube-scheduler and etcd, so that they can use the new certificates.
API server on 10.77.0.13 ready
[check-expiration] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[check-expiration] Use 'kubeadm init phase upload-config kubeadm --config your-config-file' to re-upload it.

CERTIFICATE                  EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                   Oct 29, 2027 02:37 UTC   364d            ca                      no      
apiserver                    Oct 29, 2027 02:37 UTC   364d            ca                      no      
apiserver-etcd-client        Oct 29, 2027 02:37 UTC   364d            etcd-ca                 no      
apiserver-kubelet-client     Oct 29, 2027 02:37 UTC   364d            ca                      no      
controller-manager.conf      Oct 29, 2027 02:37 UTC   364d            ca                      no      
etcd-healthcheck-client      Oct 29, 2027 02:37 UTC   364d            etcd-ca                 no      
etcd-peer                    Oct 29, 2027 02:37 UTC   364d            etcd-ca                 no      
etcd-server                  Oct 29, 2027 02:37 UTC   364d            etcd-ca                 no      
```

The cluster after the renewal: every node Ready, the virtual machines still running:

```sh
kubectl wait --for=condition=Ready node --all --timeout=600s
kubectl get nodes
kubectl get vmi -A
p=$(kubectl get vmi -A -o jsonpath='{.items[*].status.phase}')
[ -n "$p" ] && [ -z "$(echo "$p" | tr ' ' '\n' | grep -vx Running)" ] && echo "virtual machines: all Running"
```

Output on the integration cluster (2026-10-29):

```text
node/kvs-cp1 condition met
node/kvs-cp2 condition met
node/kvs-cp3 condition met
NAME      STATUS   ROLES           AGE   VERSION
kvs-cp1   Ready    control-plane   74m   v1.36.6
kvs-cp2   Ready    control-plane   72m   v1.36.6
kvs-cp3   Ready    control-plane   71m   v1.36.6
NAMESPACE   NAME         AGE   PHASE     IP           NODENAME   READY
default     kvs-cirros   59m   Running   10.244.1.9   kvs-cp2    True
virtual machines: all Running
```

## Upgrades

`kubeadm-config.yaml`'s UpgradeConfiguration carries what an upgrade needs on this stack: the patch files (root for the
static pods) and the kube-proxy skip:

`/kubernetesvmstack/install/controlplane/kubeadm-config.yaml` (part):

```yaml
kind: UpgradeConfiguration
apply:
  kubernetesVersion: v1.36.6
  skipPhases:
  - addon/kube-proxy
  patches:
    directory: /etc/kubernetes/patches
node:
  patches:
    directory: /etc/kubernetes/patches
```

The cluster runs Kubernetes v1.36.6, the 1.36 patch the stack's pin manifest names (the latest when
it was pinned, `/kubernetesvmstack/kubevirt-stack.json`), so no patch upgrade has been run on
it yet. What kubeadm plans
for this version, and what a dry run of the upgrade with the stack's configuration would do (kubeadm's preflight
checks included; nothing is changed):

On a node (kvs-cp1):

```sh
sudo kubeadm upgrade plan "$(kubeadm version -o short)"
```

Output on the integration cluster (2026-10-29):

```text
[preflight] Running pre-flight checks.
[upgrade/config] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[upgrade/config] Use 'kubeadm init phase upload-config kubeadm --config your-config-file' to re-upload it.
[upgrade] Running cluster health checks
[upgrade] Fetching available versions to upgrade to
[upgrade/versions] Cluster version: 1.36.6
[upgrade/versions] kubeadm version: v1.36.6
[upgrade/versions] Target version: v1.36.6
[upgrade/versions] Latest version in the v1.36 series: v1.36.6
```

On a node (kvs-cp1):

```sh
set -o pipefail
sudo kubeadm upgrade apply --config /root/kubeadm-config.yaml --dry-run --yes 2>&1 | tail -n 40
```

Output on the integration cluster (2026-10-29):

```text
[... 10 earlier line(s) not shown; the full output is in the run's evidence ...]
  verbs:
  - list
  - watch
- apiGroups:
  - discovery.k8s.io
  resources:
  - endpointslices
  verbs:
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:coredns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:coredns
subjects:
- kind: ServiceAccount
  name: coredns
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: coredns
  namespace: kube-system
[upgrade/successful] Finished dryrunning successfully!
```

The move to Kubernetes 1.37 waits for a KubeVirt release that supports it: KubeVirt 1.9 supports Kubernetes 1.34 to
1.36, and no KubeVirt release supports 1.37 yet
(`/kubernetesvmstack/kubevirt-stack.json`).
containerd's 2.3 line covers both 1.36 and 1.37
(`/kubernetesvmstack/kubevirt-stack.json`).

## The registry credential and containerd

`install-node.sh` gives containerd the registry's credential in `/etc/containerd/config.toml`, under
`registry.configs.<host>.auth`, because kubelet pulls the static pods' images and the sandbox image through CRI, where
image pull secrets do not apply. containerd 2.x deprecates that setting; what containerd itself reports on a node:

On a node (kvs-cp1):

```sh
sudo ctr deprecations list
```

Output on the integration cluster (2026-10-29):

```text
ID                                                LAST OCCURRENCE                   MESSAGE    
io.containerd.deprecation/cri-registry-configs    2026-10-29T01:31:21.202454799Z    The `configs` property of `[plugins."io.containerd.grpc.v1.cri".registry]` is deprecated since containerd v1.5 and will be removed in containerd v2.4. Use `config_path` instead.
```

The sections of the node's containerd configuration (values not shown; the file is root-only):

On a node (kvs-cp1):

```sh
sudo grep -nE '^\s*\[' /etc/containerd/config.toml
```

Output on the integration cluster (2026-10-29):

```text
9:[plugins.'io.containerd.cri.v1.images']
10:  [plugins.'io.containerd.cri.v1.images'.pinned_images]
13:  [plugins.'io.containerd.cri.v1.images'.registry]
18:[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc]
20:  [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
33:[plugins.'io.containerd.cri.v1.images'.registry.configs.'10.77.0.1:5000'.auth]
```

The setting that replaces it is a kubelet image credential provider; this edition of the stack does not ship one
(`/kubernetesvmstack/install/node/install-node.sh`), so containerd stays on a release that still
reads the deprecated setting until it does.

## Troubleshooting

Pods that are not running, and the latest warnings:

```sh
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded -o wide
```

Output on the integration cluster (2026-10-29):

```text
No resources found
```

```sh
kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -n 20
```

Output on the integration cluster (2026-10-29):

```text
NAMESPACE     LAST SEEN   TYPE      REASON                   OBJECT                         MESSAGE
kubevirt      61m         Warning   FailedCreatePodSandBox   pod/virt-api-b7d659dff-n7dgk   Failed to create pod sandbox: rpc error: code = Unknown desc = failed to setup network for sandbox "a536d44922f0f2852c6be250065726ef19131fae3a6ed1c397c821524d206821": plugin type="multus" failed (add): Multus: [kubevirt/virt-api-b7d659dff-n7dgk/d908378d-aebe-4ffa-a91b-a68ace7c26ce]: error waiting for pod: Get "https://10.96.0.1:443/api/v1/namespaces/kubevirt/pods/virt-api-b7d659dff-n7dgk?timeout=1m0s": context deadline exceeded
kube-system   66s         Warning   Unhealthy                pod/kube-scheduler-kvs-cp3     Readiness probe failed: Get "https://127.0.0.1:10259/readyz": dial tcp 127.0.0.1:10259: connect: connection refused
kube-system   65s         Warning   Unhealthy                pod/kube-apiserver-kvs-cp3     Readiness probe failed: HTTP probe failed with statuscode: 500
```

### An image does not pull

Every pull of docker.io, registry.k8s.io and quay.io goes to your registry and nowhere else (the `hosts.toml` files in
section "The local registry and mirroring" send each one there, with no public fallback), so an image that was not mirrored fails to pull, as one
from quay.io did on purpose during the node bundle's test.
Mirror it with `mirror-images.sh --only <slug>`, or remove whatever names it.

### KubeVirt stays in phase Deploying

virt-operator waits for every component it deploys. On the integration cluster it waited for virt-template, whose
images the stack does not ship, until the custom resource set
`virtTemplateDeployment.enabled: false`.
`kubectl -n kubevirt get pods` shows the component that does not start, and its events say why.

### Cluster DNS stops when one node goes down

Both CoreDNS replicas are on that node: spread them (section "Spreading CoreDNS over the nodes").

### A component exits right after its pod definition changed

Every image's default user is non-root (each image's user is listed in section "What the stack installs"), and only root can
read `/var/lib/etcd` (section "Where the cluster keeps its state"). A static pod without its patch file, or a DaemonSet without its `runAsUser: 0`,
starts the component as its image's user. Compare the pod with the install file it came from.

### The registry container reports unhealthy while it serves

`readystack/registry`'s own health probe asks `http://127.0.0.1:5000/`, so with the registry on another address and TLS
on, Docker reports it unhealthy while it serves
(`/kubernetesvmstack/install/README.md`).
The bundle's README shows how to ask it directly.

### A node is lost

The control-plane address moves to another node and etcd keeps its quorum with two of three members; the integration
test showed both when it destroyed the node that held the address.
Virtual machines on that node's local volumes stay down until it returns.
