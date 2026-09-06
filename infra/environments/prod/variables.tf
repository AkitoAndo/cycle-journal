variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-northeast1"
}

variable "google_client_ids" {
  description = "Additional comma-separated Google OAuth Client IDs"
  type        = string
  default     = ""
}

variable "cors_allowed_origins" {
  description = "Comma-separated browser origins allowed by API CORS"
  type        = string
  default     = ""
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


variable "apple_apns_key_id" {
  description = "Apple Push Notification service Auth Key ID. Empty disables APNs sending."
  type        = string
  default     = ""
}
