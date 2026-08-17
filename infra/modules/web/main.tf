resource "google_service_account" "cloud_run" {
  project      = var.project_id
  account_id   = "cycle-web-${var.environment}"
  display_name = "CycleJournal Web (${var.environment})"
}

resource "google_service_account_iam_member" "github_actions_act_as" {
  service_account_id = google_service_account.cloud_run.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.github_actions_service_account}"
}
