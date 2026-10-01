import SwiftUI

struct PracticeLocationEditor: View {
    let title: String
    let explanation: String
    let save: (String) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var location: String
    @State private var searching = false
    @State private var saving = false
    @State private var errorMessage: String?

    init(title: String, location: String?, explanation: String, save: @escaping (String) async throws -> Void) {
        self.title = title
        self.explanation = explanation
        self.save = save
        _location = State(initialValue: location ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Place or address", text: $location, axis: .vertical)
                        .accessibilityIdentifier("practice-location-input")
                    Button("Search for a place", systemImage: "magnifyingglass") { searching = true }
                    if !location.isEmpty {
                        Button("Clear location", role: .destructive) { location = "" }
                    }
                } header: {
                    Text("Location")
                } footer: {
                    Text(explanation)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                            .accessibilityIdentifier("practice-location-error")
                    }
                }
            }
            .disabled(saving)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saving = true
                        errorMessage = nil
                        Task {
                            do {
                                try await save(location.trimmingCharacters(in: .whitespacesAndNewlines))
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                                saving = false
                            }
                        }
                    } label: {
                        if saving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(saving)
                    .accessibilityIdentifier("save-practice-location")
                }
            }
            .interactiveDismissDisabled(saving)
            .sheet(isPresented: $searching) { LocationSearchView(selectedLocation: $location) }
        }
    }
}
