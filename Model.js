function parseJson(raw) {
  var text = String(raw || "").trim()
  if (text === "") return { ok: false, error: "The Fizzy CLI returned no data" }

  try {
    var parsed = JSON.parse(text)
    if (!parsed || typeof parsed !== "object") return { ok: false, error: "The Fizzy CLI returned invalid data" }
    if (parsed.ok === false) {
      return {
        ok: false,
        error: setupHint(parsed.error || parsed.message || "The Fizzy CLI request failed", parsed.code),
        code: String(parsed.code || "")
      }
    }
    return { ok: true, value: parsed, code: String(parsed.code || "") }
  } catch (error) {
    return { ok: false, error: "Could not parse the Fizzy CLI response", code: "" }
  }
}

function isAuthFailure(message, code) {
  var kind = String(code || "").toLowerCase()
  if (kind === "auth_required" || kind === "unauthenticated" || kind === "unauthorized")
    return true
  return /not authenticated|unauthenticated|unauthorized|no api token|no token|logged out|fizzy_token|auth login|auth_required|no fizzy account|run fizzy setup/i.test(cleanText(message))
}

function isMissingCli(message, exitCode) {
  if (Number(exitCode) === 127) return true
  var text = cleanText(message)
  if (/command not found|no such file or directory/i.test(text)) return true
  return Number(exitCode) !== 0 && text === ""
}

function setupHint(message, code) {
  if (isAuthFailure(message, code))
    return "Not authenticated. Run fizzy setup."
  return cleanText(message) || "The Fizzy CLI request failed"
}

function friendlyCliError(raw, fallback) {
  var text = String(raw || "").trim()
  if (text === "") return fallback || "The Fizzy CLI request failed"
  var parsed = parseJson(text)
  if (parsed.ok === false) return parsed.error || fallback || "The Fizzy CLI request failed"
  return fallback || "The Fizzy CLI request failed"
}

function emptyIdentity(overrides) {
  var result = {
    ok: false,
    installed: true,
    authenticated: false,
    setupKind: "",
    error: "",
    account: null,
    user: null
  }
  if (!overrides) return result
  for (var key in overrides) result[key] = overrides[key]
  return result
}

function interpretIdentity(raw, exitCode) {
  if (isMissingCli(raw, exitCode)) {
    return emptyIdentity({ installed: false, setupKind: "missing_cli" })
  }

  var parsed = parseIdentity(raw)
  if (parsed.ok) {
    return {
      ok: true,
      installed: true,
      authenticated: true,
      setupKind: "",
      error: "",
      account: parsed.account,
      user: parsed.user
    }
  }

  if (isAuthFailure(parsed.error, parsed.code)) {
    return emptyIdentity({ setupKind: "auth_required" })
  }

  return emptyIdentity({ error: parsed.error || "The Fizzy CLI request failed" })
}

function setupGuide(kind) {
  if (kind === "missing_cli") {
    return {
      kind: "missing_cli",
      hero: "CLI not installed",
      title: "Install Fizzy CLI",
      detail: "Installs fizzy-cli from the AUR, then walks you through sign-in. Refresh the panel when you're done.",
      action: "Install and set up",
      commands: ["omarchy pkg aur add fizzy-cli", "fizzy setup"]
    }
  }
  if (kind === "auth_required") {
    return {
      kind: "auth_required",
      hero: "Sign in to Fizzy",
      title: "Set up Fizzy",
      detail: "Opens fizzy setup in a terminal so you can add your API token. Refresh the panel when you're done.",
      action: "Open setup",
      commands: ["fizzy setup"]
    }
  }
  return { kind: "", hero: "", title: "", detail: "", action: "", commands: [] }
}

function parseIdentity(raw) {
  var result = parseJson(raw)
  if (!result.ok) return { ok: false, error: result.error, code: result.code || "", account: null, user: null }

  var data = result.value.data || {}
  var accounts = Array.isArray(data.accounts) ? data.accounts : []
  var first = accounts[0]
  if (!first || !first.id) {
    return { ok: false, error: "No Fizzy account found. Run fizzy setup.", code: "auth_required", account: null, user: null }
  }

  var user = first.user || data.user || {}
  return {
    ok: true,
    error: "",
    code: "",
    account: {
      id: String(first.id),
      name: cleanText(first.name || "Fizzy"),
      slug: String(first.slug || "")
    },
    user: {
      id: String(user.id || ""),
      name: cleanText(user.name || "")
    }
  }
}

