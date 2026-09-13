# platform-common + payments-api

A worked example of the **library-chart pattern**: one versioned template
contract owned by the platform team, many thin application charts owned by
product teams.

```
charts/
  platform-common/            type: library  -> renders nothing on its own
    Chart.yaml                version 1.4.0  = the TEMPLATE CONTRACT version
    values.yaml               documents the contract (NOT parent defaults)
    templates/
      _helpers.tpl            names, labels, image ref, capability shims
      _validations.tpl        fail-fast policy gate (runs at render time)
      _workload.yaml          Deployment | StatefulSet from one definition
      _service.yaml           ClusterIP + headless
      _ingress.yaml           networking.k8s.io/v1, tpl-rendered hosts
      _autoscaling.yaml       HPA (autoscaling/v2) + PodDisruptionBudget
      _rbac.yaml              ServiceAccount, Role, RoleBinding
      _networkpolicy.yaml     default-deny with explicit allow lists
      _extraobjects.tpl       escape hatch: arbitrary manifests from values

  payments-api/               type: application -> what a product team owns
    Chart.yaml                version 2.7.3, appVersion 4.11.2, deps
    values.yaml               safe defaults
    values-prod.yaml          deltas only
    values.schema.json        structural validation, enforced by Helm itself
    templates/
      deployment.yaml         one-liner: include platform-common.workload
      service|ingress|hpa|pdb|serviceaccount|rbac|networkpolicy|extra-objects.yaml
      configmap.yaml          chart-specific, not in the library
      externalsecret.yaml     chart-specific (External Secrets Operator)
      db-migration-job.yaml   pre-upgrade hook, blocks the release on failure
      tests/test-connection.yaml   `helm test` smoke check
    tests/workload_test.yaml  helm-unittest suite incl. negative policy tests
    files/                    static config pulled in via .Files.Glob

Makefile                      local dev loop: lint -> unit -> kubeconform -> policy -> push
.gitlab-ci.yml                two version streams, immutable publish, cosign + SBOM
hack/render-all-consumers.sh  library CI: diff rendered output of every consumer
```

## Quick start

```bash
helm dependency update charts/payments-api
helm lint charts/payments-api --strict
helm template rel charts/payments-api -f charts/payments-api/values-prod.yaml \
  --api-versions autoscaling/v2 | less
helm unittest charts/payments-api          # requires the helm-unittest plugin
```

Registries and image references are placeholders (`registry.example.com`);
point them at your own before use. These charts were authored but not
`helm lint`-ed in the sandbox that produced them, so run the lint step first.

## Versioning rules used here

| Change | Chart `version` | `appVersion` |
|---|---|---|
| Template output changes in a way that needs values edits | major | unchanged |
| New optional value, backwards compatible | minor | unchanged |
| Fix/default tweak, same rendered shape | patch | unchanged |
| New app image, no template change | patch | new image tag |

* `version` is SemVer and **immutable** once pushed - the publish job refuses
  to overwrite an existing version.
* `appVersion` is a free-form string, always quoted.
* Internal library dependency uses `~1.4.0` (patch drift allowed);
  third-party dependencies are pinned exactly. `Chart.lock` is committed.
* Branch builds publish `2.7.3-rc.<pipeline>.<sha>`, which SemVer sorts
  *below* `2.7.3`, so `--version '~2.7.0'` never picks up a pre-release.
* OCI tags cannot contain `+`, so use pre-release identifiers (`-rc.1`)
  rather than build metadata (`+sha`).
