variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "oauth_issuer" {
  type        = string
  description = "OAuth 2.1 / OIDC issuer used by the remote MCP client"
}

variable "allowed_emails" {
  type        = string
  description = "Comma-separated verified email allowlist for MCP users"
}

variable "github_actions_service_account" {
  type        = string
  description = "GitHub Actions deploy service account allowed to run as the MCP service account"
}

variable "image_tag" {
  type    = string
  default = "dev"
}

variable "artifact_registry_repository_id" {
  type    = string
  default = "cycle-api"
}
