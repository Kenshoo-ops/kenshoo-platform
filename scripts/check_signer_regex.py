#!/usr/bin/env python3
"""Check that the Kyverno policy's subjectRegExp matches real release signers and nothing else."""
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "apps/policies/verify-kenshoo-images.yaml"
text = open(path).read()
m = re.search(r"subjectRegExp:\s*'([^']+)'", text)
if not m:
    sys.exit("subjectRegExp not found in " + path)
rx = re.compile(m.group(1))

base = "https://github.com/Kenshoo-ops/kenshoo-workflows/.github/workflows/secure-build.yml@"
good = ["refs/tags/v0.1.2", "refs/tags/v1.0.0", "refs/tags/v10.20.30"]
bad = ["refs/tags/vanything", "refs/tags/v1", "refs/tags/v1.0", "refs/tags/v0.1.2-rc1",
       "refs/tags/v0.1.2.evil", "refs/heads/main"]

failures = []
for ref in good:
    if not rx.search(base + ref):
        failures.append("should match: " + ref)
for ref in bad:
    if rx.search(base + ref):
        failures.append("should NOT match: " + ref)
if rx.search(base.replace("kenshoo-workflows", "evil") + good[0]):
    failures.append("should NOT match a different repository")

if failures:
    print("signer regex check FAILED:\n  " + "\n  ".join(failures))
    sys.exit(1)
print("signer regex check passed (%d match, %d no-match cases)" % (len(good), len(bad) + 1))
