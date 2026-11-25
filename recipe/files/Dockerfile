# =====================================================================
# Kubernetes VM Stack L-009 HERMETIC OFFLINE BUILD: the canonical, attestation-producing build. build_kit runs
#   docker buildx build --builder readystack-builder-max --network=none
#     --attest type=provenance,mode=max,version=v1 --attest type=sbom --push <directory context>
# Pinned-public-base + vendored model: golang 1.26.10 pinned BY DIGEST (BASE_IMAGE_DIGESTS.lock) compiles stack-bundle
# from the kit's stack-bundle.go (standard library only); vendored/kubernetesvmstack-src is the kit's bundle/.
# Dockerfile and Dockerfile.offline are byte copies of this file (the repo-wide convention).
#
# SHAPE: a BUNDLE IMAGE (owner 2026-10-29: the stack ships as an image). FROM scratch: /kubernetesvmstack holds the
# install bundle (install/), the pin manifest (kubevirt-stack.json), the operator runbook and the record of its cluster
# run (runbook/), and SHA256SUMS of every file; /usr/local/bin/stack-bundle checks them (`verify`, the default command
# and the component check), lists them (`list`) and prints the stack's version (`version`). It runs no service: its
# default user is 65534:65534.
# =====================================================================
FROM golang:1.26.10-bookworm@sha256:632dff7351799a5a9954a48dc06670ade72ee44e8c351cdc0e5a57af2fea21af AS build
WORKDIR /src
COPY stack-bundle.go main.go
COPY stack-bundle.mod go.mod
ENV CGO_ENABLED=0 GOTOOLCHAIN=local GOFLAGS="-buildvcs=false" GOPROXY=off
# the stack's version (strategies/kubernetesvmstack.json, the pin manifest's own) is stamped into the program; the ARG is
# the kit's version pin (scripts/check-kit-version.py: a stack's release is its own version, not its source.ref)
ARG STACK_VERSION=v1.36.6-kubevirt1.9.1
RUN go build -trimpath -ldflags="-s -w -X main.version=${STACK_VERSION}" -o /out/stack-bundle . && \
    [ "$(go version /out/stack-bundle | awk '{print $2}')" = go1.26.10 ]

# --- every file against SHA256SUMS, and the pin manifest's version against the program's, as the image's own user ------
FROM golang:1.26.10-bookworm@sha256:632dff7351799a5a9954a48dc06670ade72ee44e8c351cdc0e5a57af2fea21af AS verify
COPY --from=build /out/stack-bundle /usr/local/bin/stack-bundle
COPY vendored/kubernetesvmstack-src/ /kubernetesvmstack/
ARG STACK_VERSION=v1.36.6-kubevirt1.9.1
USER 65534:65534
RUN /usr/local/bin/stack-bundle verify && \
    [ "$(/usr/local/bin/stack-bundle version)" = "Kubernetes VM Stack ${STACK_VERSION}" ] && \
    grep -q "\"version\": \"${STACK_VERSION}\"" /kubernetesvmstack/kubevirt-stack.json

FROM scratch
# Reproducibility: the build reads SOURCE_DATE_EPOCH (BuildKit's rewrite-timestamp clamps the layers' mtimes to it).
# ARG, never ENV: an ENV would persist into the image config and change the digest. No package manager runs here and no
# user is created (65534 is numeric, with no passwd entry): the files are the bundle and the one program. Nothing of the
# build stages' Debian is copied, so there is no /var/log/dpkg.log or /var/cache/ldconfig/aux-cache to clean, and no
# /etc/shadow to freeze.
ARG SOURCE_DATE_EPOCH=1793102572
COPY --from=verify /kubernetesvmstack/ /kubernetesvmstack/
COPY --from=build /out/stack-bundle /usr/local/bin/stack-bundle
USER 65534:65534
CMD ["/usr/local/bin/stack-bundle", "verify"]
# >>> readystack OCI labels: strategies/kubernetesvmstack.json image_labels plus the standard OCI labels,
# the set a generated kit carries (gen_dockerfile.label_lines). Written by scripts/kit_migrations.py;
# scripts/retarget.py re-renders it with every retarget. Never edit it by hand.
LABEL org.opencontainers.image.title="Kubernetes VM Stack"
LABEL org.opencontainers.image.version="v1.36.6-kubevirt1.9.1-CE-scratch-r3"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.source="https://github.com/kubernetes/kubernetes"
LABEL org.opencontainers.image.vendor="ReadyStack.dev"
LABEL org.opencontainers.image.revision="1b2171b110bb2a2542e1322035c6583ec86eb976"
LABEL org.opencontainers.image.description="The install bundle, pin manifest and operator runbook of a three-node kubeadm v1.36.6 cluster with KubeVirt v1.9.1, as one image: every file listed with its sha256 and checked by the image's own program, the runbook checked against a running cluster."
# <<< readystack OCI labels
