import SwiftUI

struct CalendarMonthView: View {
    @EnvironmentObject var bandManager: BandManager
    @EnvironmentObject var calendarManager: CalendarManager

    @State private var sheetDate: String?
    @State private var showUpcoming = false
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
        NavigationStack {
        VStack(spacing: 0) {
            // Fixed header: month name + weekday row
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(visibleMonth.isEmpty ? currentMonthName : visibleMonth)
                        .font(.title.bold())
                        .foregroundColor(.themeTextPrimary)

                    Spacer()

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.themeSuccess).frame(width: 6, height: 6)
                            Text("All members")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        HStack(spacing: 4) {
                            Circle().fill(Color.themeWarning).frame(width: 6, height: 6)
                            Text("Some members")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
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

            if showUpcoming {
                upcomingPracticesList
            } else {
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
                .coordinateSpace(name: "calendarScroll")
                .onAppear {
                    scrollProxy = proxy
                    if !hasLoadedInitial {
                        proxy.scrollTo(0, anchor: .top)
                        hasLoadedInitial = true
                    }
                }
            }
            } // end else (calendar grid)
        }
        .background(Color.themeBg)
        .sheet(item: Binding(
            get: { sheetDate.flatMap { DaySelection(date: $0) } },
            set: { sheetDate = $0?.date }
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    if let logoUrl = bandManager.currentBand?.logoUrl, let url = URL(string: logoUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(Color.themeAccent.opacity(0.2))
                                .frame(width: 36, height: 36)
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.themeAccent.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(String((bandManager.currentBand?.name ?? "B").prefix(1)).uppercased())
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.themeAccent)
                            )
                    }
                    Text(bandManager.currentBand?.name ?? "")
                        .font(.headline)
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                HStack(spacing: 0) {
                    Button {
                        withAnimation { showUpcoming.toggle() }
                    } label: {
                        Image(systemName: showUpcoming ? "calendar" : "line.3.horizontal")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 36, height: 32)
                    }

                    Divider()
                        .frame(height: 20)

                    Button {
                        withAnimation { scrollProxy?.scrollTo(0, anchor: .top) }
                    } label: {
                        Text("Today")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                    }
                }
                .background(
                    Capsule()
                        .strokeBorder(Color.themeBorder, lineWidth: 1)
                )
                .clipShape(Capsule())
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        } // NavigationStack
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
        .background(
            GeometryReader { geo in
                let frame = geo.frame(in: .named("calendarScroll"))
                // Month is "visible" when its top is within the top 100pt of the scroll view
                Color.clear
                    .onChange(of: frame.minY) { _, minY in
                        if minY < 100 && minY > -frame.height + 100 {
                            if visibleMonth != monthName {
                                visibleMonth = monthName
                            }
                        }
                    }
            }
        )
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
            if isToday || hasPractice { return .white }
            if isPast { return .themeTextTertiary }
            return .themeTextPrimary
        }()

        return Button {
            if !isPast { sheetDate = dateStr }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if hasPractice && !isToday {
                        Circle()
                            .fill(Color.themeSuccess)
                            .frame(width: 34, height: 34)
                    } else if isToday {
                        Circle()
                            .fill(Color.themeTextPrimary)
                            .frame(width: 34, height: 34)
                    }
                    Text("\(dayNum)")
                        .font(.system(size: 16, weight: hasPractice || isToday ? .semibold : .regular))
                        .foregroundColor(textColor)
                }

                HStack(spacing: 3) {
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
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Upcoming Practices List

    private var upcomingPracticesList: some View {
        let today = TimeHelpers.dateString(from: Date())
        let upcoming = bandManager.practices
            .filter { $0.date >= today }
            .sorted { $0.date < $1.date }

        return Group {
            if upcoming.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No upcoming practices")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Schedule from the calendar view")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 80)
            } else {
                List {
                    ForEach(upcoming) { practice in
                        Button {
                            sheetDate = practice.date
                        } label: {
                            HStack(spacing: 12) {
                                VStack(spacing: 2) {
                                    Text(practiceWeekday(practice.date))
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    Text(practiceDay(practice.date))
                                        .font(.title2.bold())
                                        .foregroundStyle(.primary)
                                }
                                .frame(width: 44)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.themeSuccess)
                                    .frame(width: 4, height: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(bandManager.currentBand?.name ?? "Band") Practice")
                                        .font(.body.bold())
                                        .foregroundStyle(.primary)
                                    Text("\(TimeHelpers.formatTime(practice.startMinutes)) – \(TimeHelpers.formatTime(practice.endMinutes))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if let loc = practice.location, !loc.isEmpty {
                                        Text(loc)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()

                                Text(practiceMonth(practice.date))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func practiceWeekday(_ dateStr: String) -> String {
        guard let date = TimeHelpers.date(from: dateStr) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private func practiceDay(_ dateStr: String) -> String {
        guard let date = TimeHelpers.date(from: dateStr) else { return "" }
        return "\(calendar.component(.day, from: date))"
    }

    private func practiceMonth(_ dateStr: String) -> String {
        guard let date = TimeHelpers.date(from: dateStr) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }

    // MARK: - Helpers

    private func refreshCache() {
        overlapDots = bandManager.overlapMap()
        practiceSet = Set(bandManager.practices.map(\.date))
    }

    private var currentMonthName: String {
        monthFormatter.string(from: Date())
    }

    private static let yearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f
    }()

    private static let monthNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f
    }()

    private var yearString: String {
        Self.yearFormatter.string(from: Date())
    }

    private var monthFormatter: DateFormatter {
        Self.monthNameFormatter
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
