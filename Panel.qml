import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "gigasolo.fizzy"
  ipcTarget: "gigasolo.fizzy"
  manageIpc: false

  property int selectedIndex: 0
  property bool cursorActive: false
  property bool peeking: false
  property bool showingHelp: false
  property bool showingAccounts: false
  property bool addingAccount: false
  property bool confirmingRemove: false
  property int accountIndex: 0
  property string addName: ""
  property bool enterHandled: false
  property double nowMs: Date.now()
  property string stateFilter: "unread"
  property string profileFilter: ""
  readonly property var selectedItem: filteredNotifications.length > 0 ? filteredNotifications[selectedIndex] : null

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var filteredNotifications: Model.filterNotifications(service.notifications, stateFilter, profileFilter)
  readonly property var accountRows: showingAccounts
    ? Model.accountSwitcherRows(service.profiles, service.notifications, profileFilter)
    : Model.emptyList()
  readonly property bool overlayOpen: showingHelp || showingAccounts
  readonly property bool showAccountMeta: service.profiles.length > 1 && profileFilter === ""
  readonly property bool needsSetup: service.setupKind !== ""
  readonly property var setupGuide: Model.setupGuide(service.setupKind)
  readonly property color barIconColor: service.unreadCount > 0 ? urgent : (service.authenticated ? barForeground : Qt.darker(barForeground, 1.55))
  readonly property bool canMarkSelected: {
    var item = peekTarget()
    return !!(item && item.unread)
  }
  readonly property var shortcutHelp: {
    if (!showingHelp) return Model.emptyList()
    var rows = [
      { keys: "j k", action: "Move" },
      { keys: "Enter", action: "Open in browser" },
      { keys: "Space", action: "Peek at the card" },
      { keys: "c", action: "Copy card link" },
      { keys: "a", action: "Send to agent" }
    ]
    if (canMarkSelected) rows = rows.concat([{ keys: "m", action: "Mark this as read" }])
    if (Model.unreadCount(service.notifications, profileFilter) > 0)
      rows = rows.concat([{ keys: "M", action: "Mark all as read" }])
    if (!needsSetup) {
      rows = rows.concat([
        { keys: "1-9", action: "Switch account" },
        { keys: "s", action: "Accounts" }
      ])
      if (service.profiles.length > 0) rows = rows.concat([{ keys: "[ ]", action: "Cycle account" }])
    }
    return rows.concat([
      { keys: "h l", action: "New / older" },
      { keys: "r", action: "Refresh" },
      { keys: "?", action: "Show or hide shortcuts" },
      { keys: "Esc", action: "Back / close" }
    ])
  }

  property int phraseIndex: 0
  readonly property var loadingPhrases: [
    "Checking the board",
    "Shuffling cards",
    "Looking for mentions",
    "Refreshing the tray"
  ]
  readonly property bool rotatingPhrases: service.refreshing

  readonly property string heroStatusText: {
    if (service.actionStatus !== "") return service.actionStatus
    if (root.needsSetup) return root.setupGuide.hero
    if (service.lastError !== "") return service.lastError
    if (rotatingPhrases) return loadingPhrases[phraseIndex % loadingPhrases.length]
    if (!service.installed) return "CLI not installed"
    if (!service.authenticated) return "Sign in to Fizzy"
    var names = Model.heroAccountText(service.profiles, profileFilter)
    if (names !== "") return names
    if (service.accountName !== "") return service.accountName
    return "Fizzy.do"
  }

  function emptyMessage() {
    if (!service.installed) return "Install fizzy-cli, then run fizzy setup."
    if (!service.authenticated) return "Run fizzy setup to sign in."
    if (stateFilter === "unread") return "You're all caught up."
    return "No older notifications."
  }

  property var themeColors: ({})

  function themeHue(names, fallback) {
    for (var i = 0; i < names.length; i++) {
      var value = themeColors[names[i]]
      if (value) return value
    }
    return fallback
  }

  function typeColor(type) {
    var value = String(type || "").toLowerCase()
    if (value === "mention") return themeHue(["red", "color1"], urgent)
    if (value === "event") return themeHue(["blue", "color4"], Color.accent)
    return Color.muted
  }

  function setStateFilter(value) {
    showingHelp = false
    closeAccounts()
    peeking = false
    service.closePeek()
    stateFilter = String(value || "unread")
    selectedIndex = 0
    cursorActive = false
    pointerGate.reset()
    if (panelFlick) panelFlick.contentY = 0
  }

  function setProfileFilter(value) {
    if (root.needsSetup) return
    var next = Model.safeCliToken(value)
    showingHelp = false
    peeking = false
    service.closePeek()
    if (next !== profileFilter) {
      profileFilter = next
      selectedIndex = 0
      cursorActive = false
      pointerGate.reset()
      if (panelFlick) panelFlick.contentY = 0
    }
    closeAccounts()
  }

  function cycleProfileFilter(delta) {
    if (overlayOpen || service.profiles.length < 1) return
    setProfileFilter(Model.cycleProfileFilter(service.profiles, profileFilter, delta))
  }

  function cycleStateFilter(delta) {
    if (root.needsSetup) return
    var next = Number(delta) > 0 ? "previous" : "unread"
    if (stateFilter === next) return
    setStateFilter(next)
  }

  function ensureSelection() {
    if (filteredNotifications.length === 0) {
      selectedIndex = 0
      return
    }
    selectedIndex = Math.max(0, Math.min(filteredNotifications.length - 1, selectedIndex))
  }

  function select(index) {
    cursorActive = true
    selectedIndex = Math.max(0, Math.min(filteredNotifications.length - 1, index))
    scrollSelectionIntoView()
    if (peeking && filteredNotifications[selectedIndex]) service.loadPeek(filteredNotifications[selectedIndex])
  }

  function moveSelection(delta) {
    if (filteredNotifications.length === 0) return
    if (!cursorActive) {
      select(0)
      return
    }
    select(selectedIndex + delta)
  }

  function peekTarget() {
    if (peeking && service.peekItem) return service.peekItem
    return selectedItem
  }

  function closeAccounts() {
    showingAccounts = false
    addingAccount = false
    confirmingRemove = false
    addName = ""
  }

  function selectedAccountIndex() {
    var rows = accountRows
    for (var i = 0; i < rows.length; i++) {
      if (rows[i] && rows[i].selected && rows[i].kind !== "add") return i
    }
    return 0
  }

  function toggleAccounts() {
    if (root.needsSetup) {
      service.beginSetup()
      return
    }
    if (showingAccounts) {
      closeAccounts()
      return
    }
    showingHelp = false
    peeking = false
    service.closePeek()
    confirmingRemove = false
    addingAccount = false
    showingAccounts = true
    accountIndex = selectedAccountIndex()
  }

  function moveAccountSelection(delta) {
    if (!showingAccounts || addingAccount || confirmingRemove) return
    var rows = accountRows
    if (rows.length === 0) return
    accountIndex = Math.max(0, Math.min(rows.length - 1, accountIndex + Number(delta)))
  }

  function activateAccountSelection() {
    if (!showingAccounts) return
    if (confirmingRemove) {
      confirmRemoveAccount()
      return
    }
    if (addingAccount) {
      submitAddAccount()
      return
    }
    var row = accountRows[accountIndex]
    if (!row) return
    if (row.kind === "add") {
      startAddAccount()
      return
    }
    setProfileFilter(row.profile)
  }

  function jumpAccountDigit(digit) {
    if (showingHelp || addingAccount || confirmingRemove) return
    if (root.needsSetup) return
    var next = Model.profileForDigit(service.profiles, digit)
    if (next === null) return
    setProfileFilter(next)
  }

  function startAddAccount() {
    if (!showingAccounts || confirmingRemove) return
    confirmingRemove = false
    addingAccount = true
    addName = ""
  }

  function submitAddAccount() {
    var token = Model.safeCliToken(addName)
    if (token === "") return
    if (!service.beginAddProfile(token)) return
    addingAccount = false
    addName = ""
  }

  function cancelAccountEdit() {
    addingAccount = false
    confirmingRemove = false
    addName = ""
  }

  function startRemoveAccount() {
    if (!showingAccounts || addingAccount) return
    var row = accountRows[accountIndex]
    if (!row || row.kind !== "profile") return
    confirmingRemove = true
  }

  function confirmRemoveAccount() {
    var row = accountRows[accountIndex]
    if (!row || row.kind !== "profile") {
      confirmingRemove = false
      return
    }
    service.logoutProfile(row.profile)
    confirmingRemove = false
  }

  function activateSelection() {
    if (showingAccounts) {
      activateAccountSelection()
      return
    }
    if (showingHelp) return
    if (root.needsSetup) {
      if (!cursorActive) return
      service.beginSetup()
      return
    }
    var item = peekTarget()
    if (!item) return
    if (!peeking && !cursorActive) return
    service.openNotification(item)
  }

  function togglePeek() {
    if (overlayOpen || root.needsSetup) return
    if (peeking) {
      peeking = false
      service.closePeek()
      return
    }
    if (!selectedItem) return
    if (!cursorActive) select(selectedIndex)
    peeking = true
    service.loadPeek(selectedItem)
  }

  function closePeekOrPanel() {
    if (addingAccount || confirmingRemove) {
      cancelAccountEdit()
      return
    }
    if (showingAccounts) {
      closeAccounts()
      return
    }
    if (showingHelp) {
      showingHelp = false
      return
    }
    if (peeking) {
      peeking = false
      service.closePeek()
      return
    }
    root.close()
  }

  function copySelected() {
    if (overlayOpen) return
    var item = peekTarget()
    if (!item) return
    service.copyCardLink(item)
  }

  function sendSelectedToAgent() {
    if (overlayOpen) return
    var item = peekTarget()
    if (!item) return
    if (service.sendToAgent(item)) root.close()
  }

  function markSelectedRead() {
    if (overlayOpen) return
    var item = peekTarget()
    if (!item) return
    if (item.unread) service.markRead(item)
  }

  function markAllRead() {
    if (overlayOpen || root.needsSetup) return
    service.markAllRead(root.profileFilter)
  }

  function toggleHelp() {
    if (showingAccounts) closeAccounts()
    showingHelp = !showingHelp
  }

  function scrollSelectionIntoView() {
    if (!notificationColumn || selectedIndex < 0 || selectedIndex >= notificationColumn.children.length) return
    var wrapper = notificationColumn.children[selectedIndex]
    Qt.callLater(function() {
      if (!wrapper || !panelFlick) return
      var point = wrapper.mapToItem(panelFlick.contentItem, 0, 0)
      var margin = Style.space(8)
      var top = point.y
      var bottom = top + wrapper.height
      var viewTop = panelFlick.contentY
      var viewBottom = viewTop + panelFlick.height
      var maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height)
      if (top < viewTop + margin) panelFlick.contentY = Math.max(0, top - margin)
      else if (bottom > viewBottom - margin) panelFlick.contentY = Math.min(maxY, bottom + margin - panelFlick.height)
    })
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: {
    service.panelOpen = opened
    if (opened) {
      cursorActive = false
      peeking = false
      showingHelp = false
      closeAccounts()
      enterHandled = false
      nowMs = Date.now()
      if (panelFlick) panelFlick.contentY = 0
      service.refreshIfStale()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    } else {
      peeking = false
      showingHelp = false
      closeAccounts()
      service.closePeek()
    }
  }

  onFilteredNotificationsChanged: ensureSelection()

  Connections {
    target: service
    function onProfilesChanged() {
      if (root.profileFilter !== "" && !Model.profileKnown(service.profiles, root.profileFilter))
        root.profileFilter = ""
    }
  }

  PointerMoveGate {
    id: pointerGate
    referenceItem: panelFlick
  }

  Service {
    id: service
    settings: root.settings
  }

  // Repeater delegates shadow property names; these aliases keep the row
  // from self-binding `service: service` / `pointerGate: pointerGate` to undefined.
  readonly property var fizzyService: service
  readonly property var rowPointerGate: pointerGate

  Timer {
    interval: 60000
    repeat: true
    running: root.opened
    onTriggered: root.nowMs = Date.now()
  }

  Timer {
    interval: 4000
    repeat: true
    running: root.opened && (root.needsSetup || service.awaitingProfile !== "")
    onTriggered: service.refresh()
  }

  Timer {
    id: phraseTimer
    interval: 2800
    running: root.opened && root.rotatingPhrases
    repeat: true
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    PropertyAnimation {
      target: heroStatus
      property: "opacity"
      to: 0.0
      duration: 180
      easing.type: Easing.OutQuad
    }
    ScriptAction {
      script: root.phraseIndex = (root.phraseIndex + 1) % root.loadingPhrases.length
    }
    PropertyAnimation {
      target: heroStatus
      property: "opacity"
      to: 1.0
      duration: 260
      easing.type: Easing.InQuad
    }
  }

  Connections {
    target: root
    function onRotatingPhrasesChanged() {
      if (!root.rotatingPhrases) {
        phraseSwap.stop()
        heroStatus.opacity = 1.0
      }
    }
  }

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.themeColors = Model.parseThemeColors(text())
    onFileChanged: reload()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { service.refresh(); return "ok" }
    function unread(): int { return service.unreadCount }
    function status(): string {
      return JSON.stringify({
        account: Model.heroAccountText(service.profiles, root.profileFilter) || service.accountName,
        notifications: service.notifications.length,
        unread: service.unreadCount,
        visible: root.filteredNotifications.length,
        stateFilter: root.stateFilter,
        profileFilter: root.profileFilter,
        profiles: service.profiles.length,
        refreshing: service.refreshing,
        error: service.lastError,
        setup: service.setupKind
      })
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        FizzyIcon {
          anchors.centerIn: parent
          iconSize: Style.space(12)
          color: root.barIconColor
        }

      }
    }
    tooltipText: service.refreshing
      ? "Refreshing Fizzy notifications"
      : (root.needsSetup
        ? root.setupGuide.title
        : (service.unreadCount === 1 ? "1 unread Fizzy notification" : service.unreadCount + " unread Fizzy notifications"))
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton || buttonCode === Qt.MiddleButton) service.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(fixedContent.implicitHeight + notificationContent.implicitHeight + Style.space(12), Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.addingAccount
      onMoveRequested: function(dx, dy) {
        if (root.showingAccounts) {
          if (dy !== 0) root.moveAccountSelection(dy)
          return
        }
        if (dy !== 0) root.moveSelection(dy)
        else if (dx !== 0) root.cycleStateFilter(dx)
      }
      onReturnRequested: {
        root.enterHandled = true
        root.activateSelection()
      }
      onActivateRequested: {
        if (root.enterHandled) {
          root.enterHandled = false
          return
        }
        if (root.showingAccounts) root.activateAccountSelection()
        else root.togglePeek()
      }
      onDeleteRequested: root.startRemoveAccount()
      onCloseRequested: root.closePeekOrPanel()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text >= "1" && text <= "9") root.jumpAccountDigit(text)
        else if (text === "r" || text === "R") service.refresh()
        else if (text === "s" || text === "S") root.toggleAccounts()
        else if ((text === "n" || text === "N") && root.showingAccounts) root.startAddAccount()
        else if ((text === "u" || text === "U") && !root.showingAccounts) root.setStateFilter("unread")
        else if ((text === "p" || text === "P") && !root.showingAccounts) root.setStateFilter("previous")
        else if (text === "m") root.markSelectedRead()
        else if (text === "M") root.markAllRead()
        else if (text === "c" || text === "C") root.copySelected()
        else if (text === "a" || text === "A") root.sendSelectedToAgent()
        else if (text === "?") root.toggleHelp()
        else if (text === "[") root.cycleProfileFilter(-1)
        else if (text === "]") root.cycleProfileFilter(1)
      }

      ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: Style.space(12)

        Column {
          id: fixedContent
          Layout.fillWidth: true
          spacing: Style.space(12)

          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, accountsButton.implicitHeight, helpButton.implicitHeight, refreshButton.implicitHeight)

            FizzyIcon {
              id: heroIcon
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              iconSize: Style.font.display
              color: root.foreground
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: accountsButton.visible ? accountsButton.left : helpButton.left
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(3)

              Text {
                text: "Fizzy"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                textFormat: Text.PlainText
              }

              Text {
                id: heroStatus
                visible: text !== ""
                width: parent.width
                text: root.heroStatusText.toUpperCase()
                color: service.lastError !== "" && service.actionStatus === "" ? root.urgent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
                textFormat: Text.PlainText
              }
            }

            PanelActionButton {
              id: accountsButton
              visible: !root.needsSetup
              anchors.right: helpButton.left
              anchors.rightMargin: Style.space(2)
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰀉"
              tooltipText: "Accounts"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.toggleAccounts()
            }

            PanelActionButton {
              id: helpButton
              anchors.right: refreshButton.left
              anchors.rightMargin: Style.space(2)
              anchors.verticalCenter: parent.verticalCenter
              iconText: "?"
              tooltipText: "Shortcuts"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.toggleHelp()
            }

            PanelActionButton {
              id: refreshButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: service.refreshing ? "󰑓" : "󰑐"
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !service.refreshing
              onClicked: service.refresh()
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          Row {
            visible: !root.needsSetup
            spacing: Style.space(2)

            Button {
              text: "NEW FOR YOU"
              selected: root.stateFilter === "unread"
              foreground: root.foreground
              background: "transparent"
              accent: Color.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              horizontalPadding: Style.space(7)
              verticalPadding: Style.space(1)
              onClicked: root.setStateFilter("unread")
            }

            Button {
              text: "OLDER"
              selected: root.stateFilter === "previous"
              foreground: root.foreground
              background: "transparent"
              accent: Color.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              horizontalPadding: Style.space(7)
              verticalPadding: Style.space(1)
              onClicked: root.setStateFilter("previous")
            }
          }
        }

        Flickable {
          id: panelFlick
          Layout.fillWidth: true
          Layout.fillHeight: true
          contentWidth: width
          contentHeight: notificationContent.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Column {
            id: notificationContent
            width: panelFlick.width
            spacing: Style.space(12)

            SetupCard {
              visible: !root.overlayOpen && root.needsSetup
              width: parent.width
              panel: root
              service: service
            }

            Text {
              visible: !root.overlayOpen && !root.peeking && !root.needsSetup && !service.refreshing && root.filteredNotifications.length === 0 && service.lastError === ""
              width: parent.width
              text: root.emptyMessage()
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              topPadding: Style.space(16)
              bottomPadding: Style.space(18)
              textFormat: Text.PlainText
            }

            Text {
              visible: !root.overlayOpen && !root.peeking && !root.needsSetup && service.lastError !== "" && root.filteredNotifications.length === 0
              width: parent.width
              text: service.lastError
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
              topPadding: Style.space(16)
              bottomPadding: Style.space(18)
              textFormat: Text.PlainText
            }

            HelpView {
              visible: root.showingHelp
              width: parent.width
              panel: root
            }

            AccountsView {
              visible: root.showingAccounts
              width: parent.width
              panel: root
              service: service
            }

            PeekView {
              visible: !root.overlayOpen && root.peeking && !root.needsSetup
              width: parent.width
              panel: root
              service: service
            }

            Column {
              id: notificationColumn
              visible: !root.overlayOpen && !root.peeking && !root.needsSetup && root.filteredNotifications.length > 0
              width: parent.width
              spacing: Style.space(8)

              Repeater {
                model: root.filteredNotifications

                NotificationRow {
                  width: notificationColumn.width
                  panel: root
                  service: root.fizzyService
                  pointerGate: root.rowPointerGate
                }
              }
            }
          }
        }
      }
    }
  }
}
