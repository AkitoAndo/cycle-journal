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
