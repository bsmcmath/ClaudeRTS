#version 450

// Post pass: samples the offscreen "world" target (inTex[0]) and applies a cheap CRT look —
// chromatic aberration + scanlines + vignette — writing the presented image. This is the
// "offscreen texture used in another pass" the example demonstrates.

layout(location = 0) in vec2 vUV;
layout(location = 0) out vec4 outColor;

layout(set = 0, binding = 0) uniform sampler2D inTex[8]; // inputs listed in postPass(); [0] = "world"

void main() {
    vec2 uv = vUV;
    vec2 fromCenter = uv - 0.5;

    // Chromatic aberration: pull the R and B channels apart radially (obvious proof we're
    // re-sampling the offscreen texture, not drawing it directly).
    float ab = 0.0035;
    vec3 col;
    col.r = texture(inTex[0], uv + fromCenter * ab).r;
    col.g = texture(inTex[0], uv).g;
    col.b = texture(inTex[0], uv - fromCenter * ab).b;

    // Scanlines + a soft vignette.
    col *= 0.90 + 0.10 * sin(uv.y * 900.0);
    col *= smoothstep(1.15, 0.35, length(fromCenter) * 1.35);

    outColor = vec4(col, 1.0);
}
