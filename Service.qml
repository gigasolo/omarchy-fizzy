import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property bool panelOpen: false
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
  readonly property int cliOutputLimit: Model.cliOutputLimit()

  property bool _cliReady: false
  property bool _fizzyOnPath: false
  property int _probeGen: 0
  property int _whichGen: 0
  property int _identityGen: 0
  property int _listGen: 0
  property bool _recoverWhich: false
  property string _identityOutput: ""
  property string _identityError: ""
  property bool _identityOverflow: false
  property string _listOutput: ""
  property string _listError: ""
  property bool _listOverflow: false
  property var _readQueue: []
  property var _readingNotification: null
  property string _readOutput: ""
  property string _readError: ""
  property bool _readOverflow: false
  property bool _readAll: false
  property var peek: null
  property var _peekCache: Model.emptyCache()
  property var _peekItem: null
  readonly property var peekItem: _peekItem
  property var _pendingPeekItem: null
  property bool _peekAbandoned: false
  property int _peekCardNumber: 0
  property string _cardShowOutput: ""
  property string _cardShowError: ""
  property bool _cardShowOverflow: false
  property string _commentOutput: ""
  property string _commentError: ""
  property bool _commentOverflow: false

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

  function stopProcess(proc) {
    if (proc && proc.running) proc.running = false
  }

  function takeBounded(current, chunk, proc, overflowFlagSetter) {
    var result = Model.appendBounded(current, chunk, root.cliOutputLimit)
    if (result.overflow) {
      overflowFlagSetter()
      stopProcess(proc)
    }
    return result.text
  }

  function refreshIfStale() {
    var updatedAt = lastUpdated instanceof Date ? lastUpdated.getTime() : 0
    if (updatedAt <= 0 || Date.now() - updatedAt >= refreshIntervalSec * 1000) refresh()
  }

  function beginProbe() {
    _probeGen += 1
    return _probeGen
  }

  function probeCurrent(gen) {
    return gen === _probeGen
  }

  function probeBusy() {
    return whichProcess.running || identityProcess.running || listProcess.running
  }

  function tryRecoverWhich() {
    if (!_recoverWhich || probeBusy()) return
    _recoverWhich = false
    refreshing = true
    lastError = lastError || "Timed out talking to Fizzy"
    startWhich()
  }

  function refresh() {
    if (whichProcess.running || identityProcess.running || listProcess.running) return
    refreshing = true
    lastError = ""
    beginProbe()
    probeWatchdog.restart()
    if (_cliReady && installed && authenticated) {
      startNotificationList()
      return
    }
    startWhich()
  }

  function startWhich() {
    _whichGen = _probeGen
    _identityOutput = ""
    _identityError = ""
    _identityOverflow = false
    // `fizzy` with no binary can hang a Quickshell Process.
    whichProcess.command = ["which", "fizzy"]
    whichProcess.running = true
    probeWatchdog.restart()
  }

  function startIdentity() {
    _identityGen = _probeGen
    _identityOutput = ""
    _identityError = ""
    _identityOverflow = false
    identityProcess.command = ["fizzy", "identity", "show", "--json"]
    identityProcess.running = true
    probeWatchdog.restart()
  }

  function startNotificationList() {
    _listGen = _probeGen
    _listOutput = ""
    _listError = ""
    _listOverflow = false
    listProcess.command = ["fizzy", "notification", "list", "--json"]
    listProcess.running = true
    probeWatchdog.restart()
  }

  function applyIdentityResult(raw, exitCode) {
    var parsed = Model.interpretIdentity(raw, exitCode)
    installed = parsed.installed
    authenticated = parsed.authenticated
    setupKind = parsed.setupKind
    if (!parsed.ok) {
      _cliReady = false
      if (parsed.setupKind === "missing_cli") _fizzyOnPath = false
      lastError = parsed.error
      refreshing = false
      probeWatchdog.stop()
      return
    }

    account = parsed.account
    user = parsed.user
    lastError = ""
    startNotificationList()
  }

  function applyCliFailure(raw, exitCode, fallback) {
    var parsed = Model.interpretCliFailure(raw, exitCode)
    if (parsed.kind === "missing_cli") {
      _cliReady = false
      _fizzyOnPath = false
      installed = false
      authenticated = false
      setupKind = "missing_cli"
      lastError = ""
      return
    }
    if (parsed.kind === "auth_required") {
      _cliReady = false
      authenticated = false
      setupKind = "auth_required"
      lastError = ""
      return
    }
    lastError = conciseError(parsed.error || fallback, fallback)
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
    _cliReady = true
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
    Quickshell.execDetached(["wl-copy", "--", url])
    actionStatus = "Copied card link"
    actionStatusTimer.restart()
  }

  function sendToAgent(item) {
    if (!item) return false
    if (Model.cardLink(item) === "") {
      actionStatus = "No card link to send"
      actionStatusTimer.restart()
      return false
    }
    var peekCard = peek && peek.cardNumber === item.cardNumber ? peek.card : null
    Quickshell.execDetached(["omarchy-agent-prompt", Model.agentPrompt(item, peekCard)])
    actionStatus = "Opened in agent"
    actionStatusTimer.restart()
    return true
  }

  function closePeek() {
    _peekAbandoned = true
    _pendingPeekItem = null
    peek = null
    _peekItem = null
    _peekCardNumber = 0
    peekWatchdog.stop()
    stopProcess(cardShowProcess)
    stopProcess(commentListProcess)
  }

  function loadPeek(item) {
    if (!panelOpen || !item) return
    if (cardShowProcess.running || commentListProcess.running) {
      _pendingPeekItem = item
      stopProcess(cardShowProcess)
      stopProcess(commentListProcess)
      return
    }
    beginPeek(item)
  }

  function beginPeek(item) {
    if (!panelOpen || !item) return
    var number = Number(item.cardNumber || 0)
    if (!number || Model.safeCliToken(number) === "") {
      peek = { loading: false, error: "This notification has no card", card: null, comments: [], cardNumber: 0 }
      return
    }
    _pendingPeekItem = null
    _peekAbandoned = false
    _peekItem = item
    _peekCardNumber = number
    var cached = Model.peekCacheGet(_peekCache, number)
    if (cached) {
      peek = cached
      _peekCache = Model.peekCacheTouch(_peekCache, number, Model.peekCacheLimit())
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
    _cardShowOutput = ""
    _cardShowError = ""
    _cardShowOverflow = false
    cardShowProcess.command = ["fizzy", "card", "show", Model.safeCliToken(number), "--json"]
    cardShowProcess.running = true
    peekWatchdog.restart()
  }

  function drainPendingPeek() {
    if (!panelOpen) {
      _pendingPeekItem = null
      return false
    }
    var item = _pendingPeekItem
    _pendingPeekItem = null
    if (!item) return false
    beginPeek(item)
    return true
  }

  function failedPeek(message) {
    _peekAbandoned = true
    peek = {
      loading: false,
      error: conciseError(message, "Could not load the card"),
      card: null,
      comments: [],
      cardNumber: _peekCardNumber
    }
    peekWatchdog.stop()
  }

  function cachePeek(nextPeek) {
    peek = nextPeek
    peekWatchdog.stop()
    if (!nextPeek || nextPeek.loading || nextPeek.error || !nextPeek.cardNumber) return
    _peekCache = Model.peekCachePut(_peekCache, nextPeek.cardNumber, nextPeek, Model.peekCacheLimit())
  }

  function markRead(item) {
    if (!item || !item.unread) return
    if (Model.safeCliToken(item.id) === "") return
    setReadOptimistically(item)
    var queue = _readQueue.slice()
    queue.push(item)
    _readQueue = queue
    runNextRead()
  }

  function markAllRead() {
    if (unreadCount === 0 || readProcess.running) return
    notifications = Model.withAllRead(notifications)
    unreadCount = 0
    _readAll = true
    _readingNotification = null
    _readOutput = ""
    _readError = ""
    _readOverflow = false
    actionStatusTimer.stop()
    actionStatus = "Marking all as read…"
    readProcess.command = ["fizzy", "notification", "read-all", "--json"]
    readProcess.running = true
    armActionWatchdog()
  }

  function setReadOptimistically(item) {
    notifications = Model.withItemRead(notifications, item.id)
    unreadCount = Model.unreadCount(notifications)
  }

  function runNextRead() {
    if (readProcess.running || _readQueue.length === 0) return
    var queue = _readQueue.slice()
    _readingNotification = queue.shift()
    _readQueue = queue
    var id = Model.safeCliToken(_readingNotification && _readingNotification.id)
    if (id === "") {
      _readingNotification = null
      if (_readQueue.length > 0) runNextRead()
      return
    }
    _readAll = false
    _readOutput = ""
    _readError = ""
    _readOverflow = false
    actionStatusTimer.stop()
    actionStatus = "Marking notification as read…"
    readProcess.command = ["fizzy", "notification", "read", id, "--json"]
    readProcess.running = true
    armActionWatchdog()
  }

  function actionBusy() {
    return readProcess.running
  }

  function armActionWatchdog() {
    actionWatchdog.restart()
  }

  function disarmActionWatchdog() {
    if (!actionBusy()) actionWatchdog.stop()
  }

  function finishRead(exitCode, stdout, stderr) {
    disarmActionWatchdog()
    if (_readOverflow) {
      lastError = "Fizzy CLI output was too large"
      actionStatus = lastError
    } else if (exitCode !== 0) {
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
      var wasReady = root._cliReady
      var pathKnown = root._fizzyOnPath || wasReady
      root.beginProbe()
      root.stopProcess(whichProcess)
      root.stopProcess(identityProcess)
      root.stopProcess(listProcess)
      root.refreshing = false
      root.lastError = "Timed out talking to Fizzy"
      if (wasReady) {
        root._cliReady = false
        root._recoverWhich = true
        root.tryRecoverWhich()
        return
      }
      if (pathKnown) return
      root.applyIdentityResult("", 127)
    }
  }

  Timer {
    id: peekWatchdog
    interval: 8000
    repeat: false
    onTriggered: {
      root.stopProcess(cardShowProcess)
      root.stopProcess(commentListProcess)
      if (root.peek && root.peek.loading) root.failedPeek("Timed out loading the card")
    }
  }

  Timer {
    id: actionWatchdog
    interval: 8000
    repeat: false
    onTriggered: {
      root.stopProcess(readProcess)
      if (root.actionStatus.indexOf("Marking") === 0) {
        root.lastError = "Timed out talking to Fizzy"
        root.actionStatus = root.lastError
        actionStatusTimer.restart()
      }
    }
  }

  Process {
    id: whichProcess
    running: false
    command: []
    onExited: function(exitCode) {
      if (!root.probeCurrent(root._whichGen)) {
        root.tryRecoverWhich()
        return
      }
      if (exitCode !== 0) {
        root._fizzyOnPath = false
        root.applyIdentityResult("", 127)
        return
      }
      root._fizzyOnPath = true
      root.startIdentity()
    }
  }

  Process {
    id: identityProcess
    running: false
    command: []
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        root._identityOutput = root.takeBounded(root._identityOutput, chunk, identityProcess, function() { root._identityOverflow = true })
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        root._identityError = root.takeBounded(root._identityError, chunk, identityProcess, function() { root._identityOverflow = true })
      }
    }
    onExited: function(exitCode) {
      if (!root.probeCurrent(root._identityGen)) {
        root.tryRecoverWhich()
        return
      }
      if (root._identityOverflow) {
        root._cliReady = false
        root.lastError = "Fizzy CLI output was too large"
        root.refreshing = false
        probeWatchdog.stop()
        return
      }
      root.applyIdentityResult(root._identityOutput || root._identityError, exitCode)
    }
  }

  Process {
    id: listProcess
    running: false
    command: []
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        root._listOutput = root.takeBounded(root._listOutput, chunk, listProcess, function() { root._listOverflow = true })
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        root._listError = root.takeBounded(root._listError, chunk, listProcess, function() { root._listOverflow = true })
      }
    }
    onExited: function(exitCode) {
      if (!root.probeCurrent(root._listGen)) {
        root.tryRecoverWhich()
        return
      }
      if (root._listOverflow) {
        root.lastError = "Fizzy CLI output was too large"
        root.refreshing = false
        probeWatchdog.stop()
        return
      }
      if (exitCode !== 0) {
        root.applyCliFailure(root._listError || root._listOutput, exitCode, "Could not list Fizzy notifications")
        root.refreshing = false
        probeWatchdog.stop()
        return
      }

      var parsed = Model.parseNotifications(root._listOutput, root.maxItems)
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
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        root._readOutput = root.takeBounded(root._readOutput, chunk, readProcess, function() { root._readOverflow = true })
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        root._readError = root.takeBounded(root._readError, chunk, readProcess, function() { root._readOverflow = true })
      }
    }
    onExited: function(exitCode) {
      root.finishRead(exitCode, root._readOutput, root._readError)
    }
  }

  Process {
    id: cardShowProcess
    running: false
    command: []
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        root._cardShowOutput = root.takeBounded(root._cardShowOutput, chunk, cardShowProcess, function() { root._cardShowOverflow = true })
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        root._cardShowError = root.takeBounded(root._cardShowError, chunk, cardShowProcess, function() { root._cardShowOverflow = true })
      }
    }
    onExited: function(exitCode) {
      if (root.drainPendingPeek()) return
      if (root._peekAbandoned || !root.panelOpen || root._peekCardNumber === 0) return
      if (root._cardShowOverflow) {
        root.failedPeek("Fizzy CLI output was too large")
        return
      }
      if (exitCode !== 0) {
        root.failedPeek(Model.friendlyCliError(root._cardShowError || root._cardShowOutput, "Could not load the card"))
        return
      }
      var parsed = Model.parseCard(root._cardShowOutput)
      if (!parsed.ok) {
        root.failedPeek(parsed.error)
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
      root._commentOverflow = false
      commentListProcess.command = ["fizzy", "comment", "list", "--card", Model.safeCliToken(root._peekCardNumber), "--limit", "8", "--json"]
      commentListProcess.running = true
      peekWatchdog.restart()
    }
  }

  Process {
    id: commentListProcess
    running: false
    command: []
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        root._commentOutput = root.takeBounded(root._commentOutput, chunk, commentListProcess, function() { root._commentOverflow = true })
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        root._commentError = root.takeBounded(root._commentError, chunk, commentListProcess, function() { root._commentOverflow = true })
      }
    }
    onExited: function(exitCode) {
      if (root.drainPendingPeek()) return
      if (root._peekAbandoned || !root.panelOpen || root._peekCardNumber === 0) return
      var card = root.peek && root.peek.card ? root.peek.card : null
      var comments = []
      var error = ""
      if (root._commentOverflow) error = "Fizzy CLI output was too large"
      else if (exitCode !== 0) error = root.conciseError(Model.friendlyCliError(root._commentError || root._commentOutput, "Could not load comments"))
      else {
        var parsed = Model.parseComments(root._commentOutput, 8)
        if (!parsed.ok) error = parsed.error
        else comments = parsed.items
      }
      root.cachePeek({
        loading: false,
        error: error,
        card: card,
        comments: comments,
        cardNumber: root._peekCardNumber,
        title: card && card.title ? card.title : (root.peek && root.peek.title ? root.peek.title : ""),
        boardName: card && card.boardName ? card.boardName : (root.peek && root.peek.boardName ? root.peek.boardName : "")
      })
    }
  }

}
