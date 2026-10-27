# ADR-0004: GitOps layout with Argo CD and an app-of-apps root

- **Status:** Proposed
- **Date:** 2026-10-27
- **Author:** Ilyas
- **Reviewer:** *(pending)*
- **Implemented in:** `bootstrap/`, `clusters/local/` and `apps/` of this repository (pull requests #5, #6, #7 and #11)

## 1. Context

The platform has to be deployed and changed without anyone running `kubectl apply` by hand. Every change must be reviewable, every state must be recoverable from Git, and the same manifests must later run on the Oracle (OCI) k3s server as on the local k3d cluster.

Today there is one cluster (local k3d, about 3.8 GiB of memory) and four things deployed on it: the Kyverno chart, the image policy, `sample-app`, and a lean Prometheus. A second cluster and the real kenshoo workload will follow.

## 2. Decision drivers

- **Git is the single source of truth.** A change that is not in Git does not exist.
- **Rollback is a Git operation**, not a cluster operation.
- **Bootstrap from empty:** a new cluster should need one manual step, after which everything else follows from Git.
- **Adding a service should be cheap** and visible in a pull request.
- **Memory:** the controller must stay small on the local node.
- Keep the structure simple enough to explain, with no abstraction layer that four applications do not need.

## 3. Options considered

| Option | Pros | Cons |
|---|---|---|
| **A. Manual `kubectl apply` or scripts** | Nothing to install | Cluster drifts from any record. No review, no automatic repair |
| **B. `helm install` per component, by hand** | Charts are versioned | Same drift problem. Values live in shell history, not in Git |
| **C. Argo CD, one Application created per service by hand** (CLI or UI) | Argo CD reconciles each service | The list of services lives in the cluster, not in Git. A new cluster has to be rebuilt from memory |
| **D. Argo CD with an app-of-apps root** | The list of services is itself in Git. One manual step bootstraps a cluster. Adding a service is adding one file | Pruning is powerful: deleting a file deletes the application and its resources |
| **E. Argo CD ApplicationSet generating the Applications** | Scales to many clusters and services | More abstraction than four applications justify. Harder to read while learning |

## 4. Decision

**Option D: Argo CD with a root Application that owns every other Application.**

- **Layout:**
  - `bootstrap/` holds what is applied by hand once per cluster: `argocd-values.yaml` (Argo CD chart values, with dex and notifications disabled to save memory) and `root-app.yaml`.
  - `clusters/<cluster>/` holds one Application file per deployed service. Today only `clusters/local/` exists, with `sample-app.yaml`, `kyverno.yaml`, `policies.yaml` and `prometheus.yaml`.
  - `apps/` holds manifests that this repository owns: `apps/kenshoo/sample-app/` (the Deployment), `apps/policies/` (the Kyverno image policy) and `apps/observability/` (currently an empty placeholder).
- **The root Application** watches `clusters/local` on `main` with automated sync, `prune` and `selfHeal`. A new file in that folder becomes a new child Application, and a removed file removes it.
- **Third-party software is referenced, not copied:** Kyverno (chart 3.9.2) and Prometheus (chart 29.39.0) are pulled from their chart repositories with values written inline in the Application. Versions are pinned.
- **Our own images are pinned by digest** in the manifests, so what Argo CD applies is exactly what the pipeline signed.
- **Argo CD itself is installed with `helm upgrade --install`** (chart 10.11.6, Argo CD v3.5.6, namespace `argocd`), not managed by Argo CD.
- **Only `main` is watched.** Branch protection requires a pull request, merges are merge commits, and a rollback is `git revert -m 1 <merge-commit>` followed by a pull request.
- **Access to the UI** is by `kubectl port-forward` for now. Nothing is exposed.

## 5. Consequences

- **Positive.** The list of what runs is a folder listing. Review, history and rollback come from Git. A new cluster is: install Argo CD, apply `root-app.yaml`, wait. Adding Prometheus was one file and one merged pull request.
- **Prune is a sharp tool.** Deleting a file in `clusters/local/` deletes that application and, with it, its resources. A careless merge can remove something important. The mitigation is pull request review and reading the diff.
- **Argo CD is the one component outside Git.** Its installation and upgrades are manual, and its initial admin password secret (`argocd-initial-admin-secret`) exists until it is deleted.
- **Polling delay.** Argo CD notices a merge after about three minutes, or immediately after a hard refresh.
- **Layout is single-cluster for now.** `clusters/` is already keyed by cluster, but how `apps/` is shared between `local` and OCI is not decided yet.
- **No secrets in Git yet.** Anything that needs a credential cannot be deployed through this layout until the secrets decision exists.
- **Cosmetic drift needs targeted handling.** Some charts produce differences the API server never stores. This is handled per application with a narrow `ignoreDifferences` rule, as for the Kyverno CRDs (see ADR-0003).

## 6. Follow-up decisions

1. Layout for the OCI cluster: a second `clusters/oci/` folder and root application, and how `apps/` is shared or overridden between clusters.
2. Secrets in Git with SOPS and age.
3. Whether Argo CD should manage itself after bootstrap, or stay installed by Helm.
4. Delete `argocd-initial-admin-secret`, and decide how access and RBAC work on the server.
5. Whether to use Argo CD projects to limit which repositories and namespaces each application may use.
6. Validation of manifests in pull requests before they reach `main`.

## 7. Review notes

*(To be filled in after review: questions raised, changes made, final status.)*
