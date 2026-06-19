import SwiftUI
import AppKit

/// A small settings sheet: pin behavior, editor font size, Markdown export,
/// data location, and quit.
struct SettingsView: View {
    @EnvironmentObject var store: WeekStore
    @State private var pinned = isPinnedSetting
    @AppStorage(SettingsKey.fontSize) private var fontSize: Double = defaultFontSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Style.primaryText)
                Spacer()
                Button("Done") { store.activeSheet = nil }
                    .buttonStyle(SheetButtonStyle(prominent: true))
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $pinned) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keep popover pinned above other windows")
                            .font(.system(size: 14))
                            .foregroundColor(Style.primaryText)
                        Text("When on, the popover floats and stays open instead of closing when you click another app.")
                            .font(.system(size: 12))
                            .foregroundColor(Style.secondaryText)
                    }
                }
                .toggleStyle(.switch)
                .onChange(of: pinned) { _, newValue in isPinnedSetting = newValue }

                Rectangle().fill(Style.divider).frame(height: 1)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Editor font size")
                            .font(.system(size: 14))
                            .foregroundColor(Style.primaryText)
                        Text("\(Int(fontSize)) pt")
                            .font(.system(size: 12))
                            .foregroundColor(Style.secondaryText)
                    }
                    Spacer()
                    Stepper("", value: $fontSize, in: 11...22, step: 1)
                        .labelsHidden()
                }

                Rectangle().fill(Style.divider).frame(height: 1)

                Button("Export all weeks to Markdown…") { store.exportMarkdownToFile() }
                    .buttonStyle(SheetButtonStyle())

                Button("Reveal data file in Finder") { revealData() }
                    .buttonStyle(SheetButtonStyle())

                Spacer()

                Button("Quit Taskdown") { NSApp.terminate(nil) }
                    .buttonStyle(SheetButtonStyle())
            }
            .padding(24)
        }
        .frame(width: 460, height: 420)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow)
                Color.black.opacity(0.30)
            }
        )
        .preferredColorScheme(.dark)
    }

    private func revealData() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Taskdown", isDirectory: true)
        NSWorkspace.shared.activateFileViewerSelecting([dir.appendingPathComponent("data.json")])
    }
}
