locals {
  project_services = toset([
    "run.googleapis.com",
    "firestore.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "aiplatform.googleapis.com",
  ])

  app_store_connect_secret_ids = toset([
    "app-store-connect-api-key",
    "app-store-connect-key-id",
    "app-store-connect-issuer-id",
  ])
}

resource "google_project_service" "apis" {
  for_each = local.project_services

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "api" {
  location      = var.region
  repository_id = var.artifact_registry_repository_id
  format        = "DOCKER"
  description   = "Treow API Docker images"

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret" "app_store_connect" {
  for_each = local.app_store_connect_secret_ids

  secret_id = each.key
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [
    google_project_service.apis["secretmanager.googleapis.com"],
  ]
}
