import SwiftUI

struct SettingsView: View {
    var body: some View {
        ContentUnavailableView(
            "Settings",
            systemImage: "slider.horizontal.3",
            description: Text("Phase 4 will add voice, microphone, and ABAB preferences.")
        )
    }
}
