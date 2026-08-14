import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property bool refreshing: false
  property bool installed: true
  property bool authenticated: false
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
    if (refreshing || identityProcess.running || listProcess.running) return
    refreshing = true
    installed = true
    lastError = ""
    _identityOutput = ""
    _identityError = ""
    identityProcess.command = ["fizzy", "identity", "show", "--json"]
    identityProcess.running = true
  }

  function finishRefresh(items) {
    notifications = Model.sortNotifications(items)
    unreadCount = Model.unreadCount(notifications)
    refreshing = false
    lastUpdated = new Date()
  }

  function openNotification(item) {
    if (!item) return
    var url = Model.openUrl(item)
    if (url) Qt.openUrlExternally(url)
    if (item.unread) markRead(item)
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
      lastError = conciseError(stderr || stdout, "Could not mark the notification as read")
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
      if (exitCode !== 0) {
        root.installed = exitCode !== 127
        root.authenticated = false
        root.lastError = root.conciseError(stderr || stdout, root.installed ? "Run fizzy setup" : "Fizzy CLI is not installed")
        root.refreshing = false
        return
      }

      var parsed = Model.parseIdentity(stdout)
      if (!parsed.ok) {
        root.authenticated = false
        root.lastError = parsed.error
        root.refreshing = false
        return
      }

      root.account = parsed.account
      root.user = parsed.user
      root.authenticated = true
      root._listOutput = ""
      root._listError = ""
      listProcess.command = ["fizzy", "notification", "list", "--json"]
      listProcess.running = true
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
        root.lastError = root.conciseError(stderr || stdout, "Could not list Fizzy notifications")
        root.refreshing = false
        return
      }

      var parsed = Model.parseNotifications(stdout, root.maxItems)
      if (!parsed.ok) {
        root.lastError = parsed.error
        root.refreshing = false
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
}
