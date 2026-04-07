# Artifact Registry は共有 — dev 環境でのみ管理
resource "google_artifact_registry_repository" "api" {
  count         = var.environment == "dev" ? 1 : 0
  location      = var.region
  repository_id = "cycle-api"
  format        = "DOCKER"
  description   = "CycleJournal API Docker images"

  depends_on = [google_project_service.apis]
}
