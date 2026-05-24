//
//  SubscriptionTests.swift
//  CycleTests
//
//  Issue #37 A 系 (iOS StoreKit2) - SubscriptionState / Product ID 周りの単体テスト
//

import Foundation
import Testing

@testable import Cycle

// MARK: - SubscriptionProduct

struct SubscriptionProductTests {
    @Test func monthlyProductIdMatchesAppStoreConnect() {
        #expect(SubscriptionProductID.monthly.rawValue == "com.akitoando.CycleJournal.monthly_1800")
    }

    @Test func yearlyProductIdMatchesAppStoreConnect() {
        #expect(SubscriptionProductID.yearly.rawValue == "com.akitoando.CycleJournal.yearly_14400")
    }

    @Test func allProductIdsAreEnumerated() {
        // 価格・トライアル設計の決定箇所(issue #37 A-1)に追従しているか
        let all = SubscriptionProductID.allCases.map(\.rawValue)
        #expect(all.contains("com.akitoando.CycleJournal.monthly_1800"))
        #expect(all.contains("com.akitoando.CycleJournal.yearly_14400"))
        #expect(all.count == 2)
    }

    @Test func yearlyIsTrialEligible() {
        // A-1 決定: yearly のみ 7-day Free Trial Intro Offer を設定
        #expect(SubscriptionProductID.yearly.supportsIntroductoryOffer == true)
        #expect(SubscriptionProductID.monthly.supportsIntroductoryOffer == false)
    }
}

// MARK: - SubscriptionState

struct SubscriptionStateTests {
    @Test func unknownHasNoEntitlement() {
        #expect(SubscriptionState.unknown.hasEntitlement == false)
    }

    @Test func notSubscribedHasNoEntitlement() {
        #expect(SubscriptionState.notSubscribed.hasEntitlement == false)
    }

    @Test func expiredHasNoEntitlement() {
        #expect(SubscriptionState.expired.hasEntitlement == false)
    }

    @Test func trialHasEntitlement() {
        let s = SubscriptionState.trial(
            productID: "com.akitoando.CycleJournal.yearly_14400",
            expiresAt: Date().addingTimeInterval(86400 * 7)
        )
        #expect(s.hasEntitlement == true)
    }

    @Test func activeHasEntitlement() {
        let s = SubscriptionState.active(
            productID: "com.akitoando.CycleJournal.yearly_14400",
            expiresAt: Date().addingTimeInterval(86400 * 365)
        )
        #expect(s.hasEntitlement == true)
    }

    @Test func trialReportsDayCountFromPurchase() {
        // Day1/Day3/Day6/Day7 通知 (#37 C-2) の起点判定に使う
        let purchaseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let now = purchaseDate.addingTimeInterval(86400 * 3 + 3600) // Day 3 + 1h
        let day = SubscriptionState.trialDay(purchaseDate: purchaseDate, now: now)
        #expect(day == 3)
    }

    @Test func trialDayZeroOnPurchaseDay() {
        let purchaseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let now = purchaseDate.addingTimeInterval(3600) // 1h 後
        #expect(SubscriptionState.trialDay(purchaseDate: purchaseDate, now: now) == 0)
    }
}
