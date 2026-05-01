# TodoDesk Productivity Controls Design

## Goal

Add the next layer of day-to-day productivity controls while keeping TodoDesk minimal: full subtask parity, rename, collapsible subtasks, controllable timers, keyboard shortcuts, search, daily review, and local backup/import-export.

## Product Direction

TodoDesk should stay a small, fast desktop utility rather than become a heavy project manager. The app will continue to show task blocks in a simple vertical list, with the main interactions reachable from keyboard, right-click menu, or compact inline controls. Subtasks remain one level deep: a main task may contain subtasks, and subtasks get the same task-level operations, but subtasks do not create nested sub-subtasks.

## Feature Design

### Subtask Parity

Subtask blocks support the same core task features as main tasks: complete/uncomplete, delete, rename, reorder within the visible list, estimated time, timer start/pause/resume/cancel, and swipe actions. When the user triggers "add subtask" from a subtask, TodoDesk adds a sibling under the same main task instead of nesting another level.

### Rename

Double-click remains completion toggle. Rename is exposed through `Enter` on the selected task and through a right-click menu item named `重新命名`. The first version uses a small modal text field, matching the existing add-list and add-subtask prompt style. Empty names are ignored.

### Collapsible Subtasks

Main tasks with subtasks show a small disclosure arrow on the left edge of the block. Clicking it collapses or expands the subtasks. Collapse state is UI preference state, stored in `NSUserDefaults`, not in `tasks.json`, because it should not change the user's data model or backups. Search temporarily expands matching parents so results are not hidden.

### Timer Pause / Resume / Cancel

Timers move from a deadline-only model to a small runtime state per task:

- `running`: stores a deadline date.
- `paused`: stores remaining seconds.
- no state: idle.

The block button starts a timer when idle, pauses when running, and resumes when paused. A right-click menu item cancels any active or paused timer. The remaining time stays visible beside the title while running or paused. Notifications are scheduled only for running timers; pausing/canceling removes pending notifications for that task and resume schedules a fresh one.

### Keyboard Shortcuts

- `Cmd+N`: focus the add-task field.
- `Delete`: delete selected task.
- `Enter`: rename selected task.
- `Space`: start/pause/resume selected task timer when the selected task has an estimate.
- `Cmd+1` through `Cmd+9`: switch to the matching visible tab, excluding the `+` button.

### Search

Add a compact search field in the bottom bar beside the add controls. It filters the current tab or custom list. Matching is case-insensitive and checks task titles. If a parent matches, the parent and all its children show. If a subtask matches, the parent and the matching subtask show.

### Daily Review

The `過往未完成` tab gets a compact `搬返今日` button. It moves all visible overdue incomplete today tasks back to today's date. If search is active, it moves the filtered visible overdue tasks only. Subtasks move with their parent when both are overdue; orphaned visible subtasks can also be moved.

### Backup / Export

Add local JSON export and import through app menu items:

- `匯出 JSON...`: writes the current TodoDesk database JSON to a user-selected file.
- `匯入 JSON...`: reads a TodoDesk JSON file, replaces current in-app data, saves it, and refreshes the UI.

Import is user-selected local file access, not cloud sync. The imported format is the same `version/lists/tasks` JSON used by the app store.

## Architecture

The core model remains `TDTodoTask`, `TDCustomList`, and `TDTodoList`. Rename, daily review, filtering, and subtask sibling behavior belong in `TDTodoList` so they are testable without AppKit. UI-only concerns such as collapse state, keyboard handling, timer runtime state, menu items, and panels remain in `TDAppDelegate` and `TDTaskCellView`.

Timer state should be represented in the app layer because it is transient and should not persist across app restarts in this version. Export/import should use `TDTaskFileStore` helpers so the app does not duplicate JSON serialization rules.

## Testing

Unit tests should cover:

- Renaming ignores blank names and stores nonblank names.
- Adding a subtask from an existing subtask creates a sibling under the root parent.
- Collapsed/filter behavior returns parent-child results correctly through pure filtering helpers where possible.
- Moving overdue tasks back to today updates due dates without touching custom tasks.
- JSON import/export round trips the full `version/lists/tasks` database.

Manual smoke testing should cover:

- Enter rename, Space timer control, Cmd+N, Delete, and Cmd+number tabs.
- Disclosure arrow collapse/expand.
- Search parent match and subtask match.
- Daily review button in `過往未完成`.
- Export then import JSON.
