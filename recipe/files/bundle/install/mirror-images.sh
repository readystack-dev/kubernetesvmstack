#!/usr/bin/env bash
# =====================================================================================================================
# mirror-images.sh: copy every image of the Kubernetes VM Stack into the local registry, by digest, under the names the
# install files use. Part of the Kubernetes VM Stack (install order: README.md next to this script).
#
#   ./mirror-images.sh --registry-config /root/registry.env --from-archives DIR      (air-gapped: OCI archives)
#   ./mirror-images.sh --registry-config /root/registry.env --from-hub                (online: docker.io/readystack)
#
# For each line of images.tsv (next to this script; --images FILE for another) it:
#   1. resolves the source: an OCI image archive DIR/<slug>.oci.tar (or an OCI layout directory DIR/<slug>/, as
#      BUILD_OFFLINE.sh's rebuilt.oci.tar unpacks), or docker.io/readystack/<slug>:<release tag>;
#   2. refuses the source unless its linux/amd64 image manifest IS the digest images.tsv names (a source whose tag
#      moved, or an archive of another build, is never copied);
#   3. copies it to ${REGISTRY}/readystack/<slug>:<release tag> with regctl, digest-preserving: the manifest or index
#      bytes are copied as they are, so the image keeps its digest, and with them the cosign signatures and
#      attestations the source holds (cosign's sha256-<digest>.sig/.att/.sbom tags, OCI referrers, and BuildKit's
#      SBOM/provenance manifests inside the index);
#   4. copies it again, inside the local registry, to each alias images.tsv names (kubeadm's names, e.g.
#      ${REGISTRY}/kube-apiserver:v1.36.6), signatures and attestations included (cosign looks for a signature in the
#      repository of the name it verifies);
#   5. reads every name back and checks that its linux/amd64 manifest is the expected digest.
# Nothing is pushed anywhere but --registry. Exit status 0 only when every image of the list was copied and checked.
#
# THE REGISTRY CONFIG (--registry-config FILE): the same file install-node.sh reads (registry.env.example): KEY=VALUE
# lines, never sourced, owned by you or root, mode 0600 or 0400. REGISTRY_HOST (host[:port], required),
# REGISTRY_CA_FILE (optional: its CA when private), REGISTRY_USERNAME / REGISTRY_PASSWORD (optional: both or neither).
# The password is handed to regctl on stdin, never on a command line, and regctl's login lives in a private temporary
# configuration that is removed on exit.
#
# THE TOOL: regctl (regclient) v0.11.7, linux/amd64, a single static binary. This script runs only the binary whose
# sha256 is REGCTL_SHA256 below: --regctl FILE, else ./tools/regctl next to this script, else regctl on PATH; any
# other build is refused. `--fetch-regctl` downloads the pinned release from GitHub into ./tools/ and checks the same
# sha256 (run it once on a connected host and carry tools/regctl with the bundle). The pin was taken on 2026-10-28
# from https://github.com/regclient/regclient/releases/download/v0.11.7/regctl-linux-amd64 after its Sigstore bundle
# (regctl-linux-amd64.sigstore.json) verified with cosign v2.4.3 against the signer identity
# https://github.com/regclient/regclient/.github/workflows/go.yml@refs/tags/v0.11.7 (issuer
# https://token.actions.githubusercontent.com); `regctl version` reports VCSRef 36abda84830dae07db00bf9e5cec95d97b78222a,
# Go 1.27.3.
#
# Options:
#   --registry-config FILE   the registry config above (required, except with --fetch-regctl)
#   --from-archives DIR      sources are DIR/<slug>.oci.tar or DIR/<slug>/ (an OCI image layout)
#   --from-hub [REPO]        sources are REPO/<slug>:<release tag> (default docker.io/readystack)
#   --images FILE            the image list (default: images.tsv next to this script)
#   --only SLUG[,SLUG...]    mirror only these slugs of the list
#   --regctl FILE            the regctl binary (checked against REGCTL_SHA256)
#   --fetch-regctl           download the pinned regctl into tools/ next to this script, check it, and exit
#   --record FILE            append one line per mirrored name to FILE: <name without registry>\t<tag>\t<the digest
#                            the name resolves to (index or manifest)>\t<its linux/amd64 manifest digest>\t<source:
#                            hub or archive>, so a node check can compare what each node pulled with exactly what was
#                            mirrored, and a signature check knows which names came from the signed releases
#   --dry-run                resolve and check every source, copy nothing
# =====================================================================================================================
set -euo pipefail
umask 077

