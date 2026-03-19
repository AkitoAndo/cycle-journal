resource "google_secret_manager_secret" "apple_auth" {
  secret_id = "apple-auth-config-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}
