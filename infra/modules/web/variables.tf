variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Lowercase environment name used as a GCP resource suffix"
  type        = string

  validation {
    condition = (
      length(var.environment) <= 20 &&
      can(regex("^[a-z][a-z0-9-]*$", var.environment)) &&
      !endswith(var.environment, "-")
    )
    error_message = "environment must be 1-20 lowercase letters, digits, or hyphens; it must start with a letter and end with a letter or digit."
  }
}

variable "service_account_description" {
  description = "Optional description to preserve when adopting an existing runtime identity"
  type        = string
  default     = null
}

variable "github_actions_service_account" {
  description = "GitHub Actions deployer allowed to run the Web service"
  type        = string
}
