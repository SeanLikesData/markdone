import AppKit

/// Interprets raw key events into store actions. Installed as a local key
/// monitor by the AppDelegate while the popover is open. Returns the event
/// unchanged when it should fall through to a text field or button, or `nil`
/// to consume it.
extension WeekStore {
    private enum Key {
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let tab: UInt16 = 48
        static let space: UInt16 = 49
        static let delete: UInt16 = 51
        static let forwardDelete: UInt16 = 117
        static let escape: UInt16 = 53
        static let left: UInt16 = 123
        static let right: UInt16 = 124
        static let down: UInt16 = 125
        static let up: UInt16 = 126
    }

    func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let code = event.keyCode
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shift = flags.contains(.shift)
        let command = flags.contains(.command)

        // While editing a title: Enter commits; Up/Down commit and then move to
        // the adjacent task; Escape cancels. Every other key (including Left and
        // Right, which move the text cursor) belongs to the text field.
        if editingID != nil {
            switch code {
            case Key.returnKey, Key.keypadEnter:
                commitEditing()
                return nil
            case Key.up:
                commitEditing()
                navigateVertical(up: true)
                return nil
            case Key.down:
                commitEditing()
                navigateVertical(up: false)
                return nil
            case Key.escape:
                cancelEditing()
                return nil
            default:
                return event
            }
        }

        // A sheet (weeks, template, settings, help) owns its own keys, except
        // Escape, which closes it.
        if activeSheet != nil {
            if code == Key.escape {
                activeSheet = nil
                return nil
            }
            return event
        }

        // Command combinations.
        if command {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "n":
                addNewWeek()
                return nil
            default:
                return event
            }
        }

        // Plain navigation and actions.
        switch code {
        case Key.up:
            if shift { reorderSelected(up: true) } else { navigateVertical(up: true) }
            return nil
        case Key.down:
            if shift { reorderSelected(up: false) } else { navigateVertical(up: false) }
            return nil
        case Key.left:
            if shift { moveSelectedAlongChain(forward: false) } else { navigateHorizontal(right: false) }
            return nil
        case Key.right:
            if shift { moveSelectedAlongChain(forward: true) } else { navigateHorizontal(right: true) }
            return nil
        case Key.tab:
            cycleRegion(forward: !shift)
            return nil
        case Key.space:
            if let id = selectedID { toggleDone(id) }
            return nil
        case Key.returnKey, Key.keypadEnter:
            beginEditingSelected()
            return nil
        case Key.delete, Key.forwardDelete:
            deleteSelected()
            return nil
        case Key.escape:
            onRequestClose?()
            return nil
        default:
            break
        }

        // Letter commands.
        switch event.charactersIgnoringModifiers {
        case "r":
            beginEditingSelected()
            return nil
        case "w":
            addWeekTask()
            return nil
        case "n":
            addDayTask()
            return nil
        case "t":
            activeSheet = .template
            return nil
        case "?":
            activeSheet = .help
            return nil
        default:
            return event
        }
    }
}
