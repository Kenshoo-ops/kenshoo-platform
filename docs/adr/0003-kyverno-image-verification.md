# ADR-0003: Admit only images signed by our own pipeline (Kyverno)

- **Status:** Proposed
- **Date:** 2026-10-27
- **Author:** Ilyas
- **Reviewer:** *(pending)*
- **Implemented in:** `clusters/local/kyverno.yaml`, `clusters/local/policies.yaml` and `apps/policies/verify-kenshoo-images.yaml` of this repository (pull requests #7, #8, #9 and #10)

## 1. Context

kenshoo restores database backups and reports whether they are usable. It holds database credentials and its output is a claim ("this backup is good"), so a tampered kenshoo image could lie convincingly. The platform therefore has to guarantee that the only kenshoo code running in the cluster was built by our own pipeline.

The pipeline (`secure-build.yml` in `kenshoo-workflows`) already builds, scans, signs and attests every image. A signature that nothing checks protects nothing, so the cluster needs an admission check that verifies it at deploy time.

The local cluster is a k3d node with about 3.8 GiB of memory, shared with Argo CD, so the admission layer has to stay small.

## 2. Decision drivers

- Only images built by our pipeline may run, and this must be enforced by the cluster, not by convention.
- **No long-lived signing key** that can leak.
- The platform must not be able to lock itself out (Kyverno, Argo CD and the control plane must always be able to start).
- A laptop restart must not brick the local cluster.
- Memory: the local node cannot host extra controllers.
- Use the current, supported Kyverno API. `ClusterPolicy` with `verifyImages` is deprecated since Kyverno 1.18.

## 3. Options considered

| Option | Pros | Cons |
|---|---|---|
| **A. No verification**, trust the registry | Nothing to maintain | Anyone who can push to GHCR can run code in the cluster. Signing would be decoration |
| **B. Key-based cosign signatures** | Simple to explain | A private key must live in CI secrets, and a stolen key signs anything forever |
| **C. Keyless signatures, identity = the app repo's workflow** | No key to steal | Every app repo becomes a trusted signer. Any branch or workflow edit in any app repo changes who is trusted |
| **D. Keyless signatures, identity = the reusable workflow at a `v*` tag** | No key. Trust is one reviewed, tagged pipeline instead of every app repo | Does not say which branch of the app repo was built (see section 5) |

## 4. Decision

**Option D, enforced by a Kyverno `ImageValidatingPolicy` (`policies.kyverno.io/v1`) named `verify-kenshoo-images`.**

- **Scope:** pods in all namespaces except `kube-system`, `kyverno` and `argocd`, and only images matching `ghcr.io/kenshoo-ops/*`. Kyverno autogen extends the rule to Deployments, StatefulSets, DaemonSets, ReplicaSets, Jobs and CronJobs.
- **Signer identity:** a keyless cosign attestor named `pipeline`, issuer `https://token.actions.githubusercontent.com`, subject matching `^https://github\.com/Kenshoo-ops/kenshoo-workflows/\.github/workflows/secure-build\.yml@refs/tags/v.*$`.
- **Rule:** every container image must verify against that attestor, expressed as `images.containers.map(image, verifyImageSignatures(image, [attestors.pipeline])).all(e, e > 0)`.
- **Mode:** `validationActions: [Deny]`. The policy was first run in audit mode (#8) and showed `pass` for the signed `sample-app` pod and `fail` for an unsigned image, then switched to Deny (#9). An unsigned image is now rejected with the message "image is not signed by the Kenshoo secure-build pipeline".
- **`failurePolicy: Ignore` locally, on purpose.** If Kyverno is down, pods are admitted unchecked. On a laptop this is safer than a cluster that cannot start pods after a restart.
- **`failurePolicy: Fail` on the OCI server**, together with more than one admission-controller replica, so that a gate that is down blocks rather than opens.
- **Background evaluation is off** (`evaluation.background.enabled: false`) because the background controller is disabled to save memory. Policy reports are written only at admission time. The cleanup controller is disabled too, and the reports controller stays on.
- **Installation:** Kyverno chart 3.9.2 (app v1.19.2) is installed through Argo CD with `ServerSideApply=true`, because its CRDs are too large for client-side apply. An `ignoreDifferences` rule on `CustomResourceDefinition` metadata annotations and labels removes cosmetic permanent drift (#10).

## 5. Consequences

- **Positive.** An image that was not signed by our pipeline cannot start in a covered namespace, verified by testing both the signed and the unsigned case. There is no signing key to steal, and the trust anchor is a single reviewed workflow at a tagged version.
- **Known gap: the source branch is not checked.** The policy verifies who signed, not which branch of the app repo was built. The image `test-bump-actions` was built from a branch but carries the same signer identity, so it is still admitted. Closing this needs an additional check on the certificate's source-ref extension requiring `refs/heads/main` of the app repo. The exact syntax must be verified against the installed CRD schema or the Kyverno documentation before it is written.
- **Locally the gate can be open.** With `failurePolicy: Ignore`, an outage of Kyverno means unchecked admission. This is accepted for the laptop only.
- **A signature is not a safety guarantee.** It means our pipeline built and vouched for the image. Trivy runs before signing, and a failing scan blocks signing.
- **No continuous re-scan locally.** Pods that were already running are not re-evaluated, because background evaluation is off.
- **Public packages.** The cluster pulls from GHCR anonymously, so image packages must be public. Images must never contain secrets.
- **Documentation debt.** Most web examples still use the deprecated `verifyImages`, so any example copied from the internet must be checked against the `policies.kyverno.io/v1` schema.

## 6. Follow-up decisions

1. Add the source-ref check requiring `refs/heads/main`, after verifying the syntax in the schema or documentation.
2. Switch `failurePolicy` to `Fail` with two or more admission replicas on the OCI server.
3. Re-enable background evaluation and the background controller on the OCI server, where memory allows it.
4. Review the namespace exclusions once more workloads exist, and decide how legitimate exceptions are recorded.
5. Decide how the policy is tested automatically, for example by running the unsigned-image rejection check in CI.

## 7. Review notes

*(To be filled in after review: questions raised, changes made, final status.)*
