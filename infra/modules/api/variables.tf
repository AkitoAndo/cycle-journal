variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-northeast1"
}

variable "environment" {
  description = "Environment name (dev / prod)"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "firestore_database_id" {
  description = "Firestore database ID used by the API"
  type        = string
}

variable "firestore_deletion_policy" {
  description = "Deletion behavior for Firestore databases when Terraform destroys the resource"
  type        = string
  default     = "ABANDON"

  validation {
    condition     = contains(["ABANDON", "DELETE"], var.firestore_deletion_policy)
    error_message = "firestore_deletion_policy must be ABANDON or DELETE."
  }
}

variable "artifact_registry_repository_id" {
  description = "Artifact Registry repository ID for API Docker images"
  type        = string
  default     = "cycle-api"
}

variable "image_tag" {
  description = "Initial Docker image tag. CD owns later image updates."
  type        = string
  default     = "latest"
}

variable "use_langgraph" {
  description = "Enable LangGraph coaching flow"
  type        = bool
  default     = false
}

variable "google_client_id" {
  description = "Google OAuth Client ID for iOS Sign-In"
  type        = string
  default     = "1031235624127-6fgcbv1khltu4snpktpdd0cab025coab.apps.googleusercontent.com"
}

variable "apple_bundle_id" {
  description = "Apple app bundle ID"
  type        = string
  default     = "com.akitoando.CycleJournal"
}

variable "apple_team_id" {
  description = "Apple Developer Team ID"
  type        = string
}

variable "apple_key_id" {
  description = "Apple Sign in with Apple Key ID"
  type        = string
}

variable "apple_iap_issuer_id" {
  description = "App Store Connect IAP Key Issuer ID"
  type        = string
}

variable "apple_iap_key_id" {
  description = "App Store Connect IAP Key ID"
  type        = string
}

variable "apple_iap_env" {
  description = "IAP verification Apple environment: Sandbox or Production"
  type        = string
  default     = "Sandbox"

  validation {
    condition     = contains(["Sandbox", "Production"], var.apple_iap_env)
    error_message = "apple_iap_env must be Sandbox or Production."
  }
}
