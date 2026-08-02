---
name: release
description: Cut and publish a new Espresso release. Analyzes every change since the last tag, recommends a version bump when the default patch bump is wrong, tags, then verifies the GitHub release and the Homebrew cask. Use for "release", "cut a release", "ship a new version", "/release".
---

# Release Espresso

`$ARGUMENTS` may contain a version, free-form instructions, both, or neither:

- A leading token matching `v?MAJOR.MINOR[.PATCH]` is the version to release.
- Everything else is an instruction ("mark it a prerelease", "call out the
  countdown fix in the notes").

Tagging is what publishes. `.github/workflows/release.yml` builds the universal
bundle, creates the GitHub release, and pushes the stamped cask to
`panchr/homebrew-tap`. **Never** run `gh release create` by hand — the workflow
owns the release, and a hand-made one makes the job skip asset creation.

## 1. Preflight

Stop and report if any of these fail. Do not "fix" them as part of releasing.

```sh
git rev-parse --abbrev-ref HEAD          # must be main
git status --porcelain                   # must be empty
git fetch --tags --quiet && git status -sb | head -1   # must not be ahead/behind
git describe --tags --abbrev=0           # the last released version
```

Then confirm CI is green for exactly this commit:

```sh
gh run list --branch main --limit 1 --json headSha,conclusion,status
```

If it does not match `git rev-parse HEAD`, or is not `success`, stop. A red or
stale CI means the release build is a coin flip.

## 2. Read what actually changed

```sh
LAST=$(git describe --tags --abbrev=0)
git log "$LAST"..HEAD --format='%h %s%n%b'
git diff "$LAST"..HEAD --stat
```

If there are no commits, stop — there is nothing to release.

Commit prefixes here are `area: summary`, **not** conventional commits, so
`feat:`/`fix:` parsing does not work. Read the diffs. Pay attention to the
surfaces that are a public contract:

| Surface | Why it matters |
|---|---|
| `Sources/` | user-visible behavior, menu items, durations |
| `Makefile` asset names | `install.sh` and the cask fetch `Espresso.zip` by name |
| `install.sh` flags/env vars | people have these in scripts |
| `Casks/espresso.rb` token/tap | `brew install --cask panchr/tap/espresso` |
| `Resources/Info.plist` | `LSMinimumSystemVersion`, bundle identifier |

## 3. Choose the version

Default is a **patch** bump. A missing patch component counts as 0, so `v0.1`
patches to `v0.1.1` and minors to `v0.2`.

- **patch** — bug fixes, docs, CI, refactors, anything a user would not notice
- **minor** — new user-visible capability: a new duration, a new menu item, a
  new install option, a new `install.sh` flag
- **major** — a break: an asset renamed, a flag or feature removed, the bundle
  identifier or cask token changed, `LSMinimumSystemVersion` raised (it drops
  users whose Macs can no longer run it)

**Never select, recommend, or drift into 1.0 or above on your own.** 1.0 is a
promise about stability, and that promise is the user's to make — it is not
inferable from a diff. If the work looks 1.0-worthy, say so as an observation
and still proceed with the 0.x version. Only cut 1.0+ when `$ARGUMENTS`
explicitly names it.

Then:

- **Analysis agrees with the version in play** (user-specified or the patch
  default) — proceed without asking.
- **Analysis disagrees** — say so before tagging, name the specific commits and
  diffs driving it, and ask. A user-specified version still wins if they
  confirm; report the risk once and respect the answer.
- **Only docs or CI changed** — say a release probably is not warranted, and ask
  before continuing.

## 4. Tag and publish

Annotated tag. The message is user-facing — it is what someone reads to decide
whether to upgrade, so summarize the changes, not the commit count.

```sh
git tag -a vX.Y.Z -m "Espresso vX.Y.Z

<what changed, in the user's terms>"
git push origin vX.Y.Z
```

Then watch it land:

```sh
gh run list --workflow=release.yml --limit 1 --json databaseId,status
gh run watch --exit-status <id>
```

## 5. Verify — the release is not done until this passes

```sh
gh release view vX.Y.Z --json assets --jq '[.assets[].name]'   # both assets
curl -fsSL https://raw.githubusercontent.com/panchr/homebrew-tap/main/Casks/espresso.rb | head -3
```

The cask's `version` must be the new one, and its `sha256` must equal the
first field of the release's `Espresso.zip.sha256`. If they differ, the cask
points at bytes nobody can download — say so loudly rather than reporting
success.

If the tap step was skipped, `TAP_DEPLOY_KEY` is missing; see `CLAUDE.md`.

## When something goes wrong

- **Job failed after the tag was pushed** — fix on main, then
  `gh workflow run release.yml -f tag=vX.Y.Z`. Re-runs are safe: they never
  replace a published archive, they only (re)publish the cask.
- **Wrong version tagged** — prefer cutting the next version over deleting a
  pushed tag. Anyone who already fetched it keeps a tag that no longer matches
  the remote, and Homebrew may have cached the artifact.
- **Never** `git push` main as part of releasing. Main is expected to be pushed
  already; preflight fails if it is not.
