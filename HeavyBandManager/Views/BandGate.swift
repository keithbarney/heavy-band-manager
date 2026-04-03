import SwiftUI

struct BandGate: View {
    @EnvironmentObject var bandManager: BandManager

    var body: some View {
        Group {
            if bandManager.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.themeBg)
            } else if bandManager.currentBand == nil {
                VStack {
                    if let error = bandManager.error {
                        Text("DEBUG: \(error)")
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .padding()
                    }
                    OnboardingView()
                }
            } else {
                BandTabs()
            }
        }
    }
}
