# Espresso ☕

[![CI](https://github.com/panchr/espresso/actions/workflows/ci.yml/badge.svg)](https://github.com/panchr/espresso/actions/workflows/ci.yml)

A tiny macOS menubar app that keeps your Mac awake — a modern replacement for
the classic Caffeine app, built natively on top of macOS's own `caffeinate`
tool.

## Install

With [Homebrew](https://brew.sh):

```sh
brew install --cask panchr/tap/espresso
```

Or without it — same result, no dependencies:

```sh
curl -fsSL https://raw.githubusercontent.com/panchr/espresso/main/install.sh | bash
```

Either way you get the latest release, checksum-verified, in `/Applications`.
Requires macOS 13 or later; Apple silicon and Intel are both supported.

To uninstall, `brew uninstall --cask espresso`, or:

```sh
curl -fsSL https://raw.githubusercontent.com/panchr/espresso/main/install.sh | bash -s -- --uninstall
```

<details>
<summary>Other ways to install</summary>

**Download manually.** Grab `Espresso.zip` from the
[latest release](https://github.com/panchr/espresso/releases/latest), unzip it
into `/Applications`, then clear the quarantine flag your browser set:

```sh
xattr -dr com.apple.quarantine /Applications/Espresso.app
```

Espresso is ad-hoc signed rather than notarized — shipping a notarized build
requires a paid Apple Developer account — so Gatekeeper refuses to launch a
browser-downloaded copy until that flag is gone. (The installer above uses
`curl`, which never sets the flag in the first place.)

**Build from source.** Requires a Swift toolchain (Xcode or the Command Line
Tools):

```sh
git clone https://github.com/panchr/espresso.git
cd espresso
make install
```

</details>

## Usage

- **Left-click** the cup for a panel showing the current state and duration
  options: 30m, 1h, 2h, 4h, or ∞. Pick one to keep the Mac awake; **Clear**
  ends the session early, and **Quit** exits Espresso.
- **Right-click** for Clear, Settings, and Quit. **Settings** holds Start at
  Login and the lid-close behavior below.
- While a session is active, the menubar shows a live countdown next to a
  filled cup (or ∞ for indefinite sessions).
- Closing the laptop lid ends the session, so a docked Mac doesn't sit awake
  unattended. Turn it off under **Settings** if you'd rather sessions survive
  a lid close. (Macs without a lid don't report one, so the option is inert
  there.)

> Heads up: if your menubar is full, macOS hides new icons under the notch
> with no indication. Free up a slot (e.g. hide a Control Center module) and
> the cup will appear.

## How it works

Espresso doesn't manage power assertions itself. Each session simply runs the
system's `caffeinate` command (preventing both display and idle sleep) as a
child process, and clearing a session terminates it.

The child process also watches Espresso itself and exits if the app dies for
any reason, and timed sessions additionally have their timeout enforced by
`caffeinate` — so a crashed or force-killed Espresso can never leave your Mac
stuck awake. Quitting the app ends any active session.

## Changelog

### v0.2

- Closing the laptop lid now ends an active session, so a docked Mac doesn't
  sit awake unattended. On by default; turn it off in Settings.
- New Settings window, opened from the right-click menu. **Start at Login**
  moved here from that menu, so every preference lives in one place.

### v0.1.3

- Only a copy installed in an Applications directory can claim the Start at
  Login registration, so a development build no longer steals it during a
  `brew upgrade`.

### v0.1.2

- The right-click menu names the running version and commit, so a bug report
  can quote the exact build.

### v0.1.1

- Start at Login survives app upgrades, which previously dropped the
  registration silently.
- Added a Quit button to the popover panel.

### v0.1

Initial release: menubar app, timed and indefinite sessions, live countdown,
universal binary, Homebrew cask, and a one-line installer.

## Development

```sh
make build    # release build
make test     # unit tests
make app      # assemble Espresso.app
make run      # run the raw binary
```

Cutting a release is a tag push — CI builds a universal binary, bundles it, and
publishes the archive plus its checksum:

```sh
git tag v0.1 && git push origin v0.1
```

## Built with Claude

Espresso was written end to end with [Claude Code](https://claude.com/claude-code)
— design, implementation, tests, packaging, and this README. `CLAUDE.md` holds
the working context for that, and is worth reading if you want the reasoning
behind the odd corners (why the tests are a plain executable target, why the
`caffeinate` child watches the app's pid).

The parts a language model can't check itself were checked by hand: the menubar
UI is driven manually and its power assertions confirmed with `pmset -g
assertions`. `EspressoCore` is covered by unit tests that run in CI.

## License

MIT — see [LICENSE](LICENSE).
