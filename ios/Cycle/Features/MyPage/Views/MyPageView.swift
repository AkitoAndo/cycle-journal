//
//  MyPageView.swift
//  Cycle
//
//  マイページ画面
//  [0710] 設定ボタン+シート方式をやめ、設定画面の内容を
//  そのままマイページとして表示する（SettingsView を直接埋め込み）。
//  今後プロフィール・利用状況などを追加する場合は SettingsView 側の
//  List に セクションを足していく。
//

import SwiftUI

struct MyPageView: View {
    /// シートとして開いたときに右上に「完了」を出す（U-04: ホーム右上から開く）
    var showsCloseButton = false

    var body: some View {
        SettingsView(showsCloseButton: showsCloseButton)
    }
}

#Preview {
    MyPageView()
}
