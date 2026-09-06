# App Store リリース手順

現在の対象は **Treow v1.0.10 無料MVP**。App Store Connectのアプリレコードを正とし、Bundle ID、バージョン、ビルド番号、料金表記を提出直前に照合する。

## 1. 提出前のコード確認

1. `ios/Local.xcconfig.template` を `ios/Local.xcconfig` へコピーし、Apple Developer TeamとApp Store Connectに登録済みのBundle IDを設定する
2. XcodeのCycleターゲットでSigning & Capabilitiesにエラーがないことを確認する
3. Releaseビルドが `MARKETING_VERSION = 1.0.10` であることを確認する
4. `CURRENT_PROJECT_VERSION` はApp Store Connect上の同バージョンの既存ビルドより大きくする
5. `PrivacyInfo.xcprivacy` がCycleターゲットへ含まれることを確認する

設定値の確認:

```bash
cd ios
xcodebuild -project Cycle.xcodeproj -scheme Cycle -configuration Release -showBuildSettings \
  | rg 'PRODUCT_BUNDLE_IDENTIFIER|DEVELOPMENT_TEAM|MARKETING_VERSION|CURRENT_PROJECT_VERSION'
```

## 2. 品質確認

```bash
cd ios
xcodebuild test \
  -project Cycle.xcodeproj \
  -scheme Cycle \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

加えて実機またはTestFlightで、サインイン、全タブ、同期、オフライン復帰、サインアウト時のユーザー分離、アカウント削除、通知、データエクスポートを確認する。

## 3. アーカイブとアップロード

Xcodeで次を実行する。

1. 実行先を **Any iOS Device (arm64)** にする
2. **Product → Archive**
3. Organizerで **Validate App** を実行し、Privacy Manifest・署名・entitlementの警告を解消する
4. **Distribute App → App Store Connect → Upload**
5. シンボルを含めてアップロードし、App Store Connectで処理完了を待つ

CLIでアーカイブだけ作る場合:

```bash
cd ios
xcodebuild archive \
  -project Cycle.xcodeproj \
  -scheme Cycle \
  -configuration Release \
  -archivePath build/Cycle.xcarchive \
  -destination 'generic/platform=iOS'
```

## 4. App Store Connect入力

- アプリ名、サブタイトル、キーワード、説明文: `docs/product/store-description.md`
- プライバシーポリシー: https://akitoando.github.io/cycle-journal/legal/PRIVACY_POLICY.html
- 利用規約: https://akitoando.github.io/cycle-journal/legal/TERMS_OF_SERVICE.html
- 料金: 無料。Paywall、サブスクリプション、無料トライアルの記載は入れない
- App Privacy: Privacy Manifestおよび実際の通信内容と一致させる
- Review Notes: Apple / Googleサインイン手順、AIコーチは医療・診断・治療目的ではないこと、課金がないことを明記する

## 5. スクリーンショット

```bash
./scripts/take-screenshots.sh
```

App Store Connectが要求する最新のiPhoneサイズを登録する。CycleターゲットはiPhone・iPad対応 (`TARGETED_DEVICE_FAMILY = 1,2`) のため、iPad対応を維持する場合は要求されるiPadサイズも登録し、主要画面が崩れていないことを確認する。iPad品質を保証できない場合は、提出直前に黙って対象外へ変更せず、製品判断として対応端末を決め直す。

## 6. 最終提出

- [ ] 処理済みビルドをv1.0.10へ選択
- [ ] 輸出コンプライアンス、コンテンツ権利、年齢区分へ回答
- [ ] サポートURL・Privacy URLが公開状態で開く
- [ ] 全スクリーンショットと説明文が現在のUI・無料提供と一致する
- [ ] TestFlightでRelease相当ビルドのスモークテストが完了
- [ ] **Add for Review** 前に差分を再確認
- [ ] **Submit for Review** は外部公開操作として実行直前に最終確認する

詳細な機能確認は [verification-checklist.md](37-deployment-setup/verification-checklist.md) を参照する。
