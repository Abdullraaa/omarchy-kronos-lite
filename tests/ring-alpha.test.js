// Run: node tests/ring-alpha.test.js
// Compares the new per-angle mask alpha against the OLD per-dot loop from
// RingCanvas.qml (git 2ed29eb drawDotRing), transcribed verbatim. Random
// progress per run; exits non-zero if any dot/label alpha differs by > 1e-9.
const fs=require("fs"); const src=fs.readFileSync(require("path").join(__dirname, "..", "ClockModel.js"),"utf8").replace(".pragma library","");
const C={}; new Function("Qt", src+"\nObject.assign(this,{ringDotAlphaAt,ringLabelAlphaAt,ringRotationRad,ringAngles,normalizeAngle0,dotOnArc,isRingLabelVisible,ringDotFade,ringDotAlpha,ringEdgeMeetFade,arcBoundsActive,layoutSpec,resolvedArcBounds});").call(C,{formatDate:()=>""});
function oldLoop(progress, focus, arcFrom, arcTo, fullRing, strength, emph, edgeFade) {
  const clipArc = C.arcBoundsActive(arcFrom, arcTo), fromArg = clipArc?arcFrom:null, toArg = clipArc?arcTo:null
  const rotation = C.ringRotationRad(progress, focus), angles = C.ringAngles(), out=[]
  for (let i=0;i<60;i++){
    const worldAngle = C.normalizeAngle0(angles[i]+rotation)
    if (clipArc && !C.dotOnArc(worldAngle, arcFrom, arcTo)) { out.push({w:worldAngle,dot:0,label:0}); continue }
    const onFace = fullRing || clipArc || C.isRingLabelVisible(worldAngle, fullRing, fromArg, toArg)
    const fade = clipArc ? 1 : C.ringDotFade(i, progress, onFace)
    let alpha = C.ringDotAlpha(true, fade, onFace, strength)
    if (clipArc) alpha *= C.ringEdgeMeetFade(worldAngle, arcFrom, arcTo, edgeFade)
    if (clipArc && emph) alpha = Math.min(1, alpha*1.15)
    let la = onFace ? (0.44+fade*0.52) : (0.24+fade*0.28)
    if (clipArc) la *= C.ringEdgeMeetFade(worldAngle, arcFrom, arcTo, edgeFade)
    if (clipArc && emph) la = Math.min(1, la*1.12)
    out.push({w:worldAngle,dot:alpha,label:Math.min(1,la*strength)})
  }
  return out
}
let n=0, worst=0
const cases=[["top-right","orbital",327,0],["middle-right","orbital",360,0.3],["top-left","orbital",90,-0.5],["bottom-center","orbital",200,0],["middle-left","orbital",120,1.1]]
for (const [pos,lay,deg,rotOff] of cases) {
  const spec=C.layoutSpec(pos,lay,deg), arc=C.resolvedArcBounds(spec)
  const focus=spec.focusAngle+rotOff
  for (const strength of [1,0.6,0.25]) for (let k=0;k<40;k++){
    const progress=Math.random()*60
    for (const d of oldLoop(progress,focus,arc.from,arc.to,spec.fullRing,strength,spec.arcEmphasis===true,spec.arcEdgeFade)) {
      const nd=C.ringDotAlphaAt(d.w,focus,arc.from,arc.to,spec.fullRing,strength,spec.arcEmphasis===true,spec.arcEdgeFade)
      const nl=C.ringLabelAlphaAt(d.w,focus,arc.from,arc.to,spec.fullRing,strength,spec.arcEmphasis===true,spec.arcEdgeFade)
      worst=Math.max(worst,Math.abs(nd-d.dot),Math.abs(nl-d.label)); n++
    }
  }
  console.log(pos,deg,"fullRing="+spec.fullRing,"emph="+spec.arcEmphasis,"from="+arc.from)
}
console.log("dots compared:",n,"worst abs diff:",worst)
if (worst>1e-9) process.exit(1)
