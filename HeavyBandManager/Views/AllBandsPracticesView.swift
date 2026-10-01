import SwiftUI

struct AllBandsPracticesView: View {
    @EnvironmentObject private var bandManager: BandManager
    @Environment(\.dismiss) private var dismiss
    @State private var bands: [PracticeWidgetBand] = []
    @State private var loading = true
    @State private var openingPractice = false
    @State private var errorMessage: String?
    @State private var selectedDay: String?

    var body: some View {
        NavigationStack {
            List {
                if loading && bands.isEmpty {
                    ProgressView("Loading practices")
                } else if bands.isEmpty {
                    ContentUnavailableView("No bands", systemImage: "person.3",
                        description: Text("Join a band to see its upcoming practices here."))
                }
                ForEach(bands) { band in
                    Section {
                        let upcoming = band.upcoming(at: Date())
                        if upcoming.isEmpty {
                            Text(band.updatedAt == nil ? "Open or refresh this band to load practices." : "No upcoming practices")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(upcoming) { practice in
                            Button {
                                openingPractice = true
                                Task {
                                    defer { openingPractice = false }
                                    do {
                                        selectedDay = try await bandManager.preparePracticeRoute(
                                            PracticeRoute(bandID: band.id, practiceID: practice.id))
                                    } catch {
                                        errorMessage = "This practice is unavailable. Refresh and try again."
                                    }
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    if let date = practice.start() {
                                        Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                                            .font(.headline)
                                    }
                                    Text("\(TimeHelpers.formatTime(practice.startMinutes)) – \(TimeHelpers.formatTime(practice.endMinutes))")
                                    if let location = practice.location, !location.isEmpty {
                                        Text(location).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(openingPractice)
                            .accessibilityIdentifier("all-bands-practice-\(practice.id)")
                        }
                    } header: {
                        Text(band.name)
                    } footer: {
                        if band.needsRefresh(at: Date()), band.updatedAt != nil {
                            Text("This schedule may be out of date. Pull to refresh.")
                        }
                    }
                }
            }
            .navigationTitle("All Band Practices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { await refresh() }
            .refreshable { await refresh() }
            .sheet(isPresented: Binding(get: { selectedDay != nil }, set: { if !$0 { selectedDay = nil } }), onDismiss: readSnapshot) {
                if let selectedDay { DayDetailSheet(date: selectedDay) }
            }
            .alert("Practice unavailable", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func refresh() async {
        loading = true
        defer { loading = false }
        readSnapshot()
        await PracticeWidgetSync.shared.refresh(force: true)
        readSnapshot()
    }

    private func readSnapshot() {
        if let snapshot = PracticeWidgetStore().read() {
            bands = snapshot.orderedBands(at: Date())
        } else {
            bands = bandManager.bands.map {
                PracticeWidgetBand(id: $0.id, name: $0.name, practices: [], updatedAt: nil)
            }
        }
    }
}
