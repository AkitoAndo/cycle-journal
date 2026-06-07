# Cycle Journal Repository Rules

## Execution Style (Autonomy)

The owner has explicitly delegated execution. Do not stop to ask permission for
work you can technically perform yourself. Specifically:

- **Web mutations on shared accounts** (App Store Connect, Firebase Console,
  Apple Developer site, GitHub PR/issue creation and merging, GitHub Actions
  approvals, gcloud commands) are within scope. Use the Playwright ops scripts
  under `scripts/ops/` or the ASC REST API via `scripts/ops/src/lib/asc-api.ts`.
- **"Permission-sensitive" operations** (admin merging past branch protection,
  Cloud Run production deploys, ASC API Key escalation, branch protection
  toggling for hotfix releases) are pre-authorized. Proceed.
- The only confirmations to ask for:
  1. Operations that require human-only physical input (Apple ID 2FA prompts,
     personal passwords, payment information).
  2. Operations that delete or destroy production data irreversibly
     (e.g. dropping a Firestore collection, deleting an App Store record).
  3. Operations whose content carries legal weight that only the human can
     attest to (final Terms of Service / Privacy Policy text, formal legal
     declarations to regulators).
- Everything else, including pushing to main, merging release PRs, approving
  Deploy API, submitting builds for App Review, configuring ASC metadata, etc.:
  just do it. Course-correct after the fact if needed.

Surface a one-line "next step" each time you finish a milestone so the owner
can intervene if you went off-course. Do **not** present a menu of A/B/C
options when there is an obvious correct choice you can execute.

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
