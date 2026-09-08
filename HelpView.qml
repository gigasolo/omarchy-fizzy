import QtQuick
import qs.Commons

Column {
  id: root

  property var panel

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(8)

  Text {
    width: parent.width
    text: "SHORTCUTS"
    color: root.panel.dim
    font.family: root.panel.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    textFormat: Text.PlainText
  }

  Repeater {
    model: root.panel.shortcutHelp

    Row {
      required property var modelData
      width: parent.width
      spacing: Style.space(12)

      Text {
        width: Style.space(90)
        text: modelData.keys
        color: root.panel.foreground
        font.family: root.panel.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        textFormat: Text.PlainText
      }

      Text {
        text: modelData.action
        color: root.panel.dim
        font.family: root.panel.fontFamily
        font.pixelSize: Style.font.bodySmall
        textFormat: Text.PlainText
      }
    }
  }
}
