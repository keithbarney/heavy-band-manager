import SwiftUI

struct EditCalendarView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var color: Color = .blue

    var body: some View {
        Form {
            Section("Name") {
                TextField("Calendar Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
            }

            Section("Color") {
                ColorPicker("Calendar Color", selection: $color, supportsOpacity: false)
            }
        }
        .navigationTitle("Edit Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { save() }
                    .disabled(trimmedName.isEmpty)
                    .fontWeight(.semibold)
            }
        }
        .onAppear {
            name = calendarManager.practiceCalendarName
            color = calendarManager.practiceCalendarColor
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        calendarManager.renameCalendar(to: trimmedName)
        calendarManager.recolorCalendar(color)
        dismiss()
    }
}
