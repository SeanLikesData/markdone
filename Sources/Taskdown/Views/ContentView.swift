import SwiftUI

/// The whole popover: top bar, day tabs, the two main panels, and the bottom
/// bar, on a dark frosted surface. Modal sheets (template, settings, help)
/// present over it.
struct ContentView: View {
    @EnvironmentObject var store: WeekStore

    var body: some View {
        VStack(spacing: 0) {
            DayTabsView()

            Rectangle()
                .fill(Style.divider)
                .frame(height: 1)

            HStack(spacing: 0) {
                ThisWeekPanel()
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Style.divider)
                    .frame(width: 1)

                TasksPanel()
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
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
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
