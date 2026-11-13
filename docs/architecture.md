# Architecture

```
Claude Code ──► usage_bridge ──► JSON records ──► widget
               (status line)    (<claude config>/usage-widget)
```

## The bridge (`bridge/`)

Claude Code runs the bridge as its status line command and pipes session data
to it. The bridge adds three bookkeeping fields (`written_at`, `day`,
`day_base_cost`), writes one file per session through a temp file and a rename,
deletes records older than 7 days, prints a short status line and always
exits 0. `day_base_cost` is the session's cost when the day began, so "today"
means spend since midnight.

## The app (`lib/`)

| Layer | Folder | Job |
|---|---|---|
| Config | `config/` | Constants, logger |
| Domain | `domain/` | `UsageSnapshot` (sealed: none, subscription, gateway, API), `SessionRecord`, `AggregateUsage`, `AlertPolicy`. Pure Dart: no I/O, no Flutter UI |
| Data | `data/` | Services wrap files, window, tray, autostart, notifications, settings. Mappers and repositories turn them into domain models |
| UI | `ui/` | `UsageWidgetCubit` holds one immutable state; views only draw it |

Dependencies point inwards only: `ui → data → domain → config`.
`test/architecture_test.dart` fails the build if an import breaks that rule.

### Patterns in use

| Pattern | Where | Why |
|---|---|---|
| Composition root | `app_dependencies.dart` | One place chooses concrete classes and per-OS implementations |
| Dependency injection | Every constructor | Collaborators are passed in, so tests use fakes |
| Repository | `UsageRepository`, `StatusLineRepository` | Hide where data comes from |
| Mapper | `SessionRecordMapper` | Keeps the JSON wire format out of the domain |
| Strategy | `NotificationService`, `AutostartService` per OS | New platform means a new class, not a new `if` |
| Template method | `CommandNotificationService` | Shared error handling; subclasses name the command |
| State + observer | `UsageWidgetCubit` with `flutter_bloc` | One immutable state, views rebuild on change |
| Sealed type | `UsageSnapshot` | The compiler finds every `switch` a new account type must handle |
| Interface segregation | `SettingsActions` | The settings view sees eight actions, not the whole cubit |

## Merging sessions

Every open Claude Code session reports the account's limits, but each may hold
an older snapshot, and idle sessions keep rewriting theirs. So the newest file
is not the freshest data. `AggregateUsage` takes the latest limit window and
the highest percentage seen for it, since usage only grows within a window.

## Window and motion

The card springs between three shapes. The native window is not resized per
frame: it grows to fit both shapes, the card animates inside, then the window
shrinks. The window is larger than the card by `WidgetLayout.shadowMargin` so
the shadow is never clipped.
