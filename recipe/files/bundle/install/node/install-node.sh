#!/usr/bin/env bash
# =====================================================================================================================
# install-node.sh: install the Kubernetes Node host bundle (readystack/kubernetesnode, v1.36.6) on an Ubuntu 24.04
# x86-64 host, for kubeadm init/join. Part of the Kubernetes VM Stack (install order: README.md in the install directory).
#
#   sudo ./install-node.sh --tarball kubernetesnode-v1.36.6-linux-amd64.tar.gz --registry-config /root/registry.env
#
# What it does, in order (nothing is downloaded; the tarball is the only input besides the registry config):
#   1. checks the tarball against its .sha256 (or --sha256), unpacks it into a private temporary directory and checks
#      every file against the bundle's own SHA256SUMS;
#   2. installs the binaries (/usr/local/bin: kubelet kubeadm kubectl containerd containerd-shim-runc-v2 ctr runc crictl;
#      /opt/cni/bin: the CNI plugins), the systemd units (kubelet.service + kubelet.service.d/10-kubeadm.conf,
#      containerd.service), /etc/crictl.yaml, /etc/modules-load.d/kubernetes.conf, /etc/sysctl.d/99-kubernetes.conf,
#      /etc/default/kubelet (only when absent: it is the administrator's file) and /usr/local/share/kubernetesnode;
#   3. writes /etc/containerd/config.toml (root, 0600: it can hold the registry credential) from the bundle's template:
#      SystemdCgroup = true, sandbox image <registry>/pause:3.10.2, config_path /etc/containerd/certs.d, and the local
#      registry's credential for CRI pulls (registry.configs.<host>.auth: DEPRECATED in containerd 2.x but honoured by
#      v2.3.7; the non-deprecated path is a kubelet image credential provider);
#   4. writes /etc/containerd/certs.d/<host>/hosts.toml for docker.io, registry.k8s.io, quay.io and the local registry,
#      each sending every pull to the local registry with no public fallback, and installs the registry's CA;
#   5. unless --no-enable: loads overlay + br_netfilter, applies the sysctls, daemon-reload, enables and starts
#      containerd, enables kubelet (which restarts every 10 s until kubeadm init/join writes its configuration).
# An existing file this script replaces is kept next to it as <file>.bak-<UTC timestamp> when it differs.
#
# THE REGISTRY CONFIG (--registry-config FILE): root-owned, mode 0600 (no group/other access), KEY=VALUE lines, never
# sourced (read as data; values are taken literally, no quotes, no expansion). Credentials are never taken on the
# command line, where every user of the host can read them in the process list.
#   REGISTRY_HOST=10.77.0.1:5000             # host[:port] of the local registry (TLS); required
#   REGISTRY_CA_FILE=/root/registry-ca.crt   # its CA (a private CA); optional when a CA the host trusts signed it
#   REGISTRY_USERNAME=docker                 # optional: both or neither
#   REGISTRY_PASSWORD=...                    # optional
#
# Options:
#   --tarball FILE          the bundle tarball (required)
#   --sha256 HEX            expected sha256 of the tarball (default: FILE.sha256 when present; else not checked, with
#                           a warning)
#   --registry-config FILE  the registry config above (required)
#   --no-enable             install and configure only: no modprobe, sysctl or systemctl (for images and containers)
#   --root DIR              install under DIR instead of / (implies --no-enable; for staging and tests)
#   --force                 skip the Ubuntu 24.04 / x86-64 / swap checks
# =====================================================================================================================
set -euo pipefail
umask 022

TARBALL='' SHA='' REGCFG='' ENABLE=1 ROOT=/ FORCE=0
die() { echo "install-node: ERROR: $*" >&2; exit 1; }
warn() { echo "install-node: WARNING: $*" >&2; }
say() { echo "install-node: $*"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --tarball) TARBALL=${2:?}; shift 2 ;;
    --sha256) SHA=${2:?}; shift 2 ;;
    --registry-config) REGCFG=${2:?}; shift 2 ;;
    --no-enable) ENABLE=0; shift ;;
    --root) ROOT=${2:?}; ENABLE=0; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) sed -n '2,46p' "$0"; exit 0 ;;
    *) die "unknown argument $1 (see --help)" ;;
  esac
