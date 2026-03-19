#!/bin/bash
# XCUITest を実行してスクリーンショットを docs/public/screenshots/ に配置する
#
# 使い方:
#   ./scripts/take-screenshots.sh [simulator-name]
#
# 例:
#   ./scripts/take-screenshots.sh "iPhone 16"
#   ./scripts/take-screenshots.sh  # デフォルト: iPhone 16

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SIMULATOR="${1:-iPhone 16}"
RESULT_BUNDLE="$PROJECT_DIR/TestResults.xcresult"
DEST_DIR="$PROJECT_DIR/docs/public/screenshots"

echo "=== Cycle Journal Screenshot Generator ==="
echo "Simulator: $SIMULATOR"
echo ""

# 古い結果を削除
rm -rf "$RESULT_BUNDLE"

# スクリーンショット用のテストだけを実行
echo "UITest を実行中..."
cd "$PROJECT_DIR/ios"
xcodebuild test \
    -project Cycle.xcodeproj \
    -scheme Cycle \
    -destination "platform=iOS Simulator,name=$SIMULATOR" \
    -only-testing:CycleUITests/CycleUITests/testScreenshots_Journal_01_List \
    -only-testing:CycleUITests/CycleUITests/testScreenshots_Journal_02_NewEntry \
    -only-testing:CycleUITests/CycleUITests/testScreenshots_Journal_03_EditEntry \
    -only-testing:CycleUITests/CycleUITests/testScreenshots_Journal_04_Search \
    -only-testing:CycleUITests/CycleUITests/testScreenshots_Journal_05_TagManagement \
    -only-testing:CycleUITests/CycleUITests/testScreenshots_Journal_06_Trash \
    -only-testing:CycleUITests/CycleUITests/testScreenshots_Journal_07_Calendar \
    -only-testing:CycleUITests/CycleUITests/testScreenshots_Tasks_01_List \
    -only-testing:CycleUITests/CycleUITests/testScreenshots_Tasks_02_NewEntry \
    -only-testing:CycleUITests/CycleUITests/testScreenshots_Tasks_03_Reorder \
    -only-testing:CycleUITests/CycleUITests/testScreenshots_Tasks_04_Archive \
    -only-testing:CycleUITests/CycleUITests/testScreenshots_Tasks_05_Trash \
    -only-testing:CycleUITests/CycleUITests/testScreenshots_Coach_01_Home \
    -only-testing:CycleUITests/CycleUITests/testScreenshots_Settings_01_Main \
    -only-testing:CycleUITests/CycleUITests/testScreenshots_Tabs \
    -resultBundlePath "$RESULT_BUNDLE" \
    2>&1 | tail -20

echo ""
echo "スクリーンショットを抽出中..."
mkdir -p "$DEST_DIR"

# xcresulttool で添付ファイルのIDを取得してエクスポート
# Xcode 16+ の xcresulttool を使用
cd "$PROJECT_DIR"

# テスト結果からスクリーンショットの参照IDを取得
xcrun xcresulttool get test-results attachments \
    --path "$RESULT_BUNDLE" \
    --output-path "$DEST_DIR" 2>/dev/null && {
    echo "xcresulttool でエクスポート完了"
} || {
    echo "xcresulttool v2 を試行中..."
    # フォールバック: 古い形式の xcresulttool
    ATTACHMENTS_DIR="$RESULT_BUNDLE/Data"
    if [ -d "$ATTACHMENTS_DIR" ]; then
        find "$ATTACHMENTS_DIR" -name "*.png" -exec cp {} "$DEST_DIR/" \;
        echo "直接コピーでエクスポート完了"
    fi
}

# ファイル名のリネーム（UUIDベースのファイル名を分かりやすく変換）
echo ""
echo "=== 配置されたスクリーンショット ==="
ls -la "$DEST_DIR/"*.png 2>/dev/null || echo "(スクリーンショットが見つかりません)"

echo ""
echo "完了！"
echo ""
echo "手動でスクショを確認・リネームする場合:"
echo "  open $DEST_DIR"
echo ""
echo "バックログページに反映するには:"
echo "  docs/backlog/ 内のページでコメントを外してください"

# 結果バンドルを削除
rm -rf "$RESULT_BUNDLE"
