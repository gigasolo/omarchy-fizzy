# Fizzy for Omarchy

Unread [Fizzy](https://fizzy.do) notifications in your Omarchy bar. Click the mark to open a keyboard-friendly tray, open a card in the browser, and mark it read.

This is an MIT-licensed open source plugin for [Omarchy Quattro](https://omarchy.org/). It is not affiliated with or endorsed by 37signals.

## What you get

- A small Fizzy mark on the bar. It turns urgent when something is unread.
- A panel with **New for you** and **Previous**.
- Click or press Enter to open the card and mark the notification read.
- `m` to mark everything read.
- Uses the [Fizzy CLI](https://github.com/basecamp/fizzy-cli) you already signed in with. The plugin never reads your token.

It uses the CLI’s current login only. Multiple Fizzy accounts are not supported.

## Requirements

1. [Omarchy](https://omarchy.org/) 4 (Quattro) with shell plugins.
2. The Fizzy CLI, signed in.

On Omarchy:

```sh
omarchy pkg aur add fizzy-cli
fizzy setup
fizzy auth status
```

You should see that you are authenticated before installing the plugin.

## Install

```sh
omarchy plugin add https://github.com/gigasolo/omarchy-fizzy.git --enable
```

Omarchy may ask which side of the bar to use. The default is the right.

Then click the new Fizzy mark. If the panel says to run `fizzy setup`, finish CLI login and right-click the mark to refresh.

## Use

| Action | How |
| --- | --- |
| Open or close the panel | Left-click the mark |
| Refresh now | Right-click or middle-click, or press `r` |
| Move | `j` / `k` or the arrow keys |
| Open the selected card | Enter |
| Unread / previous | `u` / `p` |
| Mark all read | `m` |
| Close | Escape |
| Next bar panel | Tab |

## Update and remove

```sh
omarchy plugin update lonbaker.fizzy
omarchy plugin remove lonbaker.fizzy
```

Removing the plugin does not log you out of Fizzy.

## Settings

Edit the widget entry in `~/.config/omarchy/shell.json` if you want to change the defaults:

| Setting | Default | Meaning |
| --- | --- | --- |
| `refreshIntervalSec` | `300` | How often the bar polls Fizzy. Opening the panel also refreshes if the data is stale. |
| `maxItems` | `40` | Newest notifications kept after each refresh. |

## If something is wrong

**The mark is missing.** Confirm the plugin is enabled:

```sh
omarchy plugin list | grep fizzy
omarchy plugin enable lonbaker.fizzy --section right
```

**The panel says the CLI is not installed.** Install `fizzy-cli` with the command in [Requirements](#requirements).

**The panel says to run `fizzy setup`.** Sign in with the Fizzy CLI, then right-click the mark.

**The count looks stale.** Right-click to refresh, or wait for the next poll.

Plugins run as unsandboxed code inside `omarchy-shell`. Read the source before you enable a third-party plugin.

## How it talks to Fizzy

The plugin only runs these local commands. It never sends a token on the command line, and it never writes notification content to disk.

```
fizzy identity show --json
fizzy notification list --json
fizzy notification read <id> --json
fizzy notification read-all --json
```

## Develop

```sh
git clone https://github.com/gigasolo/omarchy-fizzy.git
cd omarchy-fizzy
./tests/run
omarchy plugin validate .
```

To load a local checkout:

```sh
omarchy plugin add "$PWD" --enable
```

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). Copyright (c) 2026 Lon Baker.

Fizzy and Omarchy are trademarks of their respective owners.
