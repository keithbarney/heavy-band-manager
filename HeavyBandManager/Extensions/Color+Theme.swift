import SwiftUI

extension Color {
    // MARK: - Backgrounds (adaptive)
    static let themeBg = Color(UIColor.systemBackground)
    static let themeBgSecondary = Color(UIColor.secondarySystemGroupedBackground)
    static let themeSurfaceElevated = Color(UIColor.tertiarySystemGroupedBackground)

    // MARK: - Border
    static let themeBorder = Color(UIColor.separator)

    // MARK: - Accent & Status
    static let themeAccent = Color.accentColor
    static let themeSuccess = Color(UIColor.systemGreen)
    static let themeWarning = Color(UIColor.systemYellow)
    static let themeDanger = Color(UIColor.systemRed)

    // MARK: - Text (adaptive)
    static let themeTextPrimary = Color(UIColor.label)
    static let themeTextSecondary = Color(UIColor.secondaryLabel)
    static let themeTextTertiary = Color(UIColor.tertiaryLabel)

    // MARK: - Member Colors
    static let memberColors: [Color] = [
        Color(red: 0.024, green: 0.757, blue: 0.404),  // #06C167
        Color(red: 0.004, green: 0.722, blue: 0.792),  // #01B8CA
        Color(red: 0.988, green: 0.510, blue: 0.227),  // #FC823A
        Color(red: 0.973, green: 0.204, blue: 0.275),  // #F83446
        Color(red: 0.659, green: 0.333, blue: 0.969),  // #A855F7
        Color(red: 0.918, green: 0.702, blue: 0.031),  // #EAB308
    ]
}
