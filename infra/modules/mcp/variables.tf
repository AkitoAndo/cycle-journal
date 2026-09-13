variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "environment" {
  description = "Lowercase environment name used as a GCP resource suffix"
  type        = string

  validation {
    condition = (
      length(var.environment) <= 14 &&
      can(regex("^[a-z][a-z0-9-]*$", var.environment)) &&
      !endswith(var.environment, "-")
    )
    error_message = "environment must be 1-14 lowercase letters, digits, or hyphens; it must start with a letter and end with a letter or digit."
  }
}

variable "service_account_description" {
  description = "Optional description to preserve when adopting an existing runtime identity"
  type        = string
  default     = null
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
