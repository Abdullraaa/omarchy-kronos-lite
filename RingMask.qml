import QtQuick
import "ClockModel.js" as Clock

// Static on-screen alpha mask for RingCanvas's shader: minute ring in the red
// channel, seconds ring in green. Drawn as thin angular wedges in two radial
// bands per ring (dots, labels), each wedge's alpha being the old renderer's
// per-dot formula at that world angle (ClockModel.ringDotAlphaAt /
// ringLabelAlphaAt). Repaints only on config/geometry change.
Canvas {
  id: mask

  property real cx: 0
  property real cy: 0
  property real minuteRadius: 96
  property real secondRadius: 120
  property bool showSeconds: true
  property real labelScale: 1
  property real focusAngle: 0
  property bool fullRing: false
  property real arcFrom: NaN
  property real arcTo: NaN
  property real ringStrength: 1
  property bool arcEmphasis: false
  property real arcEdgeFade: 0.05

  // 0.5° wedges: fine enough that the arc-edge fade (≥ ~5% of the arc) is smooth.
  readonly property int steps: 720

  renderStrategy: Canvas.Cooperative
  renderTarget: Canvas.FramebufferObject

  readonly property string paintKey: [
    width, height, cx, cy, minuteRadius, secondRadius, showSeconds, labelScale,
    focusAngle, fullRing, arcFrom, arcTo, ringStrength, arcEmphasis, arcEdgeFade
  ].join("|")
  onPaintKeyChanged: requestPaint()

  function band(ctx, inner, outer, a0, a1, r, g, alpha) {
    if (alpha <= 0 || outer <= inner) return
    ctx.beginPath()
    ctx.arc(mask.cx, mask.cy, outer, a0, a1, false)
    ctx.arc(mask.cx, mask.cy, Math.max(0, inner), a1, a0, true)
    ctx.closePath()
    ctx.fillStyle = Qt.rgba(r, g, 0, alpha)
    ctx.fill()
  }

  function drawRing(ctx, radius, r, g) {
    var s = mask.labelScale
    var fontPx = Math.max(7, Math.round(8 * s))
    var labelOffset = Math.round(10 * s)
    // Dot/label boundary halfway between the dot (≤ ~1.3s) and the label's
    // inner edge (~labelOffset - 0.4 * fontPx).
    var split = radius + labelOffset / 2
    var dotInner = radius - labelOffset / 2
    var labelOuter = radius + labelOffset + fontPx
    var step = Math.PI * 2 / mask.steps
    // Adjacent wedges share edges exactly; with "lighter" (additive) their
    // anti-aliased coverage sums to 1, so no seam. Additive also keeps each
    // ring's channel independent of the other's.
    var arcFromArg = Clock.arcBoundsActive(mask.arcFrom, mask.arcTo) ? mask.arcFrom : null
    var arcToArg = arcFromArg === null ? null : mask.arcTo
    for (var k = 0; k < mask.steps; k++) {
      var a0 = k * step
      var mid = a0 + step / 2
      var dotA = Clock.ringDotAlphaAt(mid, mask.focusAngle, arcFromArg, arcToArg, mask.fullRing,
        mask.ringStrength, mask.arcEmphasis, mask.arcEdgeFade)
      var labelA = Clock.ringLabelAlphaAt(mid, mask.focusAngle, arcFromArg, arcToArg, mask.fullRing,
        mask.ringStrength, mask.arcEmphasis, mask.arcEdgeFade)
      mask.band(ctx, dotInner, split, a0, a0 + step, r, g, dotA)
      mask.band(ctx, split, labelOuter, a0, a0 + step, r, g, labelA)
    }
  }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    ctx.clearRect(0, 0, width, height)
    ctx.globalCompositeOperation = "lighter"
    mask.drawRing(ctx, mask.minuteRadius, 1, 0)
    if (mask.showSeconds) mask.drawRing(ctx, mask.secondRadius, 0, 1)
  }
}
