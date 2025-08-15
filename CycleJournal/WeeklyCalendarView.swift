import SwiftUI

struct WeeklyCalendarView: View {
    @ObservedObject var diaryStore: DiaryStore
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(-52...52, id: \.self) { weekOffset in
                        WeekView(
                            weekOffset: weekOffset,
                            diaryStore: diaryStore,
                            dateFormatter: dateFormatter,
                            dayFormatter: dayFormatter
                        )
                        .id(weekOffset)
                    }
                }
                .onAppear {
                    // 今日を初期選択
                    if diaryStore.selectedDate == nil {
                        diaryStore.setSelectedDate(Date())
                    }
                    // 現在の週にスクロール
                    proxy.scrollTo(0, anchor: .center)
                }
            }
        }
        .frame(height: 80)
        .background(Color(.systemGray6))
    }
    
}

struct WeekView: View {
    let weekOffset: Int
    @ObservedObject var diaryStore: DiaryStore
    let dateFormatter: DateFormatter
    let dayFormatter: DateFormatter
    
    private let calendar = Calendar.current
    
    private var weekDates: [Date] {
        let today = Date()
        let weekInterval = weekOffset * 7
        let targetDate = calendar.date(byAdding: .day, value: weekInterval, to: today) ?? today
        
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: targetDate) else {
            return []
        }
        
        var dates: [Date] = []
        let startDate = weekInterval.start
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                dates.append(date)
            }
        }
        
        return dates
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                VStack(spacing: 2) {
                    Text(dayFormatter.string(from: date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        selectDate(date)
                    }) {
                        Text(dateFormatter.string(from: date))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isSelected(date) ? .white : (isToday(date) ? .blue : .primary))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(isSelected(date) ? Color.blue : (isToday(date) ? Color.blue.opacity(0.1) : Color.clear))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 日記のインジケーター
                    Circle()
                        .fill(hasEntry(date) ? Color.orange : Color.clear)
                        .frame(width: 4, height: 4)
                }
                .frame(width: UIScreen.main.bounds.width / 7)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
    
    private func isSelected(_ date: Date) -> Bool {
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
    
    private func selectDate(_ date: Date) {
        diaryStore.setSelectedDate(date)
    }
}

struct WeeklyCalendarView_Previews: PreviewProvider {
    static var previews: some View {
        WeeklyCalendarView(diaryStore: DiaryStore())
    }
}