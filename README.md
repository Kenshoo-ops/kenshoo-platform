# kenshoo-platform

**The secure, reproducible platform that [kenshoo](https://github.com/Kenshoo-ops/kenshoo) runs on.**

This repository holds everything needed to build and operate the platform from code: cloud infrastructure, the Kubernetes cluster, GitOps configuration, security policies and observability. After a one-time bootstrap, the cluster configures itself from this repository.

> **Status: early development.** The platform runs on a local k3d cluster: Argo CD deploys everything from this repository, and Kyverno rejects any image that was not signed by the Kenshoo build pipeline. The cloud server on Oracle Cloud does not exist yet (its creation is blocked by a lack of free ARM capacity), so nothing runs in the cloud today. See the [roadmap](#roadmap).

## What it contains

| Area | Tools | Status |
|---|---|---|
| Cloud infrastructure | Terraform on Oracle Cloud (OCI): network, compute, object storage, IAM | Network applied. Compute instance blocked by "Out of host capacity" |
| Kubernetes | k3s on an ARM instance | Planned for the server. A local k3d cluster is used in the meantime |
| GitOps | Argo CD with an app-of-apps layout | Working locally |
| Admission policy | Kyverno: signed images only | Working locally, in Deny mode |
| Admission policy (more rules) | Non-root, no `latest` tag, resource limits | Planned |
| Secrets | SOPS with age, encrypted values stored in git | Planned |
| Observability | Prometheus | Working locally, trimmed to fit a small node |
| Observability (more) | Loki, Grafana, Alertmanager | Planned, for the server |

## The idea: a verified chain

Every step hands a checked artifact to the next one:

```text
code ─► build ─► scan ─► sign ─► publish ─► declare ─► admit ─► run ─► observe ─► alert
```

The [pipeline](https://github.com/Kenshoo-ops/kenshoo-workflows) signs each image. This platform verifies that signature before anything is allowed to run, so a tampered or unsigned image cannot start, even if it reaches the registry.

## Layout

```text
kenshoo-platform/
├── terraform/            OCI: compartment, network, compute instance
├── bootstrap/            Argo CD values and the root Application
├── clusters/local/       one Argo CD Application per deployed service
├── apps/
│   ├── kenshoo/          sample-app deployment (the kenshoo verifier comes later)
│   ├── observability/    placeholder, empty for now
│   └── policies/         Kyverno image verification policy
└── docs/adr/             architecture decision records
```

A `secrets/` folder for SOPS-encrypted values will be added with the secrets decision.

## Decisions

| ADR | Title | Status |
|---|---|---|
| [0001](docs/adr/0001-overall-architecture.md) | Overall architecture | See the ADR |
| [0002](docs/adr/0002-clean-rebuild-with-phase-switch.md) | Clean rebuild of the OCI infrastructure, in two phases | Proposed |
| [0003](docs/adr/0003-kyverno-image-verification.md) | Admit only images signed by our own pipeline | Proposed |
| [0004](docs/adr/0004-gitops-layout-app-of-apps.md) | GitOps layout with Argo CD and an app-of-apps root | Proposed |

## Design principles

- **Everything as code.** No manual changes to the cluster. If it is not in git, it does not exist.
- **Least privilege** for credentials, IAM, network and Pod permissions.
- **Verify, don't trust.** Every artifact is checked where it is used.
- **Reproducible.** Rebuilding the platform from nothing is a defined procedure.
- **Decisions are written down** as short Architecture Decision Records in `docs/adr/`.

## Prerequisites

To run the platform locally:

- Docker Desktop with roughly 4 GiB of memory available to its VM
- `k3d`, `kubectl` and `helm`

For the cloud part (planned):

- An Oracle Cloud account (the Always Free tier is enough for the ARM instance)
- Terraform, `sops` and `age`

## Roadmap

- [x] ADR-0001: overall architecture
- [x] Terraform for the OCI compartment and network
- [ ] Terraform for the OCI compute instance (blocked: "Out of host capacity")
- [ ] k3s installation on the server
- [x] Argo CD bootstrap and app-of-apps layout (local cluster)
- [ ] SOPS secrets
- [x] Kyverno image signature verification (local cluster, Deny mode)
- [ ] Further Kyverno policies (non-root, no `latest` tag, resource limits)
- [ ] Close the known gap: require that signed images were built from `main`
- [x] Prometheus (local, lean)
- [ ] Loki, Grafana and alerting, on the server
- [ ] Network policies and least-privilege IAM
- [ ] Local quickstart on `k3d`

## Contributing

The project is just getting started. Issues and ideas are welcome. Please open an issue before starting a large change. Significant design changes begin as an ADR pull request. All changes go through pull requests.

## Security

Please report vulnerabilities privately. See [SECURITY.md](SECURITY.md).

## License

Apache License 2.0. See [LICENSE](LICENSE).
