#!/bin/bash
# =============================================================================
# GCPプロジェクト作成 & チームメンバー追加スクリプト
#
# 前提:
#   - gcloud CLI がインストール済み
#   - オーナー権限を持つGoogleアカウントでログイン済み
#     (gcloud auth login)
#   - 請求先アカウントが存在する
#
# 使い方:
#   ./scripts/gcp-add-members.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMBERS_FILE="$SCRIPT_DIR/gcp-members.txt"

# ─── 設定 ────────────────────────────────────────────────────
PROJECT_ID="cycle-journal"
PROJECT_NAME="CycleJournal"
REGION="asia-northeast1"

# メンバーに付与するロール (管理者レベル、請求系を除く)
ROLES=(
  "roles/editor"
  "roles/resourcemanager.projectIamAdmin"
  "roles/iam.serviceAccountAdmin"
  "roles/iam.serviceAccountKeyAdmin"
  "roles/run.admin"
  "roles/cloudsql.admin"
  "roles/secretmanager.admin"
  "roles/cloudbuild.builds.editor"
  "roles/artifactregistry.admin"
  "roles/logging.admin"
  "roles/monitoring.admin"
  "roles/storage.admin"
)

# ─── 関数 ────────────────────────────────────────────────────
check_prerequisites() {
  if ! command -v gcloud &>/dev/null; then
    echo "エラー: gcloud CLI がインストールされていません"
    echo "  https://cloud.google.com/sdk/docs/install"
    exit 1
  fi

  local account
  account=$(gcloud config get-value account 2>/dev/null)
  if [ -z "$account" ] || [ "$account" = "(unset)" ]; then
    echo "エラー: gcloud にログインしていません"
    echo "  gcloud auth login を実行してください"
    exit 1
  fi
  echo "ログイン中のアカウント: $account"
}

create_project() {
  echo ""
  echo "[1/4] GCPプロジェクトを確認中..."

  if gcloud projects describe "$PROJECT_ID" &>/dev/null; then
    echo "  プロジェクト '$PROJECT_ID' は既に存在します。スキップします。"
  else
    echo "  プロジェクト '$PROJECT_ID' を作成中..."
    gcloud projects create "$PROJECT_ID" --name="$PROJECT_NAME"
    echo "  プロジェクトを作成しました。"
  fi

  gcloud config set project "$PROJECT_ID"
}

link_billing() {
  echo ""
  echo "[2/4] 請求先アカウントを確認中..."

  local current_billing
  current_billing=$(gcloud billing projects describe "$PROJECT_ID" \
    --format="value(billingAccountName)" 2>/dev/null || true)

  if [ -n "$current_billing" ]; then
    echo "  請求先は既にリンク済み: $current_billing"
    return
  fi

  echo "  利用可能な請求先アカウント:"
  gcloud billing accounts list --format="table(name, displayName, open)"
  echo ""

  read -rp "  リンクする請求先アカウントID (例: 012345-6789AB-CDEF01): " billing_id
  if [ -z "$billing_id" ]; then
    echo "  スキップしました。後で手動でリンクしてください。"
    return
  fi

  gcloud billing projects link "$PROJECT_ID" --billing-account="$billing_id"
  echo "  請求先をリンクしました。"
}

enable_apis() {
  echo ""
  echo "[3/4] 必要なAPIを有効化中..."

  local apis=(
    "cloudresourcemanager.googleapis.com"
    "iam.googleapis.com"
    "run.googleapis.com"
    "sqladmin.googleapis.com"
    "secretmanager.googleapis.com"
    "cloudbuild.googleapis.com"
    "artifactregistry.googleapis.com"
    "logging.googleapis.com"
    "monitoring.googleapis.com"
  )

  for api in "${apis[@]}"; do
    echo "  有効化: $api"
    gcloud services enable "$api" --project="$PROJECT_ID" 2>/dev/null || true
  done
}

add_members() {
  echo ""
  echo "[4/4] チームメンバーを追加中..."

  if [ ! -f "$MEMBERS_FILE" ]; then
    echo "  エラー: $MEMBERS_FILE が見つかりません"
    exit 1
  fi

  local count=0
  while IFS= read -r line; do
    # 空行とコメントをスキップ
    line=$(echo "$line" | xargs)
    [[ -z "$line" || "$line" == \#* ]] && continue

    local email="$line"
    echo ""
    echo "  メンバー追加: $email"

    for role in "${ROLES[@]}"; do
      echo "    + $role"
      gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="user:$email" \
        --role="$role" \
        --quiet \
        > /dev/null
    done

    count=$((count + 1))
  done < "$MEMBERS_FILE"

  echo ""
  if [ "$count" -eq 0 ]; then
    echo "  警告: メンバーが0人です。$MEMBERS_FILE にGmailアドレスを追加してください。"
  else
    echo "  $count 人のメンバーを追加しました。"
  fi
}

# ─── メイン ───────────────────────────────────────────────────
echo "========================================"
echo "  GCPプロジェクト セットアップ"
echo "========================================"

check_prerequisites
create_project
link_billing
enable_apis
add_members

echo ""
echo "========================================"
echo "  セットアップ完了!"
echo "========================================"
echo ""
echo "チームメンバーに以下を共有してください:"
echo "  1. gcloud CLI をインストール"
echo "     https://cloud.google.com/sdk/docs/install"
echo ""
echo "  2. ログインしてプロジェクトを設定"
echo "     gcloud auth login"
echo "     gcloud config set project $PROJECT_ID"
echo ""
echo "  3. 開発用セットアップスクリプトを実行"
echo "     ./scripts/gcp-setup-local.sh"
echo ""
