# S-04: Face ID / Touch IDによるアプリロック

| 項目 | 内容 |
|------|------|
| ステータス | :memo: Planned |
| 優先度 | P2 |
| 対象 | iOS / iPadOS |
| 依存 | S-01（設定画面UI） |

## 背景

Treowには日記、コーチ会話、タスクの意図・振り返りなど、他人に見られたくない内容が保存される。端末のロックが解除された状態で端末を他人へ渡した場合や、アプリスイッチャーに画面が残る場合に備えて、任意で有効にできる端末内アプリロックを提供する。

Face IDは**端末上でアプリを開く人を確認する機能**であり、サーバー同期、AI処理、通信、バックアップを含めた「100%プライベート」を単独で保証するものではない。マーケティング表現は「Face IDでアプリをロック」など、実装が保証できる範囲に限定する。

## ユーザーストーリー

> ユーザーとして、Treowを開いたときにFace ID、Touch IDまたは端末パスコードで本人確認し、日記やコーチ会話を周囲の人に見られないようにしたい。

## スコープ

- マイページの「プライバシー」セクションにアプリロック設定を追加する
- Face ID対応端末では「Face IDでロック」と表示する
- Touch ID対応端末では「Touch IDでロック」と表示する
- 生体認証が利用できない場合も、端末パスコードによるフォールバックを提供する
- コールド起動とバックグラウンド復帰時に、機微な画面を表示する前に本人確認する
- inactive / background移行時は即座にプライバシーカバーを重ね、アプリスイッチャーのスナップショットへ内容を残さない
- 認証をキャンセルまたは失敗した場合はロック画面に留まり、再試行できる

## 受け入れ条件

- [ ] 初期状態ではアプリロックは無効である
- [ ] アプリロックの有効化には、成功した端末所有者認証が必要である
- [ ] アプリロックを無効にする操作にも、成功した端末所有者認証が必要である
- [ ] 有効化時の認証をキャンセルまたは失敗した場合、設定は有効にならない
- [ ] 有効時はコールド起動でロック画面が先に表示され、日記・タスク・コーチ会話が一瞬も見えない
- [ ] 有効時はバックグラウンドへ移動したあと、復帰時に再認証を要求する
- [ ] inactive / background中のアプリスイッチャー表示は、ロゴとロック状態だけのプライバシーカバーになる
- [ ] Face ID / Touch ID成功時だけメイン画面を表示する
- [ ] 失敗、キャンセル、システムロックアウト時は内容を表示せず、再試行とシステムが許可する端末パスコードの導線を提供する
- [ ] Face ID未登録、利用不可、権限拒否の状態をクラッシュせず説明する
- [ ] 通知タップ、Universal Link、カスタムURLなどから起動しても、認証前に機微な画面へ遷移しない
- [ ] 認証の失敗・キャンセル・タイムアウトは、サインアウト、データ削除、同期、API呼び出しを発生させない
- [ ] `NSFaceIDUsageDescription`を追加し、日本語の理由文を表示する
- [ ] 生体情報そのもの、顔画像、認証テンプレートをアプリ内・ログ・分析基盤へ保存または送信しない
- [ ] VoiceOverでロック状態、認証ボタン、エラー内容を理解できる
- [ ] `--uitesting`では明示的な起動引数によりアプリロックを決定的に無効化またはモック成功できる
- [ ] 実機のFace ID端末で、有効化・起動・復帰・キャンセル・失敗・パスコードフォールバックを確認する

## 技術設計案

### 認証

- Appleの`LocalAuthentication`を使用する
- `LAContext.canEvaluatePolicy`の結果を毎回確認し、以前の結果を永続キャッシュしない
- 基本ポリシーは`.deviceOwnerAuthentication`とし、生体認証が使えない場合の端末パスコードを許可する
- アプリはSecure Enclave内の生体情報へアクセスせず、成功・失敗の結果だけを受け取る

### 状態管理

- `AppLockStore`を`@MainActor`の`ObservableObject`として追加する
- `LocalAuthenticating`プロトコルを用意し、`LAContext`実装とテスト用fakeを差し替えられるようにする
- ロック設定はログインユーザー単位ではなく、端末上のTreow全体へ適用する
- `scenePhase`が`.inactive`になった時点でプライバシーカバーを表示し、`.background`で再認証必要状態へ遷移する
- 自分自身のFace IDダイアログによるscene変化で再認証ループを起こさない状態機械にする

### 組み込み候補

- `ios/Cycle/App/CycleApp.swift`: `AppLockStore`の生成・注入
- `ios/Cycle/App/ContentView.swift`: 認証済み画面の前段にロックゲート、`scenePhase`監視
- `ios/Cycle/Features/Settings/Views/SettingsView.swift`: プライバシー設定トグル
- `ios/Cycle/Features/AppLock/AppLockStore.swift`: 状態機械と永続設定
- `ios/Cycle/Features/AppLock/LocalAuthenticationClient.swift`: `LAContext`ラッパー
- `ios/Info.plist`: `NSFaceIDUsageDescription`

既存の認証トークンはKeychainの`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`で保護されている。第1段階ではトークンへ生体認証ACLを追加せず、サーバー認証セッションと画面のアプリロックを独立させる。認証失敗でログアウトしたり、APIトークンを消したりしない。

## テスト計画

### Unit

- disabled / locked / authenticating / unlocked / unavailable状態の遷移
- 二重認証要求とキャンセル時の競合防止
- background復帰による再ロック
- 有効化・無効化時の認証成否

### UI

- 有効時はロック画面が最初に表示される
- fake認証成功でメイン画面へ進む
- fake認証失敗・キャンセルで内容が表示されない
- 設定トグルの有効化失敗時にOFFへ戻る
- アプリスイッチャー用カバーにユーザー内容が含まれない

### Manual / 実機

- Face ID成功・不一致・キャンセル・ロックアウト
- Face ID未登録・利用拒否
- 端末パスコードへのフォールバック
- 通知センター、着信など一時的なinactive遷移
- 複数回の高速なbackground / foreground往復

## セキュリティ上の境界

現在の`JSONFileStore`はローカルJSONを`.completeFileProtection`で保存している。これは端末ロック中のデータ保護に寄与するが、Face IDアプリロックはファイル暗号化やE2E暗号化の代替ではない。また、コーチセッションの一部は`UserDefaults`にも保存されるため、画面ロックだけで保存データ全体の機密性を保証したとは扱わない。

次は本チケットの対象外とする。

- サーバー同期データのエンドツーエンド暗号化
- AIコーチへ送る内容のクライアント側暗号化
- OSや端末が侵害された場合の保護
- バックアップ、ログ、通知本文を含む全データ経路の監査
- 生体認証セット変更時に失効するKeychain鍵を使ったファイル暗号化

「100%プライベート」または同等の包括的な表現を使用する場合は、本チケット完了だけでなく、上記経路を含む別途のセキュリティ・プライバシー監査を必須とする。

## 参照

- [Apple: Local Authentication](https://developer.apple.com/documentation/localauthentication)
- [Apple: Logging a User into Your App with Face ID or Touch ID](https://developer.apple.com/documentation/localauthentication/logging-a-user-into-your-app-with-face-id-or-touch-id)
- [Apple: NSFaceIDUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsfaceidusagedescription)
- [Apple: Data Protection](https://support.apple.com/guide/security/data-protection-overview-secf6276da8a/web)
