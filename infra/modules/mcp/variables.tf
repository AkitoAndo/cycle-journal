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

variable "image_tag" {
  type    = string
  default = "dev"
}

variable "artifact_registry_repository_id" {
  type    = string
  default = "cycle-api"
}
