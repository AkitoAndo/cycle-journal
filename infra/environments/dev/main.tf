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

  project_id                = var.project_id
  region                    = var.region
  environment               = "dev"
  firestore_database_id     = "dev-db"
  google_client_ids         = var.google_client_ids
  cors_allowed_origins      = var.cors_allowed_origins
  mcp_enabled               = true
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

  project_id                     = var.project_id
  region                         = var.region
  environment                    = "dev"
  oauth_issuer                   = var.mcp_oauth_issuer
  allowed_emails                 = "takeshiogata1105@gmail.com,28ww.lo.ol.ww28@gmail.com"
  github_actions_service_account = "github-actions-deploy@${var.project_id}.iam.gserviceaccount.com"
  service_account_description    = "Runtime identity for Treow Coach Studio MCP in development"
}
