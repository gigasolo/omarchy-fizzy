const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")

function envelope(data, extras = {}) {
  return JSON.stringify(Object.assign({ ok: true, data }, extras))
}

function eventNotification(overrides = {}) {
  return Object.assign({
    id: "03go4kzxi8b1gcmtumlig3yrc",
    read: false,
    source_type: "event",
    title: "Colorful Nails",
    body: "Added by Jay Beck",
    unread_count: 1,
    created_at: "2026-08-12T19:09:07.279Z",
    url: "https://app.fizzy.do/acct/notifications/n1",
    creator: { name: "Jay Beck" },
    card: {
      number: 510,
      title: "Colorful Nails",
      url: "https://app.fizzy.do/acct/cards/510",
      board_name: "Orders"
    }
  }, overrides)
}

function mentionNotification(overrides = {}) {
  return Object.assign({
    id: "03gmvechkr7kr9p0rp39hqtxz",
    read: false,
    source_type: "mention",
    title: "Josh @mentioned you",
    body: "We are not running Kamailio 5.5 or higher at this time.",
    unread_count: 1,
    created_at: "2026-08-11T16:00:00.000Z",
    url: "https://app.fizzy.do/acct/notifications/n2",
    creator: { name: "Josh Ferreira" },
    card: {
      number: 493,
      title: "Own AI Voice Widget: Telnyx assessment + Kazoo/SIP Attach architecture",
      url: "https://app.fizzy.do/acct/cards/493",
      board_name: "Development"
    }
  }, overrides)
}

test("parseIdentity extracts the current account and user", () => {
  const result = Model.parseIdentity(envelope({
    accounts: [{
      id: "acct-1",
      name: "Acme",
      slug: "/acme",
      user: { id: "user-1", name: "Ada Lovelace" }
    }]
  }))

  assert.equal(result.ok, true)
  assert.deepEqual(result.account, {
    id: "acct-1",
    name: "Acme",
    slug: "/acme"
  })
  assert.deepEqual(result.user, {
    id: "user-1",
    name: "Ada Lovelace"
  })
})

test("parseIdentity fails when the CLI reports an error", () => {
  const result = Model.parseIdentity(JSON.stringify({
    ok: false,
    error: "Not authenticated",
    code: "unauthenticated"
  }))

  assert.equal(result.ok, false)
  assert.match(result.error, /not authenticated|fizzy setup/i)
})

const AUTH_REQUIRED_ENVELOPE = `{
  "ok": false,
  "error": "No API token configured. Run 'fizzy auth login TOKEN' or set FIZZY_TOKEN",
  "code": "auth_required",
  "hint": "Run 'fizzy auth login TOKEN' or set FIZZY_TOKEN"
}`

