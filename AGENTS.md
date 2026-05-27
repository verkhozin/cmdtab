# AGENTS.md — cmdtab

Working notes for any AI agent (or human) editing this repo. Read this before
touching code. Idea spec lives in [cmdtab.md](cmdtab.md).

## What this app is

A menu-bar macOS utility that replaces (rather, runs alongside) the system
Cmd+Tab switcher. Apps are organised into user-defined groups ("Dev",
"Comms", …); the user toggles a switcher overlay via a global hotkey, picks
an app within the active group, and the chosen app is brought to the front.

**Minimum OS: macOS 26.0** (Liquid Glass — see decision below).

Default hotkey is **Option+Tab** — coexists with the system Cmd+Tab on
purpose. Replacing Cmd+Tab itself requires Accessibility tricks and is
explicitly out of scope for the MVP.

## Build & run

The project is generated from [project.yml](project.yml) by **XcodeGen**
(`brew install xcodegen`). The `.xcodeproj` is gitignored — never edit it
by hand.

```bash
xcodegen generate
xcodebuild -project cmdtab.xcodeproj -scheme cmdtab -configuration Debug build
xcodebuild -project cmdtab.xcodeproj -scheme cmdtab test
open cmdtab.xcodeproj
```

When you add or rename a Swift file, just put it under `Sources/` (or `App/`)
and rerun `xcodegen generate`. The `sources:` entry is folder-based so new
files are picked up automatically.

## Layout

```
App/                       @main entry, AppDelegate, Info.plist, entitlements
Sources/
  Core/                    Hotkey + activation + permissions (AppKit, Carbon, AX)
  Models/                  AppEntry, AppGroup, GroupsStore (Codable, persisted)
  RunningApps/             NSWorkspace observers, icon cache
  Switcher/                Borderless NSPanel, SwiftUI overlay, ViewModel, Coordinator
  Settings/                SwiftUI Settings scene (Groups / Hotkey / Appearance tabs)
  MenuBar/                 NSStatusItem controller
Resources/
  Assets.xcassets          App icon
  default-groups.json      Seed groups, copied to Application Support on first run
Tests/cmdtabTests/         XCTest target
```

Layering rule: `Switcher/` and `Settings/` may import from `Models/`,
`RunningApps/`, and `Core/` — never the reverse. `Models/` has zero AppKit
imports beyond what `AppEntry` strictly needs (it uses `NSRunningApplication`
in its convenience init only).

## Architectural decisions (and why)

These have non-obvious reasons. **Do not change them without re-reading the
reasoning here.**

### Hotkey: Carbon `RegisterEventHotKey`, not CGEventTap or NSEvent monitor
- `RegisterEventHotKey` is the only API that registers a global hotkey
  *without* requiring Accessibility permission. Apple's own apps use it.
- `CGEventTap` requires Accessibility, intercepts the entire keyboard
  stream, and is observably heavier — overkill for one chord.
- `NSEvent.addGlobalMonitorForEvents` cannot consume the event, so the
  original key combo still propagates.

### Switcher window: `NSPanel` with `.nonactivatingPanel`
- `.nonactivatingPanel` lets the panel become key without stealing focus
  from the previously-active app's text input — essential for a switcher.
- `.floating` level + `.canJoinAllSpaces` so it appears over fullscreen
  apps and any Space.
- `canBecomeKey` must be overridden to `true` (NSPanel returns false by
  default for borderless panels) — without it, SwiftUI key handlers do
  nothing.

### App activation: `NSRunningApplication.activate()` (no options)
- The `.activateIgnoringOtherApps` option is deprecated in macOS 14 and
  has no effect. Plain `activate()` is correct.
- For raising a *specific window* of an app (post-MVP), use the AX API:
  `AXUIElementCreateApplication` → `AXWindows` → `AXRaise`. This is the
  feature gated on the `NSAccessibilityUsageDescription` prompt.

### Switcher chrome: Liquid Glass (macOS 26+)
- Deployment target is **macOS 26.0** specifically so we can use
  `.glassEffect(...)` and `GlassEffectContainer`. Don't downgrade unless
  you're prepared to fall back to `.ultraThinMaterial` everywhere — they
  do not look or behave the same.
- The selected cell uses `.glassEffect(.regular.tint(...).interactive(), in:)`
  inside a `GlassEffectContainer`, which makes the highlight morph into
  the panel rather than stack as a separate layer.
- All glass shapes inside the switcher must share one
  `GlassEffectContainer` — separate containers won't morph into each
  other.

### Persistence: JSON in Application Support, not UserDefaults
- Groups are user-curated structured data, may grow, and benefit from
  being human-editable for power users. `~/Library/Application Support/cmdtab/groups.json`.
- `UserDefaults` is fine for tiny scalar prefs (hotkey codes, toggles)
  but not for the group list.

