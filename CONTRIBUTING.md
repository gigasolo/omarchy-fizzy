# Contributing

Thanks for helping with Fizzy for Omarchy.

## Before you start

You need [Omarchy](https://omarchy.org/) 4 (Quattro), the Fizzy CLI, and a signed-in Fizzy account so you can click through the panel.

## Make a change

1. Fork [gigasolo/omarchy-fizzy](https://github.com/gigasolo/omarchy-fizzy).
2. Create a branch.
3. Pass `--profile` on every Fizzy command via `Model.fizzyArgs`. Do not call `fizzy auth switch`. Add account with `fizzy setup --profile` in a visible terminal. Remove with `fizzy auth logout --profile`. Do not read tokens or Fizzy config files. For published screenshots, switch the active CLI profile to `gigasolo` and follow [docs/screenshots.md](docs/screenshots.md). Do not commit shots of VirtualPBX or any other live board.
4. Put parse and format logic in `Model.js` so it can be tested without QML.
5. Run the checks:

```sh
./tests/run
```

That runs the Model tests, `tests/qml.test.sh`, and `omarchy plugin validate`. Omarchy will not install a plugin that fails validation.

6. Load your checkout and click through the panel: open, refresh, new/older, peek (does not mark read), copy, send to agent, mark read on New for you only, shortcuts overlay, disable, re-enable.

## Pull requests

- Describe what you changed and how you tried it.
- Keep the MIT license.
- Do not commit tokens, Fizzy config, screenshots of tokens, or personal account names. Marketplace shots belong in `preview.png` and `docs/`; crop the panel only. Recapture from the GigaBoard Example board (see [docs/screenshots.md](docs/screenshots.md)) so **Older** and the current shortcuts are what people see.

## License

By contributing you agree your changes are licensed under the MIT License in [LICENSE](LICENSE).
