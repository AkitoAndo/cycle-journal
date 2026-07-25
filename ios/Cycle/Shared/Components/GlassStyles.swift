//
//  GlassStyles.swift
//  Cycle
//
//  アプリ共通の Liquid Glass スタイル定義
//  素の .regular ガラスは背景色に引っ張られて色がずれるため、
//  用途別に tint 済みのバリアントをここに集約する。
//  ガラスの見た目を調整するときはこのファイルを変えれば全画面に効く。
//

import SwiftUI

@available(iOS 26.0, *)
extension Glass {
    /// カード・検索バー・入力欄・チップ・ヘッダーボタンなど surface 面用。
    /// 温白（surface）を 85% で tint して色を安定させる。
    static var surfaceTinted: Glass {
        .regular.tint(DesignSystem.Colors.surface.opacity(0.85))
    }

    /// FAB などプライマリアクション用。アクセント（ブラウン）tint。
    static var accentTinted: Glass {
        .regular.tint(DesignSystem.Colors.accent.opacity(0.90))
    }
}
