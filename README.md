# Taskdown

Taskdown is a local macOS menu bar application for planning a week of tasks in
Markdown. Every region — the **Big Three** priorities, the undated **This Week**
list, and each weekday — is a Markdown text field that live-renders: Markdown
syntax is hidden on the lines your cursor is not on, headings are colored, and
checkboxes render as clickable boxes.

It is built with SwiftUI and AppKit, opens as a compact dark glass popover (or a
resizable window), saves to a local JSON file, and shows no Dock icon.

## The idea

It replaces a long, hand-managed Markdown file of tasks-by-day with the same
fluid plain-text editing, plus structure:

- **Write tasks as Markdown.** Type `[] task` or `- [ ] task` to make a
  checkbox. Click the rendered box to mark it done — the text dims and strikes
  through. Add notes under a task, indent subtasks, use headings — it is just
  Markdown.
- **One day at a time.** Each weekday is its own block. Switch days with the
  tabs instead of scrolling one long file. Today is selected when you open the
  app.
- **Recurring templates.** A weekly template seeds every new week, so a standard
  Monday block (or weekly tasks) appears automatically.

## Layout

- **Day tabs (top):** Monday through Sunday. The active day drives the day
  panel. Each tab shows the number of completed checkboxes for that day.
- **Left column:** the per-week **Big Three** priorities and the undated **This
  Week** tasks, each a live-rendering Markdown field.
- **Day panel (right):** the selected day's Markdown block.
- **Bottom bar:** a week pill showing the current week and its `done/total`
  count (tap it to manage weeks), a **New Week** button, save status, and
  buttons to pop out into a window, open the Template editor, help, and
  settings.

## Markdown rendering

The line your cursor is on always shows its raw Markdown; every other line (and
every other, unfocused field) renders. Supported inline: headings (`#`–`######`,
colored by level), **bold**, *italic*, ~~strikethrough~~, `code`, links, block
quotes, and ordered/unordered lists. Task checkboxes — `[ ]`, `[x]`, `[]`, with
or without a leading `-`/`*`/`+` bullet — render as boxes you can click.

## Pop-out window

The `macwindow` button in the bottom bar opens the same content in a normal
resizable window, for when you want room to write longer notes. The window and
the popover share one store, so they always show the same data.

## Weekly template

The Template editor (square button in the bottom bar) holds a Markdown block for
the Big Three, This Week, and each weekday. Creating a new week copies those
blocks into the new week. Template edits apply to new weeks only.

## Keyboard shortcuts

Most keys belong to the focused Markdown field (normal text editing). The
app-level shortcuts are:

| Key | Action |
| --- | --- |
| Cmd-1 … Cmd-7 | Jump to Monday … Sunday |
| Cmd-Option-Left / Right | Previous / next day |
| Cmd-N | New week |
| Cmd-W | Close the popover or window |
| Esc | Close an open panel (template, settings, help) |

## Build and run

From this repository root:

```sh
./build.sh
open build/Taskdown.app
```

The build script compiles the Swift sources directly with `swiftc` and assembles
a proper `.app` bundle with `LSUIElement=true`, so the application runs as a menu
bar accessory. (Swift Package Manager's manifest step does not link on a machine
with only the Xcode Command Line Tools, so `swift build` is not used.)

To build, install to `/Applications`, and relaunch in one step:

```sh
./build.sh --install
```

To quit, press **Cmd-Q**, or use Quit Taskdown in Settings.

## Data storage

Taskdown stores everything locally:

```text
~/Library/Application Support/Taskdown/data.json
```

Each region is stored as a Markdown string. **Export all weeks to Markdown…** in
Settings writes a single readable `.md` snapshot. There is no server, account,
analytics, or cloud synchronization.
