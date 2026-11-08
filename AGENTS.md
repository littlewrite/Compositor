# Notes for AI agents

Compositor is an image editor for compositing and photo work: a Mac app written in SwiftUI and AppKit, and an iOS app for iPhone and iPad written in UIKit. Both present the same core in `Compositor/` (Swift, with some C for pixel work).

## Designing or editing a Compositor project

If you've been asked to make or change an image in a `.comp` project, you don't need the app's source code. Read [docs/writing-comp-files.md](docs/writing-comp-files.md): it covers the file format, the rules that make a project load, and how to write it safely while it's open, so the person can watch the canvas update as you work.

## Working on the app itself

- Build: open `Compositor.xcodeproj` and run the **Compositor** scheme, or `xcodebuild -project Compositor.xcodeproj -scheme Compositor -destination 'platform=macOS' build`.
- Tests: `CompositorTests` on macOS, `CompositorMobileTests` on the iOS simulator. CI runs the Mac suites on every push.
- Match the surrounding code: its naming, its comment style and density.
- American spelling in code, comments and UI ("color", not "colour").
- The project file format is described in [docs/project-format.md](docs/project-format.md). A change to what's saved means a format version bump there and in `ProjectManifest.current`.

## Working pace

The project is in a fast-iteration phase: prefer a larger batch of changes followed by one verification pass over building or testing after every edit. Add test cases and tighten suites once the feature has settled.

- Run only the suites that cover what changed (`-only-testing:CompositorTests/<Suite>`, `CompositorMobileTests/<Suite>`). Run everything, or at least every suite the handoff touches, before reporting work done.
- Reuse build products across runs: `xcodebuild build-for-testing` once, then `test-without-building`.
- Keep one simulator running: one iPad, plus one iPhone when checking the phone. Layout is chosen in code from the window size (`CompositorMobile/Window/LayoutContext.swift`) and layout tests set their own window frames, so the same suites do not need running on several devices or sizes.
- The long suites (the filter suites, `ProjectTests`) run in CI, which splits them across processes with `scripts/ci-tests.sh`.

## Shared code and the two UIs

- Behavior belongs in `Compositor/`; the SwiftUI and UIKit layers present it. When the Mac app already has a rule a mobile screen needs, move the rule into a shared value type and have both use it — never retype it in the second UI.
- A feature is done when both UIs use the same rule. Where one UI still copies another (the canvas compositor, the layer-list menus, command availability), prefer moving the shared home over extending the copy.
- New controllers take the session and their services as parameters from a composition root and avoid singletons. Keep rules — layout decisions, control tables, command availability, validity checks — in plain value types a test can exercise without a window or simulator.
- Layout follows the measured window size, not the device: `LayoutContext` maps a window's size to a shell, and its breakpoints are design constraints (the canvas keeps at least 480 points), not per-device numbers. New thresholds belong there, with a test.
- Say "the iOS app" for behavior that holds on both iPhone and iPad, and name a device only where the two differ — in code, comments and UI strings alike.
- A comment states the rule, not the history. "For now" is allowed only with the condition that removes it; never leave a comment describing a design the code no longer has.
