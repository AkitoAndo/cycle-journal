//
//  SubscriptionState.swift
//  CycleJournal
//
//  Issue #37 A 系: ユーザーのサブスクリプション状態を一元管理する値型。
//

import Foundation

/// StoreKit 2 `Transaction.currentEntitlements` から導出される状態。
///
/// `hasEntitlement` がプロダクト機能解放の判定に使われ、
/// `trialDay(purchaseDate:now:)` で Day1/3/6/7 通知 (#37 C-2) の起点判定に使う。
enum SubscriptionState: Equatable {
    /// 初期状態 (StoreKit 復元処理が完了する前)。
    case unknown

    /// 未契約 (トライアル経験なし or トライアル済みで未復帰)。
    case notSubscribed

    /// トライアル中。`expiresAt` は Apple が決めるトライアル終了時刻 (purchaseDate + 7日)。
    case trial(productID: String, expiresAt: Date)

    /// 有料アクティブ (トライアル後の課金成功 or 即時課金プラン)。
    case active(productID: String, expiresAt: Date)

    /// 期限切れ (契約完了後、解約 or 払戻し or 自動更新失敗)。
    case expired

    /// 有料機能を解放するか。
    var hasEntitlement: Bool {
        switch self {
        case .trial, .active: return true
        case .unknown, .notSubscribed, .expired: return false
        }
    }

    /// トライアル開始からの経過日数 (0 起点)。
    ///
    /// 1 日 = 86400 秒 で割って int 化。同日内は 0、24 時間経過で 1、72 時間で 3。
    /// `now` を引数化することでテスト時に時間を固定できる。
    static func trialDay(purchaseDate: Date, now: Date = Date()) -> Int {
        let elapsed = now.timeIntervalSince(purchaseDate)
        guard elapsed >= 0 else { return 0 }
        return Int(elapsed / 86400.0)
    }
}
