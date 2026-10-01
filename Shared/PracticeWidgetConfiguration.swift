import AppIntents
import Foundation

/// Store stable band IDs as the intent value and show names in the system picker.
/// This avoids requiring cross-process AppEntity registration to resolve a widget.
struct PracticeBandOptions: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<String> {
        let bands = PracticeWidgetStore().read()?.bands ?? []
        let all = IntentItem(SelectPracticeBand.allBandsIdentifier, title: "All bands")
        return IntentItemCollection(sections: [IntentItemSection(items: [all] + bands.map {
            IntentItem($0.id.uuidString, title: "\($0.name)")
        })])
    }

    func defaultResult() async -> String? {
        SelectPracticeBand.allBandsIdentifier
    }
}

struct SelectPracticeBand: WidgetConfigurationIntent {
    static let allBandsIdentifier = "all-bands"
    static var title: LocalizedStringResource = "Choose a band"
    static var description = IntentDescription("Show upcoming practices for all your bands or one band.")
    @Parameter(title: "Band", optionsProvider: PracticeBandOptions()) var bandIdentifier: String?
    var showsAllBands: Bool { bandIdentifier == Self.allBandsIdentifier }

    /// Resolve only the saved band, even after the app's selected band changes.
    func selectedBand(in snapshot: PracticeWidgetSnapshot) -> PracticeWidgetBand? {
        guard let bandIdentifier, let id = UUID(uuidString: bandIdentifier) else { return nil }
        return snapshot.bands.first { $0.id == id }
    }
}
