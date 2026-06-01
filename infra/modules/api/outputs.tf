output "cloud_run_url" {
  description = "Cloud Run service URL"
  value       = google_cloud_run_v2_service.api.uri
}

output "service_account_email" {
  description = "Cloud Run service account email"
  value       = google_service_account.cloud_run.email
}

output "firestore_database_id" {
  description = "Firestore database ID used by this environment"
  value       = google_firestore_database.main.name
}
