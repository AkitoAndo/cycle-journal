//
//  JSONFileStore.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import Foundation

/// JSONファイルを使用した汎用的なデータ永続化ユーティリティ
///
/// DocumentsディレクトリにJSONファイルとしてデータを保存・読み込み
/// アプリ全体で使用可能なシンプルなストレージ抽象化
enum JSONFileStore {
    /// ファイル名からDocumentsディレクトリのフルパスURLを取得
    /// - Parameter fileName: ファイル名（例: "data.json"）
    /// - Returns: DocumentsディレクトリのファイルURL
    static func url(_ fileName: String) -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(fileName)
    }

    /// JSONファイルからデータを読み込み
    /// - Parameters:
    ///   - fileName: 読み込むファイル名
    ///   - type: デコードする型
    /// - Returns: デコードされたデータ（失敗時はnil）
    static func load<T: Decodable>(_ fileName: String, as type: T.Type) -> T? {
        let u = url(fileName)
        guard let data = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// データをJSONファイルに保存
    /// - Parameters:
    ///   - value: 保存する値
    ///   - fileName: 保存先のファイル名
    static func save<T: Encodable>(_ value: T, to fileName: String) {
        let u = url(fileName)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        if let data = try? enc.encode(value) {
            try? data.write(to: u, options: .atomic)
        }
    }
}
