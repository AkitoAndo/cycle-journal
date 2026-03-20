# App Store リリース手順

## 前提条件

| 項目 | 状態 |
|------|------|
| Apple Developer Program（年$99） | 必須 |
| Xcode 16+ | 必須 |
| App Store Connect アカウント | 必須 |

---

## 1. 署名証明書の取得

App StoreにアップロードするにはApple Distribution証明書が必要。

### 手順

1. **Xcode** を開く
2. **Xcode → Settings → Accounts**
3. Apple IDでサインイン（未サインインの場合）
4. Team ID `784249657M` を選択
5. **Manage Certificates** をクリック
6. 左下の **+** → **Apple Distribution** を選択

確認コマンド:

```bash
security find-identity -v -p codesigning
# "Apple Distribution: ..." が表示されればOK
```

---

## 2. App Store Connect APIキーの作成

CLIからApp Store Connectを操作するために必要。

### 手順

1. https://appstoreconnect.apple.com/access/integrations/api を開く
2. **「キーを生成」** をクリック
3. 名前: `CLI`
4. アクセス: **Admin**
5. **「生成」** をクリック

### 取得する3つの値

| 値 | 場所 | 例 |
|----|------|-----|
| **Issuer ID** | ページ上部に表示 | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| **Key ID** | 作成したキーの横 | `XXXXXXXXXX` |
| **秘密鍵 (.p8)** | ダウンロードボタン | `AuthKey_XXXXXXXXXX.p8` |

> **注意**: `.p8`ファイルのダウンロードは**1回のみ**。紛失したら再作成が必要。

### 秘密鍵の配置

```bash
mkdir -p ~/.private_keys
mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.private_keys/
```

### 環境変数の設定（オプション）

```bash
# ~/.zshrc に追加
export APP_STORE_CONNECT_ISSUER_ID="your-issuer-id"
export APP_STORE_CONNECT_KEY_ID="your-key-id"
export APP_STORE_CONNECT_KEY_PATH="$HOME/.private_keys/AuthKey_XXXXXXXXXX.p8"
```

---

## 3. App Store Connectでアプリ登録（初回のみ）

1. https://appstoreconnect.apple.com/apps を開く
2. **「+」→「新規App」**
3. プラットフォーム: **iOS**
4. 名前: `Cycle Journal`（またはApp Store上の表示名）
5. プライマリ言語: **日本語**
6. バンドルID: `com.wisdomhills.Cycle`
7. SKU: `cycle-journal`（任意の一意な文字列）

---

## 4. ビルド＆アップロード（CLI）

以下はCLIで自動実行可能:

```bash
cd ios

# アーカイブ
xcodebuild archive \
  -project Cycle.xcodeproj \
  -scheme Cycle \
  -archivePath build/Cycle.xcarchive \
  -destination 'generic/platform=iOS'

# IPA書き出し
xcodebuild -exportArchive \
  -archivePath build/Cycle.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist

# App Store Connectにアップロード
xcrun altool --upload-app \
  -f build/export/Cycle.ipa \
  -t ios \
  --apiKey $APP_STORE_CONNECT_KEY_ID \
  --apiIssuer $APP_STORE_CONNECT_ISSUER_ID
```

### ExportOptions.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store</string>
  <key>teamID</key>
  <string>784249657M</string>
  <key>uploadSymbols</key>
  <true/>
  <key>uploadBitcode</key>
  <false/>
</dict>
</plist>
```

---

## 5. 審査提出

アップロード後、App Store Connect上で:

1. ビルドを選択
2. スクリーンショットを追加（6.7インチ + 6.1インチ必須）
3. アプリの説明文、キーワード、カテゴリを入力
4. 輸出コンプライアンス情報を回答
5. **「審査に提出」** をクリック

---

## スクリーンショット自動生成

```bash
# シミュレータでスクリーンショット取得
./scripts/take-screenshots.sh
```

---

## チェックリスト

- [ ] Apple Distribution証明書を取得
- [ ] App Store Connect APIキーを作成・配置
- [ ] App Store Connectでアプリを登録
- [ ] ExportOptions.plist を作成
- [ ] アーカイブ＆IPA書き出し
- [ ] App Store Connectにアップロード
- [ ] スクリーンショット追加
- [ ] メタデータ入力（説明文、カテゴリ、キーワード）
- [ ] 審査提出
