import SwiftUI

struct BandTabs: View {
    var body: some View {
        TabView {
            CalendarMonthView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(Color.themeAccent)
    }
}
