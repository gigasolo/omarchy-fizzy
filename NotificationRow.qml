import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

CursorSurface {
  id: root

  required property var modelData
  required property int index
  property var panel
  property var service
  property var pointerGate

  foreground: panel.foreground
  hasCursor: panel.cursorActive && panel.selectedIndex === index
  implicitHeight: rowContent.implicitHeight + Style.space(16)

  MouseArea {
    id: rowMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPositionChanged: function(mouse) {
      if (root.pointerGate.moved(root, mouse)) root.panel.select(root.index)
    }
    onClicked: root.service.openNotification(root.modelData)
  }

  PanelToolTip {
    visible: rowMouse.containsMouse
    text: Model.plainLabel((root.modelData.sourceType || "Notification") + (root.modelData.unread ? " · Unread" : " · Read"), 80)
    fontFamily: root.panel.fontFamily
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
      color: root.panel.typeColor(root.modelData.sourceType)

      TextMetrics {
        id: glyphMetrics
        font.family: root.panel.fontFamily
        font.pixelSize: Math.round(Style.font.icon)
        text: Model.notificationTypeIcon(root.modelData.sourceType)
      }

      Text {
        id: glyphText
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: glyphText.implicitWidth / 2 - (glyphMetrics.tightBoundingRect.x + glyphMetrics.tightBoundingRect.width / 2)
        anchors.verticalCenterOffset: glyphText.implicitHeight / 2 - (glyphText.baselineOffset + glyphMetrics.tightBoundingRect.y + glyphMetrics.tightBoundingRect.height / 2)
        text: glyphMetrics.text
        color: Color.popups.background
        font.family: root.panel.fontFamily
        font.pixelSize: glyphMetrics.font.pixelSize
        renderType: Text.NativeRendering
        textFormat: Text.PlainText
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(2)

      Text {
        Layout.fillWidth: true
        text: root.modelData.title
        color: root.panel.foreground
        font.family: root.panel.fontFamily
        font.pixelSize: Style.font.body
        font.weight: root.modelData.unread ? Font.DemiBold : Font.Normal
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }

      Text {
        visible: root.modelData.excerpt !== ""
        Layout.fillWidth: true
        text: root.modelData.excerpt
        color: root.panel.dim
        font.family: root.panel.fontFamily
        font.pixelSize: Style.font.bodySmall
        maximumLineCount: 2
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }

      Text {
        Layout.fillWidth: true
        text: Model.notificationMeta(root.modelData, root.panel.nowMs, { includeAccount: root.panel.showAccountMeta })
        color: root.panel.dim
        font.family: root.panel.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }
    }

    Rectangle {
      visible: root.modelData.unread
      Layout.alignment: Qt.AlignTop
      Layout.topMargin: Style.space(2)
      Layout.preferredHeight: Style.space(16)
      Layout.preferredWidth: Math.max(Style.space(16), rowBadgeText.implicitWidth + Style.space(8))
      radius: Style.space(8)
      color: root.panel.urgent

      Text {
        id: rowBadgeText
        anchors.centerIn: parent
        text: String(Math.max(1, root.modelData.unreadCount || 0))
        color: Color.background
        font.family: root.panel.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        textFormat: Text.PlainText
      }
    }

    PanelActionButton {
      iconText: "󰆏"
      tooltipText: "Copy card link"
      foreground: root.panel.foreground
      fontFamily: root.panel.fontFamily
      Layout.alignment: Qt.AlignVCenter
      onClicked: root.service.copyCardLink(root.modelData)
    }

    PanelActionButton {
      iconText: "󰚩"
      tooltipText: "Send to agent"
      foreground: root.panel.foreground
      fontFamily: root.panel.fontFamily
      Layout.alignment: Qt.AlignVCenter
      onClicked: { if (root.service.sendToAgent(root.modelData)) root.panel.close() }
    }

    PanelActionButton {
      visible: root.modelData.unread
      iconText: "󰡕"
      tooltipText: "Mark as read"
      foreground: root.panel.foreground
      fontFamily: root.panel.fontFamily
      Layout.alignment: Qt.AlignVCenter
      onClicked: root.service.markRead(root.modelData)
    }
  }
}
