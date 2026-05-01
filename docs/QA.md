# QA

Use this checklist before publishing changes or telling someone the app is ready.

## Automated Checks

GitHub Actions runs the automated CI checklist on pushes to `main`, pull requests, and manual dispatches.

```bash
git status --short --branch
make test
make app
codesign --verify --deep --strict --verbose=4 .build/TodoDesk.app
git diff --check
```

Expected signals:

- `make test` prints `TodoDeskCoreTests passed`.
- `make app` prints `Built .../.build/TodoDesk.app`.
- `codesign --verify` exits successfully and reports the bundle is valid.
- `git diff --check` prints nothing.

Run `codesign --verify` immediately after building. Finder, `open`, `GetFileInfo`, and other metadata inspection tools may add extended attributes on some machines.

If strict verification fails with `Disallowed xattr com.apple.FinderInfo`, rebuild with `make app` and verify again before opening or inspecting the bundle.

## Clean Clone Smoke Test

From a fresh checkout:

```bash
git clone https://github.com/0xScot/TodoDesk.git
cd TodoDesk
make test
make app
open .build/TodoDesk.app
```

Confirm the app opens without requiring files outside the repo.

## Safe Data Smoke Test

Use a temporary store so QA does not touch personal task data:

```bash
rm -f /tmp/tododesk-qa-tasks.json
TODODESK_STORE_PATH=/tmp/tododesk-qa-tasks.json open .build/TodoDesk.app
```

Manual checks:

- Add a main task with title, hours, and minutes using only `Tab` between fields.
- Confirm focus returns to the title field after adding.
- Add a description through the pencil button and confirm the task block height does not grow.
- Edit estimated time through the pencil button.
- Complete the task and confirm completion time appears inline between the estimate and pencil area without resizing the block.
- Add a subtask and repeat description/time editing.
- Start, pause, resume, and cancel a timer for a task with estimated minutes.
- Drag tasks within Today or a custom list and confirm order persists after restart.
- Use `檔案 > 打開資料夾` and confirm the temporary data folder opens.

## Data Migration Check

If persistence changes, test both:

- current `version: 2` JSON with lists and tasks
- legacy root array JSON

Legacy custom tasks without a `listID` should be assigned to a default custom list named `自定義`.

## Packaging Check

After `make app`, inspect:

```bash
plutil -p .build/TodoDesk.app/Contents/Info.plist
ls -la .build/TodoDesk.app/Contents
```

Confirm:

- `CFBundlePackageType` is `APPL`
- `CFBundleIdentifier` is `io.github.0xscot.tododesk`
- `LSMinimumSystemVersion` is `13.0`
- `Contents/PkgInfo` exists
- `Contents/MacOS/TodoDesk` is executable

## Known Limits

- The app is ad-hoc signed for local use, not notarized for public binary distribution.
- UI tests are manual for now; core rules are covered by the standalone test binary.