done
[ -n "$TARBALL" ] || die "--tarball is required"
[ -f "$TARBALL" ] || die "no such tarball: $TARBALL"
[ -n "$REGCFG" ] || die "--registry-config is required"
[ "$(id -u)" = 0 ] || die "run as root (sudo)"
ROOT=${ROOT%/}; R=${ROOT:-}   # R prefixes every installed path ("" for /)

# --- host checks ------------------------------------------------------------------------------------------------------
if [ "$FORCE" = 0 ] && [ -z "$R" ]; then
  [ "$(uname -m)" = x86_64 ] || die "this bundle is linux/amd64; this host is $(uname -m)"
  . /etc/os-release 2>/dev/null || true
  [ "${ID:-}" = ubuntu ] && [ "${VERSION_ID:-}" = 24.04 ] || warn "built and tested for Ubuntu 24.04; this host is ${PRETTY_NAME:-unknown}"
  if [ -n "$(swapon --noheadings 2>/dev/null)" ]; then
    warn "swap is on: kubelet refuses to start with swap unless KubeletConfiguration allows it (failSwapOn: false). Turn it off (swapoff -a, and remove it from /etc/fstab) before kubeadm init/join."
  fi
  for t in iptables mount nsenter ip; do command -v "$t" >/dev/null || warn "$t is not installed: kubeadm's preflight needs it"; done
  for t in conntrack socat ethtool; do command -v "$t" >/dev/null || warn "$t is not installed (apt-get install conntrack socat ethtool): kubeadm's preflight checks for it"; done
fi

# --- the registry config (data, not code) -----------------------------------------------------------------------------
[ -f "$REGCFG" ] || die "no such registry config: $REGCFG"
[ "$(stat -c %u "$REGCFG")" = 0 ] || die "$REGCFG must be owned by root"
case "$(stat -c %a "$REGCFG")" in 600|400) ;; *) die "$REGCFG must be mode 0600 or 0400 (it holds the registry password); it is $(stat -c %a "$REGCFG")" ;; esac
REGISTRY_HOST='' REGISTRY_CA_FILE='' REGISTRY_USERNAME='' REGISTRY_PASSWORD=''
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|'#'*) continue ;; esac
  k=${line%%=*}; v=${line#*=}
  [ "$k" != "$line" ] || die "$REGCFG: not a KEY=VALUE line: ${line%%=*}"
  case "$k" in
    REGISTRY_HOST) REGISTRY_HOST=$v ;;
    REGISTRY_CA_FILE) REGISTRY_CA_FILE=$v ;;
    REGISTRY_USERNAME) REGISTRY_USERNAME=$v ;;
    REGISTRY_PASSWORD) REGISTRY_PASSWORD=$v ;;
    *) die "$REGCFG: unknown key $k" ;;
  esac
done < "$REGCFG"
[[ "$REGISTRY_HOST" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:[0-9]{1,5})?$ ]] || die "REGISTRY_HOST must be host[:port] (got '$REGISTRY_HOST')"
if [ -n "$REGISTRY_USERNAME$REGISTRY_PASSWORD" ]; then
  [ -n "$REGISTRY_USERNAME" ] && [ -n "$REGISTRY_PASSWORD" ] || die "set both REGISTRY_USERNAME and REGISTRY_PASSWORD, or neither"
  case "$REGISTRY_USERNAME" in *:*) die "REGISTRY_USERNAME cannot contain ':'" ;; esac
fi
[ -z "$REGISTRY_CA_FILE" ] || [ -f "$REGISTRY_CA_FILE" ] || die "REGISTRY_CA_FILE does not exist: $REGISTRY_CA_FILE"

