resource "google_secret_manager_secret" "apple_auth" {
  secret_id = "apple-auth-config-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

# IAP (App Store Server API / ASSN V2 JWS 検証) 用 .p8 秘密鍵。
# 値 (version) は TF state に秘密を残さないため手動投入する:
#   gcloud secrets versions add apple-iap-private-key-<env> --data-file=./SubscriptionKey_XXX.p8 --project=cycle-journal
resource "google_secret_manager_secret" "apple_iap_private_key" {
  secret_id = "apple-iap-private-key-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

# JWT署名鍵（サーバー発行アクセストークン用）
resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "jwt-secret-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

resource "google_secret_manager_secret_version" "jwt_secret" {
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = random_password.jwt_secret.result
}
