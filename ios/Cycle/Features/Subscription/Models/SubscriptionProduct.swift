//
//  SubscriptionProduct.swift
//  CycleJournal
//
//  Issue #37 A 系: プロダクト ID とトライアル適用範囲の定義
//

import Foundation

/// App Store Connect で作成するサブスクリプション商品。
///
/// - `monthly_1800`: ¥1,800/月 (3-day Free Trial Intro Offer 付き)
/// - `yearly_14400`: ¥14,400/年 (フェーズ1中は ASC で「配信から削除」)
///
/// Issue #54 決定 (フェーズ制):
///   フェーズ1: 月額のみ。3日トライアル。
///   フェーズ2: 年額追加 (7日トライアル付き)。月額トライアルは3日のまま据え置き。
///
/// 命名は App Store Connect のプロダクト ID と完全一致させること。
enum SubscriptionProductID: String, CaseIterable {
    case monthly = "com.akitoando.CycleJournal.monthly_1800"
    case yearly = "com.akitoando.CycleJournal.yearly_14400"

    /// Intro Offer を持つか。フェーズ1では monthly のみ。
    var supportsIntroductoryOffer: Bool {
        switch self {
        case .monthly: return true
        case .yearly: return true  // フェーズ2で復活時の7日トライアルを想定
        }
    }

    /// 表示順。フェーズ1では monthly を先頭に。
    var displayOrder: Int {
        switch self {
        case .monthly: return 0
        case .yearly: return 1
        }
    }
}
