#version 450

// Supersample resolve: box-downsample a higher-resolution source into this pass's
// (lower-res) target. Each destination pixel covers `footprint` source texels each
// axis; we average a `taps`×`taps` grid evenly spanning that footprint. With the
// fullscreen pass's LINEAR sampler each tap is itself a 2x2 average, so for an integer
// N× supersample `taps = N` box-filters exactly. Driven by RenderGraph::downsample(),
// which sets the params from the two targets' sizes — so it works for any multiplier.
layout(location = 0) in vec2 vUV;
layout(location = 0) out vec4 outColor;

layout(set = 0, binding = 0) uniform sampler2D inTex[8];

layout(push_constant) uniform P {
    vec2 srcTexel;  // 1/srcWidth, 1/srcHeight
    vec2 footprint; // source texels covered per destination pixel, each axis (= multiplier)
    int  taps;      // samples per axis (clamped 1..8 on the CPU side)
} p;

void main() {
    const int kMax = 8;
    int n = clamp(p.taps, 1, kMax);
    float inv = 1.0 / float(n);
    vec4 sum = vec4(0.0);
    for (int y = 0; y < kMax; ++y) {
        if (y >= n) break;
        for (int x = 0; x < kMax; ++x) {
            if (x >= n) break;
            // Offset in [-0.5, 0.5] of the footprint, sampled at sub-cell centers.
            vec2 o = (vec2(float(x), float(y)) + 0.5) * inv - 0.5;
            sum += texture(inTex[0], vUV + o * p.footprint * p.srcTexel);
        }
    }
    outColor = sum / float(n * n);
}
