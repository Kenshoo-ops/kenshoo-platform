# kenshoo-platform

**The secure, reproducible platform that [kenshoo](https://github.com/Kenshoo-ops/kenshoo) runs on.**

This repository holds everything needed to build and operate the platform from code: cloud infrastructure, the Kubernetes cluster, GitOps configuration, security policies and observability. After a one-time bootstrap, the cluster configures itself from this repository.

> **Status: early development.** The design is settled, but the infrastructure is not built yet. Nothing here is deployable today. See the [roadmap](#roadmap).

## What it will contain

| Area | Tools |
|---|---|
| Cloud infrastructure | Terraform on Oracle Cloud (OCI): network, compute, object storage, IAM |
| Kubernetes | k3s on an ARM instance |
| GitOps | Argo CD with an app-of-apps layout |
| Admission policy | Kyverno: signed images only, non-root, no `latest` tag, resource limits |
| Secrets | SOPS with age, encrypted values stored in git |
| Observability | Prometheus, Loki, Grafana, Alertmanager |

## The idea: a verified chain

Every step hands a checked artifact to the next one:

```text
code ─► build ─► scan ─► sign ─► publish ─► declare ─► admit ─► run ─► observe ─► alert
```

The [pipeline](https://github.com/Kenshoo-ops/kenshoo-workflows) signs each image. This platform verifies that signature before anything is allowed to run, so a tampered or unsigned image cannot start, even if it reaches the registry.

## Planned layout

*This is the intended structure. It may change as the work progresses.*

```text
kenshoo-platform/
├── terraform/            OCI: network, compute, object storage, IAM
├── bootstrap/            k3s install, Argo CD install
├── clusters/prod/        Argo CD app-of-apps entry point
├── apps/
│   ├── kenshoo/          verifier deployment
│   ├── observability/    Prometheus, Loki, Grafana, Alertmanager
│   └── policies/         Kyverno policies
├── secrets/              SOPS-encrypted values
└── docs/adr/             architecture decision records
```

## Design principles

- **Everything as code.** No manual changes to the cluster. If it is not in git, it does not exist.
- **Least privilege** for credentials, IAM, network and Pod permissions.
- **Verify, don't trust.** Every artifact is checked where it is used.
- **Reproducible.** Rebuilding the platform from nothing is a defined procedure.
- **Decisions are written down** as short Architecture Decision Records in `docs/adr/`.

## Prerequisites (planned)

- An Oracle Cloud account (the Always Free tier is enough for the ARM instance)
- Terraform, `kubectl`, `sops` and `age`
- Optionally `kind` for trying the platform locally

## Roadmap

- [ ] ADR-001: overall architecture
- [ ] Terraform for the OCI network and compute instance
- [ ] k3s installation and Argo CD bootstrap
- [ ] App-of-apps layout and SOPS secrets
- [ ] Kyverno policies, including image signature verification
- [ ] Observability stack with dashboards and alerts
- [ ] Network policies and least-privilege IAM
- [ ] Local quickstart on `kind`

## Contributing

The project is just getting started. Issues and ideas are welcome. Please open an issue before starting a large change. Significant design changes begin as an ADR pull request. All changes go through pull requests.

## Security

Please report vulnerabilities privately. See [SECURITY.md](SECURITY.md).

## License

Apache License 2.0. See [LICENSE](LICENSE).
