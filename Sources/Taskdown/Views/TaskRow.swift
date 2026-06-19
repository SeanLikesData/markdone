import SwiftUI

/// The completion marker shape for a row.
enum MarkerStyle {
    case circle   // tasks and Big Three
    case checkbox // habits
}

/// A single task/Big Three row: a completion marker, an inline-editable title,
/// and an optional "…" overflow menu. Used in This Week, the day Tasks list,
/// and (without the menu) the template lists.
struct TaskRow: View {
    let item: TaskItem
    var placeholder: String = ""
    var markerStyle: MarkerStyle = .circle
    var isSelected: Bool
    var isEditing: Bool
    var showMenu: Bool = true
    var dimWhenEmpty: Bool = false
    /// The shared in-progress edit text, held by the store so a commit can be
    /// triggered from the keyboard handler (Enter, or arrow-away) as well as
    /// from this field.
    var draft: Binding<String>

    var onToggle: () -> Void = {}
    var onSelect: () -> Void = {}
    var onBeginEdit: () -> Void = {}
    var onCommit: () -> Void = {}
    var onDelete: () -> Void = {}
    var onMove: (Int) -> Void = { _ in } // 0 = This Week, 1...7 = Mon...Sun

    @FocusState private var fieldFocused: Bool

    private var isEmpty: Bool { item.title.isEmpty }

    var body: some View {
        HStack(spacing: 11) {
            Button(action: onToggle) {
                Marker(style: markerStyle, done: item.done)
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField(placeholder, text: draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(Style.primaryText)
                    .focused($fieldFocused)
                    .onSubmit { onCommit() }
                    .onChange(of: fieldFocused) { _, focused in
                        if !focused { onCommit() }
                    }
            } else {
                Text(isEmpty ? placeholder : item.title)
                    .font(.system(size: 14))
                    .foregroundColor(titleColor)
                    .strikethrough(item.done, color: Style.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 4)

            if showMenu && !isEditing {
                overflowMenu
            }
        }
        .padding(.horizontal, Style.rowHPadding)
        .padding(.vertical, Style.rowVPadding)
        .background(
            RoundedRectangle(cornerRadius: Style.rowCorner, style: .continuous)
                .fill(isSelected ? Style.selectionFill : Style.rowFill)
        )
        .focusRing(isSelected)
        .contentShape(RoundedRectangle(cornerRadius: Style.rowCorner, style: .continuous))
        .onTapGesture(count: 2) { onBeginEdit() }
        .onTapGesture(count: 1) { onSelect() }
        .onChange(of: isEditing) { _, editing in
            if editing { focusField() }
        }
        .onAppear {
            if isEditing { focusField() }
        }
    }

    /// Request keyboard focus on the next runloop tick. Setting focus in the
    /// same update pass that inserts the field is unreliable in a borderless
    /// panel — when renaming an already-visible row the request gets dropped —
    /// so defer it until the field is installed.
    private func focusField() {
        DispatchQueue.main.async { fieldFocused = true }
    }

    private var titleColor: Color {
        if isEmpty { return Style.mutedText }
        if item.done { return Style.secondaryText }
        return Style.primaryText
    }

    private var overflowMenu: some View {
        Menu {
            Button("Rename") { onBeginEdit() }
            Menu("Move to") {
                Button("This Week") { onMove(0) }
                ForEach(Weekday.allCases) { day in
                    Button(day.shortLabel) { onMove(day.rawValue + 1) }
                }
            }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Style.secondaryText)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

/// Hollow circle / filled check for tasks; hollow square / checked box for
/// habits.
struct Marker: View {
    let style: MarkerStyle
    let done: Bool

    var body: some View {
        ZStack {
            switch style {
            case .circle:
                Circle()
                    .strokeBorder(done ? Style.accent : Style.secondaryText, lineWidth: 1.6)
                    .background(Circle().fill(done ? Style.accent.opacity(0.18) : Color.clear))
                    .frame(width: 18, height: 18)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Style.accent)
                }
            case .checkbox:
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(done ? Style.accent : Style.secondaryText, lineWidth: 1.6)
                    .background(RoundedRectangle(cornerRadius: 4).fill(done ? Style.accent.opacity(0.18) : Color.clear))
                    .frame(width: 17, height: 17)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Style.accent)
                }
            }
        }
        .frame(width: 20, height: 20)
    }
}

/// A compact habit checkbox chip used in the day Tasks panel: a checkbox plus
/// the habit name. Selectable for keyboard focus; not editable here.
struct HabitChip: View {
    let item: TaskItem
    var isSelected: Bool
    var onToggle: () -> Void
    var onSelect: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Button(action: onToggle) {
                Marker(style: .checkbox, done: item.done)
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.system(size: 13))
                .foregroundColor(item.done ? Style.secondaryText : Style.primaryText)
                .strikethrough(item.done, color: Style.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Style.selectionFill : Style.chipFill)
        )
        .focusRing(isSelected, corner: 8)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture { onSelect() }
    }
}
