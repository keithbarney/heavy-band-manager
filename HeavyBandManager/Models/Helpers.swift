import SwiftUI

enum TimeHelpers {
    static func formatTime(_ minutes: Int) -> String {
        let hour = minutes / 60
        let min = minutes % 60
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        if min == 0 {
            return "\(displayHour) \(period)"
        }
        return "\(displayHour):\(String(format: "%02d", min)) \(period)"
    }

    static func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        }
        return "\(mins)m"
    }

    static let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static let dayAbbrevs = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    static func dayName(_ day: Int) -> String { dayNames[day % 7] }
    static func dayAbbrev(_ day: Int) -> String { dayAbbrevs[day % 7] }

    // MARK: - Date helpers

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let fullDisplayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    static func dateString(from date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        isoFormatter.date(from: string)
    }

    static func displayDate(_ dateString: String) -> String {
        guard let d = date(from: dateString) else { return dateString }
        return displayFormatter.string(from: d)
    }

    static func fullDisplayDate(_ dateString: String) -> String {
        guard let d = date(from: dateString) else { return dateString }
        return fullDisplayFormatter.string(from: d)
    }
}

enum MemberColors {
    static let palette: [Color] = [
        Color(hex: "06C167"),
        Color(hex: "01B8CA"),
        Color(hex: "FC823A"),
        Color(hex: "F83446"),
        Color(hex: "A855F7"),
        Color(hex: "EAB308"),
    ]

    static func color(at index: Int) -> Color {
        palette[index % palette.count]
    }

    static func color(hex: String) -> Color {
        Color(hex: hex)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
