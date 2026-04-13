import SwiftUI

struct WelcomeView: View {
    let isInitialized: Bool
    let beginAction: () -> Void
    let historyAction: () -> Void
    let settingsAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Phonetics Maestro")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Train perception before production with local, distraction-free minimal pair practice.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: 540, alignment: .leading)

            HStack(spacing: 12) {
                Button("Begin", action: beginAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isInitialized)

                Button("History", action: historyAction)
                    .buttonStyle(.bordered)

                Button("Settings", action: settingsAction)
                    .buttonStyle(.bordered)
            }

            Text(isInitialized ? "Seed data loaded. Phase 1 skeleton is ready for navigation." : "Preparing the local library…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(32)
    }
}