# --- 1. verify and unpack ----------------------------------------------------------------------------------------------
[ -n "$SHA" ] || { [ -f "$TARBALL.sha256" ] && SHA=$(awk '{print $1; exit}' "$TARBALL.sha256"); } || true
if [ -n "$SHA" ]; then
  got=$(sha256sum "$TARBALL" | cut -c1-64)
  [ "$got" = "$SHA" ] || die "tarball sha256 is $got, expected $SHA"
  say "tarball sha256 OK ($got)"
else
  warn "no --sha256 and no $TARBALL.sha256: the tarball itself is not checked (its files still are, against SHA256SUMS)"
fi
W=$(mktemp -d /tmp/install-node.XXXXXX)
trap 'rm -rf -- "$W"' EXIT
chmod 0700 "$W"
tar -xzf "$TARBALL" -C "$W" --no-same-owner
S=$W/usr/local/share/kubernetesnode
[ -f "$S/SHA256SUMS" ] || die "the tarball has no usr/local/share/kubernetesnode/SHA256SUMS: not a Kubernetes Node bundle"
( cd "$W" && sha256sum --strict --quiet -c usr/local/share/kubernetesnode/SHA256SUMS ) || die "a file of the bundle does not match SHA256SUMS"
n=$(find "$W" -type f ! -path "$W/usr/local/share/kubernetesnode/SHA256SUMS" | wc -l)
[ "$n" = "$(wc -l < "$S/SHA256SUMS")" ] || die "the bundle has files SHA256SUMS does not list"
say "bundle unpacked and verified: $n files"

# put <src> <dst> <mode>: install a file, keeping a differing original as <dst>.bak-<ts>
TS=$(date -u +%Y%m%dT%H%M%SZ)
put() {
  local src=$1 dst=$R$2 mode=$3
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then cp -a "$dst" "$dst.bak-$TS"; say "kept the previous $2 as $2.bak-$TS"; fi
  install -o 0 -g 0 -m "$mode" "$src" "$dst"
}

