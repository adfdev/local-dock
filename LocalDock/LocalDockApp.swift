import SwiftUI

@main
struct LocalDockApp: App {
    @State private var store = PortStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView(store: store)
        } label: {
            MenuBarLabel(portCount: store.activePortCount)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    let portCount: Int

    var body: some View {
        HStack(spacing: 3) {
            Image("StatusBarIcon")
                .renderingMode(.template)
            if portCount > 0 {
                Text(verbatim: "\(portCount)")
                    .font(.system(.caption2, weight: .bold))
                    .monospacedDigit()
            }
        }
    }
}
