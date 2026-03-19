#!/bin/bash
# XCUITest の結果からスクリーンショットを抽出して docs/public/screenshots/ にコピーするスクリプト
#
# 使い方:
#   1. Xcode でテストを実行 (Cmd+U) または下記コマンド:
#      cd ios && xcodebuild test \
#        -project Cycle.xcodeproj \
#        -scheme Cycle \
#        -destination 'platform=iOS Simulator,name=iPhone 16' \
#        -testPlan CycleUITests \
#        -resultBundlePath ../TestResults.xcresult
#
#   2. このスクリプトを実行:
#      ./scripts/extract-screenshots.sh [xcresult-path]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEST_DIR="$PROJECT_DIR/docs/public/screenshots"

# xcresult のパスを引数から取得、なければ最新のものを探す
if [ -n "${1:-}" ]; then
    XCRESULT="$1"
else
    # Xcode のデフォルトの結果ディレクトリから最新の xcresult を探す
    DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
    XCRESULT=$(find "$DERIVED_DATA" -name "*.xcresult" -maxdepth 4 -type d 2>/dev/null | \
        xargs ls -dt 2>/dev/null | head -1)

    if [ -z "$XCRESULT" ]; then
        echo "Error: .xcresult が見つかりません"
        echo "Usage: $0 [path/to/TestResults.xcresult]"
        exit 1
    fi
fi

echo "xcresult: $XCRESULT"
echo "出力先: $DEST_DIR"
echo ""

mkdir -p "$DEST_DIR"

# xcresulttool で添付ファイル一覧を取得し、スクリーンショットを抽出
# xcrun xcresulttool を使用してスクリーンショットをエクスポート
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# xcresult からテスト結果のJSONを取得
xcrun xcresulttool get --path "$XCRESULT" --format json > "$TEMP_DIR/result.json" 2>/dev/null || {
    echo "Error: xcresulttool の実行に失敗しました"
    exit 1
}

# attachments を探してエクスポート
EXPORTED=0

# xcresulttool の export で添付ファイルを取り出す
xcrun xcresulttool export --path "$XCRESULT" --output-path "$TEMP_DIR/export" --type directory 2>/dev/null || true

# エクスポートされたファイルからスクリーンショットを探す
if [ -d "$TEMP_DIR/export" ]; then
    find "$TEMP_DIR/export" -name "*.png" -o -name "*.jpg" | while read -r img; do
        filename=$(basename "$img")
        cp "$img" "$DEST_DIR/$filename"
        echo "  Copied: $filename"
        EXPORTED=$((EXPORTED + 1))
    done
fi

# 代替手法: xcparse を使用（インストールされている場合）
if command -v xcparse &>/dev/null; then
    echo ""
    echo "xcparse でスクリーンショットを抽出中..."
    xcparse screenshots "$XCRESULT" "$DEST_DIR" --test 2>/dev/null || true
    EXPORTED=$(find "$DEST_DIR" -name "*.png" -newer "$TEMP_DIR/result.json" 2>/dev/null | wc -l | tr -d ' ')
fi

# 最終手段: xcresult 内のファイルを直接探す
if [ "$EXPORTED" -eq 0 ]; then
    echo ""
    echo "直接 xcresult 内を探索中..."
    find "$XCRESULT" -name "*.png" 2>/dev/null | while read -r img; do
        # ファイル名からスクリーンショット名を推測
        filename=$(basename "$img")
        cp "$img" "$DEST_DIR/$filename"
        echo "  Copied: $filename"
    done
    EXPORTED=$(find "$DEST_DIR" -name "*.png" -newer "$TEMP_DIR/result.json" 2>/dev/null | wc -l | tr -d ' ')
fi

echo ""
echo "完了: $DEST_DIR にスクリーンショットを配置しました"
echo ""
echo "次のステップ:"
echo "  1. docs/public/screenshots/ のファイル名を確認"
echo "  2. docs/backlog/ 内の該当ページのコメントを外す"
echo "  3. git add docs/public/screenshots/"
