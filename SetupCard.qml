import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

CursorSurface {
  id: root

  property var panel
  property var service

  hasCursor: panel.cursorActive && panel.needsSetup
  foreground: panel.foreground

  implicitHeight: setupRow.implicitHeight + Style.spacing.rowPaddingX

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: root.panel.cursorActive = true
    onClicked: root.service.beginSetup()
  }

  RowLayout {
    id: setupRow
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(10)
    anchors.rightMargin: Style.space(10)
    spacing: Style.space(8)

    Text {
      text: root.panel.setupGuide.kind === "missing_cli" ? "󰏖" : "󰌆"
      color: root.panel.foreground
      font.family: root.panel.fontFamily
      font.pixelSize: Style.font.heading
      Layout.alignment: Qt.AlignTop
      Layout.topMargin: Style.space(2)
      textFormat: Text.PlainText
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(4)

      Text {
        Layout.fillWidth: true
        text: root.panel.setupGuide.title
        color: root.panel.foreground
        font.family: root.panel.fontFamily
        font.pixelSize: Style.font.body
        font.weight: Font.DemiBold
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
      }

      Text {
        Layout.fillWidth: true
        text: root.panel.setupGuide.detail
        color: root.panel.dim
        font.family: root.panel.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
      }

      Text {
        Layout.fillWidth: true
        text: root.panel.setupGuide.commands.map(function(command) { return "$ " + command }).join("\n")
        color: root.panel.dim
        font.family: root.panel.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        topPadding: Style.space(2)
        textFormat: Text.PlainText
      }
    }

    PanelActionButton {
      iconText: "󰌋"
      foreground: root.panel.foreground
      fontFamily: root.panel.fontFamily
      tooltipText: root.panel.setupGuide.action
      Layout.alignment: Qt.AlignVCenter
      onClicked: root.service.beginSetup()
    }
  }
}
