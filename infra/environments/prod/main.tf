provider "google" {
  project = var.project_id
  region  = var.region
}

module "api" {
  source = "../../modules/api"

  project_id            = var.project_id
  region                = var.region
  environment           = "prod"
  firestore_database_id = "(default)"
  google_client_ids     = var.google_client_ids
  cors_allowed_origins  = var.cors_allowed_origins
  apple_team_id         = var.apple_team_id
  apple_key_id          = var.apple_key_id
  apple_apns_key_id     = var.apple_apns_key_id
  apple_iap_issuer_id   = var.apple_iap_issuer_id
  apple_iap_key_id      = var.apple_iap_key_id
  apple_iap_env         = "Sandbox" # テスト完了後 "Production" に変更
  apple_apns_env        = "Production"
}