REGCTL_VERSION=v0.11.7
REGCTL_SHA256=3737fbbdd791e04e7a831640b681f3397a376498e80e2ad9b1b2d27296f239bc
REGCTL_URL=https://github.com/regclient/regclient/releases/download/$REGCTL_VERSION/regctl-linux-amd64

HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
REGCFG='' ARCHIVES='' HUB='' IMAGES=$HERE/images.tsv ONLY='' REGCTL='' FETCH=0 DRY=0 RECORD=
die() { echo "mirror-images: ERROR: $*" >&2; exit 1; }
say() { echo "mirror-images: $*"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --registry-config) REGCFG=${2:?}; shift 2 ;;
    --from-archives) ARCHIVES=${2:?}; shift 2 ;;
    --from-hub) if [ -n "${2:-}" ] && [ "${2#--}" = "$2" ]; then HUB=$2; shift 2; else HUB=docker.io/readystack; shift; fi ;;
    --images) IMAGES=${2:?}; shift 2 ;;
    --only) ONLY=${2:?}; shift 2 ;;
    --regctl) REGCTL=${2:?}; shift 2 ;;
    --fetch-regctl) FETCH=1; shift ;;
    --record) RECORD=${2:?}; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,56p' "$0"; exit 0 ;;
    *) die "unknown argument $1 (see --help)" ;;
  esac
done

sha_ok() { [ -f "$1" ] && [ "$(sha256sum "$1" | cut -c1-64)" = "$REGCTL_SHA256" ]; }

# --- the tool -----------------------------------------------------------------------------------------------------------
if [ "$FETCH" = 1 ]; then
  mkdir -p "$HERE/tools"
  curl -fsSL -o "$HERE/tools/regctl.part" "$REGCTL_URL"
  sha_ok "$HERE/tools/regctl.part" || { rm -f "$HERE/tools/regctl.part"; die "the download of $REGCTL_URL does not have the pinned sha256 $REGCTL_SHA256"; }
  chmod 0755 "$HERE/tools/regctl.part" && mv "$HERE/tools/regctl.part" "$HERE/tools/regctl"
  say "tools/regctl: regctl $REGCTL_VERSION, sha256 $REGCTL_SHA256"
  exit 0
fi
if [ -z "$REGCTL" ]; then
  if [ -f "$HERE/tools/regctl" ]; then REGCTL=$HERE/tools/regctl; else REGCTL=$(command -v regctl || true); fi
fi
[ -n "$REGCTL" ] || die "no regctl: pass --regctl FILE, or run --fetch-regctl once on a connected host"
sha_ok "$REGCTL" || die "$REGCTL is not regctl $REGCTL_VERSION (sha256 must be $REGCTL_SHA256)"
[ -x "$REGCTL" ] || die "$REGCTL is not executable"

