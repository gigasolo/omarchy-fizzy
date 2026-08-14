import QtQuick
import qs.Commons

// Original kanban mark: two columns of rounded cards. Recolors with the
// theme so it stays readable on light and dark bars.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true

    Connections {
      target: root
      function onColorChanged() { canvas.requestPaint() }
      function onIconSizeChanged() { canvas.requestPaint() }
    }

    onPaint: {
      var ctx = getContext("2d")
      var s = Math.min(width, height)
      var ox = (width - s) / 2
      var oy = (height - s) / 2
      function px(u) { return ox + u * s }
      function py(v) { return oy + v * s }
      function card(x, y, w, h, r) {
        ctx.beginPath()
        ctx.moveTo(px(x + r), py(y))
        ctx.lineTo(px(x + w - r), py(y))
        ctx.quadraticCurveTo(px(x + w), py(y), px(x + w), py(y + r))
        ctx.lineTo(px(x + w), py(y + h - r))
        ctx.quadraticCurveTo(px(x + w), py(y + h), px(x + w - r), py(y + h))
        ctx.lineTo(px(x + r), py(y + h))
        ctx.quadraticCurveTo(px(x), py(y + h), px(x), py(y + h - r))
        ctx.lineTo(px(x), py(y + r))
        ctx.quadraticCurveTo(px(x), py(y), px(x + r), py(y))
        ctx.closePath()
        ctx.fill()
      }

      ctx.reset()
      ctx.fillStyle = root.color
      card(0.08, 0.10, 0.38, 0.28, 0.06)
      card(0.08, 0.46, 0.38, 0.44, 0.06)
      card(0.54, 0.10, 0.38, 0.52, 0.06)
      card(0.54, 0.70, 0.38, 0.20, 0.06)
    }
  }
}
