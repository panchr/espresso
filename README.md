# Espresso ☕

A tiny macOS menubar app that keeps your Mac awake — a modern replacement for
the classic Caffeine app, built natively on top of macOS's own `caffeinate`
tool.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/panchr/espresso/main/install.sh | bash
```

This downloads the latest release, verifies its checksum, installs it to
`/Applications`, and launches it. Requires macOS 13 or later; Apple silicon and
Intel are both supported.

To uninstall:

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
  ends the session early.
- **Right-click** for Clear, Start at Login, and Quit.
- While a session is active, the menubar shows a live countdown next to a
  filled cup (or ∞ for indefinite sessions).

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
git tag v1.0.0 && git push origin v1.0.0
```

## License

MIT — see [LICENSE](LICENSE).
