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
