# Contributing

Thanks for helping make TodoDesk better.

## Setup

Requirements:

- macOS 13 or later
- Xcode Command Line Tools

```bash
xcode-select --install
make test
make app
open .build/TodoDesk.app
```

## Development Workflow

1. Create a branch from `main`.
2. Keep changes focused and aligned with the existing Objective-C/AppKit style.
3. Put pure task logic in `Sources/TodoDeskCore/` when possible.
4. Add or update `Tests/TodoDeskCoreTests/TodoDeskCoreTests.m` for core behavior changes.
5. Run the verification checklist before opening a pull request.

## Verification

```bash
make test
make app
codesign --verify --deep --strict --verbose=4 .build/TodoDesk.app
git diff --check
```

## Data Safety

TodoDesk stores real user data at:

```text
~/Library/Application Support/TodoDesk/tasks.json
```

Use a temporary store while testing:

```bash
TODODESK_STORE_PATH=/tmp/tododesk-dev-tasks.json open .build/TodoDesk.app
```

Do not include personal task data, private screenshots, `.build/`, `.DS_Store`, `DerivedData/`, or generated local files in commits.

## Pull Requests

Please include:

- a short description of the user-facing change
- test commands run and their results
- screenshots or notes for UI changes when helpful
- any data migration concerns

## Project Style

- Interface text is currently Traditional Chinese.
- The task row height should stay compact and stable.
- Add-task keyboard flow should remain title -> hours -> minutes -> add button.
- The pencil task details flow should work for both main tasks and subtasks.
