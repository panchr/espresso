#!/bin/bash
#
# Espresso installer.
#
#   curl -fsSL https://raw.githubusercontent.com/panchr/espresso/main/install.sh | bash
#
# Downloads the latest released Espresso.app, verifies its checksum, and
# installs it to /Applications. Overrides:
#
#   ESPRESSO_VERSION=v1.2.3   install a specific tag instead of the latest
#   ESPRESSO_INSTALL_DIR=...  install somewhere other than /Applications
#
# Uninstall with:
#
#   curl -fsSL https://raw.githubusercontent.com/panchr/espresso/main/install.sh | bash -s -- --uninstall

set -euo pipefail

REPO="${ESPRESSO_REPO:-panchr/espresso}"
VERSION="${ESPRESSO_VERSION:-latest}"
INSTALL_DIR="${ESPRESSO_INSTALL_DIR:-/Applications}"
APP_NAME="Espresso.app"
ASSET="Espresso.zip"
MIN_MACOS_MAJOR=13

if [ -t 1 ]; then
	BOLD=$'\033[1m'; BLUE=$'\033[1;34m'; YELLOW=$'\033[1;33m'; RED=$'\033[1;31m'; RESET=$'\033[0m'
else
	BOLD=""; BLUE=""; YELLOW=""; RED=""; RESET=""
fi

# The scratch dir is global so the EXIT trap can still see it after main
# returns and its locals go out of scope.
WORKDIR=""
cleanup() { [ -n "$WORKDIR" ] && rm -rf "$WORKDIR"; return 0; }
trap cleanup EXIT

log() { printf '%s==>%s %s\n' "$BLUE" "$RESET" "$*"; }
warn() { printf '%swarning:%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die() { printf '%serror:%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

usage() {
	cat <<EOF
Espresso installer

Usage: install.sh [--uninstall] [--help]

Environment:
  ESPRESSO_VERSION       tag to install (default: latest release)
  ESPRESSO_INSTALL_DIR   destination directory (default: /Applications)
EOF
}

# Terminating the app is enough to end any keep-awake session: the caffeinate
# child watches Espresso's pid and exits with it.
quit_running_app() {
	if pgrep -x Espresso >/dev/null 2>&1; then
		log "Quitting the running copy of Espresso"
		pkill -x Espresso || true
		for _ in 1 2 3 4 5 6 7 8 9 10; do
			pgrep -x Espresso >/dev/null 2>&1 || return 0
			sleep 0.2
		done
		warn "Espresso is still running; the install may fail"
	fi
}

# /Applications is group-writable by admins on a stock Mac, so sudo is usually
# unnecessary. Escalate only when it actually is.
detect_sudo() {
	SUDO=""
	[ -w "$INSTALL_DIR" ] && return 0
	[ -d "$INSTALL_DIR" ] || die "$INSTALL_DIR does not exist"
	command -v sudo >/dev/null 2>&1 || die "$INSTALL_DIR is not writable and sudo is unavailable"
	log "$INSTALL_DIR is not writable; using sudo"
	SUDO="sudo"
}

uninstall() {
	local target="$INSTALL_DIR/$APP_NAME"
	[ -d "$target" ] || die "$target is not installed"
	detect_sudo
	quit_running_app
	$SUDO rm -rf "$target"
	log "Removed $target"
	log "If you enabled ${BOLD}Start at Login${RESET}, clear the leftover entry in System Settings > General > Login Items."
}

main() {
	case "${1:-}" in
		--uninstall) uninstall; return 0 ;;
		--help|-h) usage; return 0 ;;
		"") ;;
		*) usage >&2; die "unknown argument: $1" ;;
	esac

	[ "$(uname -s)" = "Darwin" ] || die "Espresso is macOS only"
	local major
	major="$(sw_vers -productVersion | cut -d. -f1)"
	[ "$major" -ge "$MIN_MACOS_MAJOR" ] || die "macOS $MIN_MACOS_MAJOR or later is required (found $(sw_vers -productVersion))"

	local base
	if [ "$VERSION" = "latest" ]; then
		base="https://github.com/$REPO/releases/latest/download"
	else
		base="https://github.com/$REPO/releases/download/$VERSION"
	fi

	local tmp
	tmp="$(mktemp -d "${TMPDIR:-/tmp}/espresso-install.XXXXXX")"
	WORKDIR="$tmp"

	log "Downloading Espresso ($VERSION)"
	curl -fsSL --retry 3 -o "$tmp/$ASSET" "$base/$ASSET" \
		|| die "download failed — is there a published release at https://github.com/$REPO/releases ?"
	curl -fsSL --retry 3 -o "$tmp/$ASSET.sha256" "$base/$ASSET.sha256" \
		|| die "checksum file missing from the release; refusing to install unverified"

	log "Verifying checksum"
	( cd "$tmp" && shasum -a 256 -c "$ASSET.sha256" >/dev/null 2>&1 ) \
		|| die "checksum mismatch — the download is corrupt or tampered with"

	ditto -x -k "$tmp/$ASSET" "$tmp/extracted"
	[ -d "$tmp/extracted/$APP_NAME" ] || die "release archive did not contain $APP_NAME"

	detect_sudo
	quit_running_app

	local target="$INSTALL_DIR/$APP_NAME"
	log "Installing to $target"
	$SUDO rm -rf "$target"
	$SUDO ditto "$tmp/extracted/$APP_NAME" "$target"

	# Espresso is ad-hoc signed, not notarized, so Gatekeeper would otherwise
	# refuse to launch a downloaded copy.
	$SUDO xattr -dr com.apple.quarantine "$target" 2>/dev/null || true

	log "Launching Espresso"
	open "$target"

	printf '\n%sEspresso is installed.%s Look for the cup in your menubar.\n' "$BOLD" "$RESET"
	printf 'Right-click it for Clear, Start at Login, and Quit.\n'
	printf "If you don't see it, your menubar is probably full — macOS hides new icons under the notch.\n"
}

main "$@"
