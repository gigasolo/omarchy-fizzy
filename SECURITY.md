# Security

This plugin runs as unsandboxed code inside `omarchy-shell`. Treat it like anything else you would execute as your user.

## What it can access

The plugin only shells out to the local [Fizzy CLI](https://github.com/basecamp/fizzy-cli). It does not read `FIZZY_TOKEN`, `~/.config/fizzy/`, or `~/.fizzy.yaml`.

It runs:

```
fizzy identity show --json
fizzy notification list --json
fizzy notification read <id> --json
fizzy notification read-all --json
```

Install and sign-in actions launch Omarchy terminals (`omarchy pkg aur add fizzy-cli` and `fizzy setup`). Those run in a terminal you can see, not hidden in the shell process.

## Reporting a vulnerability

Please do **not** open a public issue for a security problem.

Use [GitHub Security Advisories](https://github.com/gigasolo/omarchy-fizzy/security/advisories/new) on this repository.

Do not include API tokens, Fizzy config files, or notification content in the report.
