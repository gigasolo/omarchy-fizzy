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
    url: "https://app.fizzy.do/6101773/notifications/03go4kzxi8b1gcmtumlig3yrc",
    creator: { name: "Jay Beck" },
    card: {
      number: 510,
      title: "Colorful Nails",
      url: "https://app.fizzy.do/6101773/cards/510",
      board_name: "VirtualText Orders"
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
    url: "https://app.fizzy.do/6101773/notifications/03gmvechkr7kr9p0rp39hqtxz",
    creator: { name: "Josh Ferreira" },
    card: {
      number: 493,
      title: "Own AI Voice Widget: Telnyx assessment + Kazoo/SIP Attach architecture",
      url: "https://app.fizzy.do/6101773/cards/493",
      board_name: "Development"
    }
  }, overrides)
}

test("parseIdentity extracts the current account and user", () => {
  const result = Model.parseIdentity(envelope({
    accounts: [{
      id: "03f57o0komzjxizcioldj38aa",
      name: "VirtualPBX",
      slug: "/6101773",
      user: { id: "03f57o0krj41pxd9zorhtsmiu", name: "Lon Baker" }
    }]
  }))

  assert.equal(result.ok, true)
  assert.deepEqual(result.account, {
    id: "03f57o0komzjxizcioldj38aa",
    name: "VirtualPBX",
    slug: "/6101773"
  })
  assert.deepEqual(result.user, {
    id: "03f57o0krj41pxd9zorhtsmiu",
    name: "Lon Baker"
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
  assert.equal(event.boardName, "VirtualText Orders")
  assert.equal(event.cardUrl, "https://app.fizzy.do/6101773/cards/510")
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
        url: "https://app.fizzy.do/6101773/cards/510",
        board_name: "VirtualText Orders"
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
    cardUrl: "https://app.fizzy.do/6101773/cards/510",
    url: "https://app.fizzy.do/6101773/notifications/abc"
  }), "https://app.fizzy.do/6101773/cards/510")

  assert.equal(Model.openUrl({
    cardUrl: "",
    url: "https://app.fizzy.do/6101773/notifications/abc"
  }), "https://app.fizzy.do/6101773/notifications/abc")
})

test("notificationMeta includes time, creator, and board", () => {
  const item = {
    timestampMs: Date.parse("2026-08-12T19:09:07.279Z"),
    creator: "Jay Beck",
    boardName: "VirtualText Orders"
  }
  const nowMs = Date.parse("2026-08-14T12:00:00.000Z")
  assert.equal(Model.notificationMeta(item, nowMs), "Aug 12 • Jay Beck • VirtualText Orders")
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
