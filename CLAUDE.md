# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:7510c1e2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->


## Build & Test

```bash
make build    # swift build -c release
make test     # unit tests: swift run EspressoCoreTests (custom harness, see below)
make app      # assemble Espresso.app bundle (Info.plist + binary, ad-hoc signed)
make install  # copy Espresso.app to /Applications (canonical copy for Login Items)
make run      # run the raw binary for quick iteration
```

**Tests are a plain executable target, not a `.testTarget`.** This machine has
Command Line Tools only — XCTest isn't shipped and the CLT's Swift Testing
integration is broken (no `xctest` harness to load `.xctest` bundles,
`_Testing_Foundation` ships without its Swift module, runner discovers zero
tests). `Tests/EspressoCoreTests` uses a ~40-line harness (`TestHarness.swift`:
`test`/`expect`/`require`/`eventually`). Don't convert to `.testTarget` unless
building with full Xcode. Unit tests cover `EspressoCore` only, substituting
stub scripts for `caffeinate` so tests never hold real power assertions.

The AppKit layer is verified manually: launch the app, drive the menubar UI,
and confirm `caffeinate` children/assertions via `ps` and `pmset -g assertions`
(attribute caffeinate processes by ppid — other tools also spawn caffeinate).

## Architecture Overview

Menubar-only AppKit app (SwiftPM executable, no Xcode project; `.accessory`
activation policy + `LSUIElement`).

Two targets: `EspressoCore` (testable logic, no AppKit) and the `Espresso`
executable (UI).

- `Sources/EspressoCore/CaffeinateController.swift` — single source of truth
  for the keep-awake session; spawns `caffeinate -di [-t secs]` as a child
  process (executable injectable for tests) and reports expiry via callback
- `Sources/EspressoCore/Countdown.swift` — pure remaining-time formatter
- `Sources/Espresso/main.swift` — entry point; wires NSApplication + delegate
- `Sources/Espresso/AppDelegate.swift` — owns the NSStatusItem: left-click
  opens an NSPopover (SwiftUI panel), right-click shows an NSMenu (Clear /
  Start at Login / Quit), and a 1s timer renders the countdown in the menubar
- `Sources/Espresso/StatusPanelView.swift` — SwiftUI popover content +
  `SessionModel` (ObservableObject bridging app state into the view)

**Core design decision**: all power management is delegated to the `caffeinate`
child process. The child runs with `-w <app pid>` so it exits when Espresso
dies (even SIGKILL — graceful-quit cleanup alone misses SIGTERM/crash, which
orphans the child), and timed sessions also pass `-t`; caffeinate honors
whichever fires first (verified empirically). A dead app can never leave the
Mac stuck awake. Clearing/quitting terminates the child directly.

## Conventions & Patterns

- State flows one way: `CaffeinateController` → `sessionChanged()` →
  `SessionModel` + status item refresh. Don't mutate UI state elsewhere.
- The status item uses the assign-menu-then-`performClick` trick so left and
  right clicks can do different things; the menu is detached in `menuDidClose`.
- `statusItem.autosaveName` is set ("EspressoStatusItem") so the user's
  menubar position persists; don't remove it.
- macOS 26 gotcha: when the menubar is full, ControlCenter parks new status
  items under the notch with no overflow UI — an "invisible icon" is usually
  crowding, not a bug. Third-party items don't appear under the app's own pid
  in CGWindowList; they're hosted by ControlCenter.
- Comment only the non-obvious "why"; keep views/state bridging minimal.
