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
  spacing: Style.space(10)

  readonly property var peek: service.peek
  readonly property var card: peek && peek.card ? peek.card : null
  readonly property string boardName: (card && card.boardName) ? card.boardName : (peek && peek.boardName ? peek.boardName : "")
  readonly property var comments: peek && peek.comments ? peek.comments : Model.emptyList()

  RowLayout {
    width: parent.width
    spacing: Style.space(8)

    Button {
      text: "BACK"
      foreground: root.panel.foreground
      background: "transparent"
      accent: Color.accent
      fontFamily: root.panel.fontFamily
      fontSize: Style.font.caption
      horizontalPadding: Style.space(7)
      verticalPadding: Style.space(1)
      onClicked: root.panel.togglePeek()
    }

    Item { Layout.fillWidth: true }

    PanelActionButton {
      iconText: "󰆏"
      tooltipText: "Copy card link"
      foreground: root.panel.foreground
      fontFamily: root.panel.fontFamily
      onClicked: root.panel.copySelected()
    }

    PanelActionButton {
      iconText: "󰚩"
      tooltipText: "Send to agent"
      foreground: root.panel.foreground
      fontFamily: root.panel.fontFamily
      onClicked: root.panel.sendSelectedToAgent()
    }

    PanelActionButton {
      visible: root.panel.canMarkSelected
      iconText: "󰡕"
      tooltipText: "Mark as read"
      foreground: root.panel.foreground
      fontFamily: root.panel.fontFamily
      onClicked: root.panel.markSelectedRead()
    }
  }

  Text {
    width: parent.width
    text: card ? card.title : (peek && peek.title ? peek.title : "Card")
    color: root.panel.foreground
    font.family: root.panel.fontFamily
    font.pixelSize: Style.font.body
    font.weight: Font.DemiBold
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
  }

  Text {
    visible: boardName !== ""
    width: parent.width
    text: boardName
    color: root.panel.dim
    font.family: root.panel.fontFamily
    font.pixelSize: Style.font.caption
    textFormat: Text.PlainText
  }

  Text {
    visible: peek && peek.loading
    width: parent.width
    text: "Loading card…"
    color: root.panel.dim
    font.family: root.panel.fontFamily
    font.pixelSize: Style.font.bodySmall
    textFormat: Text.PlainText
  }

  Text {
    visible: peek && peek.error !== ""
    width: parent.width
    text: peek ? peek.error : ""
    color: root.panel.urgent
    font.family: root.panel.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
  }

  Text {
    visible: card && card.description !== ""
    width: parent.width
    text: card ? card.description : ""
    color: root.panel.foreground
    font.family: root.panel.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.Wrap
    maximumLineCount: 12
    elide: Text.ElideRight
    textFormat: Text.PlainText
  }

  PanelSeparator {
    visible: comments.length > 0
    foreground: root.panel.foreground
  }

  Text {
    visible: peek && !peek.loading && comments.length === 0 && peek.error === ""
    width: parent.width
    text: "No comments yet."
    color: root.panel.dim
    font.family: root.panel.fontFamily
    font.pixelSize: Style.font.caption
    textFormat: Text.PlainText
  }

  Repeater {
    model: comments

    Column {
      required property var modelData
      width: parent.width
      spacing: Style.space(2)

      Text {
        width: parent.width
        text: Model.notificationMeta({ timestampMs: modelData.timestampMs, creator: modelData.creator }, root.panel.nowMs)
        color: root.panel.dim
        font.family: root.panel.fontFamily
        font.pixelSize: Style.font.caption
        textFormat: Text.PlainText
      }

      Text {
        width: parent.width
        text: modelData.text
        color: root.panel.foreground
        font.family: root.panel.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
        maximumLineCount: 6
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }
    }
  }
}
