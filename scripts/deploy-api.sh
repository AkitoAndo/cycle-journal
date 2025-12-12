#!/bin/bash
# =============================================================================
# API デプロイスクリプト
# CDKを使用してAWS環境にAPIをデプロイ
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
API_DIR="$PROJECT_ROOT/api"
CDK_DIR="$API_DIR/cdk"

# デフォルト値
STAGE="${1:-dev}"
APPLE_BUNDLE_ID="${2:-com.cycle.journal}"

echo "========================================"
echo "  CycleJournal API Deploy Script"
echo "========================================"
echo ""
echo "Stage: $STAGE"
echo "Apple Bundle ID: $APPLE_BUNDLE_ID"
echo ""

# Lambda Layer が存在するか確認
LAYER_DIR="$API_DIR/src/layers/jwt/python"
if [ ! -d "$LAYER_DIR" ] || [ -z "$(ls -A "$LAYER_DIR" 2>/dev/null)" ]; then
    echo "⚠️  Lambda Layer が見つかりません。ビルドを実行します..."
    "$SCRIPT_DIR/build-lambda-layer.sh"
    echo ""
fi

# 仮想環境をアクティベート
echo "[1/4] 仮想環境をアクティベート中..."
cd "$API_DIR"
if [ -d ".venv" ]; then
    source .venv/bin/activate
else
    echo "❌ 仮想環境が見つかりません。先に以下を実行してください:"
    echo "   cd $API_DIR && python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt"
    exit 1
fi

# CDKディレクトリに移動
cd "$CDK_DIR"

# CDK synth (テンプレート生成)
echo "[2/4] CDK synth を実行中..."
cdk synth --quiet

# CDK diff (変更確認)
echo "[3/4] 変更内容を確認中..."
cdk diff || true

# ユーザーに確認
echo ""
read -p "デプロイを続行しますか？ (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "デプロイをキャンセルしました。"
    exit 0
fi

# CDK deploy
echo "[4/4] デプロイ中..."
cdk deploy --require-approval never

echo ""
echo "========================================"
echo "  デプロイ完了!"
echo "========================================"
echo ""
echo "API URLはCloudFormationのOutputsを確認してください。"
