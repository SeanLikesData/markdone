import SwiftUI

/// The whole popover: day tabs, the left column (Big Three and This Week), the
/// day panel, and the bottom bar, on a dark frosted surface. Modal sheets
/// present over it.
struct ContentView: View {
    @EnvironmentObject var store: WeekStore
    /// In the pop-out window the content fills the whole window with square
    /// corners; in the popover it is a rounded, bordered card.
    var inWindow: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if inWindow {
                // Clearance for the window's traffic-light buttons, which float
                // over the full-size content.
                Color.clear.frame(height: 22)
            }

            DayTabsView()

            Rectangle()
                .fill(Style.divider)
                .frame(height: 1)

            HStack(spacing: 0) {
                LeftColumn()
                    .frame(width: 300)

                Rectangle()
                    .fill(Style.divider)
                    .frame(width: 1)

                DayPanel()
                    .frame(maxWidth: .infinity)
            }

            Rectangle()
                .fill(Style.divider)
                .frame(height: 1)

            BottomBar()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow)
                Color.black.opacity(0.30)
            }
            // Fill the whole window, including under the window's title bar, so
            // the traffic-light buttons sit on the frosted material instead of
            // floating over empty space.
            .ignoresSafeArea()
        )
        .clipShape(RoundedRectangle(cornerRadius: inWindow ? 0 : 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: inWindow ? 0 : 16, style: .continuous)
                .strokeBorder(Color.white.opacity(inWindow ? 0 : 0.08), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
        .sheet(item: $store.activeSheet) { sheet in
            switch sheet {
            case .weeks:
                WeeksSheet().environmentObject(store)
            case .template:
                TemplateSheet().environmentObject(store)
            case .settings:
                SettingsView().environmentObject(store)
            case .help:
                HelpSheet().environmentObject(store)
            }
        }
    }
}
