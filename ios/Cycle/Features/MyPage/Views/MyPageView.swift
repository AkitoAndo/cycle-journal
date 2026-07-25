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
    var body: some View {
        SettingsView()
    }
}

#Preview {
    MyPageView()
}
