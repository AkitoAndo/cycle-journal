//
//  SubscriptionProduct.swift
//  CycleJournal
//
//  Issue #37 A 系: プロダクト ID とトライアル適用範囲の定義
//

import Foundation

/// App Store Connect で作成するサブスクリプション商品。
///
/// - `monthly_1800`: ¥1,800/月 (Intro Offer なし、Calm 型: 月額は即課金)
/// - `yearly_14400`: ¥14,400/年 (7-day Free Trial Intro Offer 付き)
///
/// 命名は App Store Connect のプロダクト ID と完全一致させること。
/// 変更時は App Store Connect 側と本 enum の両方を必ずセットで更新。
enum SubscriptionProductID: String, CaseIterable {
    case monthly = "com.akitoando.CycleJournal.monthly_1800"
    case yearly = "com.akitoando.CycleJournal.yearly_14400"

    /// 7-day Free Trial Intro Offer を持つか。
    ///
    /// Issue #37 A-1 決定: yearly のみトライアル付き (LTV の高い年額に集中)。
    var supportsIntroductoryOffer: Bool {
        switch self {
        case .yearly: return true
        case .monthly: return false
        }
    }

    /// 表示順 (Paywall で年額を上位に出す)。
    var displayOrder: Int {
        switch self {
        case .yearly: return 0
        case .monthly: return 1
        }
    }
}