function parseNotifications(raw, limit) {
  var result = parseJson(raw)
  if (!result.ok) return { ok: false, error: result.error, items: [] }

  var data = result.value.data
  var source = []
  if (Array.isArray(data)) source = data
  else if (data && Array.isArray(data.notifications)) source = data.notifications

  var items = []
  for (var i = 0; i < source.length; i++) {
    var item = normalizeNotification(source[i])
    if (item) items.push(item)
  }

  items = sortNotifications(items)
  var count = positiveInteger(limit, 40)
  if (items.length > count) items = items.slice(0, count)
  return { ok: true, error: "", items: items }
}

function normalizeNotification(value) {
  var item = value || {}
  var id = String(item.id || "").trim()
  if (id === "") return null

  var card = item.card || {}
  var timestamp = String(item.created_at || item.updated_at || "")
  var parsedTime = Date.parse(timestamp)
  if (!isFinite(parsedTime)) parsedTime = 0

  var cardTitle = cleanText(card.title || "")
  var fallbackTitle = cleanText(item.title || "Fizzy notification")
  var excerpt = cleanText(item.body || "")
  if (excerpt === "" && cardTitle !== "" && fallbackTitle !== cardTitle) excerpt = fallbackTitle

  return {
    id: id,
    title: cardTitle || fallbackTitle,
    excerpt: excerpt,
    sourceType: cleanText(item.source_type || item.sourceType || ""),
    timestamp: timestamp,
    timestampMs: parsedTime,
    url: String(item.url || ""),
    cardUrl: String(card.url || ""),
    cardTitle: cardTitle,
    cardNumber: positiveInteger(card.number, 0),
    boardName: cleanText(card.board_name || card.boardName || ""),
    creator: cleanText(item.creator && item.creator.name ? item.creator.name : ""),
    unread: item.read !== true,
    unreadCount: positiveInteger(item.unread_count, item.read === true ? 0 : 1)
  }
}

function sortNotifications(items) {
  var sorted = Array.isArray(items) ? items.slice() : []
  sorted.sort(function(a, b) {
    var timeDifference = Number(b.timestampMs || 0) - Number(a.timestampMs || 0)
    if (timeDifference !== 0) return timeDifference
    return String(a.id || "").localeCompare(String(b.id || ""))
  })
  return sorted
}

function filterNotifications(items, state) {
  var source = Array.isArray(items) ? items : []
  var selected = String(state || "all")
  return source.filter(function(item) {
    if (selected === "unread") return item.unread === true
    if (selected === "previous") return item.unread !== true
    return true
  })
}

function unreadCount(items) {
  var source = Array.isArray(items) ? items : []
  var count = 0
  for (var i = 0; i < source.length; i++) if (source[i] && source[i].unread === true) count += 1
  return count
}

function openUrl(item) {
  if (!item) return ""
  return String(item.cardUrl || item.url || "")
}

function cardLink(item) {
  return openUrl(item)
}

function parseCard(raw) {
  var result = parseJson(raw)
  if (!result.ok) return { ok: false, error: result.error, card: null }

  var data = result.value.data || result.value
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    return { ok: false, error: "The Fizzy CLI returned no card", card: null }
  }

  var board = data.board || {}
  var number = positiveInteger(data.number, 0)
  return {
    ok: true,
    error: "",
    card: {
      id: String(data.id || ""),
      number: number,
      title: cleanText(data.title || "Fizzy card"),
      url: String(data.url || ""),
      description: cleanText(data.description || ""),
      boardName: cleanText(board.name || "")
    }
  }
}

