#!/bin/bash
# =============================================================================
# Lambda Layer ビルドスクリプト
# JWT依存関係（PyJWT, cryptography）をLambda用にビルド
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LAYER_DIR="$PROJECT_ROOT/api/src/layers/jwt/python"

echo "========================================"
echo "  Lambda Layer Build Script"
echo "========================================"
echo ""

# Clean and recreate the directory
echo "[1/3] クリーンアップ中..."
rm -rf "$LAYER_DIR"
mkdir -p "$LAYER_DIR"

# Install packages for Lambda (Linux x86_64)
echo "[2/3] 依存関係をインストール中..."
pip install \
    --platform manylinux2014_x86_64 \
    --target "$LAYER_DIR" \
    --implementation cp \
    --python-version 3.12 \
    --only-binary=:all: \
    --upgrade \
    -r "$PROJECT_ROOT/api/src/layers/jwt/requirements.txt"

echo "[3/3] ビルド完了!"
echo ""
echo "Layer contents:"
ls -la "$LAYER_DIR"
echo ""
echo "========================================"
echo "  次のステップ: ./scripts/deploy-api.sh を実行"
echo "========================================"
