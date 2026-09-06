# Branching and Deployment

## Branch Strategy

Treow uses a GitLab Flow style environment branch model.

| Flow | Target |
| --- | --- |
| `feature/*` -> PR -> `develop` | Integration and dev deploy |
| `develop` -> PR -> `main` | Production release |
| `fix/*` -> PR -> `main` -> merge back to `develop` | Production hotfix |

`develop` is the default branch. `main` is production and must receive changes
only through pull requests.

## Environments

| Environment | Branch | Cloud Run | Firestore |
| --- | --- | --- | --- |
| dev | `develop` | `cycle-api-dev` | `dev-db` |
| prod | `main` | `cycle-api-prod` | `(default)` |

The GCP project remains `cycle-journal`. Project-level IAM, billing, quotas, and
Artifact Registry are shared.

## CI/CD

`.github/workflows/api-ci-cd.yml` runs API lint and tests on pull requests to
`develop` or `main`.

On push:

- `develop` builds and deploys the API image to `cycle-api-dev`.
- `main` builds and deploys the API image to `cycle-api-prod`.

The workflow expects these GitHub secrets:

| Secret | Purpose |
| --- | --- |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Workload Identity Federation provider |
| `GCP_SERVICE_ACCOUNT` | Deploy service account email |

Use GitHub Environments:

- `api-dev`: no approval gate
- `api-prod`: require reviewer approval before production deploy

## Terraform

Use directory-per-environment Terraform:

```bash
terraform -chdir=infra/environments/shared plan
terraform -chdir=infra/environments/dev plan
terraform -chdir=infra/environments/prod plan
```

Do not switch environments with Terraform workspaces.
