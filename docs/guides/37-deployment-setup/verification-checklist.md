# 動作確認チェックリスト

このチェックリストは、現在提出する **v1.0.10 無料MVP** を対象とする。サブスクリプション、無料トライアル、Paywall、Firebase Analytics / Crashlytics は現在のビルドでは有効化していないため、提出条件には含めない。

## 1. iOS基本フロー

- [ ] 新規起動: Welcome → Cycle概念 → Goal選択 → Sign In → 初回ジャーナル → 通知選択 → メイン画面
- [ ] Goal未選択、初回ジャーナル未入力では先へ進めない
- [ ] Appleでサインインできる
- [ ] Googleでサインインできる
- [ ] ホーム、ジャーナル、セッション、タスク、マイページの全タブを操作できる
- [ ] マイページに「現在、すべての機能を無料で利用できます」と表示される
- [ ] Paywallや購入ボタンが表示されない

## 2. データと同期

- [ ] ジャーナル、タスク、コーチ会話を作成・編集・削除できる
- [ ] オフライン中のタスク操作が端末に残り、再接続後に同期される
- [ ] 削除したタスクやコーチ会話が再同期で復活しない
- [ ] サインアウト後、別アカウントに前ユーザーのローカルデータが表示されない
- [ ] 元のアカウントへ再ログインすると、そのユーザーのローカルデータだけが復元される
- [ ] 「アカウントを削除」で端末とサーバーのユーザーデータが削除される
- [ ] データエクスポートのJSON / CSVを開ける

## 3. 通知

- [ ] 通知許可はオンボーディングまたはリマインダー有効化時だけ要求される
- [ ] 指定時刻の日次リマインダーがローカル通知として登録される
- [ ] 無料MVPではAPNsデバイストークンをサーバーへ送信しない

## 4. App Store提出物

- [ ] Releaseビルドのバージョンが `1.0.10`、ビルド番号がApp Store Connect上の既存番号より大きい
- [ ] Bundle ID、Team、署名がApp Store Connectのアプリレコードと一致する
- [ ] `PrivacyInfo.xcprivacy` がアーカイブへ含まれる
- [ ] Xcode OrganizerのPrivacy ReportとApp Store ConnectのApp Privacy回答が一致する
- [ ] Google Sign-In SDKのPrivacy ManifestにあるName / Email / Phone / Coarse Location / User ID / Device ID / Other Usage Data / Other Data TypesをApp Privacy回答へ反映する
- [ ] 説明文・利用規約・プライバシーポリシーが「無料MVP」と一致する
- [ ] サポートURL、プライバシーポリシーURL、問い合わせ先が有効
- [ ] iPhone用と、iPad対応を維持する場合はiPad用スクリーンショットを登録する
- [ ] 年齢区分、コンテンツ権利、広告識別子、暗号化輸出コンプライアンスへ回答する
- [ ] TestFlightのRelease相当ビルドを実機でスモークテストする
- [ ] Review NotesへAIコーチが医療行為ではないこと、課金がないこと、ログイン手順を記載する

## 5. リリース直後の監視

- [ ] Cloud Runのエラーレートと5xxを毎日確認する
- [ ] Vertex AIのエラー率・クォータ・費用を確認する
- [ ] Firestoreの読み書き量とアカウント削除ログを確認する
- [ ] App Store Connectのクラッシュ、ハング、レビュー指摘を確認する

## 課金を再開する場合

Paywallを再接続するリリースでは、`Configuration.storekit`、商品状態、Introductory Offer、購入・復元・解約・返金、App Store Server Notifications、APNs、料金表記、規約、App Privacyを別リリースとして再検証する。無料MVPの審査へ未使用の課金設定を混在させない。
