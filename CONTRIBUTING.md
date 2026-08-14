# Contributing

Thanks for helping with Fizzy for Omarchy.

## Before you start

You need Omarchy Quattro, the Fizzy CLI, and a signed-in Fizzy account so you can click through the panel.

## Make a change

1. Fork [gigasolo/omarchy-fizzy](https://github.com/gigasolo/omarchy-fizzy).
2. Create a branch.
3. Keep the plugin on the **current** Fizzy CLI login. Do not add multi-account or `--profile` fan-out.
4. Put parse and format logic in `Model.js` so it can be tested without QML.
5. Run the checks:

```sh
./tests/run
```

That runs the Model tests and `omarchy plugin validate`.

6. Load your checkout and click through the panel: open, refresh, unread/previous, open a card, mark read, disable, re-enable.

## Pull requests

- Describe what you changed and how you tried it.
- Keep the MIT license.
- Do not commit tokens, Fizzy config, or personal account names.

## License

By contributing you agree your changes are licensed under the MIT License in [LICENSE](LICENSE).
