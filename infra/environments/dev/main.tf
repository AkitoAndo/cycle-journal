provider "google" {
  project = var.project_id
  region  = var.region
}

module "web" {
  source = "../../modules/web"

  project_id                     = var.project_id
  environment                    = "dev"
  github_actions_service_account = "github-actions-deploy@${var.project_id}.iam.gserviceaccount.com"
}

module "api" {
  source = "../../modules/api"

  project_id            = var.project_id
  region                = var.region
  environment           = "dev"
  firestore_database_id = "dev-db"
  google_client_ids     = "1031235624127-j358em4cvl8hll11p4kg3pd650chj82f.apps.googleusercontent.com"
  cors_allowed_origins = join(",", [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://localhost:3001",
    "http://127.0.0.1:3001",
    "https://cycle-web-dev-1031235624127.asia-northeast1.run.app",
  ])
  mcp_service_account_email = module.coach_mcp.service_account_email
  apple_team_id             = var.apple_team_id
  apple_key_id              = var.apple_key_id
  apple_apns_key_id         = var.apple_apns_key_id
  apple_iap_issuer_id       = var.apple_iap_issuer_id
  apple_iap_key_id          = var.apple_iap_key_id
  apple_iap_env             = "Sandbox"
  apple_apns_env            = "Sandbox"
}

module "coach_mcp" {
  source = "../../modules/mcp"

  project_id     = var.project_id
  region         = var.region
  environment    = "dev"
  oauth_issuer   = var.mcp_oauth_issuer
  allowed_emails = "takeshiogata1105@gmail.com,28ww.lo.ol.ww28@gmail.com"
}
