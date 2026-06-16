//
//  SandboxDetector.swift
//  CycleJournal
//
//  TestFlight / Sandbox 環境を本番 App Store ビルドと区別するためのヘルパー。
//  PaywallView の「テスター用にスキップ」ボタン表示判定に使う。
//
//  判定は appStoreReceiptURL の末尾パスで行う:
//   - 本番 App Store ビルド: ".../receipt"
//   - TestFlight / Sandbox  : ".../sandboxReceipt"
//   - Xcode から直接実行 (DEBUG): receipt 未取得 → DEBUG flag を fallback
//
//  本番ビルドでは isSandbox = false が保証されるため、bypass ボタンが
//  実ユーザーに表示されることはない。
//

import Foundation

enum SandboxDetector {
    static var isSandbox: Bool {
        #if DEBUG
        return true
        #else
        guard let url = Bundle.main.appStoreReceiptURL?.lastPathComponent else {
            return false
        }
        return url == "sandboxReceipt"
        #endif
    }
}
