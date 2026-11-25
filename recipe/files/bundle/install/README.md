# Kubernetes VM Stack: install bundle

A three-node kubeadm v1.36.6 cluster (all three nodes control-plane, etcd stacked) behind a kube-vip virtual IP, with
flannel, Multus and KubeVirt v1.9.1. Every host pulls only from a local registry, and every image is a ReadyStack build
pinned by digest: each image and its digest are listed in `images.tsv`. This order of operations is the one the stack was tested with, end to end, on three
Ubuntu 24.04 nodes; the operator runbook (`/kubernetesvmstack/runbook/RUNBOOK.md` in the `readystack/kubernetesvmstack`
image) records that run and the checks to repeat on your own cluster.

| Path | What it is |
|---|---|
| `images.tsv` | Every stack image: slug, release tag, linux/amd64 manifest digest, and the extra names it is mirrored under (kubeadm's, KubeVirt's) |
| `mirror-images.sh` | Copies each image by digest into the local registry, with its signatures and attestations (regctl v0.11.7, sha256-pinned) |
| `node/install-node.sh`, `node/registry.env.example` | The host bundle installer (kubelet, kubeadm, kubectl, containerd, runc, CNI plugins, crictl, units, containerd config) |
| `controlplane/` | `kubeadm-config.yaml`, the kubeadm patches that give the static Pods root, `kube-proxy.yaml`, `IMAGES.md` |
| `network/` | `bridge-netplan.example.yaml` (the host bridge), kube-vip (static Pod + script), `kube-flannel.yml`, `multus-daemonset.yml`, `nad-host-bridge.yaml` |
| `kubevirt/` | `kubevirt-operator.yaml`, `kubevirt-cr.yaml` (virt-handler's root, virt-template off), README |
| `vm/local-disk-vm.yaml` | A VM from an existing disk on a static local volume, pod network + host bridge NICs |

Every image defaults to a non-root user; where a component needs root, its Pod sets it (`runAsUser: 0`). The files
above already do this; a component started without them exits at once with "permission denied".

## Before you start

- Three Ubuntu 24.04 x86-64 hosts on one layer-2 network, each with a static address on its uplink (step 3 moves it
  onto a bridge, `br0` on all three: kube-vip holds the VIP on it), swap off, `/dev/kvm` present (or plan for KubeVirt emulation, which is slow), and the OS
  packages kubeadm's preflight wants: `iptables conntrack socat ethtool` (`qemu-utils` to convert VM disks).
- A free address on that network for the control-plane VIP (outside any DHCP range).
- A machine that runs the local registry and can reach the hosts (port 5000), and, for the mirror step, the images:
  either the ReadyStack OCI archives, or Docker Hub (`docker.io/readystack`).
- The pod CIDR (`10.244.0.0/16` in these files) and the service CIDR (`10.96.0.0/12`) must not overlap your networks.

## 1. The local registry

Run `readystack/registry` (the stack reuses the registry product) with TLS from a CA the hosts will trust:

```
docker run -d --name registry --restart unless-stopped --network host \
  -e REGISTRY_HTTP_ADDR=<registry-ip>:5000 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/reg.crt -e REGISTRY_HTTP_TLS_KEY=/certs/reg.key \
  -v /srv/registry/reg.crt:/certs/reg.crt:ro -v /srv/registry/reg.key:/certs/reg.key:ro \
  -v registry-data:/var/lib/registry readystack/registry:<release tag>
```

- The certificate's subjectAltName must name the address the hosts use (`IP:<registry-ip>` or the DNS name).
- Authentication is on: on first start the registry creates `/var/lib/registry/auth/htpasswd` with the user `docker`
  and a random password, printed once (`docker logs registry 2>&1 | grep 'provisioning with default user'`). Keep it in a
  root-only file; replace the htpasswd file with your own bcrypt entries if the logs leave the host.
- The image's HEALTHCHECK probes `http://127.0.0.1:5000/`, so with `REGISTRY_HTTP_ADDR` on another address and TLS on,
  Docker reports the container `unhealthy` while it serves; check it with `curl --cacert ca.crt https://<registry-ip>:5000/v2/`
  (401 = up, authentication required).

## 2. The registry config, to every host

Write the registry config (`node/registry.env.example`) on each host as `/root/registry.env`, root-owned, mode 0600, and
the registry's CA as `/root/registry-ca.crt`:

```
REGISTRY_HOST=<registry-ip>:5000
REGISTRY_CA_FILE=/root/registry-ca.crt
REGISTRY_USERNAME=docker
REGISTRY_PASSWORD=<the password>
```

It is read as data (never sourced). Copy it through stdin so the password never sits in a world-readable file, e.g.
`ssh host 'sudo sh -c "umask 077; cat > /root/registry.env"' < registry.env`. The same format, with the CA path valid on
the machine that runs it, is `mirror-images.sh`'s `--registry-config`.

## 3. The host bridge

VMs reach the hosts' LAN through a Linux bridge on each host's uplink (Multus attaches their second NIC to it), so the
uplink is enslaved to a bridge (`br0`) and the host's address moves onto the bridge. `network/bridge-netplan.example.yaml`
is that netplan configuration (static address; the bridge keeps the uplink's MAC). On each host, filling in its uplink,
MAC, address, gateway and DNS:

```
envsubst < network/bridge-netplan.example.yaml > bridge.yaml        # UPLINK UPLINK_MAC BRIDGE HOST_CIDR GATEWAY DNS
sudo install -m 0600 bridge.yaml /etc/netplan/60-bridge.yaml
sudo netplan generate                                                 # parses everything; stops on an error
sudo netplan try --timeout 120                                        # rolls back by itself unless you press ENTER
echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg   # cloud images
```

Do it from the console where you can. Over ssh the session survives when the address and the MAC stay the same (they
do here), and `netplan try` reverts the change if you lose the session and cannot confirm it. Afterwards the host's
address is on `br0`: **kube-vip's interface is `br0`** (`KUBE_VIP_INTERFACE=br0` in step 6), the bridge in
`network/nad-host-bridge.yaml` is `br0` (`HOST_BRIDGE=br0`), and flannel follows the default route onto it.

## 4. Mirror the images

On the machine that reaches both the source and the registry:

```
./mirror-images.sh --fetch-regctl                                    # once, on a connected machine: tools/regctl (sha256-checked)
./mirror-images.sh --registry-config registry.env --from-hub         # the published releases, signatures and attestations included
./mirror-images.sh --registry-config registry.env --from-archives DIR  # or: DIR/<slug>.oci.tar (no signatures)
```

Each source must resolve to the digest in `images.tsv`, or it is not copied. etcd is always the published, signed
`readystack/etcd` v3.7.3 release (mirror it `--from-hub --only etcd` when the rest comes from archives). Then check each
signature against
ReadyStack's release key, for every mirrored name, e.g.
`cosign verify --key https://readystack.dev/keys/cosign.pub <registry-ip>:5000/kube-apiserver:v1.36.6` (cosign needs the
registry CA, e.g. through `SSL_CERT_FILE`, and the registry login in its Docker config).

## 5. The hosts

On each host, with the bundle tarball `kubernetesnode-v1.36.6-linux-amd64.tar.gz` and its `.sha256` next to the script:

```
sudo ./node/install-node.sh --tarball kubernetesnode-v1.36.6-linux-amd64.tar.gz --registry-config /root/registry.env
```

It installs the binaries and units, writes containerd's config (systemd cgroups, the sandbox image
`<registry>/pause:3.10.2`, the registry credential) and sends every pull of docker.io, registry.k8s.io and quay.io to
the local registry, with no public fallback.

## 6. The first control-plane node

1. The kubeadm patches: copy `controlplane/patches/*.yaml` to `/etc/kubernetes/patches/` (they give kube-apiserver,
   kube-controller-manager, kube-scheduler and etcd root).
2. kube-vip, before kubeadm init (it needs super-admin.conf until init finishes):
   `sudo env LOCAL_REGISTRY=<registry-ip>:5000 DIGEST_kubevip=<images.tsv> KUBE_VIP_ADDRESS=<vip> KUBE_VIP_INTERFACE=br0 sh network/kube-vip-static-pod.sh first-node`
3. Render `controlplane/kubeadm-config.yaml` with envsubst: `LOCAL_REGISTRY` (the registry's `host:port`, its root),
   `KUBE_VIP`, `NODE_IP` (this host), `TAG_etcd` (`v3.7.3`: the etcd image is the live `readystack/etcd` v3.7.3
   release; CoreDNS keeps kubeadm's own `v1.14.2`), `BOOTSTRAP_TOKEN` (`kubeadm token generate`), `CERTIFICATE_KEY`
   (`kubeadm certs certificate-key`); `CA_CERT_HASH` is for the joins. Keep the rendered file root-only (it holds the
   token and key). The file's comment lists each placeholder.
4. `sudo kubeadm config images pull --config kubeadm-config.yaml`, then
   `sudo kubeadm init --config kubeadm-config.yaml --upload-certs` (kube-proxy is skipped on purpose: step 8 deploys ours).
5. `sudo sh network/kube-vip-static-pod.sh after-init` (back to admin.conf).

## 7. The other two control-plane nodes

On each: the patches (6.1), `kube-vip-static-pod.sh join` (same variables as 6.2), the kubeadm config rendered for
that host (`NODE_IP`, and `CA_CERT_HASH` = `sha256:` + the sha256 of the cluster CA's public key, e.g.
`openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl pkey -pubin -outform der | sha256sum` on the first node),
then `sudo kubeadm join --config kubeadm-config.yaml`. The uploaded certificates expire after two hours; re-upload
them with `kubeadm init phase upload-certs --upload-certs --config kubeadm-config.yaml` on the first node if needed.

## 8. Add-ons

Render with envsubst (`LOCAL_REGISTRY`, `KUBE_VIP`, the `DIGEST_<slug>` values from `images.tsv`, `POD_CIDR` =
kubeadm's `podSubnet`) and apply, in this order:

```
kubectl apply -f controlplane/kube-proxy.yaml
kubectl apply -f network/kube-flannel.yml
kubectl apply -f network/multus-daemonset.yml
kubectl -n kube-system rollout restart deployment/coredns   # kubeadm init put both CoreDNS replicas on the first node
```

The CoreDNS restart spreads the two replicas over the nodes; without it, losing the first node stops cluster DNS.

## 9. KubeVirt

Render `kubevirt/kubevirt-operator.yaml` and `kubevirt/kubevirt-cr.yaml` (`LOCAL_REGISTRY`, `DIGEST_<slug>` of the six
KubeVirt images), apply the operator, wait for it, apply the CR, and wait for Available:

```
kubectl apply -f kubevirt-operator.yaml && kubectl -n kubevirt rollout status deployment/virt-operator
kubectl apply -f kubevirt-cr.yaml && kubectl -n kubevirt wait kv kubevirt --for condition=Available --timeout=20m
```

The CR gives virt-handler root and turns virt-template off (not shipped; see `kubevirt/README.md`). The admin machine's
client is the stack's `virtctl` (its own tarball).

## 10. VMs on static local disks

1. `network/nad-host-bridge.yaml` (envsubst `HOST_BRIDGE=br0`, the bridge of step 3) in the VMs' namespace.
2. Per VM, follow `vm/local-disk-vm.yaml`: the disk as raw `disk.img` in a directory on its node, owned by 107:107,
   mode 0660; render and apply the file (a local PersistentVolume + claim + the VirtualMachine).
3. `virtctl console <vm>`; `virtctl start|stop <vm>`.

A VM on a local volume is pinned to its node: it cannot live-migrate, and it stops while that node is down.

## Check it

The runbook (`/kubernetesvmstack/runbook/RUNBOOK.md`) lists the checks that prove each step above on your cluster, with
the output the tested cluster gave: nodes Ready, uid 0 only where a Pod sets it, every node image at its mirrored
digest, pod and Service traffic, the Multus bridge, a control-plane node lost and restarted, KubeVirt Available, a
VM's console and its address on the LAN.

## Lifecycle

The runbook (`/kubernetesvmstack/runbook/RUNBOOK.md`) covers the cluster's upkeep, one section each:

- **"Backing up etcd":** taking an etcd snapshot on a node with the `etcdctl` in the etcd image, checking that it
  restores, and keeping it in a root-only backup directory, because a snapshot holds every Secret of the cluster.
- **"Restoring the whole cluster from a snapshot":** restoring every etcd member from one snapshot and starting etcd,
  then the rest of the control plane, again, which takes the cluster's state back to the moment of the snapshot.
- **"Renewing the control-plane certificates":** renewing them with `kubeadm certs renew all` one node at a time,
  restarting that node's static pods and checking its API server before the next node.
- **"Upgrades":** what `kubeadm-config.yaml`'s UpgradeConfiguration carries for this stack (the patch files and the
  kube-proxy skip), and why the move to Kubernetes 1.37 waits for a KubeVirt release that supports it.
- **"The registry credential and containerd":** why containerd holds the registry credential in its deprecated
  `registry.configs` setting, and that containerd stays on a release that still reads it until the stack ships a
  kubelet image credential provider.
