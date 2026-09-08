# Changelog

All notable changes to Fizzy for Omarchy are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] — 2026-09-07

Peek, copy, and send-to-agent from a notification tray. New for you is your
inbox, not every new card on the board. Older is pings you have already seen.

### Added

- Space peeks at the selected card and its comments (up to eight). Peek does
  not mark the notification read.
- `c` copies the card link with `wl-copy -- <url>` (no shell).
- `a` sends a length-capped prompt to `omarchy-agent-prompt`. Fizzy fields
  are labeled as untrusted data.
- `?` and the help button open a shortcuts overlay.
- `h` / `l` and the left / right arrows switch New for you and Older.
  `u` / `p` still jump. The tabs are clickable.
- `tests/qml.test.sh` greps QML invariants during `./tests/run`.
- Marketplace `preview.png` is the shortcuts overlay. `docs/help.png` is the
  same crop. Live list and peek shots are not published (they showed a real
  board).

### Changed

- Second tab is **Older** (already-seen notifications), not Previous.
- `m` marks this notification read on New for you only. `M` marks all unread
  notifications. The check is hidden on Older. The tray does not call
  `fizzy card mark-read`.
- `j` / `k` only move.
- Plugin id is `gigasolo.fizzy`. Early 1.0 installs as `lonbaker.fizzy` cannot
  be renamed in place: remove, then add this repo again.
- Panel UI is split into `HelpView`, `PeekView`, `SetupCard`, and
  `NotificationRow`.
- Peek results are cached for eight cards (LRU) for the rest of the session.

### Fixed

- A missing Fizzy CLI no longer leaves the panel on “Checking the board”.
  Quickshell never exits a `Process` whose command is not on `PATH`, so the
  plugin probes with `which fizzy` first.
- A list timeout is not treated as a missing CLI.
- A vanished binary after a successful probe shows a timeout, not a hang.
- Late `SIGTERM` from a killed probe cannot cancel a newer recovery.
- Peeking no longer dismisses the row from New for you.
- Marking a peeked ping read hides the check and does not queue a second
  `fizzy notification read`. A failed CLI read restores the check so `m`
  retries while still peeking.
- A peek timeout cannot cache a partial card, fail the card you already
  moved to, or leave a leftover timer after a cached peek. A late
  `onExited` is ignored by generation, like the CLI probe.
- A list refresh cannot unhide the peek check after a successful mark-read.
  Only a failed CLI read restores it. Failed `read-all` restores the peeked
  row's prior unread state (Older + `M` does not force the check on).
- Notification list asks the CLI for `--limit` matching `maxItems`.
- Card URLs must be `https` on `*.fizzy.do` before they are copied, opened,
  or sent to the agent.
- Copyright is GigaSolo LLC.

## [1.0.0] — 2026-08-14

First stable release.

### Added

- Unread Fizzy notifications in the Omarchy 4 (Quattro) bar.
- Keyboard tray: move, open in the browser, mark read, unread / previous.
- Setup card when you are not signed in, instead of raw CLI JSON.
- MIT license, README, and `docs/panel.png` / `docs/setup.png`.

### Security

- The plugin only shells out to the local Fizzy CLI. It never reads
  `FIZZY_TOKEN`, `~/.config/fizzy/`, or `~/.fizzy.yaml`.
