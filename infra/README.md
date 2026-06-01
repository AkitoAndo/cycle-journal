# Cycle Journal Infrastructure

Terraform is split by directory and state:

| Directory | State prefix | Owns |
| --- | --- | --- |
| `environments/shared` | `terraform/state/shared` | Project APIs, Artifact Registry |
| `environments/dev` | `terraform/state/dev` | `cycle-api-dev`, Firestore `dev`, dev secrets/IAM |
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
