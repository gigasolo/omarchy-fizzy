function parseJson(raw) {
  var text = String(raw || "").trim()
  if (text === "") return { ok: false, error: "The Fizzy CLI returned no data" }

  try {
    var parsed = JSON.parse(text)
    if (!parsed || typeof parsed !== "object") return { ok: false, error: "The Fizzy CLI returned invalid data" }
    if (parsed.ok === false) {
      return { ok: false, error: setupHint(parsed.error || parsed.message || "The Fizzy CLI request failed") }
    }
    return { ok: true, value: parsed }
  } catch (error) {
    return { ok: false, error: "Could not parse the Fizzy CLI response" }
  }
}

function setupHint(message) {
  var text = cleanText(message)
  if (/not authenticated|unauthenticated|unauthorized|no token|logged out/i.test(text))
    return "Not authenticated. Run fizzy setup."
  return text || "The Fizzy CLI request failed"
}

function parseIdentity(raw) {
  var result = parseJson(raw)
  if (!result.ok) return { ok: false, error: result.error, account: null, user: null }

  var data = result.value.data || {}
  var accounts = Array.isArray(data.accounts) ? data.accounts : []
  var first = accounts[0]
  if (!first || !first.id) {
    return { ok: false, error: "No Fizzy account found. Run fizzy setup.", account: null, user: null }
  }

  var user = first.user || data.user || {}
  return {
    ok: true,
    error: "",
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

function parseProfiles(raw) {
  var result = parseJson(raw)
  if (!result.ok) return { ok: false, error: result.error, profiles: [] }

  var data = Array.isArray(result.value.data) ? result.value.data : []
  var profiles = []
  for (var i = 0; i < data.length; i++) {
    var entry = data[i] || {}
    var name = String(entry.profile || "").trim()
    if (name === "" || entry.has_token !== true) continue
    profiles.push({
      profile: name,
      account: cleanText(entry.account || name),
      active: entry.active === true,
      baseUrl: String(entry.base_url || entry.baseUrl || "")
    })
  }
  return { ok: true, error: "", profiles: profiles }
}

function parseNotifications(raw, limit, context) {
  var result = parseJson(raw)
  if (!result.ok) return { ok: false, error: result.error, items: [] }

  var data = result.value.data
  var source = []
  if (Array.isArray(data)) source = data
  else if (data && Array.isArray(data.notifications)) source = data.notifications

  var items = []
  for (var i = 0; i < source.length; i++) {
    var item = normalizeNotification(source[i], context)
    if (item) items.push(item)
  }

  items = sortNotifications(items)
  var count = positiveInteger(limit, 40)
  if (items.length > count) items = items.slice(0, count)
  return { ok: true, error: "", items: items }
}

function normalizeNotification(value, context) {
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

  var profileContext = context && typeof context === "object" ? context : {}
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
    unreadCount: positiveInteger(item.unread_count, item.read === true ? 0 : 1),
    profile: String(profileContext.profile || ""),
    accountName: cleanText(profileContext.accountName || "")
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

function filterNotifications(items, profile, state) {
  var source = Array.isArray(items) ? items : []
  var selectedProfile = String(profile || "")
  var selected = String(state || "all")
  return source.filter(function(item) {
    if (selectedProfile !== "" && String(item.profile || "") !== selectedProfile) return false
    if (selected === "unread") return item.unread === true
    if (selected === "previous") return item.unread !== true
    return true
  })
}

function accountFilterOptions(profiles) {
  var options = [{ value: "", label: "All accounts" }]
  var source = Array.isArray(profiles) ? profiles.slice() : []
  source.sort(function(a, b) {
    return cleanText(a.accountName || a.account || a.profile || "").toLowerCase().localeCompare(
      cleanText(b.accountName || b.account || b.profile || "").toLowerCase())
  })
  for (var i = 0; i < source.length; i++) {
    var profile = source[i] || {}
    var value = String(profile.profile || "")
    if (value === "") continue
    options.push({
      value: value,
      label: cleanText(profile.accountName || profile.account || value)
    })
  }
  return options
}

function fizzyArgs(profile, args) {
  var command = ["fizzy"]
  var name = String(profile || "").trim()
  if (name !== "") {
    command.push("--profile")
    command.push(name)
  }
  var rest = Array.isArray(args) ? args : []
  for (var i = 0; i < rest.length; i++) command.push(rest[i])
  return command
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

function notificationMeta(item, nowMs, showAccount) {
  if (!item) return ""
  var parts = []
  var age = notificationTime(item.timestampMs, nowMs)
  var creator = cleanText(item.creator || "")
  var board = cleanText(item.boardName || "")
  var account = cleanText(item.accountName || "")
  if (age !== "") parts.push(age)
  if (creator !== "") parts.push(creator)
  if (board !== "") {
    parts.push(showAccount === true && account !== "" ? board + " (" + account + ")" : board)
  } else if (showAccount === true && account !== "") {
    parts.push(account)
  }
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
    parseProfiles: parseProfiles,
    parseNotifications: parseNotifications,
    sortNotifications: sortNotifications,
    filterNotifications: filterNotifications,
    accountFilterOptions: accountFilterOptions,
    fizzyArgs: fizzyArgs,
    unreadCount: unreadCount,
    openUrl: openUrl,
    parseThemeColors: parseThemeColors,
    notificationTypeIcon: notificationTypeIcon,
    notificationMeta: notificationMeta,
    cleanText: cleanText
  }
}
