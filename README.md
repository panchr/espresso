# Espresso ☕

A tiny macOS menubar app that keeps your Mac awake — a modern replacement for
the classic Caffeine app, built natively on top of macOS's own `caffeinate`
tool.

## Usage

- **Left-click** the cup for a panel showing the current state and duration
  options: 30m, 1h, 2h, 4h, or ∞. Pick one to keep the Mac awake; **Clear**
  ends the session early.
- **Right-click** for Clear, Start at Login, and Quit.
- While a session is active, the menubar shows a live countdown next to a
  filled cup (or ∞ for indefinite sessions).

## How it works

Espresso doesn't manage power assertions itself. Each session simply runs the
system's `caffeinate` command (preventing both display and idle sleep) as a
child process, and clearing a session terminates it.

For timed sessions, the timeout is enforced by `caffeinate` itself — so even
if Espresso crashes, the wake-lock expires on schedule and your Mac never gets
stuck awake. Quitting the app ends any active session.

## Install

Requires macOS 13+ and a Swift toolchain (Xcode Command Line Tools).

```sh
make install
```

This builds `Espresso.app` and copies it to `/Applications`. Launch it, then
right-click the cup and enable **Start at Login** if you want it always
available.

> Heads up: if your menubar is full, macOS hides new icons under the notch
> with no indication. Free up a slot (e.g. hide a Control Center module) and
> the cup will appear.
