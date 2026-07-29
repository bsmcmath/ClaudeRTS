#version 450

// Anti-banding dither. Copies the input and adds a small triangular-PDF noise (a
// fraction of an 8-bit level) so the quantization at present spreads a smooth gradient
// across neighbouring codes instead of stepping. Triangular PDF (difference of two
// uniforms) gives noise that's independent of the signal — the "right" dither. Noise
// is per-pixel/per-channel and static (no shimmer). Amplitude comes from the pass
// params (RenderGraph::dither). Added in linear space, so it's most effective on
// mid/bright ramps; raise the amount for dark gradients.
layout(location = 0) in vec2 vUV;
layout(location = 0) out vec4 outColor;

layout(set = 0, binding = 0) uniform sampler2D inTex[8];

layout(push_constant) uniform P {
    float amount; // dither amplitude in 8-bit LSBs (of 255)
} p;

float hash(vec2 v) {
    return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec3 c = texture(inTex[0], vUV).rgb;
    vec2 fc = gl_FragCoord.xy;
    // Per-channel triangular noise in (-1, 1) from decorrelated hashes.
    vec3 tri = vec3(hash(fc) - hash(fc + 11.3),
                    hash(fc + 23.7) - hash(fc + 37.1),
                    hash(fc + 51.9) - hash(fc + 67.5));
    c += tri * (p.amount / 255.0);
    outColor = vec4(c, 1.0);
}
