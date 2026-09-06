# 06. Firebase Project / iOS SDK 統合

## 目的

KPI 計測（Trial→Paid 25% / 3ヶ月継続 60% / アクティベーション率）のため Firebase Analytics（GA4）を iOS から起動時にイベント送信できる状態にする。Crashlytics も同パッケージで取れるので併用する。

## 前提条件

- GCP プロジェクト `cycle-journal` が存在
- 同プロジェクトに Firebase が紐付け可能（請求先アカウント設定済）
- Xcode 16+

## 手順

### 1. Firebase Project の作成 / 紐付け

1. [Firebase Console](https://console.firebase.google.com/) → **Add project**
2. プロジェクト名で **既存の GCP プロジェクト `cycle-journal` を選択** することを推奨
   - 新規作成すると `cycle-journal-XXXXX` の別 GCP プロジェクトになり、Firestore とテナント分離されてしまう
3. Google Analytics を **有効化**
   - Analytics account: 既存または新規作成
   - データの保存場所: **United States** または **Region with similar policies**（GA4 のグローバル設定）

### 2. iOS App の登録

1. Firebase Console → **+ Add app** → iOS アイコン
2. **iOS bundle ID**: `com.akitoando.CycleJournal`
3. App nickname: `Treow iOS`
4. App Store ID: 後で入力可
5. **Register App**
6. **Download GoogleService-Info.plist** をクリック
7. ダウンロードしたファイルを `ios/Cycle/` 配下に配置
8. Xcode で **左サイドバーにドラッグ&ドロップ** → **Cycle ターゲットを選択 / Copy items if needed: ON**

> File System Synchronized Groups を使っているので、ファイルを `ios/Cycle/` に置くだけで自動的にターゲットに含まれる。

### 3. Firebase SDK の追加（Swift Package Manager）

1. Xcode → **File → Add Package Dependencies...**
2. 検索: `https://github.com/firebase/firebase-ios-sdk`
3. Dependency Rule: **Up to Next Major Version** / 11.0.0 以上
4. **Add Package**
5. 追加するライブラリを選択（Cycle ターゲットへ）:
   - **FirebaseAnalytics** （必須）
   - **FirebaseCrashlytics** （推奨）
6. **Add Package**

### 4. アプリ起動時の初期化

`ios/Cycle/App/CycleApp.swift` に以下を追加:

```swift
import FirebaseCore
import SwiftUI

@main
struct CycleApp: App {
    init() {
        FirebaseApp.configure()
    }
    // ... 既存の body / @StateObject 群
}
```

### 5. AnalyticsLogger ラッパー作成

`ios/Cycle/Shared/Utilities/AnalyticsLogger.swift` を新規作成（コードは別 PR で実装、本書は配置先のみ指示）:

```swift
import FirebaseAnalytics
import Foundation

enum AnalyticsEvent: String {
    case onboardingStart = "onboarding_start"
    case onboardingComplete = "onboarding_complete"
    case journalFirstEntryCreated = "journal_first_entry_created"
    case journalEntryCreated = "journal_entry_created"
    case coachFirstMessageSent = "coach_first_message_sent"
    case coachMessageSent = "coach_message_sent"
    case paywallViewed = "paywall_viewed"
    case paywallDismissed = "paywall_dismissed"
    case trialStarted = "trial_started"  // server-side でも発火
    // ... 他のイベント
}

enum AnalyticsLogger {
    static func log(_ event: AnalyticsEvent, params: [String: Any]? = nil) {
        Analytics.logEvent(event.rawValue, parameters: params)
    }

    static func setUserId(_ id: String?) {
        Analytics.setUserID(id)
    }

    static func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }
}
```

### 6. ATT 不要設定

`Info.plist` に `NSUserTrackingUsageDescription` を **追加しない**。`AdSupport.framework` をリンクしていなければ、Firebase Analytics は IDFA を取得せず、ATT ダイアログも出ない（CVR 維持）。

### 7. Crashlytics の dSYM アップロード設定

1. Xcode → Cycle ターゲット → **Build Phases**
2. **+ → New Run Script Phase**
3. Script:
   ```
   ${PODS_ROOT:-${BUILD_DIR%/Build/*}/SourcePackages/checkouts}/firebase-ios-sdk/Crashlytics/run
   ```
4. **Input Files**:
   - `$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)`
   - `${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}`

### 8. .gitignore の確認

`GoogleService-Info.plist` には API キーが含まれるが、**iOS Firebase の API キーは公開情報扱い**（Bundle ID と紐付いており他アプリから使えない）。コミットして問題ない。

ただし社内ポリシーで `.gitignore` する場合は `ios/Cycle/GoogleService-Info.plist` を追加し、CI で復元する形にする。

## 検証

### 動作確認

1. Xcode で実機ビルド & 起動
2. アプリを 30 秒程度操作
3. Firebase Console → **Analytics → DebugView**
   - シミュレータからのイベントは: Xcode の Run Arguments に `-FIRDebugEnabled` を追加して再起動 → DebugView に即時表示
   - 実機: `xcrun simctl spawn booted log stream | grep FIRAnalytics` でログ確認

4. Firebase Console → **Crashlytics**
   - 「Set up Crashlytics」が完了し「Crash-free users」に最初のセッションが反映される（数分かかる）

### Analytics の初期イベント

`first_open` / `session_start` / `screen_view` などは Firebase が自動収集する。カスタムイベントは AnalyticsLogger 経由で送信したものが Console に出る。

## トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| DebugView にイベントが出ない | `-FIRDebugEnabled` 未設定 | Scheme → Arguments Passed On Launch に追加 |
| `FirebaseApp.configure()` でクラッシュ | `GoogleService-Info.plist` がターゲットに含まれていない | Project Navigator で plist を選択し Target Membership にチェック |
| Crashlytics にクラッシュが出ない | dSYM 未アップロード | Run Script Phase を確認、アーカイブ後に dSYM が `~/Library/Developer/Xcode/Archives/...` にあるか |
| `ATT` ダイアログが出てしまう | `AdSupport.framework` をリンクしている | Build Phases → Link Binary With Libraries から削除 |
| Firebase と既存 GCP プロジェクトが別になっている | 紐付けミスで Firestore とテナント分離 | Firebase プロジェクトを削除 → 既存 GCP プロジェクトを選択して再作成 |

## 公式ドキュメント

- [Add Firebase to your Apple project](https://firebase.google.com/docs/ios/setup)
- [Get started with Google Analytics](https://firebase.google.com/docs/analytics/get-started?platform=ios)
- [Crashlytics for Apple](https://firebase.google.com/docs/crashlytics/get-started?platform=ios)
- [Apple App Tracking Transparency](https://developer.apple.com/documentation/apptrackingtransparency)

## 次のステップ

→ [07. GA4 Measurement Protocol API secret 発行](07-ga4-measurement-protocol.md)
