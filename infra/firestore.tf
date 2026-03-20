# Firestore は GCP プロジェクトで1つ — dev 環境でのみ管理
resource "google_firestore_database" "main" {
  count       = var.environment == "dev" ? 1 : 0
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.apis]
}

# セッション一覧取得用（ユーザー別・作成日降順）
resource "google_firestore_index" "sessions_by_created_at" {
  count      = var.environment == "dev" ? 1 : 0
  project    = var.project_id
  database   = "(default)"
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

# タスク一覧取得用（ユーザー別・ステータス・作成日降順）
resource "google_firestore_index" "tasks_by_status" {
  count      = var.environment == "dev" ? 1 : 0
  project    = var.project_id
  database   = "(default)"
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
