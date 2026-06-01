//
//  MeditationLog.swift
//  CycleJournal
//

import Foundation

/// 呼吸・瞑想セッションのローカルログ
struct MeditationLog: Identifiable, Codable {
    let id: UUID
    let date: Date
    let duration: Int // 秒数

    init(id: UUID = UUID(), date: Date = Date(), duration: Int) {
        self.id = id
        self.date = date
        self.duration = duration
    }

    /// 表示用の時間文字列（例: "5分"、"1分30秒"）
    var durationText: String {
        let minutes = duration / 60
        let seconds = duration % 60
        if seconds == 0 {
            return "\(minutes)分"
        } else if minutes == 0 {
            return "\(seconds)秒"
        } else {
            return "\(minutes)分\(seconds)秒"
        }
    }
}
