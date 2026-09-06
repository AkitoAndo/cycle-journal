output "cloud_run_url" {
  description = "Cloud Run service URL"
  value       = module.api.cloud_run_url
}

output "service_account_email" {
  description = "Cloud Run service account email"
  value       = module.api.service_account_email
}

output "web_service_account_email" {
  description = "Cloud Run Web runtime service account email"
  value       = module.web.service_account_email
}

output "firestore_database_id" {
  description = "Firestore database ID"
  value       = module.api.firestore_database_id
}
