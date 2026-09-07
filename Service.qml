import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property bool refreshing: false
  property bool installed: true
  property bool authenticated: false
  property string setupKind: ""
  property var account: null
  property var user: null
  property var notifications: []
  property int unreadCount: 0
  property date lastUpdated: new Date(0)
  property string lastError: ""
  property string actionStatus: ""

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 300, 60, 3600)
  readonly property int maxItems: intSetting("maxItems", 40, 5, 100)
  readonly property string accountName: account && account.name ? account.name : ""
  readonly property string userName: user && user.name ? user.name : ""

  property string _identityOutput: ""
  property string _identityError: ""
  property string _listOutput: ""
  property string _listError: ""
  property var _readQueue: []
  property var _readingNotification: null
  property string _readOutput: ""
  property string _readError: ""
  property bool _readAll: false
  property var peek: null
  property var _peekCache: ({})
  property var _peekItem: null
  property int _peekCardNumber: 0
  property string _cardShowOutput: ""
  property string _cardShowError: ""
  property string _commentOutput: ""
  property string _commentError: ""
  property string _cardReadOutput: ""
  property string _cardReadError: ""

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, minimum, maximum) {
    var value = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(value)) value = fallback
    return Math.max(minimum, Math.min(maximum, value))
  }

  function conciseError(value, fallback) {
    var text = String(value || fallback || "Fizzy request failed").replace(/\s+/g, " ").trim()
    return text.length > 180 ? text.substring(0, 177) + "…" : text
  }

  function refreshIfStale() {
    var updatedAt = lastUpdated instanceof Date ? lastUpdated.getTime() : 0
    if (updatedAt <= 0 || Date.now() - updatedAt >= refreshIntervalSec * 1000) refresh()
  }

  function refresh() {
    if (whichProcess.running || identityProcess.running || listProcess.running) return
    refreshing = true
    lastError = ""
    _identityOutput = ""
    _identityError = ""
    whichProcess.command = ["which", "fizzy"]
    whichProcess.running = true
    probeWatchdog.restart()
  }

  function applyIdentityResult(raw, exitCode) {
    var parsed = Model.interpretIdentity(raw, exitCode)
    installed = parsed.installed
    authenticated = parsed.authenticated
    setupKind = parsed.setupKind
    if (!parsed.ok) {
      lastError = parsed.error
      refreshing = false
      probeWatchdog.stop()
      return
    }

    account = parsed.account
    user = parsed.user
    lastError = ""
    _listOutput = ""
    _listError = ""
    listProcess.command = ["fizzy", "notification", "list", "--json"]
    listProcess.running = true
  }

  function beginSetup() {
    if (setupLaunchLock.running) return
    setupLaunchLock.restart()
    if (setupKind === "missing_cli" || !installed) {
      Quickshell.execDetached([
        "omarchy-launch-floating-terminal-with-presentation",
        "echo 'Installing Fizzy CLI...'; omarchy pkg aur add fizzy-cli && echo && fizzy setup"
      ])
      actionStatus = "Opened install in a terminal"
    } else {
      Quickshell.execDetached([
        "omarchy-launch-tui",
        "--app-id=org.omarchy.fizzy-setup",
        "fizzy",
        "setup"
      ])
      actionStatus = "Opened fizzy setup"
    }
    actionStatusTimer.restart()
  }

  function finishRefresh(items) {
    notifications = Model.sortNotifications(items)
    unreadCount = Model.unreadCount(notifications)
    refreshing = false
    lastUpdated = new Date()
    probeWatchdog.stop()
  }

  function openNotification(item) {
    if (!item) return
    var url = Model.openUrl(item)
    if (url) Qt.openUrlExternally(url)
    if (item.unread) markRead(item)
  }

  function copyCardLink(item) {
    var url = Model.cardLink(item)
    if (url === "") {
      actionStatus = "No card link to copy"
      actionStatusTimer.restart()
      return
    }
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(url) + " | wl-copy"])
    actionStatus = "Copied card link"
    actionStatusTimer.restart()
  }

  function sendToAgent(item) {
    if (!item) return
    var peekCard = peek && peek.cardNumber === item.cardNumber ? peek.card : null
    var prompt = Model.agentPrompt(item, peekCard)
    Quickshell.execDetached(["omarchy-agent-prompt", prompt])
    actionStatus = "Opened in agent"
    actionStatusTimer.restart()
  }

  function markCardRead(item) {
    if (!item || !item.cardNumber || cardReadProcess.running) return
    _cardReadOutput = ""
    _cardReadError = ""
    actionStatusTimer.stop()
    actionStatus = "Marking card as read…"
    cardReadProcess.command = ["fizzy", "card", "mark-read", String(item.cardNumber), "--json"]
    cardReadProcess.running = true
  }

  function closePeek() {
    peek = null
    _peekItem = null
    _peekCardNumber = 0
  }

  function loadPeek(item) {
    if (!item) return
    var number = Number(item.cardNumber || 0)
    if (!number) {
      peek = { loading: false, error: "This notification has no card", card: null, comments: [], cardNumber: 0 }
      return
    }
    _peekItem = item
    _peekCardNumber = number
    var cached = _peekCache[String(number)]
    if (cached) {
      peek = cached
      if (item.unread) markRead(item)
      return
    }
    peek = {
      loading: true,
      error: "",
      card: null,
      comments: [],
      cardNumber: number,
      title: item.title,
      boardName: item.boardName
    }
    if (item.unread) markRead(item)
    _cardShowOutput = ""
    _cardShowError = ""
    cardShowProcess.command = ["fizzy", "card", "show", String(number), "--json"]
    cardShowProcess.running = true
  }

  function cachePeek(nextPeek) {
    peek = nextPeek
    if (nextPeek && nextPeek.cardNumber) {
      var cache = {}
      for (var key in _peekCache) cache[key] = _peekCache[key]
      cache[String(nextPeek.cardNumber)] = nextPeek
      _peekCache = cache
    }
  }

  function markRead(item) {
    if (!item || !item.unread) return
    setReadOptimistically(item)
    var queue = _readQueue.slice()
    queue.push(item)
    _readQueue = queue
    runNextRead()
  }

  function markAllRead() {
    if (unreadCount === 0 || readProcess.running) return
    var changed = []
    for (var i = 0; i < notifications.length; i++) {
      var existing = notifications[i]
      var replacement = {}
      for (var key in existing) replacement[key] = existing[key]
      replacement.unread = false
      replacement.unreadCount = 0
      changed.push(replacement)
    }
    notifications = changed
    unreadCount = 0
    _readAll = true
    _readingNotification = null
    _readOutput = ""
    _readError = ""
    actionStatusTimer.stop()
    actionStatus = "Marking all as read…"
    readProcess.command = ["fizzy", "notification", "read-all", "--json"]
    readProcess.running = true
  }

  function setReadOptimistically(item) {
    var changed = []
    for (var i = 0; i < notifications.length; i++) {
      var existing = notifications[i]
      if (existing.id === item.id) {
        var replacement = {}
        for (var key in existing) replacement[key] = existing[key]
        replacement.unread = false
        replacement.unreadCount = 0
        changed.push(replacement)
      } else {
        changed.push(existing)
      }
    }
    notifications = changed
    unreadCount = Model.unreadCount(notifications)
  }

  function runNextRead() {
    if (readProcess.running || _readQueue.length === 0) return
    var queue = _readQueue.slice()
    _readingNotification = queue.shift()
    _readQueue = queue
    _readAll = false
    _readOutput = ""
    _readError = ""
    actionStatusTimer.stop()
    actionStatus = "Marking notification as read…"
    readProcess.command = ["fizzy", "notification", "read", String(_readingNotification.id), "--json"]
    readProcess.running = true
  }

  function finishRead(exitCode, stdout, stderr) {
    if (exitCode !== 0) {
      lastError = conciseError(Model.friendlyCliError(stderr || stdout, "Could not mark the notification as read"))
      actionStatus = lastError
    } else {
      actionStatus = _readAll ? "Marked all as read" : "Marked as read"
    }
    actionStatusTimer.restart()
    _readingNotification = null
    _readAll = false
    if (_readQueue.length > 0) runNextRead()
    else refreshAfterRead.restart()
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: refreshAfterRead
    interval: 1200
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    id: actionStatusTimer
    interval: 2200
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  Timer {
    id: setupLaunchLock
    interval: 1500
    repeat: false
  }

  Timer {
    id: probeWatchdog
    interval: 8000
    repeat: false
    onTriggered: {
      if (!root.refreshing) return
      if (whichProcess.running) whichProcess.running = false
      if (identityProcess.running) identityProcess.running = false
      if (listProcess.running) listProcess.running = false
      if (root.setupKind === "") root.applyIdentityResult("", 127)
      else root.refreshing = false
    }
  }

  Process {
    id: whichProcess
    running: false
    command: []
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.applyIdentityResult("", exitCode)
        return
      }
      root._identityOutput = ""
      root._identityError = ""
      identityProcess.command = ["fizzy", "identity", "show", "--json"]
      identityProcess.running = true
    }
  }

  Process {
    id: identityProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: identityStdout
      waitForEnd: true
      onStreamFinished: root._identityOutput = text
    }
    stderr: StdioCollector {
      id: identityStderr
      waitForEnd: true
      onStreamFinished: root._identityError = text
    }
    onExited: function(exitCode) {
      var stdout = String(identityStdout.text || root._identityOutput || "")
      var stderr = String(identityStderr.text || root._identityError || "")
      root.applyIdentityResult(stdout || stderr, exitCode)
    }
  }

  Process {
    id: listProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: listStdout
      waitForEnd: true
      onStreamFinished: root._listOutput = text
    }
    stderr: StdioCollector {
      id: listStderr
      waitForEnd: true
      onStreamFinished: root._listError = text
    }
    onExited: function(exitCode) {
      var stdout = String(listStdout.text || root._listOutput || "")
      var stderr = String(listStderr.text || root._listError || "")
      if (exitCode !== 0) {
        root.lastError = root.conciseError(Model.friendlyCliError(stderr || stdout, "Could not list Fizzy notifications"))
        root.refreshing = false
        probeWatchdog.stop()
        return
      }

      var parsed = Model.parseNotifications(stdout, root.maxItems)
      if (!parsed.ok) {
        root.lastError = parsed.error
        root.refreshing = false
        probeWatchdog.stop()
        return
      }
      root.finishRefresh(parsed.items)
    }
  }

  Process {
    id: readProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: readStdout
      waitForEnd: true
      onStreamFinished: root._readOutput = text
    }
    stderr: StdioCollector {
      id: readStderr
      waitForEnd: true
      onStreamFinished: root._readError = text
    }
    onExited: function(exitCode) {
      var stdout = String(readStdout.text || root._readOutput || "")
      var stderr = String(readStderr.text || root._readError || "")
      root.finishRead(exitCode, stdout, stderr)
    }
  }

  Process {
    id: cardShowProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: cardShowStdout
      waitForEnd: true
      onStreamFinished: root._cardShowOutput = text
    }
    stderr: StdioCollector {
      id: cardShowStderr
      waitForEnd: true
      onStreamFinished: root._cardShowError = text
    }
    onExited: function(exitCode) {
      var stdout = String(cardShowStdout.text || root._cardShowOutput || "")
      var stderr = String(cardShowStderr.text || root._cardShowError || "")
      if (exitCode !== 0) {
        root.peek = {
          loading: false,
          error: root.conciseError(Model.friendlyCliError(stderr || stdout, "Could not load the card")),
          card: null,
          comments: [],
          cardNumber: root._peekCardNumber
        }
        return
      }
      var parsed = Model.parseCard(stdout)
      if (!parsed.ok) {
        root.peek = {
          loading: false,
          error: parsed.error,
          card: null,
          comments: [],
          cardNumber: root._peekCardNumber
        }
        return
      }
      root.peek = {
        loading: true,
        error: "",
        card: parsed.card,
        comments: [],
        cardNumber: root._peekCardNumber,
        title: parsed.card.title,
        boardName: parsed.card.boardName
      }
      root._commentOutput = ""
      root._commentError = ""
      commentListProcess.command = ["fizzy", "comment", "list", "--card", String(root._peekCardNumber), "--json"]
      commentListProcess.running = true
    }
  }

  Process {
    id: commentListProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: commentListStdout
      waitForEnd: true
      onStreamFinished: root._commentOutput = text
    }
    stderr: StdioCollector {
      id: commentListStderr
      waitForEnd: true
      onStreamFinished: root._commentError = text
    }
    onExited: function(exitCode) {
      var stdout = String(commentListStdout.text || root._commentOutput || "")
      var stderr = String(commentListStderr.text || root._commentError || "")
      var card = root.peek && root.peek.card ? root.peek.card : null
      var comments = []
      var error = ""
      if (exitCode !== 0) error = root.conciseError(Model.friendlyCliError(stderr || stdout, "Could not load comments"))
      else {
        var parsed = Model.parseComments(stdout, 8)
        if (!parsed.ok) error = parsed.error
        else comments = parsed.items
      }
      root.cachePeek({
        loading: false,
        error: error,
        card: card,
        comments: comments,
        cardNumber: root._peekCardNumber,
        title: card ? card.title : "",
        boardName: card ? card.boardName : ""
      })
    }
  }

  Process {
    id: cardReadProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: cardReadStdout
      waitForEnd: true
      onStreamFinished: root._cardReadOutput = text
    }
    stderr: StdioCollector {
      id: cardReadStderr
      waitForEnd: true
      onStreamFinished: root._cardReadError = text
    }
    onExited: function(exitCode) {
      var stdout = String(cardReadStdout.text || root._cardReadOutput || "")
      var stderr = String(cardReadStderr.text || root._cardReadError || "")
      if (exitCode !== 0) {
        root.lastError = root.conciseError(Model.friendlyCliError(stderr || stdout, "Could not mark the card as read"))
        root.actionStatus = root.lastError
      } else {
        root.actionStatus = "Marked card as read"
      }
      actionStatusTimer.restart()
    }
  }
}
