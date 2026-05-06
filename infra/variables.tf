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
  default     = "dev"
}

variable "use_langgraph" {
  description = "Enable LangGraph coaching flow (emotion analysis, cycle detection, safety filter)"
  type        = bool
  default     = false
}

variable "google_client_id" {
  description = "Google OAuth Client ID for iOS Sign-In"
  type        = string
  default     = "1031235624127-6fgcbv1khltu4snpktpdd0cab025coab.apps.googleusercontent.com"
}

variable "apple_team_id" {
  description = "Apple Developer Team ID (Sign in with Apple revoke 用)"
  type        = string
}

variable "apple_key_id" {
  description = "Apple Sign in with Apple Key ID (.p8 と対になる)"
  type        = string
}
