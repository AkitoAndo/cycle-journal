# Cloud Run用サービスアカウント
resource "google_service_account" "cloud_run" {
  account_id   = "cycle-api-${var.environment}"
  display_name = "CycleJournal API (${var.environment})"
  project      = var.project_id
}

# Firestore読み書き
resource "google_project_iam_member" "firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Secret Manager読み取り
resource "google_project_iam_member" "secret_manager" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Vertex AI呼び出し
resource "google_project_iam_member" "vertex_ai" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}