# --- 2. binaries, units, node configuration ----------------------------------------------------------------------------
for b in "$W"/usr/local/bin/*; do put "$b" "/usr/local/bin/$(basename "$b")" 0755; done
for b in "$W"/opt/cni/bin/*; do put "$b" "/opt/cni/bin/$(basename "$b")" 0755; done
put "$W/etc/systemd/system/kubelet.service" /etc/systemd/system/kubelet.service 0644
put "$W/etc/systemd/system/kubelet.service.d/10-kubeadm.conf" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf 0644
put "$W/etc/systemd/system/containerd.service" /etc/systemd/system/containerd.service 0644
put "$W/etc/crictl.yaml" /etc/crictl.yaml 0644
put "$W/etc/modules-load.d/kubernetes.conf" /etc/modules-load.d/kubernetes.conf 0644
put "$W/etc/sysctl.d/99-kubernetes.conf" /etc/sysctl.d/99-kubernetes.conf 0644
[ -e "$R/etc/default/kubelet" ] || put "$W/etc/default/kubelet" /etc/default/kubelet 0644
mkdir -p "$R/usr/local/share/kubernetesnode" "$R/etc/kubernetes/manifests" "$R/var/lib/kubelet"
cp -a "$S/." "$R/usr/local/share/kubernetesnode/"
for d in containerd-config.toml.tmpl containerd-registry-auth.toml.tmpl; do
  install -o 0 -g 0 -m 0644 "$W/etc/containerd/$d" "$R/usr/local/share/kubernetesnode/$d"; done
install -o 0 -g 0 -m 0644 "$W/etc/containerd/certs.d/_local-registry/hosts.toml.tmpl" "$R/usr/local/share/kubernetesnode/hosts.toml.tmpl"

# --- 3. containerd config.toml -----------------------------------------------------------------------------------------
H=$REGISTRY_HOST
cfg=$W/config.toml
sed "s|\${LOCAL_REGISTRY}|$H|g" "$W/etc/containerd/containerd-config.toml.tmpl" > "$cfg"
if [ -n "$REGISTRY_USERNAME" ]; then
  AUTH=$(printf '%s:%s' "$REGISTRY_USERNAME" "$REGISTRY_PASSWORD" | base64 -w0)
  sed -e "s|\${LOCAL_REGISTRY}|$H|g" -e "s|\${LOCAL_REGISTRY_AUTH}|$AUTH|g" "$W/etc/containerd/containerd-registry-auth.toml.tmpl" >> "$cfg"
  unset AUTH
fi
! grep -q '\${' "$cfg" || die "internal: an unrendered placeholder is left in config.toml"
mkdir -p "$R/etc/containerd"
if [ -e "$R/etc/containerd/config.toml" ] && ! cmp -s "$cfg" "$R/etc/containerd/config.toml"; then
  cp -a "$R/etc/containerd/config.toml" "$R/etc/containerd/config.toml.bak-$TS"; chmod 0600 "$R/etc/containerd/config.toml.bak-$TS"
  say "kept the previous /etc/containerd/config.toml as config.toml.bak-$TS"
fi
install -o 0 -g 0 -m 0600 "$cfg" "$R/etc/containerd/config.toml"
"$R/usr/local/bin/containerd" --config "$R/etc/containerd/config.toml" config dump >/dev/null \
  || die "containerd does not accept the written /etc/containerd/config.toml"

# --- 4. registry hosts: docker.io, registry.k8s.io, quay.io and the local registry, all to the local registry ------
CERTS=$R/etc/containerd/certs.d
if [ -n "$REGISTRY_CA_FILE" ]; then
  mkdir -p "$CERTS/$H"; install -o 0 -g 0 -m 0644 "$REGISTRY_CA_FILE" "$CERTS/$H/ca.crt"
fi
for ns in docker.io registry.k8s.io quay.io "$H"; do
  mkdir -p "$CERTS/$ns"
  if [ -n "$REGISTRY_CA_FILE" ]; then
    sed "s|\${LOCAL_REGISTRY}|$H|g" "$W/etc/containerd/certs.d/_local-registry/hosts.toml.tmpl" > "$W/hosts.toml"
  else
    sed -e "s|\${LOCAL_REGISTRY}|$H|g" -e '/^ca = /d' "$W/etc/containerd/certs.d/_local-registry/hosts.toml.tmpl" > "$W/hosts.toml"
  fi
  put "$W/hosts.toml" "/etc/containerd/certs.d/$ns/hosts.toml" 0644
done
say "containerd: sandbox $H/pause:3.10.2, pulls of docker.io, registry.k8s.io and quay.io go to https://$H only$([ -n "$REGISTRY_USERNAME" ] && echo ", with the credential of $REGISTRY_USERNAME")"

# --- 5. enable --------------------------------------------------------------------------------------------------------
if [ "$ENABLE" = 1 ]; then
  modprobe overlay; modprobe br_netfilter
  sysctl --system >/dev/null
  systemctl daemon-reload
  systemctl enable --now containerd
  systemctl restart containerd
  systemctl enable kubelet
  ok=0; for _ in 1 2 3 4 5 6 7 8 9 10; do crictl info >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
  [ "$ok" = 1 ] || die "containerd does not answer CRI (crictl info); see journalctl -u containerd"
  say "containerd is running and answers CRI (crictl info)"
  say "kubelet is enabled; it restarts every 10 s until kubeadm init/join configures it"
else
  say "--no-enable: modprobe, sysctl and systemctl were not run"
fi
say "installed: $(sed -n 's/^Kubernetes v/kubelet v/p' "$S/VERSIONS" | head -1), $("$R/usr/local/bin/containerd" --version | awk '{print "containerd "$3}'), $("$R/usr/local/bin/runc" --version | head -1)"
say "next: kubeadm init/join --config <your kubeadm config> --patches <the kubeadm patch directory> (README.md in the install directory)"