test("parseIdentity maps the real no-token envelope to a setup hint", () => {
  const result = Model.parseIdentity(AUTH_REQUIRED_ENVELOPE)

  assert.equal(result.ok, false)
  assert.match(result.error, /fizzy setup/i)
  assert.doesNotMatch(result.error, /\{|FIZZY_TOKEN|auth login/)
})

test("interpretIdentity treats auth_required JSON as setup, not a raw dump", () => {
  const result = Model.interpretIdentity(AUTH_REQUIRED_ENVELOPE, 3)

  assert.equal(result.ok, false)
  assert.equal(result.installed, true)
  assert.equal(result.authenticated, false)
  assert.equal(result.setupKind, "auth_required")
  assert.equal(result.error, "")
})

test("interpretIdentity treats a missing CLI as an install setup state", () => {
  const result = Model.interpretIdentity("fizzy: command not found", 127)

  assert.equal(result.installed, false)
  assert.equal(result.authenticated, false)
  assert.equal(result.setupKind, "missing_cli")
  assert.equal(result.error, "")
})

test("interpretIdentity treats a failed which-style probe as missing CLI", () => {
  const result = Model.interpretIdentity("", 1)

  assert.equal(result.installed, false)
  assert.equal(result.setupKind, "missing_cli")
  assert.equal(result.error, "")
})

test("interpretIdentity keeps unexpected failures as errors, not setup", () => {
  const result = Model.interpretIdentity("not json", 1)

  assert.equal(result.setupKind, "")
  assert.equal(result.authenticated, false)
  assert.match(result.error, /parse/i)
})

test("setupGuide for missing CLI explains the Omarchy AUR install", () => {
  const guide = Model.setupGuide("missing_cli")

  assert.match(guide.hero, /not installed/i)
  assert.match(guide.title, /install/i)
  assert.match(guide.action, /install/i)
  assert.ok(guide.commands.some(command => /omarchy pkg aur add fizzy-cli/.test(command)))
  assert.ok(guide.commands.some(command => command === "fizzy setup"))
})

test("setupGuide for auth points at fizzy setup", () => {
  const guide = Model.setupGuide("auth_required")

  assert.match(guide.hero, /sign in/i)
  assert.match(guide.action, /set up|setup|sign in/i)
  assert.deepEqual(guide.commands, ["fizzy setup"])
  assert.doesNotMatch(guide.detail, /\{|FIZZY_TOKEN/)
})

test("friendlyCliError unwraps JSON envelopes instead of dumping them", () => {
  assert.match(Model.friendlyCliError(AUTH_REQUIRED_ENVELOPE, "fallback"), /fizzy setup/i)
  assert.doesNotMatch(Model.friendlyCliError(AUTH_REQUIRED_ENVELOPE, "fallback"), /\{/)
  assert.equal(Model.friendlyCliError("", "Could not list Fizzy notifications"), "Could not list Fizzy notifications")
})

test("parseIdentity fails when no accounts are available", () => {
  const result = Model.parseIdentity(envelope({ accounts: [] }))
  assert.equal(result.ok, false)
  assert.match(result.error, /fizzy setup|no account/i)
})

test("parseNotifications normalizes event and mention fields", () => {
  const result = Model.parseNotifications(envelope([
    eventNotification(),
    mentionNotification()
  ]), 40)

  assert.equal(result.ok, true)
  assert.equal(result.items.length, 2)

  const event = result.items.find(item => item.sourceType === "event")
  assert.equal(event.title, "Colorful Nails")
  assert.equal(event.excerpt, "Added by Jay Beck")
  assert.equal(event.boardName, "Orders")
  assert.equal(event.cardUrl, "https://app.fizzy.do/acct/cards/510")
  assert.equal(event.cardNumber, 510)
  assert.equal(event.creator, "Jay Beck")
  assert.equal(event.unread, true)
  assert.equal(event.unreadCount, 1)

  const mention = result.items.find(item => item.sourceType === "mention")
  assert.equal(mention.title, "Own AI Voice Widget: Telnyx assessment + Kazoo/SIP Attach architecture")
  assert.equal(mention.excerpt, "We are not running Kamailio 5.5 or higher at this time.")
  assert.equal(mention.boardName, "Development")
})

test("parseNotifications skips items without ids and strips markup", () => {
  const result = Model.parseNotifications(envelope([
    { title: "no id" },
    eventNotification({
      body: "<p>Added by Jay &amp; Abi</p>",
      card: {
        number: 510,
        title: "Colorful &amp; Bright Nails",
        url: "https://app.fizzy.do/acct/cards/510",
        board_name: "Orders"
      }
    })
  ]), 40)

  assert.equal(result.ok, true)
  assert.equal(result.items.length, 1)
  assert.equal(result.items[0].title, "Colorful & Bright Nails")
  assert.equal(result.items[0].excerpt, "Added by Jay & Abi")
})

test("parseNotifications respects the item limit after newest-first sort", () => {
  const result = Model.parseNotifications(envelope([
    eventNotification({ id: "old", created_at: "2026-08-01T00:00:00.000Z", title: "Old" }),
    eventNotification({ id: "new", created_at: "2026-08-14T00:00:00.000Z", title: "New" }),
    eventNotification({ id: "mid", created_at: "2026-08-10T00:00:00.000Z", title: "Mid" })
  ]), 2)

  assert.deepEqual(result.items.map(item => item.id), ["new", "mid"])
})

test("filterNotifications splits unread and previous without reordering", () => {
  const items = [
    { id: "new", unread: true },
    { id: "old", unread: false },
    { id: "also-new", unread: true }
  ]

  assert.deepEqual(Model.filterNotifications(items, "unread").map(item => item.id), ["new", "also-new"])
  assert.deepEqual(Model.filterNotifications(items, "previous").map(item => item.id), ["old"])
  assert.deepEqual(Model.filterNotifications(items, "all").map(item => item.id), ["new", "old", "also-new"])
})

test("unreadCount counts unread items", () => {
  assert.equal(Model.unreadCount([
    { unread: true },
    { unread: false },
    { unread: true }
  ]), 2)
})

test("openUrl prefers the card URL", () => {
  assert.equal(Model.openUrl({
    cardUrl: "https://app.fizzy.do/acct/cards/510",
    url: "https://app.fizzy.do/acct/notifications/abc"
  }), "https://app.fizzy.do/acct/cards/510")

  assert.equal(Model.openUrl({
    cardUrl: "",
    url: "https://app.fizzy.do/acct/notifications/abc"
  }), "https://app.fizzy.do/acct/notifications/abc")
})

test("cardLink copies the card URL, falling back to the notification URL", () => {
  assert.equal(Model.cardLink({
    cardUrl: "https://app.fizzy.do/6101773/cards/557",
    url: "https://app.fizzy.do/6101773/notifications/n1"
  }), "https://app.fizzy.do/6101773/cards/557")
  assert.equal(Model.cardLink({
    cardUrl: "",
    url: "https://app.fizzy.do/6101773/notifications/n1"
  }), "https://app.fizzy.do/6101773/notifications/n1")
  assert.equal(Model.cardLink(null), "")
})

test("parseCard extracts description and board from card show JSON", () => {
  const result = Model.parseCard(envelope({
    id: "03gs9gzg6h5izhp52wq35yccu",
    number: 557,
    title: "Assistant Call Limits",
    url: "https://app.fizzy.do/6101773/cards/557",
    description: "Incident (folded from #555): Marketing DID showing dead air.",
    description_html: "<p>Incident (folded from #555)</p>",
    board: { name: "AI Agents & Tools" }
  }))

  assert.equal(result.ok, true)
  assert.equal(result.card.number, 557)
  assert.equal(result.card.title, "Assistant Call Limits")
  assert.equal(result.card.boardName, "AI Agents & Tools")
  assert.match(result.card.description, /dead air/i)
  assert.equal(result.card.url, "https://app.fizzy.do/6101773/cards/557")
})

test("parseComments keeps the newest comments as plain text", () => {
  const comments = []
  for (let i = 1; i <= 10; i++) {
    comments.push({
      id: "c" + i,
      created_at: "2026-08-0" + Math.min(i, 9) + "T12:00:00.000Z",
      body: { plain_text: "Note " + i, html: "<p>Note " + i + "</p>" },
      creator: { name: "Ada" }
    })
  }
  const result = Model.parseComments(envelope(comments), 8)

  assert.equal(result.ok, true)
  assert.equal(result.items.length, 8)
  assert.equal(result.items[0].text, "Note 3")
  assert.equal(result.items[7].text, "Note 10")
  assert.equal(result.items[0].creator, "Ada")
})

test("parseComments strips html when plain_text is missing", () => {
  const result = Model.parseComments(envelope([
    { id: "c1", created_at: "2026-08-12T12:00:00.000Z", body: { html: "<p>Looks <strong>good</strong></p>" }, creator: { name: "Jay" } }
  ]), 8)

  assert.equal(result.items[0].text, "Looks good")
})

test("agentPrompt includes the card URL, title, and excerpt", () => {
  const prompt = Model.agentPrompt({
    title: "Assistant Call Limits",
    boardName: "AI Agents & Tools",
    excerpt: "Dead air on marketing DIDs",
    cardUrl: "https://app.fizzy.do/6101773/cards/557",
    url: "https://app.fizzy.do/6101773/notifications/n1"
  }, null)

  assert.match(prompt, /https:\/\/app\.fizzy\.do\/6101773\/cards\/557/)
  assert.match(prompt, /Assistant Call Limits/)
  assert.match(prompt, /Dead air/)
  assert.match(prompt, /AI Agents & Tools/)
})

test("agentPrompt prefers a loaded peek description over the notification excerpt", () => {
  const prompt = Model.agentPrompt({
    title: "Assistant Call Limits",
    excerpt: "short ping",
    cardUrl: "https://app.fizzy.do/6101773/cards/557"
  }, { description: "Full incident writeup about idle timeouts." })

  assert.match(prompt, /Full incident writeup/)
  assert.doesNotMatch(prompt, /short ping/)
})

test("notificationMeta includes time, creator, and board", () => {
  const item = {
    timestampMs: Date.parse("2026-08-12T19:09:07.279Z"),
    creator: "Jay Beck",
    boardName: "Orders"
  }
  const nowMs = Date.parse("2026-08-14T12:00:00.000Z")
  assert.equal(Model.notificationMeta(item, nowMs), "Aug 12 • Jay Beck • Orders")
})

test("parseThemeColors reads named six-digit colors", () => {
  assert.deepEqual(Model.parseThemeColors([
    "mode = \"dark\"",
    "red = \"#ff0000\"",
    "color4=#112233",
    "invalid = \"blue\""
  ].join("\n")), { red: "#ff0000", color4: "#112233" })
})

test("notificationTypeIcon maps known Fizzy source types", () => {
  assert.notEqual(Model.notificationTypeIcon("mention"), Model.notificationTypeIcon("event"))
  assert.ok(Model.notificationTypeIcon("mention"))
  assert.ok(Model.notificationTypeIcon("unknown"))
})

test("invalid CLI output returns a useful parse failure", () => {
  assert.equal(Model.parseNotifications("not json", 40).ok, false)
  assert.match(Model.parseNotifications("not json", 40).error, /parse/i)
  assert.deepEqual(Model.parseNotifications("not json", 40).items, [])
})
