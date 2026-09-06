data "google_project" "current" {
  project_id = var.project_id
}

locals {
  service_name = "cycle-coach-mcp-${var.environment}"
  image        = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repository_id}/api:${var.image_tag}"
  public_url   = "https://${local.service_name}-${data.google_project.current.number}.${var.region}.run.app/mcp"
  api_url      = "https://cycle-api-${var.environment}-${data.google_project.current.number}.${var.region}.run.app"
}

resource "google_service_account" "mcp" {
  account_id   = "cycle-coach-mcp-${var.environment}"
  display_name = "Treow Coach MCP (${var.environment})"
  project      = var.project_id
}

resource "google_cloud_run_v2_service" "mcp" {
  name     = local.service_name
  location = var.region
  project  = var.project_id

  template {
    service_account = google_service_account.mcp.email

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image   = local.image
      command = ["uv"]
      args = [
        "run",
        "uvicorn",
        "app.mcp_server:app",
        "--host",
        "0.0.0.0",
        "--port",
        "8080",
      ]

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
        name  = "MCP_PUBLIC_URL"
        value = local.public_url
      }

      env {
        name  = "MCP_OAUTH_ISSUER"
        value = var.oauth_issuer
      }

      env {
        name  = "MCP_OAUTH_AUDIENCE"
        value = local.public_url
      }

      env {
        name  = "MCP_ALLOWED_EMAILS"
        value = var.allowed_emails
      }

      env {
        name  = "MCP_REQUIRED_SCOPE"
        value = "coach:manage"
      }

      env {
        name  = "MCP_BACKEND_API_URL"
        value = local.api_url
      }
    }
  }

  lifecycle {
    ignore_changes = [
      client,
      client_version,
      template[0].containers[0].image,
    ]
  }
}

# OAuth discovery and health must be reachable before a user has a token.
# Every /mcp request is still rejected by the application-level OAuth verifier.
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.mcp.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
