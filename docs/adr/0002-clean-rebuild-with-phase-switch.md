# ADR-0002: Clean rebuild of the OCI infrastructure, in two phases

- **Status:** Proposed
- **Date:** 2026-10-26
- **Author:** Ilyas
- **Reviewer:** *(pending)*
- **Implemented in:** `terraform/` of this repository (pull request #3)

## 1. Context

The platform needs a server to run k3s on. The account is on the Oracle Cloud Always Free tier. The ARM allowance of this account is **2 OCPUs and 12 GB of memory in total**, which fits **one** instance of the size we need, not two.

That whole allowance was already used by `portfolio-vm`, which hosted an earlier personal project (Folio). That VM was created by hand in the console. A Terraform file existed for it, but there was **no state file**, so Terraform never managed it. It lived in the tenancy's root compartment and was reachable over SSH from the whole internet.

We need the kenshoo infrastructure defined as code, isolated from other things in the account, and rebuildable from scratch.

## 2. Decision drivers

- The platform must be **reproducible from code**, starting from an empty account.
- **Isolation:** the platform should not share a compartment with unrelated resources.
- **Least privilege:** SSH and the Kubernetes API should not be open to the internet.
- The free allowance allows only one instance, so the old and new instances **cannot exist together**.
- Free-tier ARM capacity can be unavailable, and a failed launch must not leave a half-built state.
- Minimal cost and minimal risk of data loss for the old project.

## 3. Options considered

| Option | Pros | Cons |
|---|---|---|
| **A. Adopt the existing VM** with `terraform import` | No downtime, no capacity risk | Keeps old names, the root compartment and the open SSH rule. Describes console-made resources instead of proving a rebuild |
| **B. Clean rebuild** in a new compartment | Right names, isolation and security rules from the start. Proves the platform can be built from nothing | The old project goes offline. The new instance needs free ARM capacity, which may be unavailable |
| **C. Run both** old and new side by side | No downtime | Not possible: the allowance fits one instance |

## 4. Decision

**Option B, in two phases controlled by a variable `create_instance`.**

- **Phase 1** (`create_instance = false`): Terraform creates the `kenshoo` compartment and the whole network (VCN, internet gateway, route table, security list, subnet). This needs no compute capacity, so it cannot fail for that reason, and it can run while the old VM still exists.
- **Phase 2** (`create_instance = true`): after the old VM is backed up and terminated, Terraform creates the ARM instance.
- A small retry script (`retry-apply.sh`) repeats the apply while OCI answers "Out of host capacity", and stops on any other error.

Security defaults built into the code:
- SSH (22) and the Kubernetes API (6443) accept traffic only from the administrator's IP, and a validation refuses `0.0.0.0/0`.
- Ports 80 and 443 are open to everyone, for web traffic later.
- The legacy instance metadata service is disabled.
- A newer OS image appearing later does not force the instance to be replaced.

## 5. Consequences

**Positive**
- The whole platform base is defined in code and lives in an isolated compartment.
- Network exposure is much smaller than before.
- The phase switch makes the risky part (the instance) separate from the part that always works.

**Negative and risks**
- **Downtime of the old project** until it returns on Kubernetes. Mitigated: its code is in git, and its database dump and secrets were backed up before the old VM was removed.
- **Capacity.** The first launch attempt failed with "Out of host capacity", which shows the risk is real. The retry script is a workaround, not a guarantee. If capacity stays unavailable, the fallback is to try a smaller shape first and resize later, or to upgrade the account type.
- **`create_instance` is dangerous if flipped back.** Setting it to `false` after the instance exists makes the next plan destroy the instance. Always read the plan before applying.
- **State is local and kept out of git on purpose.** If the state file is lost, Terraform loses track of what it created. Moving state to remote storage is a separate decision.
- **The public IP changes** because the instance is new.

## 6. Follow-up decisions

1. Remote Terraform state (OCI Object Storage) and state locking.
2. Whether to attach a reserved public IP so the address survives a rebuild.
3. How k3s is installed: cloud-init, Ansible or a script, and who owns that boundary.
4. Moving the earlier project onto the platform as a workload deployed through GitOps.

## 7. Review notes

*(To be filled in after review: questions raised, changes made, final status.)*
