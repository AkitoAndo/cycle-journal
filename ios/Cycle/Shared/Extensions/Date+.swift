//
//  Date+.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import Foundation

extension Date {
    var ymdString: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.dateFormat = "yyyy-MM-dd"
        
        return df.string(from: self)
    }
    var timeHM: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.dateFormat = "HH:mm"
        return df.string(from: self)
    }
}
