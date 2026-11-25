import QtQuick
import "ClockModel.js" as Clock
import "ClockTheme.js" as Theme

// One ring's 60 dots and 60 labels, unrotated and at full alpha, rasterised
// at `supersample`x. Rotation and alpha are applied later, on the GPU, by
// RingCanvas's shader — so this repaints only when its inputs change, never
// per tick. Geometry matches the old per-frame drawDotRing exactly.
Canvas {
  id: tex

  property real supersample: 1
  property real cx: 0
  property real cy: 0
  property real radius: 96
  property color dotColor: "white"
  property color labelColor: "white"
  property bool showLabels: true
  property real labelScale: 1
  property string labelFont: ""
  property string numerals: "western"

  renderStrategy: Canvas.Cooperative
  renderTarget: Canvas.FramebufferObject

  readonly property string paintKey: [
    width, height, supersample, cx, cy, radius, dotColor, labelColor,
    showLabels, labelScale, labelFont, numerals
  ].join("|")
  onPaintKeyChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    ctx.clearRect(0, 0, width, height)
    ctx.save()
    ctx.scale(tex.supersample, tex.supersample)

    var s = tex.labelScale
    var fontPx = Math.max(7, Math.round(8 * s))
    var dotR = Math.max(1.1, 1.3 * s)
    var angles = Clock.ringAngles()
    var fontFamilies = tex.labelFont.split(",").map(function(f) { return "\"" + f.trim() + "\"" }).join(", ")
    var labelR = tex.radius + Math.round(10 * s)
    var dotFill = Theme.ink(tex.dotColor, 1)
    var labelFill = Theme.ink(tex.labelColor, 1)

    ctx.font = "500 " + fontPx + "px " + fontFamilies
    ctx.textAlign = "center"
    ctx.textBaseline = "middle"

    for (var i = 0; i < 60; i++) {
      var angle = angles[i]
      ctx.beginPath()
      ctx.fillStyle = dotFill
      ctx.arc(tex.cx + Math.cos(angle) * tex.radius, tex.cy + Math.sin(angle) * tex.radius, dotR, 0, Math.PI * 2)
      ctx.fill()

      if (tex.showLabels) {
        ctx.save()
        ctx.translate(tex.cx + Math.cos(angle) * labelR, tex.cy + Math.sin(angle) * labelR)
        ctx.rotate(angle + Math.PI / 2)
        ctx.fillStyle = labelFill
        ctx.fillText(Clock.localizeDigits(Clock.pad2(i), tex.numerals), 0, 0)
        ctx.restore()
      }
    }
    ctx.restore()
  }
}
