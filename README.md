# Fizzy for Omarchy

A Quickshell bar plugin that shows notifications from [Fizzy](https://fizzy.do) through the [Fizzy CLI](https://github.com/basecamp/fizzy-cli).

## Features

- Shows unread Fizzy notifications in the Omarchy bar.
- Turns the bar mark urgent while anything is unread.
- Filters the panel between **New for you** and **Previous**.
- Opens the related card in the browser and marks the notification as read.
- Marks all notifications as read from the keyboard.
- Uses the Fizzy CLI's existing credential store. It does not read, copy, or store API tokens.
- Combines every signed-in CLI profile (`fizzy auth list`) without calling `fizzy auth switch`. Add another account with `fizzy auth login TOKEN --profile NAME --account SLUG`.

## Requirements

- Omarchy Quattro (4.0) with third-party shell plugins.
- [Fizzy CLI](https://github.com/basecamp/fizzy-cli) 4.x, signed in.

On Omarchy / Arch:

```sh
omarchy pkg aur add fizzy-cli
fizzy setup
fizzy auth status
```

## Install

```sh
omarchy plugin add https://github.com/gigasolo/omarchy-fizzy.git --enable
```

For a local checkout:

```sh
omarchy plugin add /home/lonbaker/code/omarchy-fizzy --enable
```

Choose a bar section if Omarchy asks. The manifest defaults to the right.

## Usage

- Left-click the Fizzy mark to open or close the panel.
- Right-click or middle-click to refresh.
- Click a notification to open its card. Unread items are also marked as read.
- `j` / `k` or arrows move through notifications.
- Enter opens the selected card.
- `u` shows unread, `p` shows previous, `r` refreshes, `m` marks all as read.
- Escape closes the panel. Tab moves to the next bar panel.

## Updates

```sh
omarchy plugin update lonbaker.fizzy
```

## Remove

```sh
omarchy plugin remove lonbaker.fizzy
```

Removing the plugin does not log out of Fizzy or change the CLI config.

## Privacy and security

The plugin runs these local CLI commands:

```
fizzy identity show --json
fizzy notification list --json
fizzy notification read <id> --json
fizzy notification read-all --json
```

Notification data is held in the Quickshell process memory. The plugin does not write notification content, account details, credentials, or tokens to disk.

Plugins run as unsandboxed code inside `omarchy-shell`. Review the source before enabling it.

## Development

```sh
./tests/run
omarchy plugin validate .
```

## License

MIT. Not affiliated with or endorsed by 37signals.
