# Cycle Journal Repository Rules

## Branch Flow

- Default branch: `develop`
- Feature work: `feature/*` -> pull request -> `develop`
- Release promotion: `develop` -> pull request -> `main`
- Hotfix only: `fix/*` -> pull request -> `main`, then merge `main` back into `develop`
- Do not push directly to `main`. Use pull requests for production changes.

## Deployments

- Push to `develop` deploys the API to `cycle-api-dev`.
- Push to `main` deploys the API to `cycle-api-prod`.
- Production approval is controlled by the GitHub Environment named `api-prod`.

## Infrastructure

- Use `infra/environments/shared`, `infra/environments/dev`, and `infra/environments/prod`.
- Do not use Terraform workspaces for environment switching.
- Shared project-level resources live in `shared`; environment-specific Cloud Run,
  Secret Manager, IAM, and Firestore resources live in `dev` or `prod`.
