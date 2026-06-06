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
- Firestore named database IDs must be at least 4 characters. The dev database
  is `dev-db`; production remains `(default)`.

## AI Provider (Temporary)

`coach_service.chat()` currently routes through **Vertex AI Gemini**
(`settings.use_gemini_fallback=True`, default) because Vertex AI Claude (Sonnet
4.5 / Haiku 4.5) is access-OK but **quota 0** on the global endpoint and not
provisioned on regional endpoints. The Claude path is still in the codebase and
can be re-enabled by setting `use_gemini_fallback=False` once quota is granted.

Tracking: Issue #79. Do not remove the Gemini path until that issue is closed.
