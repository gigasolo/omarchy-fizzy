import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

Column {
  id: root

  property var panel
  property var service

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(8)

  readonly property var rows: panel.accountRows
  readonly property var currentRow: rows.length > 0 ? rows[Math.max(0, Math.min(rows.length - 1, panel.accountIndex))] : null

  Text {
    width: parent.width
    text: panel.confirmingRemove ? "REMOVE ACCOUNT" : (panel.addingAccount ? "ADD ACCOUNT" : "ACCOUNTS")
    color: root.panel.dim
    font.family: root.panel.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    textFormat: Text.PlainText
  }

  Text {
    visible: panel.confirmingRemove
    width: parent.width
    text: currentRow ? "Remove " + (currentRow.label || currentRow.profile) + "?" : "Remove this account?"
    color: root.panel.foreground
    font.family: root.panel.fontFamily
    font.pixelSize: Style.font.body
    font.weight: Font.DemiBold
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
  }

  Text {
    visible: panel.confirmingRemove
    width: parent.width
    text: Model.removeConfirmDetail(currentRow)
    color: root.panel.dim
    font.family: root.panel.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
  }

  Text {
    visible: panel.addingAccount
    width: parent.width
    text: "Short CLI profile name, then fizzy setup opens in a terminal. It will not change your default fizzy login."
    color: root.panel.dim
    font.family: root.panel.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
  }

  TextField {
    id: addField
    visible: panel.addingAccount
    width: parent.width
    placeholderText: "work"
    foreground: root.panel.foreground
    font.family: root.panel.fontFamily
    text: panel.addName
    onTextChanged: panel.addName = text
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) {
        root.panel.cancelAccountEdit()
        event.accepted = true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        root.panel.submitAddAccount()
        event.accepted = true
      }
    }
  }

  Repeater {
    model: panel.addingAccount || panel.confirmingRemove ? Model.emptyList() : rows

    CursorSurface {
      required property var modelData
      required property int index
      width: root.width
      hasCursor: root.panel.accountIndex === index
      foreground: root.panel.foreground
      implicitHeight: rowContent.implicitHeight + Style.space(12)

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.panel.accountIndex = index
        onClicked: {
          root.panel.accountIndex = index
          root.panel.activateAccountSelection()
        }
      }

      RowLayout {
        id: rowContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(10)

        Text {
          Layout.preferredWidth: Style.space(24)
          text: modelData.number > 0 ? String(modelData.number) : "+"
          color: root.panel.foreground
          font.family: root.panel.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          textFormat: Text.PlainText
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(2)

          Text {
            Layout.fillWidth: true
            text: modelData.label
            color: root.panel.foreground
            font.family: root.panel.fontFamily
            font.pixelSize: Style.font.body
            font.weight: modelData.selected || modelData.kind === "add" ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            textFormat: Text.PlainText
          }

          Text {
            visible: modelData.active === true
            Layout.fillWidth: true
            text: "CLI default"
            color: root.panel.dim
            font.family: root.panel.fontFamily
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
          }
        }

        Rectangle {
          visible: modelData.kind !== "add" && modelData.unread > 0
          Layout.preferredHeight: Style.space(16)
          Layout.preferredWidth: Math.max(Style.space(16), unreadLabel.implicitWidth + Style.space(8))
          radius: Style.space(8)
          color: root.panel.urgent

          Text {
            id: unreadLabel
            anchors.centerIn: parent
            text: String(modelData.unread)
            color: Color.background
            font.family: root.panel.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            textFormat: Text.PlainText
          }
        }
      }
    }
  }

  Text {
    width: parent.width
    topPadding: Style.space(4)
    text: panel.confirmingRemove
      ? "Esc cancel   Enter remove"
      : (panel.addingAccount
        ? "Esc cancel   Enter set up"
        : "j k move   Enter view   n add   x remove   1-9 jump")
    color: root.panel.dim
    font.family: root.panel.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
  }

  onVisibleChanged: if (visible && panel.addingAccount) Qt.callLater(function() { addField.forceActiveFocus() })

  Connections {
    target: panel
    function onAddingAccountChanged() {
      if (root.panel.addingAccount) Qt.callLater(function() { addField.forceActiveFocus() })
    }
  }
}
