import Foundation

/// UserDefaults keys for the small set of app preferences.
enum SettingsKey {
    static let pinned = "pinned"
}

/// Whether the popover should stay open and float above other windows instead
/// of closing when another application is clicked.
var isPinnedSetting: Bool {
    get { UserDefaults.standard.bool(forKey: SettingsKey.pinned) }
    set { UserDefaults.standard.set(newValue, forKey: SettingsKey.pinned) }
}
