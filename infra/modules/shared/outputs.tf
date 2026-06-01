output "artifact_registry_repository_id" {
  description = "Artifact Registry repository ID"
  value       = google_artifact_registry_repository.api.repository_id
}

output "artifact_registry_repo" {
  description = "Artifact Registry repository path"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.api.repository_id}"
}
