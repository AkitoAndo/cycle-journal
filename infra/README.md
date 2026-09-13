# Treow Infrastructure

Terraform is split by directory and state:

| Directory | State prefix | Owns |
| --- | --- | --- |
| `environments/shared` | `terraform/state/shared` | Project APIs, Artifact Registry |
| `environments/dev` | `terraform/state/dev` | `cycle-api-dev`, Firestore `dev-db`, dev secrets/IAM |
| `environments/prod` | `terraform/state/prod` | `cycle-api-prod`, Firestore `(default)`, prod secrets/IAM |

The legacy root Terraform files are retained only as the source for the first
state migration. Do not run regular plans from `infra/`; use one of the
`infra/environments/*` directories instead.

## Commands

```bash
terraform -chdir=infra/environments/shared init
terraform -chdir=infra/environments/shared plan

terraform -chdir=infra/environments/dev init
terraform -chdir=infra/environments/dev plan

terraform -chdir=infra/environments/prod init
terraform -chdir=infra/environments/prod plan
```

## State Migration Outline

Do the migration before removing the legacy root state from operation.

1. Back up the current state:

   ```bash
   terraform -chdir=infra workspace select prod
   terraform -chdir=infra state pull > infra-state-prod-backup.json
   ```

2. Move shared resources into `environments/shared` state:

   ```bash
   terraform -chdir=infra/environments/shared init
   terraform -chdir=infra/environments/shared import \
     'module.shared.google_artifact_registry_repository.api' \
     'projects/cycle-journal/locations/asia-northeast1/repositories/cycle-api'

   terraform -chdir=infra/environments/shared import \
     'module.shared.google_project_service.apis["run.googleapis.com"]' \
     'cycle-journal/run.googleapis.com'
   terraform -chdir=infra/environments/shared import \
     'module.shared.google_project_service.apis["firestore.googleapis.com"]' \
     'cycle-journal/firestore.googleapis.com'
   terraform -chdir=infra/environments/shared import \
     'module.shared.google_project_service.apis["artifactregistry.googleapis.com"]' \
     'cycle-journal/artifactregistry.googleapis.com'
   terraform -chdir=infra/environments/shared import \
     'module.shared.google_project_service.apis["secretmanager.googleapis.com"]' \
     'cycle-journal/secretmanager.googleapis.com'
terraform -chdir=infra/environments/shared import \
  'module.shared.google_project_service.apis["aiplatform.googleapis.com"]' \
  'cycle-journal/aiplatform.googleapis.com'
terraform -chdir=infra/environments/shared import \
  'module.shared.google_project_service.apis["cloudquotas.googleapis.com"]' \
  'cycle-journal/cloudquotas.googleapis.com'
```

3. Move existing production resources into `environments/prod` state with
   `terraform import` or `terraform state mv -state-out`. Keep Firestore
   `(default)` in prod; do not create a new prod database.

4. Create the dev environment from the new directory:

   ```bash
   terraform -chdir=infra/environments/dev init
   terraform -chdir=infra/environments/dev plan
   terraform -chdir=infra/environments/dev apply
   ```

5. Confirm both environment plans show no unintended destroy:

   ```bash
   terraform -chdir=infra/environments/prod plan
   terraform -chdir=infra/environments/dev plan
   ```

## Manual Resource Reconciliation

The App Store Connect secrets and the production `tasks` index have already
been imported into the split states. The commands below are retained only as
a migration record; do not rerun them against the current state:

```bash
terraform -chdir=infra/environments/shared import \
  'module.shared.google_secret_manager_secret.app_store_connect["app-store-connect-api-key"]' \
  'projects/cycle-journal/secrets/app-store-connect-api-key'
terraform -chdir=infra/environments/shared import \
  'module.shared.google_secret_manager_secret.app_store_connect["app-store-connect-key-id"]' \
  'projects/cycle-journal/secrets/app-store-connect-key-id'
terraform -chdir=infra/environments/shared import \
  'module.shared.google_secret_manager_secret.app_store_connect["app-store-connect-issuer-id"]' \
  'projects/cycle-journal/secrets/app-store-connect-issuer-id'

terraform -chdir=infra/environments/prod import \
  'module.api.google_firestore_index.tasks_by_created_at' \
  'projects/cycle-journal/databases/(default)/collectionGroups/tasks/indexes/CICAgJim14AK'
```

The Web production identity and three Coach MCP development resources were
imported into the split states on 2026-09-13. The commands below are retained
as a migration record; do not rerun them against the current state:

```bash
terraform -chdir=infra/environments/prod import \
  'module.web.google_service_account.cloud_run' \
  'projects/cycle-journal/serviceAccounts/cycle-web-prod@cycle-journal.iam.gserviceaccount.com'
terraform -chdir=infra/environments/prod import \
  'module.web.google_service_account_iam_member.github_actions_act_as' \
  'projects/cycle-journal/serviceAccounts/cycle-web-prod@cycle-journal.iam.gserviceaccount.com roles/iam.serviceAccountUser serviceAccount:github-actions-deploy@cycle-journal.iam.gserviceaccount.com'

terraform -chdir=infra/environments/dev import \
  'module.coach_mcp.google_service_account.mcp' \
  'projects/cycle-journal/serviceAccounts/cycle-coach-mcp-dev@cycle-journal.iam.gserviceaccount.com'
terraform -chdir=infra/environments/dev import \
  'module.coach_mcp.google_service_account_iam_member.github_actions_act_as' \
  'projects/cycle-journal/serviceAccounts/cycle-coach-mcp-dev@cycle-journal.iam.gserviceaccount.com roles/iam.serviceAccountUser serviceAccount:github-actions-deploy@cycle-journal.iam.gserviceaccount.com'
terraform -chdir=infra/environments/dev import \
  'module.coach_mcp.google_cloud_run_v2_service.mcp' \
  'projects/cycle-journal/locations/asia-northeast1/services/cycle-coach-mcp-dev'
```

After the imports, review a fresh plan. The development `tasks` index, the
Coach MCP public invoker binding, and the API environment additions are not
present in GCP and should remain as intentional changes. Do not import them.

The Random provider can show an in-place update for
`module.api.random_password.jwt_secret` even when its before and after
attributes are identical. For each occurrence, save and review the exact plan,
confirm that `google_secret_manager_secret_version.jwt_secret` has no action,
and apply that saved plan only. Never taint or replace the password resource.
After applying, run a final plan in all three environments.