# --- the source and the registry config ------------------------------------------------------------------------------
[ -n "$ARCHIVES$HUB" ] || die "say where the images come from: --from-archives DIR or --from-hub"
[ -z "$ARCHIVES" ] || [ -z "$HUB" ] || die "--from-archives and --from-hub are exclusive"
[ -z "$ARCHIVES" ] || [ -d "$ARCHIVES" ] || die "no such directory: $ARCHIVES"
[ -f "$IMAGES" ] || die "no image list $IMAGES"
[ -n "$REGCFG" ] || die "--registry-config is required"
[ -f "$REGCFG" ] || die "no such registry config: $REGCFG"
case "$(stat -c %u "$REGCFG")" in 0|"$(id -u)") ;; *) die "$REGCFG must be owned by you or by root" ;; esac
case "$(stat -c %a "$REGCFG")" in 600|400) ;; *) die "$REGCFG must be mode 0600 or 0400 (it holds the registry password)" ;; esac
REGISTRY_HOST='' REGISTRY_CA_FILE='' REGISTRY_USERNAME='' REGISTRY_PASSWORD=''
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|'#'*) continue ;; esac
  k=${line%%=*}; v=${line#*=}
  [ "$k" != "$line" ] || die "$REGCFG: not a KEY=VALUE line"
  case "$k" in
    REGISTRY_HOST) REGISTRY_HOST=$v ;; REGISTRY_CA_FILE) REGISTRY_CA_FILE=$v ;;
    REGISTRY_USERNAME) REGISTRY_USERNAME=$v ;; REGISTRY_PASSWORD) REGISTRY_PASSWORD=$v ;;
    *) die "$REGCFG: unknown key $k" ;;
  esac
done < "$REGCFG"
[[ "$REGISTRY_HOST" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:[0-9]{1,5})?$ ]] || die "REGISTRY_HOST must be host[:port]"
[ -z "$REGISTRY_CA_FILE" ] || [ -f "$REGISTRY_CA_FILE" ] || die "REGISTRY_CA_FILE does not exist: $REGISTRY_CA_FILE"
if [ -n "$REGISTRY_USERNAME$REGISTRY_PASSWORD" ]; then
  [ -n "$REGISTRY_USERNAME" ] && [ -n "$REGISTRY_PASSWORD" ] || die "set both REGISTRY_USERNAME and REGISTRY_PASSWORD, or neither"
fi
REG=$REGISTRY_HOST

W=$(mktemp -d "${TMPDIR:-/tmp}/mirror-images.XXXXXX")
trap 'rm -rf -- "$W"' EXIT
export REGCTL_CONFIG=$W/regctl.json          # regctl's login lives here only, never in ~/.regctl
rc() { "$REGCTL" "$@"; }
if [ -n "$REGISTRY_CA_FILE" ]; then rc registry set "$REG" --skip-check --tls enabled --cacert "$(cat "$REGISTRY_CA_FILE")" >/dev/null
else rc registry set "$REG" --skip-check --tls enabled >/dev/null; fi
if [ -n "$REGISTRY_USERNAME" ] && [ "$DRY" = 0 ]; then
  printf '%s' "$REGISTRY_PASSWORD" | rc registry login "$REG" -u "$REGISTRY_USERNAME" --pass-stdin >/dev/null \
    || die "login to $REG as $REGISTRY_USERNAME failed"
fi
unset REGISTRY_PASSWORD

# amd64 <ref>: the linux/amd64 image-manifest digest a reference resolves to (the reference itself when it is one)
amd64() {
  local raw mt
  raw=$(rc manifest get --format raw-body "$1") || return 1
  mt=$(printf '%s' "$raw" | jq -r '.mediaType // empty')
  case "$mt" in
    application/vnd.oci.image.index.v1+json|application/vnd.docker.distribution.manifest.list.v2+json)
      printf '%s' "$raw" | jq -r '[.manifests[] | select(.platform.os=="linux" and .platform.architecture=="amd64")][0].digest' ;;
    *) rc manifest head "$1" ;;
  esac
}

