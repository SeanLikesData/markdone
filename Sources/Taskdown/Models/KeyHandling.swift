import AppKit

/// Interprets raw key events into store actions. Installed as a local key
/// monitor by the AppDelegate while the popover is open. Most keys belong to the
/// focused Markdown text field, so this returns the event unchanged unless it is
/// an app-level shortcut, in which case it acts and returns `nil` to consume it.
extension WeekStore {
    private enum Key {
        static let escape: UInt16 = 53
        static let left: UInt16 = 123
        static let right: UInt16 = 124
    }

    func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let code = event.keyCode
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let option = flags.contains(.option)

        // A sheet owns its own keys, except Escape, which closes it.
        if activeSheet != nil {
            if code == Key.escape {
                activeSheet = nil
                return nil
            }
            return event
        }

        guard command else { return event }

        // Day navigation: Cmd+Option+Left/Right steps days; Cmd+1...7 jumps to a
        // specific weekday. These use modifiers the text field does not, so
        // text editing keeps Cmd+arrows for line movement.
        if option {
            switch code {
            case Key.left:
                switchDay(forward: false)
                return nil
            case Key.right:
                switchDay(forward: true)
                return nil
            default:
                break
            }
        }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "w":
            onRequestClose?()
            return nil
        case "n":
            addNewWeek()
            return nil
        case "1", "2", "3", "4", "5", "6", "7":
            if let n = Int(event.charactersIgnoringModifiers ?? ""),
               let weekday = Weekday(rawValue: n - 1) {
                selectTab(weekday)
            }
            return nil
        default:
            return event
        }
    }
}