function parseComments(raw, limit) {
  var result = parseJson(raw)
  if (!result.ok) return { ok: false, error: result.error, items: [] }

  var data = result.value.data
  var source = []
  if (Array.isArray(data)) source = data
  else if (data && Array.isArray(data.comments)) source = data.comments

  var items = []
  for (var i = 0; i < source.length; i++) {
    var comment = source[i] || {}
    var id = String(comment.id || "").trim()
    if (id === "") continue
    var body = comment.body || {}
    var text = cleanText(body.plain_text || body.html || comment.body || "")
    var timestamp = String(comment.created_at || "")
    var parsedTime = Date.parse(timestamp)
    if (!isFinite(parsedTime)) parsedTime = 0
    items.push({
      id: id,
      text: text,
      creator: cleanText(comment.creator && comment.creator.name ? comment.creator.name : ""),
      timestamp: timestamp,
      timestampMs: parsedTime
    })
  }

  var count = positiveInteger(limit, 8)
  if (items.length > count) items = items.slice(items.length - count)
  return { ok: true, error: "", items: items }
}

function agentExcerpt(item, peek) {
  if (peek && cleanText(peek.description)) return cleanText(peek.description)
  if (!item) return ""
  return cleanText(item.excerpt || "")
}

function agentPrompt(item, peek) {
  var url = cardLink(item)
  var title = item ? cleanText(item.title || "") : ""
  var board = item ? cleanText(item.boardName || "") : ""
  if (peek && peek.boardName) board = cleanText(peek.boardName)
  var excerpt = agentExcerpt(item, peek)
  if (excerpt.length > 400) excerpt = excerpt.substring(0, 397) + "…"

  var lines = ["Look at this Fizzy card: " + (url || "(no url)")]
  if (title !== "") lines.push("", title)
  if (board !== "") lines.push(board)
  if (excerpt !== "") lines.push("", excerpt)
  return lines.join("\n")
}

function parseThemeColors(raw) {
  var lines = String(raw || "").split("\n")
  var colors = {}
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
    if (match) colors[match[1]] = match[2]
  }
  return colors
}

function notificationTypeIcon(type) {
  var value = String(type || "").toLowerCase()
  if (value === "mention") return "󰀓"
  if (value === "event") return "󰆉"
  return "󰍡"
}

var MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

function notificationTime(timestampMs, nowMs) {
  var value = Number(timestampMs || 0)
  if (!isFinite(value) || value <= 0) return ""
  var now = nowMs === undefined ? Date.now() : Number(nowMs)
  var date = new Date(value)
  var ref = new Date(now)
  if (date.getFullYear() === ref.getFullYear() && date.getMonth() === ref.getMonth() && date.getDate() === ref.getDate()) {
    var hours = date.getHours()
    var hour12 = hours % 12 === 0 ? 12 : hours % 12
    var minutes = date.getMinutes()
    return hour12 + ":" + (minutes < 10 ? "0" + minutes : minutes) + (hours >= 12 ? "pm" : "am")
  }
  var label = MONTH_NAMES[date.getMonth()] + " " + date.getDate()
  if (date.getFullYear() !== ref.getFullYear()) label += ", " + date.getFullYear()
  return label
}

function notificationMeta(item, nowMs) {
  if (!item) return ""
  var parts = []
  var age = notificationTime(item.timestampMs, nowMs)
  var creator = cleanText(item.creator || "")
  var board = cleanText(item.boardName || "")
  if (age !== "") parts.push(age)
  if (creator !== "") parts.push(creator)
  if (board !== "") parts.push(board)
  return parts.join(" • ")
}

function cleanText(value) {
  return String(value || "")
    .replace(/\\[nrt]/g, " ")
    .replace(/<br\s*\/?\s*>/gi, " ")
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, "\"")
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/\s+/g, " ")
    .trim()
}

function positiveInteger(value, fallback) {
  var number = parseInt(String(value), 10)
  return isFinite(number) && number > 0 ? number : fallback
}

if (typeof module !== "undefined") {
  module.exports = {
    parseIdentity: parseIdentity,
    interpretIdentity: interpretIdentity,
    setupGuide: setupGuide,
    friendlyCliError: friendlyCliError,
    parseNotifications: parseNotifications,
    sortNotifications: sortNotifications,
    filterNotifications: filterNotifications,
    unreadCount: unreadCount,
    openUrl: openUrl,
    cardLink: cardLink,
    parseCard: parseCard,
    parseComments: parseComments,
    agentPrompt: agentPrompt,
    parseThemeColors: parseThemeColors,
    notificationTypeIcon: notificationTypeIcon,
    notificationMeta: notificationMeta,
    cleanText: cleanText
  }
}
