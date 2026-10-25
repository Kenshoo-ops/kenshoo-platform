# ADR-0001: Overall architecture

- **Status:** Proposed
- **Date:** 2026-10-25
- **Author:** Ilyas
- **Reviewer:** *(pending)*

## 1. Context

Teams run database backups, but few ever restore them. A backup job that reports "success" only proves that a file was written. It does not prove the file is complete, restorable with the current database version, or contains the data we expect. The usual discovery method is an incident, when it is too late.

kenshoo is a tool that restores backups into a throwaway database on a schedule, runs checks on the restored data, and reports the result.

A tool that reads production backups is a sensitive target, because it handles database dumps and storage credentials. So the project must also answer a second question: how do we build, ship and run a sensitive tool safely?

This ADR records the top-level decisions that shape everything else.

## 2. Decision drivers

- Make "can we recover?" a **measured fact**, not an assumption.
- The tool itself must be **trustworthy**: reproducible, least-privilege, and deployed only from verified artifacts.
- Everything should be **defined as code** and reviewable.
- The project should be **easy for other people to adopt and contribute to**, with clear boundaries between areas.
- It must run on **free-tier infrastructure** (one small ARM instance).

## 3. Decisions

### D1. Verify backups by restoring them

**Options considered**

| Option | Pros | Cons |
|---|---|---|
| A. Monitor the backup job only | Trivial to set up | Proves nothing about the content |
| B. Check file integrity (checksum, size) | Cheap, catches truncation | Cannot detect version incompatibility, missing extensions or wrong data |
| C. **Restore into a throwaway database and check the data** | Proves the backup is usable and gives a recovery-time measurement | Needs compute, and temporary access to backup data |

**Decision:** option C. Options A and B remain useful as inexpensive first checks, but only a real restore proves recoverability.

### D2. Three repositories with separate responsibilities

| Repository | Responsibility |
|---|---|
| `kenshoo` | The verifier (Go) and its container packaging |
| `kenshoo-platform` | Infrastructure, cluster, GitOps and security policies |
| `kenshoo-workflows` | Reusable CI workflows that build, scan, sign and attest images |

**Why:** the workflows must be versioned independently so other repositories can pin a tag. Each layer has a clear review scope, and a contributor can work on one without understanding the others. A monorepo was considered and rejected because versioning the workflows separately becomes awkward and unrelated changes would mix.

### D3. A verified chain from code to running workload

```text
code ─► build ─► scan ─► sign ─► publish ─► declare ─► admit ─► run ─► observe ─► alert
```

- The **pipeline** builds multi-arch images, scans them, produces an SBOM, signs them with keyless signing, and attaches build provenance.
- The **cluster** pulls desired state from git (GitOps) and an admission controller **refuses any image that is not signed by the expected pipeline identity**.

**Why:** signing without enforcement proves nothing, and enforcement without signing has nothing to check. Together they mean a tampered image cannot run, even if someone pushes it to the registry.

### D4. Runtime: a scheduled Job with an ephemeral database

Each verification is a short-lived Kubernetes Job (started by a CronJob). The Pod holds the verifier and an empty temporary Postgres container with ephemeral storage. The Pod is deleted after each run.

**Why:** nothing from production remains after the run, the temporary database is unreachable from outside the Pod, and there is no long-running component to attack or maintain. A custom operator is deferred until the simple model has proven its limits.

### D5. The verifier is written in Go

**Why:** Go is the standard language of the cloud-native ecosystem, builds into a single static binary with a very small image, and has mature libraries for the pieces we need (Postgres, S3-compatible storage, Prometheus). Other languages were considered, including Rust, and set aside to keep the learning effort on the infrastructure and security chain rather than on the language.

## 4. Consequences

**Positive**

- The headline signal, *time since the last verified restore*, directly measures recoverability.
- Supply-chain trust is enforced by the cluster, not by convention.
- Layers can evolve and be maintained independently.
- Backup types and checks can be added as plugins without changing the core.

**Negative and risks**

- Three repositories mean more setup and more coordination than one.
- Restoring large databases costs compute time and may need sampling strategies.
- The verifier needs read access to backups, which makes it a high-value target. Mitigated by read-only credentials, least-privilege IAM, non-root containers, network policies and signed images, and still a real risk to keep reviewing.
- Signing and admission policy add moving parts that can block legitimate deployments if misconfigured. Policies should start in audit mode and move to enforce mode once tested.

## 5. Out of scope for this ADR

Decisions that need their own records:

1. How results are reported from short-lived jobs (Pushgateway or alternatives)
2. GitOps layout and environment structure
3. Secrets management (SOPS and age versus other options)
4. The expected signing identity and admission policy design
5. Network policy baseline
6. Object storage access model and IAM scope
7. Versioning and release strategy for the workflows
8. Where the Helm chart lives and how the platform consumes it

## 6. Review notes

*(To be filled in after review: questions raised, changes made, final status.)*
