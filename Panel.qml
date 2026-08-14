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
  moduleName: "lonbaker.fizzy"
  ipcTarget: "lonbaker.fizzy"
  manageIpc: false

  property int selectedIndex: 0
  property bool cursorActive: false
  property double nowMs: Date.now()
  property string stateFilter: "unread"
  property string accountFilter: ""

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var filteredNotifications: Model.filterNotifications(service.notifications, accountFilter, stateFilter)
  readonly property var accountFilterOptions: Model.accountFilterOptions(service.profiles)
  readonly property color barIconColor: service.unreadCount > 0 ? urgent : (service.authenticated ? barForeground : Qt.darker(barForeground, 1.55))

  readonly property var accountDropdownOptions: {
    var options = accountFilterOptions
    var out = []
    for (var i = 0; i < options.length; i++) {
      var count = accountUnreadCount(options[i].value)
      out.push({
        value: options[i].value,
        label: count > 0 ? options[i].label + " (" + count + ")" : options[i].label
      })
    }
    return out
  }

  readonly property bool otherAccountsUnread: {
    if (accountFilter === "") return false
    for (var i = 0; i < service.notifications.length; i++) {
      var item = service.notifications[i]
      if (item.unread === true && String(item.profile || "") !== accountFilter) return true
    }
    return false
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
    if (service.lastError !== "") return service.lastError
    if (rotatingPhrases) return loadingPhrases[phraseIndex % loadingPhrases.length]
    if (!service.installed) return "Fizzy CLI is not installed"
    if (!service.authenticated) return "Run fizzy setup"
    if (service.accountName !== "") return service.accountName
    return "Fizzy.do"
  }

  function emptyMessage() {
    if (!service.installed) return "Install fizzy-cli, then run fizzy setup."
    if (!service.authenticated) return "Run fizzy setup to sign in."
    if (stateFilter === "unread") return "You're all caught up."
    return "No previous notifications."
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

  function accountUnreadCount(profile) {
    var id = String(profile || "")
    if (id === "") return 0
    var count = 0
    for (var i = 0; i < service.notifications.length; i++) {
      var item = service.notifications[i]
      if (item.unread === true && String(item.profile || "") === id) count++
    }
    return count
  }

  function ensureAccountFilter() {
    if (accountFilter === "") return
    for (var i = 0; i < service.profiles.length; i++) {
      if (String(service.profiles[i].profile) === accountFilter) return
    }
    setAccountFilter("")
  }

  function resetFilteredView() {
    selectedIndex = 0
    cursorActive = false
    pointerGate.reset()
    if (panelFlick) panelFlick.contentY = 0
  }

  function setAccountFilter(value) {
    accountFilter = String(value || "")
    resetFilteredView()
  }

  function setStateFilter(value) {
    stateFilter = String(value || "unread")
    resetFilteredView()
  }

  function cycleAccountFilter(delta) {
    var options = accountFilterOptions
    if (options.length < 2) return
    var current = 0
    for (var i = 0; i < options.length; i++) {
      if (String(options[i].value) === accountFilter) {
        current = i
        break
      }
    }
    setAccountFilter(options[(current + delta + options.length) % options.length].value)
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
  }

  function moveSelection(delta) {
    if (filteredNotifications.length === 0) return
    if (!cursorActive) {
      select(0)
      return
    }
    select(selectedIndex + delta)
  }

  function activateSelection() {
    if (!cursorActive || filteredNotifications.length === 0) return
    service.openNotification(filteredNotifications[selectedIndex])
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

  onOpenedChanged: if (opened) {
    cursorActive = false
    nowMs = Date.now()
    if (panelFlick) panelFlick.contentY = 0
    service.refreshIfStale()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  onFilteredNotificationsChanged: ensureSelection()

  PointerMoveGate {
    id: pointerGate
    referenceItem: panelFlick
  }

  Service {
    id: service
    settings: root.settings
    onProfilesChanged: root.ensureAccountFilter()
  }

  Timer {
    interval: 30000
    repeat: true
    running: root.opened
    onTriggered: root.nowMs = Date.now()
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
        account: service.accountName,
        profiles: service.accountCount,
        notifications: service.notifications.length,
        unread: service.unreadCount,
        visible: root.filteredNotifications.length,
        stateFilter: root.stateFilter,
        accountFilter: root.accountFilter,
        refreshing: service.refreshing,
        error: service.lastError
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
      : (service.unreadCount === 1 ? "1 unread Fizzy notification" : service.unreadCount + " unread Fizzy notifications")
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
      blocked: accountDropdown.popupOpen
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.cycleAccountFilter(dx)
        else if (dy !== 0) root.moveSelection(dy)
      }
      onActivateRequested: root.activateSelection()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") service.refresh()
        else if (text === "u" || text === "U") root.setStateFilter("unread")
        else if (text === "p" || text === "P") root.setStateFilter("previous")
        else if (text === "m" || text === "M") service.markAllRead(root.accountFilter)
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
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, refreshButton.implicitHeight)

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
              anchors.right: refreshButton.left
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(3)

              Text {
                text: "Fizzy"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
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
              }
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

          Dropdown {
            id: accountDropdown
            visible: service.accountCount > 1
            width: parent.width
            showLabel: false
            options: root.accountDropdownOptions
            foreground: root.foreground
            background: Color.popups.background
            accent: Color.accent
            fontFamily: root.fontFamily
            onChanged: function(value) { root.setAccountFilter(value) }

            Binding on value {
              value: root.accountFilter
            }

            Rectangle {
              visible: root.accountFilter !== "" && root.otherAccountsUnread
              x: parent.width - width / 2
              y: -height / 2
              width: Style.space(8)
              height: width
              radius: width / 2
              color: root.urgent
            }
          }

          Row {
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
              text: "PREVIOUS"
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

            Text {
              visible: !service.refreshing && root.filteredNotifications.length === 0 && service.lastError === ""
              width: parent.width
              text: root.emptyMessage()
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              topPadding: Style.space(16)
              bottomPadding: Style.space(18)
            }

            Text {
              visible: service.lastError !== "" && root.filteredNotifications.length === 0
              width: parent.width
              text: service.lastError
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
              topPadding: Style.space(16)
              bottomPadding: Style.space(18)
            }

            Column {
              id: notificationColumn
              visible: root.filteredNotifications.length > 0
              width: parent.width
              spacing: Style.space(8)

              Repeater {
                model: root.filteredNotifications

                CursorSurface {
                  id: notificationRow
                  required property var modelData
                  required property int index
                  width: notificationColumn.width
                  foreground: root.foreground
                  hasCursor: root.cursorActive && root.selectedIndex === index
                  implicitHeight: rowContent.implicitHeight + Style.space(16)

                  MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: function(mouse) {
                      if (pointerGate.moved(notificationRow, mouse)) root.select(notificationRow.index)
                    }
                    onClicked: service.openNotification(notificationRow.modelData)
                  }

                  PanelToolTip {
                    visible: rowMouse.containsMouse
                    text: (notificationRow.modelData.sourceType || "Notification") + (notificationRow.modelData.unread ? " · Unread" : " · Read")
                    fontFamily: root.fontFamily
                  }

                  RowLayout {
                    id: rowContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    spacing: Style.space(9)

                    Rectangle {
                      Layout.preferredWidth: Style.space(24)
                      Layout.preferredHeight: Style.space(24)
                      Layout.alignment: Qt.AlignTop
                      radius: width / 2
                      color: root.typeColor(notificationRow.modelData.sourceType)

                      TextMetrics {
                        id: glyphMetrics
                        font.family: root.fontFamily
                        font.pixelSize: Math.round(Style.font.icon)
                        text: Model.notificationTypeIcon(notificationRow.modelData.sourceType)
                      }

                      Text {
                        id: glyphText
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: glyphText.implicitWidth / 2 - (glyphMetrics.tightBoundingRect.x + glyphMetrics.tightBoundingRect.width / 2)
                        anchors.verticalCenterOffset: glyphText.implicitHeight / 2 - (glyphText.baselineOffset + glyphMetrics.tightBoundingRect.y + glyphMetrics.tightBoundingRect.height / 2)
                        text: glyphMetrics.text
                        color: Color.popups.background
                        font.family: root.fontFamily
                        font.pixelSize: glyphMetrics.font.pixelSize
                        renderType: Text.NativeRendering
                      }
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(2)

                      Text {
                        Layout.fillWidth: true
                        text: notificationRow.modelData.title
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        font.weight: notificationRow.modelData.unread ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                      }

                      Text {
                        visible: notificationRow.modelData.excerpt !== ""
                        Layout.fillWidth: true
                        text: notificationRow.modelData.excerpt
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                      }

                      Text {
                        Layout.fillWidth: true
                        text: Model.notificationMeta(notificationRow.modelData, root.nowMs, root.accountFilter === "")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                      }
                    }

                    Rectangle {
                      visible: notificationRow.modelData.unread
                      Layout.alignment: Qt.AlignTop
                      Layout.topMargin: Style.space(2)
                      Layout.preferredHeight: Style.space(16)
                      Layout.preferredWidth: Math.max(Style.space(16), rowBadgeText.implicitWidth + Style.space(8))
                      radius: Style.space(8)
                      color: root.urgent

                      Text {
                        id: rowBadgeText
                        anchors.centerIn: parent
                        text: String(Math.max(1, notificationRow.modelData.unreadCount || 0))
                        color: Color.background
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
