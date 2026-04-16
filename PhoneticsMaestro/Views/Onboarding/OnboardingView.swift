import SwiftUI

struct OnboardingView: View {
    let beginAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("FIRST RUN")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text("Welcome to Phonetics Maestro")
                    .font(.system(size: 28, weight: .semibold))
                Text("This is a one-time introduction. After this, the app opens directly into Training while History and Settings stay in the sidebar.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Button("Begin Training") {
                    beginAction()
                }
                .buttonStyle(.borderedProminent)

                Button("Not Now") {
                    dismissAction()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(28)
        .frame(maxWidth: 420, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
    }
}
