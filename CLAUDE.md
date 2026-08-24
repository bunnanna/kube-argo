# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

GitOps config repo for a home/personal Kubernetes cluster, synced by ArgoCD from
`https://github.com/bunnanna/kube-argo.git` (branch `main`). There is no build/test/lint
tooling — every change is a YAML manifest that ArgoCD applies to the cluster. "Testing" a
change means validating YAML and reasoning about what ArgoCD will sync, not running a
command locally.

Domain: `bunnana.dev`, served through an internal CA (Vault PKI + cert-manager), routed by
Kong ingress.

## Directory layout and the ApplicationSet convention

- `argocd/` — the ArgoCD Applications/ApplicationSets that bootstrap everything else
  (self-management, install, and the generators below). Anything here is applied manually /
  once, not auto-discovered.
- `common/<component>/` — one directory per cluster-wide component (`argocd`, `cert-manager`,
  `kong`, `vault`). Two shapes exist and are auto-discovered by the ApplicationSets in
  `argocd/`:
  - **Install-based component**: `install/` holds either `helm.yaml` (chart, repoURL,
    targetRevision, namespace) + `values.yaml`, or a plain Kustomize `kustomization.yaml` (+
    whatever it patches, e.g. `configmap.yaml`). Both shapes are picked up by
    `common-apply-install-application-set.yaml`, which unions two git generators — one
    matching `common/*/install/helm.yaml`, one matching `common/*/install/kustomization.yaml`
    — into a single Application per component: `helm.yaml` items render as a Helm multi-source
    Application (same `ref: values` pattern as before), `kustomization.yaml` items render as a
    plain path-based source. The Application's `name` is the component dir name
    (`{{index .path.segments 1}}`) and its destination `namespace` is read straight from the
    `namespace:` field of whichever file matched.
  - **Plain-manifest component**: any other `*.yaml` directly under `common/<name>/` (e.g.
    `ingress.yaml`), picked up by `common-apply-application-set.yaml`, which applies the file
    at that path directly as an Application source. `common/*/install/**` is explicitly
    excluded from this generator so it isn't double-applied.
- `certificate/*.yaml` — `cert-manager.io/v1 Certificate` objects, one per issued cert.
  Auto-discovered by `argocd/issue-certificate.yaml`'s ApplicationSet (glob
  `certificate/*.yaml`), one Application per file.

**Adding a new component follows the existing shape**: drop a Helm chart under
`common/<name>/install/{helm.yaml,values.yaml}`, a Kustomize overlay under
`common/<name>/install/kustomization.yaml`, or a plain manifest under `common/<name>/*.yaml` —
no new ArgoCD Application needs to be hand-written, the matching ApplicationSet generator picks
it up from git automatically. Same for a new certificate: add a file under `certificate/`.

## Cert issuance chain

Vault runs in-cluster (`common/vault`) as the PKI backend. `common/cert-manager/cluster-issuer.yaml`
defines a `ClusterIssuer` (`vault-issuer`) that talks to Vault over Kubernetes auth
(`serviceAccountRef: cert-manager`) and signs via `pki/sign/cert-manager`. Each
`certificate/*.yaml` references `issuerRef: vault-issuer` and produces a `<name>-cert-tls`
secret consumed by the matching `common/<component>/ingress.yaml`.

`common/vault/k.txt` holds the Vault unseal key, root token, and the one-time `vault operator
init`/PKI/auth setup commands for this cluster — it's manual bootstrap documentation, not
applied by ArgoCD, and is gitignored (`*.txt`) so it never gets committed. Don't add secrets to
tracked files.

## Working conventions

- Namespaces are created implicitly by `syncOptions: [CreateNamespace=true]` on the
  ApplicationSet templates — individual manifests don't need `Namespace` objects.
- All Applications point at `destination.server: https://kubernetes.default.svc` (in-cluster
  only, no multi-cluster).
- `argocd-self-manage-app.yaml` and `common-apply`/`common-apply-install`/`issue-cert`
  ApplicationSets are how the repo bootstraps itself — the `path: argocd` Application
  (self-apply) keeps ArgoCD in sync with changes to `argocd/*.yaml` itself. ArgoCD's own
  install manifests (`common/argocd/install/`) are now also just another
  `common-apply-install` entry, no longer a separate hand-applied Application — mind that its
  `syncPolicy` (`prune: true`, `ServerSideApply=true`) is now shared with every other
  install-based component instead of being tuned on its own.
