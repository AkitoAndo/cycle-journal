resource "google_cloud_run_v2_service" "api" {
  name     = "cycle-api-${var.environment}"
  location = var.region

  template {
    service_account = google_service_account.cloud_run.email

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.api.repository_id}/api:latest"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }

      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }

      env {
        name  = "GCP_REGION"
        value = var.region
      }

      env {
        name  = "APPLE_BUNDLE_ID"
        value = "com.akitoando.CycleJournal"
      }

      env {
        name  = "APPLE_TEAM_ID"
        value = var.apple_team_id
      }

      env {
        name  = "APPLE_KEY_ID"
        value = var.apple_key_id
      }

      env {
        name = "APPLE_PRIVATE_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.apple_auth.secret_id
            version = "latest"
          }
        }
      }

      # IAP (App Store Server API / ASSN V2)
      env {
        name  = "APPLE_IAP_ISSUER_ID"
        value = var.apple_iap_issuer_id
      }

      env {
        name  = "APPLE_IAP_KEY_ID"
        value = var.apple_iap_key_id
      }

      env {
        name = "APPLE_IAP_PRIVATE_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.apple_iap_private_key.secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "APPLE_IAP_ENV"
        value = var.apple_iap_env
      }

      env {
        name  = "USE_LANGGRAPH"
        value = var.use_langgraph ? "true" : "false"
      }

      env {
        name  = "GOOGLE_CLIENT_ID"
        value = var.google_client_id
      }

      env {
        name  = "GOOGLE_CLIENT_IDS"
        value = var.google_client_ids
      }

      env {
        name  = "CORS_ALLOWED_ORIGINS"
        value = var.cors_allowed_origins
      }

      env {
        name = "JWT_SECRET_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }
    }
  }

  depends_on = [
    google_project_service.apis,
    google_secret_manager_secret_version.jwt_secret,
    google_secret_manager_secret.apple_auth,
    google_secret_manager_secret.apple_iap_private_key,
  ]
}

# 未認証アクセスを許可（認証はアプリ側のミドルウェアで行う）
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
