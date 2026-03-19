resource "google_artifact_registry_repository" "api" {
  location      = var.region
  repository_id = "cycle-api"
  format        = "DOCKER"
  description   = "CycleJournal API Docker images"

  depends_on = [google_project_service.apis]
}
