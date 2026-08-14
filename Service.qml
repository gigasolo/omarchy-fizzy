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
  property var profiles: []
  property var account: null
  property var user: null
  property var notifications: []
  property int unreadCount: 0
  property date lastUpdated: new Date(0)
  property string lastError: ""
  property string actionStatus: ""

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 300, 60, 3600)
  readonly property int maxItems: intSetting("maxItems", 40, 5, 100)
  readonly property int accountCount: profiles.length
  readonly property string accountName: {
    if (accountCount === 1) return profiles[0].accountName || profiles[0].account || ""
    if (accountCount > 1) return accountCount + " accounts"
    return account && account.name ? account.name : ""
  }
  readonly property string userName: user && user.name ? user.name : ""

  property string _profilesOutput: ""
  property string _profilesError: ""
  property string _identityOutput: ""
  property string _identityError: ""
  property string _listOutput: ""
  property string _listError: ""
  property var _fetchProfiles: []
  property int _fetchIndex: 0
  property var _currentProfile: null
  property var _resolvedProfiles: []
  property var _fetchedNotifications: []
  property var _partialErrors: []
  property var _readQueue: []
  property var _readingJob: null
  property string _readOutput: ""
  property string _readError: ""

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
    if (refreshing || profilesProcess.running || identityProcess.running || listProcess.running) return
    refreshing = true
    installed = true
    lastError = ""
    _partialErrors = []
    _profilesOutput = ""
    _profilesError = ""
    profilesProcess.command = ["fizzy", "auth", "list", "--json"]
    profilesProcess.running = true
  }

  function beginProfileFetch(nextProfiles) {
    _fetchProfiles = nextProfiles
    _fetchIndex = 0
    _resolvedProfiles = []
    _fetchedNotifications = []
    fetchNextProfile()
  }

  function fetchNextProfile() {
    if (_fetchIndex >= _fetchProfiles.length) {
      finishRefresh()
      return
    }
    _currentProfile = _fetchProfiles[_fetchIndex]
    _identityOutput = ""
    _identityError = ""
    identityProcess.command = Model.fizzyArgs(_currentProfile.profile, ["identity", "show", "--json"])
    identityProcess.running = true
  }

  function finishRefresh() {
    profiles = _resolvedProfiles
    if (profiles.length > 0) {
      account = {
        id: profiles[0].account || "",
        name: profiles[0].accountName || profiles[0].account || "",
        slug: ""
      }
      authenticated = true
    }
    notifications = Model.sortNotifications(_fetchedNotifications)
    unreadCount = Model.unreadCount(notifications)
    refreshing = false
    lastUpdated = new Date()
    lastError = _partialErrors.length > 0 ? _partialErrors.join(" · ") : ""
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
    queue.push({ kind: "one", profile: item.profile || "", id: item.id })
    _readQueue = queue
    runNextRead()
  }

  function markAllRead(profile) {
    var selected = String(profile || "")
    var targets = {}
    for (var i = 0; i < notifications.length; i++) {
      var item = notifications[i]
      if (!item || item.unread !== true) continue
      if (selected !== "" && String(item.profile || "") !== selected) continue
      targets[String(item.profile || "")] = true
    }
    var names = Object.keys(targets)
    if (names.length === 0 || readProcess.running) return

    var changed = []
    for (var n = 0; n < notifications.length; n++) {
      var existing = notifications[n]
      var replacement = {}
      for (var key in existing) replacement[key] = existing[key]
      if (selected === "" || String(existing.profile || "") === selected) {
        replacement.unread = false
        replacement.unreadCount = 0
      }
      changed.push(replacement)
    }
    notifications = changed
    unreadCount = Model.unreadCount(notifications)

    var queue = _readQueue.slice()
    for (var t = 0; t < names.length; t++) queue.push({ kind: "all", profile: names[t] })
    _readQueue = queue
    runNextRead()
  }

  function setReadOptimistically(item) {
    var changed = []
    for (var i = 0; i < notifications.length; i++) {
      var existing = notifications[i]
      if (existing.id === item.id && String(existing.profile || "") === String(item.profile || "")) {
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
    _readingJob = queue.shift()
    _readQueue = queue
    _readOutput = ""
    _readError = ""
    actionStatusTimer.stop()
    actionStatus = _readingJob.kind === "all" ? "Marking all as read…" : "Marking notification as read…"
    if (_readingJob.kind === "all") {
      readProcess.command = Model.fizzyArgs(_readingJob.profile, ["notification", "read-all", "--json"])
    } else {
      readProcess.command = Model.fizzyArgs(_readingJob.profile, ["notification", "read", String(_readingJob.id), "--json"])
    }
    readProcess.running = true
  }

  function finishRead(exitCode, stdout, stderr) {
    if (exitCode !== 0) {
      lastError = conciseError(stderr || stdout, "Could not mark the notification as read")
      actionStatus = lastError
    } else {
      actionStatus = _readingJob && _readingJob.kind === "all" ? "Marked all as read" : "Marked as read"
    }
    actionStatusTimer.restart()
    _readingJob = null
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
    id: profilesProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: profilesStdout
      waitForEnd: true
      onStreamFinished: root._profilesOutput = text
    }
    stderr: StdioCollector {
      id: profilesStderr
      waitForEnd: true
      onStreamFinished: root._profilesError = text
    }
    onExited: function(exitCode) {
      var stdout = String(profilesStdout.text || root._profilesOutput || "")
      var stderr = String(profilesStderr.text || root._profilesError || "")
      if (exitCode !== 0) {
        root.installed = exitCode !== 127
        root.authenticated = false
        root.lastError = root.conciseError(stderr || stdout, root.installed ? "Run fizzy setup" : "Fizzy CLI is not installed")
        root.refreshing = false
        return
      }

      var parsed = Model.parseProfiles(stdout)
      if (!parsed.ok) {
        root.authenticated = false
        root.lastError = parsed.error
        root.refreshing = false
        return
      }
      if (parsed.profiles.length === 0) {
        root.authenticated = false
        root.lastError = "No Fizzy account found. Run fizzy setup."
        root.refreshing = false
        return
      }
      root.beginProfileFetch(parsed.profiles)
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
      var profile = root._currentProfile || { profile: "" }
      var stdout = String(identityStdout.text || root._identityOutput || "")
      var stderr = String(identityStderr.text || root._identityError || "")
      var accountName = profile.account || profile.profile || ""
      if (exitCode === 0) {
        var parsed = Model.parseIdentity(stdout)
        if (parsed.ok) {
          accountName = parsed.account.name || accountName
          root.user = parsed.user
        } else {
          root._partialErrors.push((profile.profile || "Fizzy") + ": " + parsed.error)
        }
      } else {
        root._partialErrors.push((profile.profile || "Fizzy") + ": " + root.conciseError(stderr || stdout, "Could not read identity"))
      }

      root._currentProfile = {
        profile: profile.profile,
        account: profile.account,
        accountName: accountName,
        active: profile.active === true
      }
      root._listOutput = ""
      root._listError = ""
      listProcess.command = Model.fizzyArgs(profile.profile, ["notification", "list", "--json"])
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
      var profile = root._currentProfile || { profile: "" }
      var stdout = String(listStdout.text || root._listOutput || "")
      var stderr = String(listStderr.text || root._listError || "")
      if (exitCode === 0) {
        var parsed = Model.parseNotifications(stdout, root.maxItems, {
          profile: profile.profile,
          accountName: profile.accountName
        })
        if (parsed.ok) {
          root._fetchedNotifications = root._fetchedNotifications.concat(parsed.items)
          root._resolvedProfiles.push(profile)
        } else {
          root._partialErrors.push((profile.accountName || profile.profile || "Fizzy") + ": " + parsed.error)
        }
      } else {
        root._partialErrors.push((profile.accountName || profile.profile || "Fizzy") + ": " + root.conciseError(stderr || stdout, "request failed"))
      }
      root._fetchIndex += 1
      root.fetchNextProfile()
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
