#!/bin/bash
# =============================================================================
# API開発環境セットアップスクリプト
# Python仮想環境の作成と依存関係のインストール
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
API_DIR="$PROJECT_ROOT/api"

echo "========================================"
echo "  API Development Environment Setup"
echo "========================================"
echo ""

cd "$API_DIR"

# Python仮想環境の作成
echo "[1/4] Python仮想環境を作成中..."
if [ -d ".venv" ]; then
    echo "  既存の仮想環境を削除します..."
    rm -rf .venv
fi
python3 -m venv .venv

# 仮想環境をアクティベート
echo "[2/4] 仮想環境をアクティベート中..."
source .venv/bin/activate

# pipをアップグレード
echo "[3/4] pipをアップグレード中..."
pip install --upgrade pip

# 依存関係をインストール
echo "[4/4] 依存関係をインストール中..."
pip install -r requirements.txt

echo ""
echo "========================================"
echo "  セットアップ完了!"
echo "========================================"
echo ""
echo "仮想環境をアクティベートするには:"
echo "  source $API_DIR/.venv/bin/activate"
echo ""
echo "次のステップ:"
echo "  1. ./scripts/build-lambda-layer.sh  # Lambda Layerをビルド"
echo "  2. ./scripts/deploy-api.sh          # APIをデプロイ"
