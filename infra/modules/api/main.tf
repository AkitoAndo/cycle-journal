locals {
  api_image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repository_id}/api:${var.image_tag}"
}

resource "google_service_account" "cloud_run" {
  account_id   = "cycle-api-${var.environment}"
  display_name = "CycleJournal API (${var.environment})"
  project      = var.project_id
}

resource "google_project_iam_member" "firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_project_iam_member" "secret_manager" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_project_iam_member" "vertex_ai" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_secret_manager_secret" "apple_auth" {
  secret_id = "apple-auth-config-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "apple_iap_private_key" {
  secret_id = "apple-iap-private-key-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "jwt-secret-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

resource "google_secret_manager_secret_version" "jwt_secret" {
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = random_password.jwt_secret.result
}

resource "google_firestore_database" "main" {
  project     = var.project_id
  name        = var.firestore_database_id
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  deletion_policy = var.firestore_deletion_policy
}

resource "google_firestore_index" "sessions_by_created_at" {
  project    = var.project_id
  database   = google_firestore_database.main.name
  collection = "sessions"

  fields {
    field_path = "user_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "created_at"
    order      = "DESCENDING"
  }
}

resource "google_firestore_index" "tasks_by_status" {
  project    = var.project_id
  database   = google_firestore_database.main.name
  collection = "tasks"

  fields {
    field_path = "user_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "status"
    order      = "ASCENDING"
  }

  fields {
    field_path = "created_at"
    order      = "DESCENDING"
  }
}

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
      image = local.api_image

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
        name  = "FIRESTORE_DATABASE_ID"
        value = var.firestore_database_id
      }

      env {
        name  = "APPLE_BUNDLE_ID"
        value = var.apple_bundle_id
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

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }

  depends_on = [
    google_firestore_database.main,
    google_secret_manager_secret_version.jwt_secret,
    google_secret_manager_secret.apple_auth,
    google_secret_manager_secret.apple_iap_private_key,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
