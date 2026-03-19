#!/bin/bash
# =============================================================================
# GCP 開発者向けローカル環境セットアップ
#
# チームメンバーがクローン後に実行するスクリプト。
# gcloud CLIの認証とプロジェクト設定を行います。
#
# 使い方:
#   ./scripts/gcp-setup-local.sh
# =============================================================================

set -euo pipefail

PROJECT_ID="cycle-journal"
REGION="asia-northeast1"

echo "========================================"
echo "  CycleJournal - GCP ローカルセットアップ"
echo "========================================"
echo ""

# ─── gcloud CLI チェック ──────────────────────────────────────
echo "[1/4] gcloud CLI を確認中..."

if ! command -v gcloud &>/dev/null; then
  echo ""
  echo "  gcloud CLI がインストールされていません。"
  echo "  以下からインストールしてください:"
  echo "    https://cloud.google.com/sdk/docs/install"
  exit 1
fi

echo "  OK: $(gcloud version 2>/dev/null | head -1)"

# ─── 認証 ────────────────────────────────────────────────────
echo ""
echo "[2/4] Google アカウント認証..."

current_account=$(gcloud config get-value account 2>/dev/null || true)
if [ -n "$current_account" ] && [ "$current_account" != "(unset)" ]; then
  echo "  現在のアカウント: $current_account"
  read -rp "  このアカウントを使いますか? (Y/n): " use_current
  if [[ "$use_current" =~ ^[Nn] ]]; then
    gcloud auth login
  fi
else
  echo "  ブラウザが開きます。Googleアカウントでログインしてください。"
  gcloud auth login
fi

# ─── プロジェクト設定 ─────────────────────────────────────────
echo ""
echo "[3/4] GCPプロジェクトを設定中..."

gcloud config set project "$PROJECT_ID"
gcloud config set compute/region "$REGION"

echo "  プロジェクト: $PROJECT_ID"
echo "  リージョン:   $REGION"

# ─── アプリケーションデフォルト認証 ──────────────────────────
echo ""
echo "[4/4] アプリケーションデフォルト認証を設定中..."
echo "  ローカル開発でGCPサービスにアクセスするための認証です。"

gcloud auth application-default login

echo ""
echo "========================================"
echo "  セットアップ完了!"
echo "========================================"
echo ""
echo "確認コマンド:"
echo "  gcloud config list                    # 現在の設定を確認"
echo "  gcloud projects get-iam-policy $PROJECT_ID  # IAM権限を確認"
echo ""