# --- the list ---------------------------------------------------------------------------------------------------------
fail=0 n=0
while IFS=$'\t' read -r slug tag want aliases _rest || [ -n "${slug:-}" ]; do
  case "${slug:-}" in ''|'#'*) continue ;; esac
  if [ -n "$ONLY" ]; then case ",$ONLY," in *",$slug,"*) ;; *) continue ;; esac; fi
  [[ "$want" =~ ^sha256:[0-9a-f]{64}$ ]] || die "$IMAGES: $slug: '$want' is not a sha256 digest"
  n=$((n + 1))
  # 1-2. the source, checked against the expected digest
  if [ -n "$ARCHIVES" ]; then
    if [ -f "$ARCHIVES/$slug.oci.tar" ]; then
      L=$W/src-$slug; mkdir -p "$L"; tar -xf "$ARCHIVES/$slug.oci.tar" -C "$L"
    elif [ -f "$ARCHIVES/$slug/index.json" ]; then L=$ARCHIVES/$slug
    else say "FAIL $slug: neither $ARCHIVES/$slug.oci.tar nor $ARCHIVES/$slug/index.json"; fail=1; continue; fi
    top=$(jq -r '.manifests[0].digest' "$L/index.json")
    src="ocidir://$L@$top"
  else
    top=$(rc manifest head "$HUB/$slug:$tag" 2>/dev/null) || { say "FAIL $slug: $HUB/$slug:$tag not found"; fail=1; continue; }
    src="$HUB/$slug@$top"
  fi
  got=$(amd64 "$src") || { say "FAIL $slug: cannot read $src"; fail=1; continue; }
  if [ "$got" != "$want" ]; then say "FAIL $slug: the source's linux/amd64 manifest is $got, the list names $want: not copied"; fail=1; continue; fi
  dsts="$REG/readystack/$slug:$tag"
  [ "${aliases:--}" = - ] || for a in ${aliases//,/ }; do dsts="$dsts $REG/$a"; done
  if [ "$DRY" = 1 ]; then say "ok (dry run) $slug $want <- $src -> $dsts"; continue; fi
  # 3-4. copy: the release name from the source, then each alias from the release name (inside the registry)
  first="$REG/readystack/$slug:$tag"
  rc image copy --digest-tags --referrers "$src" "$first" >/dev/null || { say "FAIL $slug: copy to $first"; fail=1; continue; }
  for d in $dsts; do
    [ "$d" = "$first" ] || rc image copy --digest-tags --referrers "$first" "$d" >/dev/null || { say "FAIL $slug: copy to $d"; fail=1; continue 2; }
  done
  # 5. read every name back
  for d in $dsts; do
    g=$(amd64 "$d") || g=unreadable
    [ "$g" = "$want" ] || { say "FAIL $slug: $d resolves to $g, not $want"; fail=1; continue 2; }
  done
  if [ -n "$RECORD" ]; then
    for d in $dsts; do nm=${d#"$REG"/}; printf '%s\t%s\t%s\t%s\t%s\n' "${nm%:*}" "${nm##*:}" "$top" "$want" "$( [ -n "$HUB" ] && echo hub || echo archive)" >> "$RECORD"; done
  fi
  sigs=$(rc tag ls "$REG/readystack/$slug" 2>/dev/null | grep -cE '^sha256-[0-9a-f]{64}\.(sig|att|sbom)$' || true)
  atts=0
  [ "$top" = "$want" ] || atts=$(rc manifest get --format raw-body "$first" | jq '[.manifests[]? | select(.annotations["vnd.docker.reference.type"] == "attestation-manifest")] | length')
  say "ok $slug $want ($( [ "$top" = "$want" ] && echo manifest || echo "index $top with $atts attestation manifest(s)"), $sigs cosign tag(s)) -> $dsts"
done < "$IMAGES"
[ "$n" -gt 0 ] || die "no image of $IMAGES was selected"
[ "$fail" = 0 ] || die "some images were not mirrored (see FAIL above)"
if [ "$DRY" = 1 ]; then say "dry run: all $n sources resolved and match their digests; nothing was copied"
else say "all $n images mirrored into $REG by digest"; fi
