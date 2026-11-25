#version 440
// Composites the two static ring textures, each rotated by its own angle
// about the dial centre, and multiplies each by its fixed on-screen alpha
// mask (minute ring in maskTex.r, seconds ring in maskTex.g).
// Recompile after editing:  /usr/lib/qt6/bin/qsb --qt6 -o shaders/ring.frag.qsb shaders/ring.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  vec2 center;
  vec2 size;
  float minuteAngle;
  float secondAngle;
  float showSecond;
};

layout(binding = 1) uniform sampler2D minuteTex;
layout(binding = 2) uniform sampler2D secondTex;
layout(binding = 3) uniform sampler2D maskTex;

// Content rotated by +a on screen is sampled at R(-a) applied to the pixel.
vec4 sampleRotated(sampler2D tex, vec2 uv, float a) {
  vec2 p = uv * size - center;
  float c = cos(a);
  float s = sin(a);
  vec2 q = (vec2(c * p.x + s * p.y, -s * p.x + c * p.y) + center) / size;
  if (q.x < 0.0 || q.y < 0.0 || q.x > 1.0 || q.y > 1.0) return vec4(0.0);
  return texture(tex, q);
}

void main() {
  vec4 mask = texture(maskTex, qt_TexCoord0);
  vec4 m = sampleRotated(minuteTex, qt_TexCoord0, minuteAngle) * mask.r;
  vec4 s = sampleRotated(secondTex, qt_TexCoord0, secondAngle) * (mask.g * showSecond);
  // Premultiplied source-over: seconds ring drawn on top of the minute ring,
  // as the old renderer did.
  fragColor = (s + m * (1.0 - s.a)) * qt_Opacity;
}
