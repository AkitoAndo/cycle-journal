import SwiftUI

struct CalendarView: View {
    @ObservedObject var diaryStore: DiaryStore
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedMonth = Date()
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()
    
    private var monthDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedMonth) else {
            return []
        }
        
        let monthStart = monthInterval.start
        
        // 月の最初の日が何曜日か取得
        let weekday = calendar.component(.weekday, from: monthStart)
        let daysFromSunday = (weekday - 1) % 7
        
        // 前月の日付を含める
        guard let calendarStart = calendar.date(byAdding: .day, value: -daysFromSunday, to: monthStart) else {
            return []
        }
        
        var dates: [Date] = []
        for i in 0..<42 { // 6週間分（6 * 7 = 42日）
            if let date = calendar.date(byAdding: .day, value: i, to: calendarStart) {
                dates.append(date)
            }
        }
        
        return dates
    }
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekDays = ["日", "月", "火", "水", "木", "金", "土"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 月ナビゲーション
                HStack {
                    Button(action: {
                        changeMonth(by: -1)
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                    
                    Spacer()
                    
                    Text(dateFormatter.string(from: selectedMonth))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                        changeMonth(by: 1)
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                }
                .padding()
                
                // 曜日ヘッダー
                HStack {
                    ForEach(weekDays, id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // カレンダーグリッド
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(monthDates, id: \.self) { date in
                        VStack(spacing: 2) {
                            Button(action: {
                                selectDate(date)
                            }) {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(dateTextColor(date))
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(dateBackgroundColor(date))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // 日記のインジケーター
                            Circle()
                                .fill(hasEntry(date) ? Color.orange : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(height: 50)
                    }
                }
                .padding()
                
                Spacer()
                
                // 選択した日付の情報
                if let selectedDate = diaryStore.selectedDate {
                    VStack {
                        Text("選択した日付")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(selectedDate, style: .date)
                            .font(.headline)
                        
                        let entryCount = entriesCount(for: selectedDate)
                        if entryCount > 0 {
                            Text("\(entryCount)件の日記")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else {
                            Text("日記なし")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding()
                }
            }
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("今日") {
                        selectedMonth = Date()
                        diaryStore.setSelectedDate(Date())
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
    
    private func selectDate(_ date: Date) {
        diaryStore.setSelectedDate(date)
    }
    
    private func dateTextColor(_ date: Date) -> Color {
        let isCurrentMonth = calendar.isDate(date, equalTo: selectedMonth, toGranularity: .month)
        let isSelected = isSelectedDate(date)
        let isToday = calendar.isDateInToday(date)
        
        if isSelected {
            return .white
        } else if isToday {
            return .blue
        } else if isCurrentMonth {
            return .primary
        } else {
            return .secondary
        }
    }
    
    private func dateBackgroundColor(_ date: Date) -> Color {
        let isSelected = isSelectedDate(date)
        let isToday = calendar.isDateInToday(date)
        
        if isSelected {
            return .blue
        } else if isToday {
            return .blue.opacity(0.1)
        } else {
            return .clear
        }
    }
    
    private func isSelectedDate(_ date: Date) -> Bool {
        guard let selectedDate = diaryStore.selectedDate else {
            return false
        }
        return calendar.isDate(date, inSameDayAs: selectedDate)
    }
    
    private func hasEntry(_ date: Date) -> Bool {
        diaryStore.entries.contains { entry in
            calendar.isDate(entry.createdAt, inSameDayAs: date)
        }
    }
    
    private func entriesCount(for date: Date) -> Int {
        diaryStore.entries.filter { entry in
            calendar.isDate(entry.createdAt, inSameDayAs: date)
        }.count
    }
}

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView(diaryStore: DiaryStore())
    }
}