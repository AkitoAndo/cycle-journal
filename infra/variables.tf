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
  description = "Apple Developer Team ID (Sign in with Apple revoke 用)"
  type        = string
}

variable "apple_key_id" {
  description = "Apple Sign in with Apple Key ID (.p8 と対になる)"
  type        = string
}

variable "apple_iap_issuer_id" {
  description = "App Store Connect IAP Key Issuer ID (UUID, アカウント全体で固定)"
  type        = string
}

variable "apple_iap_key_id" {
  description = "App Store Connect IAP Key ID (10 文字、IAP 専用キー。Sign in with Apple の key_id とは別物)"
  type        = string
}

variable "apple_iap_env" {
  description = "IAP 検証先の Apple 環境。Sandbox / Production。deploy 環境(environment)とは独立。テスト中は Sandbox。"
  type        = string
  default     = "Sandbox"
}
