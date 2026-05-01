# AGENTS.md

永遠使用繁體中文回應使用者。

## Project Snapshot

TodoDesk is a native macOS AppKit app written in Objective-C. It is local-first, stores tasks as JSON, and currently uses Traditional Chinese interface text.

Repository: `https://github.com/0xScot/TodoDesk`

## Fast Start

```bash
make test
make app
open .build/TodoDesk.app
```

Before claiming a change is complete, run:

```bash
make test
make app
codesign --verify --deep --strict --verbose=4 .build/TodoDesk.app
```

Run the `codesign` verification immediately after `make app`; Finder, manual app opening, `GetFileInfo`, and other metadata inspection tools may add extended attributes on some machines.

## Source Map

- `Sources/TodoDeskCore/`: Foundation-only domain model, persistence, formatting, and testable task logic.
- `Sources/TodoDeskApp/`: AppKit UI, menus, timers, notifications, keyboard handling, drag-and-drop, and window wiring.
- `Tests/TodoDeskCoreTests/`: lightweight Objective-C test binary for core behavior.
- `scripts/build-app.sh`: builds `.build/TodoDesk.app`, writes `Info.plist`/`PkgInfo`, copies the icon, and ad-hoc signs the bundle.
- `scripts/test.sh`: compiles and runs the Foundation-only core tests.
- `Assets/`: source app icon assets.
- `docs/`: architecture, QA, and planning notes.

## Data Safety

Default task data lives outside the repo:

```text
~/Library/Application Support/TodoDesk/tasks.json
```

For development, QA, and automated agents, use a temporary data path:

```bash
TODODESK_STORE_PATH=/tmp/tododesk-agent-tasks.json open .build/TodoDesk.app
```

Never commit real task data, local app data, build outputs, generated plist analyzer files, or screenshots with private content.

## Coding Guidelines

- Keep behavior changes small and close to the existing Objective-C/AppKit style.
- Prefer putting business rules in `Sources/TodoDeskCore/` when possible, then cover them in `Tests/TodoDeskCoreTests/`.
- Keep `Sources/TodoDeskApp/` focused on UI, event handling, timers, notifications, and persistence calls.
- Do not introduce SwiftPM, CocoaPods, or an Xcode project unless the user explicitly asks for a packaging migration.
- Use `NSTimeZone.localTimeZone` and `NSLocale.currentLocale` for user-facing time behavior unless a test needs a fixed calendar.
- Keep task rows compact: task descriptions and completion timestamps should not increase the task block height.
- Keep add-task keyboard flow as title -> hours -> minutes -> add button -> title.
- The pencil/details flow should support both main tasks and subtasks, including estimated time edits.

## Generated And Ignored Files

Do not commit:

- `.build/`
- `.DS_Store`
- `DerivedData/`
- `Assets/AppIcon.iconset/`
- `*.plist` analyzer or local generated plist files outside the app bundle
- `findings.md`, `progress.md`, `task_plan.md`
- `.gstack/`
- private screenshots or local task data

## GitHub Notes

The repository is public on GitHub. GitHub Actions CI lives at `.github/workflows/ci.yml` and runs `make test`, `make app`, strict code-sign verification, and `plutil` validation on macOS.

## Release Checklist

1. `git status --short --branch`
2. `make test`
3. `make app`
4. `codesign --verify --deep --strict --verbose=4 .build/TodoDesk.app`
5. Review `git diff --check`
6. Confirm docs match behavior if user-facing behavior changed.
7. Commit and push.

If strict code-sign verification fails with `Disallowed xattr com.apple.FinderInfo`, rebuild with `make app` and run verification again before opening or inspecting the bundle with Finder-oriented tools.
