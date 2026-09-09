# Screenshots for publishing

Public shots must look like the current tray and must not show a real
customer board. The 2026-09-08 GigaBoard Example captures are cropped into
`preview.png`, `docs/panel.png`, `docs/peek.png`, `docs/help.png`, and
`docs/accounts.png`. Recapture only if the tray labels or chrome change.

For shots, select GigaBoard in the accounts overlay (or `fizzy auth switch
gigasolo` so the header reads **GIGABOARD**), refresh the tray, capture,
then switch back if you need VirtualPBX again. Never publish the live
profile.

```sh
fizzy auth list --json
fizzy auth switch gigasolo
omarchy-shell gigasolo.fizzy refresh
```

## Why a second user

Fizzy never notifies you of your own work. Mentions of yourself are dropped.
Card and comment events skip the creator. GigaBoard currently has one user
(`Lon Baker`), and `fizzy --profile gigasolo notification list` is empty.

A Demo / Example board that only you touch will not fill **New for you**.
You need a second GigaBoard user (a throwaway "Ada Example" is enough) who
comments, mentions you, or publishes cards you watch.

Do not use the `virtualpbx` profile for published images.

## Shot list

| File | What to show | Why |
| --- | --- | --- |
| `preview.png` | **New for you** with 3–4 unread fake pings, action buttons visible | Marketplace listing. This is the product. |
| `docs/panel.png` | Same crop as `preview.png` | README / extra listing still. |
| `docs/peek.png` | Peek of one Example card plus two or three short comments | README: Space peeks without marking read. |
| `docs/help.png` | Shortcuts overlay (`?`) with `m` / `M` / **New / older** | README: full keyboard navigation. |
| `docs/accounts.png` | Accounts overlay on GigaBoard only (`1` All, `2` GigaBoard, Add) | README: `s` switcher. Crop out any live profile. |
| `docs/setup.png` | Setup card (already fine) | First-time install. Keep unless the copy changes. |

Crop to the panel. No real email addresses, customer names, or other bar
widgets if you can avoid them. The header should read **GIGABOARD**.

## Seed the Example board (`gigasolo`)

Leave the existing **FACTORY** board alone. Create a separate board so demo
cards never mix with real work.

This is already on GigaBoard:

| | |
| --- | --- |
| Board | [Example](https://app.fizzy.do/6101440/boards/03gu0igjr26s89cthukv6x0yn) (`03gu0igjr26s89cthukv6x0yn`) |
| Columns | Inbox, Ready |
| #107 | Polish the shortcuts overlay (Inbox) |
| #108 | Crop the marketplace preview (Inbox) |
| #109 | Write the 1.1 listing blurb (Ready) |
| #110 | Peek without marking the ping read (Inbox) |

Cards are published and watched as Lon. Recreate only if that board is gone:

```sh
PROFILE=gigasolo

fizzy --profile "$PROFILE" board create --name Example --json
# save the board id from data.id

fizzy --profile "$PROFILE" card create --board <board-id> --title "Polish the shortcuts overlay" \
  --description "Make the overlay match the 1.1 keys: peek, copy, send to agent, mark read." --json
fizzy --profile "$PROFILE" card create --board <board-id> --title "Crop the marketplace preview" \
  --description "Panel only. No customer boards. Header says GIGABOARD." --json
fizzy --profile "$PROFILE" card create --board <board-id> --title "Write the 1.1 listing blurb" \
  --description "New for you is the inbox. Older is pings you have already seen." --json

# watch so Ada's comments land in your tray
fizzy --profile "$PROFILE" card watch <number>
fizzy --profile "$PROFILE" card publish <number>
```

Titles stay short so they elide cleanly. Descriptions are the peek body.

## Ping the cards (second profile)

Invite the second user with the GigaBoard join code, then log them in as a
named CLI profile (not `gigasolo`, not `virtualpbx`):

```sh
fizzy --profile gigasolo account join-code-show --json
fizzy auth login <token> --profile example
```

As that user, comment and mention Lon so **New for you** gets a mix of
`event` and `mention` rows:

```sh
fizzy --profile example comment create --card <number> \
  --body "The overlay crop looks right. @Lon Baker can you mark this read after the shot?"
fizzy --profile example comment create --card <number> \
  --body "Peek should show this comment and the one above. No customer names."
```

Mark one notification read so **Older** is not an empty tab:

```sh
fizzy --profile gigasolo notification list --limit 10 --json
fizzy --profile gigasolo notification read <id>
fizzy auth switch gigasolo
omarchy-shell gigasolo.fizzy refresh
omarchy-shell gigasolo.fizzy open
```

## Capture

Open the tray, then save a region (skips the editor and prints the path):

```sh
omarchy capture screenshot region save
```

Copy the crops into the repo:

```sh
cp <captured> preview.png
cp <captured> docs/panel.png
cp <captured> docs/peek.png
cp <captured> docs/help.png       # only if you recaptured shortcuts
cp <captured> docs/accounts.png   # GigaBoard only; crop out live profiles
```

`preview.png` is the populated **New for you** list. Keep the overlay as
`docs/help.png`. If the accounts overlay is in frame, crop out every live
customer profile before the file is `docs/accounts.png`.

After the shots: `fizzy auth switch virtualpbx` if that is the daily profile.
Do not delete the Example board until you are done with 1.1 listing images;
you can close the cards.

## Checklist before you commit images

- [x] Header is GIGABOARD, tabs say **NEW FOR YOU** / **OLDER**
- [x] No VirtualPBX board names, people, or card titles
- [x] Peek comments are dummy copy
- [x] Help overlay lists `h l` New / older, not Unread / previous
- [x] Alts in README match the files you committed
- [x] `docs/accounts.png` is GigaBoard only (live profiles cropped out)
