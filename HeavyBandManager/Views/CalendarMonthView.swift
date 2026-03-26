import SwiftUI

struct CalendarMonthView: View {
    @EnvironmentObject var bandManager: BandManager
    @EnvironmentObject var calendarManager: CalendarManager

    @State private var selectedDate: String?
    @State private var isSyncing = false
    @State private var hasLoadedInitial = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var monthOffsets: [Int] { [0, 1, 2, 3, 4, 5] }

    @State private var overlapDots: [String: OverlapQuality] = [:]
    @State private var practiceSet: Set<String> = []
    @State private var scrollProxy: ScrollViewProxy?

    @State private var visibleMonth: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header: month name + Today button + weekday row
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(visibleMonth.isEmpty ? currentMonthName : visibleMonth)
                        .font(.title.bold())
                        .foregroundColor(.themeTextPrimary)

                    Spacer()

                    Button {
                        withAnimation { scrollProxy?.scrollTo(0, anchor: .top) }
                    } label: {
                        Text("Today")
                            .font(.subheadline)
                            .foregroundColor(.themeAccent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)

                HStack(spacing: 0) {
                    ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, letter in
                        Text(letter)
                            .font(.caption.bold())
                            .foregroundColor(.themeTextTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

                Divider().background(Color.themeBorder)
            }
            .background(Color.themeBg)

            // Scrollable month grids
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(monthOffsets, id: \.self) { offset in
                            let monthDate = calendar.date(byAdding: .month, value: offset, to: currentMonthStart)!
                            monthSection(for: monthDate)
                                .id(offset)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .onAppear {
                    scrollProxy = proxy
                    if !hasLoadedInitial {
                        proxy.scrollTo(0, anchor: .top)
                        hasLoadedInitial = true
                    }
                }
            }
        }
        .background(Color.themeBg)
        .sheet(item: Binding(
            get: { selectedDate.flatMap { DaySelection(date: $0) } },
            set: { selectedDate = $0?.date }
        )) { selection in
            DayDetailSheet(date: selection.date)
                .environmentObject(bandManager)
        }
        .task {
            await loadVisibleRange()
            refreshCache()
        }
        .onChange(of: bandManager.slots.count) { _, _ in
            refreshCache()
        }
        .onChange(of: bandManager.practices.count) { _, _ in
            refreshCache()
        }
    }

    // MARK: - Current month start

    private var currentMonthStart: Date {
        let comps = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: comps)!
    }

    // MARK: - Month Section (label + grid)

    private func monthSection(for monthStart: Date) -> some View {
        let monthName = monthFormatter.string(from: monthStart)
        let isFirst = calendar.isDate(monthStart, equalTo: currentMonthStart, toGranularity: .month)
        let days = daysInMonth(for: monthStart)

        return VStack(spacing: 0) {
            // Month divider label (not shown for the first/current month since header shows it)
            if !isFirst {
                Text(monthName)
                    .font(.title3.bold())
                    .foregroundColor(.themeTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 8)
            }

            // Day grid
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 52)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .onAppear {
            // Only update if different to avoid unnecessary redraws
            if visibleMonth != monthName {
                DispatchQueue.main.async { visibleMonth = monthName }
            }
        }
    }

    // MARK: - Day Cell

    private func dayCell(_ date: Date) -> some View {
        let dateStr = TimeHelpers.dateString(from: date)
        let isToday = calendar.isDateInToday(date)
        let isPast = date < calendar.startOfDay(for: Date()) && !isToday
        let quality = overlapDots[dateStr] ?? .none
        let hasPractice = practiceSet.contains(dateStr)
        let hasOpening = quality != .none || hasPractice
        let dayNum = calendar.component(.day, from: date)

        let textColor: Color = {
            if isToday { return .white }
            if isPast { return .themeTextTertiary }
            return .themeTextPrimary
        }()

        return Button {
            if !isPast { selectedDate = dateStr }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isToday {
                        Circle()
                            .fill(Color.themeAccent)
                            .frame(width: 32, height: 32)
                    }
                    Text("\(dayNum)")
                        .font(.body)
                        .foregroundColor(textColor)
                }

                HStack(spacing: 3) {
                    if hasPractice {
                        Circle().fill(Color.themeAccent).frame(width: 7, height: 7)
                    }
                    if quality == .full {
                        Circle().fill(Color.themeSuccess).frame(width: 7, height: 7)
                    } else if quality == .partial {
                        Circle().fill(Color.themeWarning).frame(width: 7, height: 7)
                    }
                }
                .frame(height: 8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .padding(2)
            .background(
                quality == .full ? Color.themeSuccess.opacity(0.08) :
                quality == .partial ? Color.themeWarning.opacity(0.06) :
                Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Helpers

    private func refreshCache() {
        overlapDots = bandManager.overlapMap()
        practiceSet = Set(bandManager.practices.map(\.date))
    }

    private var currentMonthName: String {
        monthFormatter.string(from: Date())
    }

    private var yearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }

    private var monthFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f
    }

    private func daysInMonth(for monthStart: Date) -> [Date?] {
        let firstWeekday = calendar.component(.weekday, from: monthStart) - 1
        let daysCount = calendar.range(of: .day, in: .month, for: monthStart)!.count

        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in 1...daysCount {
            var comps = calendar.dateComponents([.year, .month], from: monthStart)
            comps.day = day
            days.append(calendar.date(from: comps))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func loadVisibleRange() async {
        let start = currentMonthStart
        let end = calendar.date(byAdding: .month, value: 6, to: currentMonthStart)!
        let startStr = TimeHelpers.dateString(from: start)
        let endStr = TimeHelpers.dateString(from: end)

        await bandManager.loadSlots(from: startStr, to: endStr)
        await bandManager.loadPractices(from: startStr, to: endStr)
    }
}

struct DaySelection: Identifiable {
    let date: String
    var id: String { date }
}
