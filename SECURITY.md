# Security

This plugin runs as unsandboxed code inside `omarchy-shell`. Treat it like anything else you would execute as your user.

## What it can access

The plugin only shells out to the local [Fizzy CLI](https://github.com/basecamp/fizzy-cli). It does not read `FIZZY_TOKEN`, `~/.config/fizzy/`, or `~/.fizzy.yaml`. Card links are copied with `wl-copy` as an argv vector (no shell). Send-to-agent launches `omarchy-agent-prompt` with a length-capped prompt that labels Fizzy fields as untrusted data.

It runs:

```
fizzy auth list --json
fizzy --profile <name> identity show --json
fizzy --profile <name> notification list --limit <maxItems> --json
fizzy --profile <name> notification read <id> --json
fizzy --profile <name> notification read-all --json
fizzy --profile <name> card show <number> --json
fizzy --profile <name> comment list --card <number> --limit 8 --json
fizzy --profile <name> setup
fizzy --profile <name> auth logout --json
```

`--profile` is a per-command override. The plugin does not run `fizzy auth switch`. Add account launches `fizzy setup --profile` in a visible terminal. Remove runs `fizzy auth logout --profile`.

Copy and agent handoff, on an explicit keypress or button:

```
wl-copy -- <https-url>
omarchy-agent-prompt <prompt>
```

Install and sign-in actions launch Omarchy terminals (`omarchy pkg aur add fizzy-cli` and `fizzy setup`). Those run in a terminal you can see, not hidden in the shell process.

CLI ids, card numbers, and URLs are validated before they become process arguments or `Qt.openUrlExternally` targets. Notification HTML is shown as plain text.

## Reporting a vulnerability

Please do **not** open a public issue for a security problem.

Use [GitHub Security Advisories](https://github.com/gigasolo/omarchy-fizzy/security/advisories/new) on this repository.

Do not include API tokens, Fizzy config files, or notification content in the report.
