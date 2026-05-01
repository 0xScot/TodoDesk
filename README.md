# TodoDesk

TodoDesk is a lightweight native macOS todo app built with AppKit and Objective-C. It is local-first, has no account requirement, and stores tasks as JSON on your Mac.

The interface text is currently Traditional Chinese.

## Features

- Today, Tomorrow, Past Completed, Past Incomplete, and custom list tabs
- Local JSON task storage, import, and export
- One-level subtasks with completion, rename, delete, reorder, estimate, timer, and description support
- Estimated duration fields in hours/minutes
- Start, pause, resume, and cancel timers with macOS notifications
- Drag-and-drop ordering for Today, Tomorrow, and custom lists
- Search within the current tab or list
- Daily review flow for moving overdue incomplete tasks back to Today
- Compact task blocks that keep descriptions and completion timestamps on one line

## Requirements

- macOS 13 or later
- Xcode Command Line Tools

Install the command line tools if needed:

```bash
xcode-select --install
```

## Build And Run

```bash
git clone https://github.com/0xScot/TodoDesk.git
cd TodoDesk
make app
open .build/TodoDesk.app
```

The build uses `clang`, Foundation, and Cocoa. It does not require SwiftPM or a full Xcode project.

## Install

Build the app, then copy it to Applications:

```bash
make app
cp -R .build/TodoDesk.app /Applications/
open /Applications/TodoDesk.app
```

The generated app bundle is ad-hoc signed for local use.

## Data Location

By default, TodoDesk stores data at:

```text
~/Library/Application Support/TodoDesk/tasks.json
```

Inside the app, use `檔案 > 打開資料夾` to open the data folder.

For development or testing, override the data file path:

```bash
TODODESK_STORE_PATH=/tmp/tododesk-tasks.json open .build/TodoDesk.app
```

This is useful when you want to try the app without touching your real task data.

## Testing

```bash
make test
```

## Packaging

```bash
make app
codesign --verify --deep --strict --verbose=4 .build/TodoDesk.app
```

## Keyboard Shortcuts

- `Cmd+N`: focus the add-task field
- `Tab`: move through add-task title, hours, minutes, and add button
- `Enter`: rename the selected task
- `Space`: start, pause, or resume the selected task timer
- `Delete`: delete the selected task
- `Cmd+1` to `Cmd+9`: switch tabs

## Troubleshooting

If Finder says there is no application set to open `TodoDesk.app`, rebuild the app:

```bash
make clean
make app
open .build/TodoDesk.app
```

If macOS blocks the app because it was downloaded from the internet, open `System Settings > Privacy & Security` and allow TodoDesk, or right-click the app and choose `Open`.

## License

MIT
