import SwiftUI

struct HistoryView: View {
    var body: some View {
        ContentUnavailableView(
            "History",
            systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
            description: Text("Phase 4 will add session summaries and accuracy trends.")
        )
    }
}