### `LSUIElement = YES` + accessory activation policy
- The app is menu-bar-only; we don't want a Dock tile or a main window.
- The Settings scene is opened explicitly via the status item; SwiftUI's
  `Settings { ... }` scene plays nicely with this.

### Sandboxing: **off**
- Activating an arbitrary third-party app by bundle id (`NSWorkspace.openApplication`)
  works under the sandbox, but enumerating other apps' running state and
  raising specific windows via AX requires the app to be unsandboxed.
- Hardened runtime stays **on** for distribution. Sandbox stays off.

## Concurrency

- Strict concurrency is on (`SWIFT_STRICT_CONCURRENCY=complete`). Don't
  silence warnings — fix them.
- AppKit objects (`NSWorkspace`, `NSWindow`, `NSPanel`, `NSStatusItem`)
  are main-actor-only. Coordinators/managers that own them are
  `@MainActor`. Models that don't touch UIKit/AppKit are `Sendable`
  value types.

## What to do / not do

### Do
- Use **dependency injection** for the coordinators (see `AppDelegate`).
  Singletons are reserved for genuinely global caches like `AppIconLoader.shared`.
- Add a unit test for any model logic with branching (group cycling,
  candidate filtering, hotkey decoding).
- Run `xcodebuild ... build` after non-trivial edits — the strict
  concurrency checker catches subtle issues SwiftUI previews miss.
- Keep `Models/` free of AppKit. The single exception (`AppEntry`'s
  `NSRunningApplication` init) is deliberate; don't widen it.
- Update `project.yml` (not the `.xcodeproj`) when changing target
  config. Regenerate with `xcodegen generate` and commit `project.yml`
  only.
- Comment **why**, not what. The "why" lines in `HotkeyManager.swift`,
  `SwitcherWindow.swift`, and `AppActivator.swift` are the model.

### Don't
- Don't silently suppress the deprecation of `activateIgnoringOtherApps`
  by adding `@available` shims — just call `activate()`.
- Don't add a SwiftUI `WindowGroup` for the switcher overlay. SwiftUI
  windows can't get the borderless / non-activating / floating combo we
  need; that's why the switcher uses `NSPanel` + `NSHostingView`.
- Don't add `CGEventTap`-based hotkey handling "for power" — see above.
- Don't enable App Sandbox. It will break window activation across apps.
- Don't switch persistence to SwiftData / Core Data. JSON is enough and
  keeps the file user-editable.
- Don't use force-unwrap (`!`) on `NSRunningApplication.bundleIdentifier`,
  on dictionaries from `urlForApplication`, or on AX results — every
  one of these can legitimately be `nil` (helper apps, daemons, missing
  permissions).
- Don't introduce a third-party global-hotkey library (HotKey, Magnet,
  KeyboardShortcuts) for the MVP. The Carbon wrapper in `HotkeyManager`
  is ~50 lines and self-contained.

## Permissions matrix

| Feature                                  | Permission             | When prompted                                  |
|------------------------------------------|------------------------|------------------------------------------------|
| Global hotkey (Option+Tab)               | none                   | never                                          |
| List running apps, activate by bundle id | none                   | never                                          |
| Raise a specific window of an app (AX)   | Accessibility          | First time the user opts in (post-MVP feature) |
| Apple Events to scripted apps            | Automation             | First scripted activation                      |

The Info.plist already declares `NSAccessibilityUsageDescription` and
`NSAppleEventsUsageDescription` so the system can prompt cleanly.

## Coding style

- Swift 5.10, four-space indent (Xcode default).
- `final class` everywhere except SwiftUI views and `XCTestCase`.
- Prefer `struct` for value types and DTOs.
- Access control: lean on `private` / `private(set)` aggressively;
  expose the minimum.
- File names match the primary type: `SwitcherWindow.swift` exposes
  `SwitcherWindow`. One top-level type per file unless the helpers are
  trivially small (e.g. `AppIconCell` lives next to `SwitcherView`).
- All identifiers, comments, log strings, and commit messages are
  English-only.

## Testing

The `cmdtabTests` target uses XCTest. Tests touching `GroupsStore` must be
`@MainActor`. We don't have UI tests yet — when adding them, gate them
behind the Accessibility prompt locally; CI cannot grant that permission.

## Roadmap signal

When picking up MVP/feature work, prefer the order in [cmdtab.md](cmdtab.md):

1. Hotkey-triggered switcher (one default group). ← scaffolded
2. JSON-defined groups, group cycling. ← scaffolded
3. Settings UI for editing groups (drag-and-drop apps in / out).
4. Appearance tab: icon size, blur strength, position on screen.
5. Per-window switching via AX (raise specific window).
6. Drag-and-drop windows between apps in the switcher overlay.

Anything beyond #6 is product expansion, not MVP.
