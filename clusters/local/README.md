# clusters/local

Argo CD Application manifests for the local k3d cluster.
The root Application (`bootstrap/root-app.yaml`) watches this directory:
every manifest added here becomes a deployed Application, and every manifest
removed from here is pruned from the cluster.

| File | Deploys |
|---|---|
| `kyverno.yaml` | Kyverno (admission controller and reports controller) |
| `policies.yaml` | The image verification policy from `apps/policies/` |
| `sample-app.yaml` | The throwaway signed image from `apps/kenshoo/sample-app/` |
| `prometheus.yaml` | A lean Prometheus (server only) |

See [ADR-0004](../../docs/adr/0004-gitops-layout-app-of-apps.md) for the layout.
