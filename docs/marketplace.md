# Marketplace listing (1.1.0)

Paste-ready copy for [plugins.omarchy.org](https://plugins.omarchy.org/).
`omarchyplugins.com` redirects there. Keep this file on the branch until
1.1.0 is on `main`, then open the GitHub form against that commit.

The marketplace listing is `preview.png` at the repository root: **New for
you** with unread Example pings and the copy / send-to-agent / mark-read
buttons. `docs/help.png` is the shortcuts overlay. `docs/peek.png` is Space
peek (card and comments). `docs/accounts.png` is the switcher on GigaBoard
only. Do not upload shots from VirtualPBX or any other live board. Recipe:
[screenshots.md](screenshots.md).

## Public blurb

Unread Fizzy notifications in your Omarchy bar. New for you is your inbox,
not every new card on the board. Peek at a card and its comments, copy or
open the link, send it to your Omarchy agent (Send to Agent), or mark a ping
read. Full keyboard navigation. If the Fizzy CLI is not installed yet, the
panel shows how to finish setup.

## Install

```sh
omarchy plugin add https://github.com/gigasolo/omarchy-fizzy.git --enable
```

## Submit a plugin (new listing)

Use [Submit a plugin](https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml).

| Field | Value |
| --- | --- |
| Repository URL | `https://github.com/gigasolo/omarchy-fizzy` |
| Category | Productivity |
| Tags | Bar, Quickshell, AI |
| Suggest a missing tag | Notifications |

### Maintainer notes

Bar widget (`gigasolo.fizzy`). Depends on the Fizzy CLI (`omarchy pkg aur add fizzy-cli`). Discovers every signed-in CLI profile and shows a combined inbox. The plugin never reads `FIZZY_TOKEN` or `~/.fizzy.yaml`; it only runs `fizzy` subcommands (with `--profile`), `wl-copy`, and `omarchy-agent-prompt`. Missing CLI or unsigned-in accounts get a setup card that launches `omarchy pkg aur add fizzy-cli` and `fizzy setup` in a visible terminal. `preview.png` is the populated New for you list from the GigaBoard Example board ([screenshots.md](screenshots.md)). MIT, GigaSolo LLC.

## Verify or update a listed plugin

Use [Verify or update](https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=verify-plugin.yml) after 1.1.0 is on `main`.

| Field | Value |
| --- | --- |
| Verification action | Verify and publish a newer upstream commit |
| Plugin ID | `gigasolo.fizzy` |
| Repository URL | `https://github.com/gigasolo/omarchy-fizzy` |
| Target commit | Full 40-character SHA of the 1.1.0 commit on `main` |
