import QtQuick
import qs.Commons
import "ClockModel.js" as Clock
import "ClockTheme.js" as Theme

// Minute and seconds dot rings, 60 ticks each with a numeric label (00–59).
//
// Nothing here repaints per tick. Each ring is drawn once, unrotated and at
// full alpha, into a static texture (RingTexture); a static on-screen alpha
// mask (RingMask) holds the fade/arc-clip that the old renderer applied per
// dot. Both are fixed for a given config — the per-dot alpha depends only on
// a dot's world angle (see ClockModel.ringDotAlphaAt). Per tick, only the two
// rotation angles change, as ShaderEffect uniforms, and the GPU composites.
// Static layers repaint only when one of their inputs changes.
Item {
  id: canvas

  property real cx: 0
  property real cy: 0
  property real minuteRadius: 96
  property real secondRadius: 120
  property real minuteProgress: 0
  property real secondProgress: 0
  property real focusAngle: 0
  property bool fullRing: false
  property bool showSeconds: true
  property real ringStrength: 1
  property color ringColor: Color.foreground
  property color secondRingColor: canvas.ringColor
  property color minuteLabelColor: canvas.ringColor
  property color secondLabelColor: canvas.secondRingColor
  property bool showLabels: true
  property real labelScale: 1
  property real chromeScale: 1
  property string labelFont: Style.font.family
  property string numerals: "western"
  property real arcFrom: NaN
  property real arcTo: NaN
  property bool showGuideRing: false
  property bool arcEmphasis: false
  property real arcEdgeFade: 0.05

  readonly property bool arcClip: Clock.arcBoundsActive(canvas.arcFrom, canvas.arcTo)

  // Ring textures are rasterised at this multiple of the item size and
  // minified (mipmapped) by the shader, so rotated label text stays crisp.
  readonly property real supersample: 2

  function repaint() {
    guide.requestPaint()
    minuteTexture.requestPaint()
    secondTexture.requestPaint()
    mask.requestPaint()
  }

  // Fixed on-screen guide strokes (full-ring guide, arc guides). Not masked.
  Canvas {
    id: guide
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative
    renderTarget: Canvas.FramebufferObject

    readonly property string paintKey: [
      canvas.width, canvas.height, canvas.cx, canvas.cy, canvas.minuteRadius, canvas.secondRadius,
      canvas.showSeconds, canvas.chromeScale, canvas.ringStrength, canvas.arcEmphasis,
      canvas.showGuideRing, canvas.fullRing, canvas.arcFrom, canvas.arcTo, canvas.ringColor
    ].join("|")
    onPaintKeyChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)

      var outerR = canvas.showSeconds ? canvas.secondRadius : canvas.minuteRadius
      var guideR = outerR + Math.round(16 * canvas.chromeScale) * 0.42
      var lw = Math.max(1, canvas.chromeScale * 0.8)
      var guideAlpha = 0.14 * canvas.ringStrength * (canvas.arcEmphasis ? 2 : 1)

      if (canvas.showGuideRing && canvas.fullRing) {
        ctx.beginPath()
        ctx.strokeStyle = Theme.ink(canvas.ringColor, 0.07 * canvas.ringStrength)
        ctx.lineWidth = lw
        ctx.arc(canvas.cx, canvas.cy, guideR, 0, Math.PI * 2)
        ctx.stroke()
      }

      if (canvas.arcClip) {
        var guideFrom = Clock.normalizeAngle0(canvas.arcFrom)
        var guideTo = Clock.normalizeAngle0(canvas.arcTo)
        var arcLw = lw * (canvas.arcEmphasis ? 1.55 : 1)
        ctx.beginPath()
        ctx.strokeStyle = Theme.ink(canvas.ringColor, guideAlpha)
        ctx.lineWidth = arcLw
        ctx.arc(canvas.cx, canvas.cy, guideR, guideFrom, guideTo)
        ctx.stroke()
        if (canvas.arcEmphasis) {
          var innerGuideR = canvas.minuteRadius + Math.round(16 * canvas.chromeScale) * 0.42
          ctx.beginPath()
          ctx.strokeStyle = Theme.ink(canvas.ringColor, guideAlpha * 0.75)
          ctx.lineWidth = Math.max(1, arcLw * 0.9)
          ctx.arc(canvas.cx, canvas.cy, innerGuideR, guideFrom, guideTo)
          ctx.stroke()
        }
      }
    }
  }

  RingTexture {
    id: minuteTexture
    width: canvas.width * canvas.supersample
    height: canvas.height * canvas.supersample
    supersample: canvas.supersample
    cx: canvas.cx
    cy: canvas.cy
    radius: canvas.minuteRadius
    dotColor: canvas.ringColor
    labelColor: canvas.minuteLabelColor
    showLabels: canvas.showLabels
    labelScale: canvas.labelScale
    labelFont: canvas.labelFont
    numerals: canvas.numerals
  }

  RingTexture {
    id: secondTexture
    width: canvas.width * canvas.supersample
    height: canvas.height * canvas.supersample
    supersample: canvas.supersample
    cx: canvas.cx
    cy: canvas.cy
    radius: canvas.secondRadius
    dotColor: canvas.secondRingColor
    labelColor: canvas.secondLabelColor
    showLabels: canvas.showLabels
    labelScale: canvas.labelScale
    labelFont: canvas.labelFont
    numerals: canvas.numerals
  }

  RingMask {
    id: mask
    width: canvas.width
    height: canvas.height
    cx: canvas.cx
    cy: canvas.cy
    minuteRadius: canvas.minuteRadius
    secondRadius: canvas.secondRadius
    showSeconds: canvas.showSeconds
    labelScale: canvas.labelScale
    focusAngle: canvas.focusAngle
    fullRing: canvas.fullRing
    arcFrom: canvas.arcFrom
    arcTo: canvas.arcTo
    ringStrength: canvas.ringStrength
    arcEmphasis: canvas.arcEmphasis
    arcEdgeFade: canvas.arcEdgeFade
  }

  ShaderEffectSource {
    id: minuteSource
    sourceItem: minuteTexture
    hideSource: true
    mipmap: true
    smooth: true
    visible: false
  }

  ShaderEffectSource {
    id: secondSource
    sourceItem: secondTexture
    hideSource: true
    mipmap: true
    smooth: true
    visible: false
  }

  ShaderEffectSource {
    id: maskSource
    sourceItem: mask
    hideSource: true
    smooth: true
    visible: false
  }

  ShaderEffect {
    anchors.fill: parent
    blending: true
    fragmentShader: Qt.resolvedUrl("shaders/ring.frag.qsb")

    property var minuteTex: minuteSource
    property var secondTex: secondSource
    property var maskTex: maskSource
    property point center: Qt.point(canvas.cx, canvas.cy)
    property size size: Qt.size(Math.max(1, canvas.width), Math.max(1, canvas.height))
    // The only per-tick inputs.
    property real minuteAngle: Clock.ringRotationRad(canvas.minuteProgress, canvas.focusAngle)
    property real secondAngle: Clock.ringRotationRad(canvas.secondProgress, canvas.focusAngle)
    property real showSecond: canvas.showSeconds ? 1 : 0
  }
}
