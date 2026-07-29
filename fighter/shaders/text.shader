#version 450

// The engine's built-in screen-space text shader (bitmap-font glyph quads). Split
// into text.vert.spv / text.frag.spv, loaded by name in TextRenderer. Positions are
// in screen pixels (top-left origin); the push constant carries the tint and the
// pixels->NDC scale.
layout(push_constant) uniform Push {
    vec4 color;
    vec2 invScreen; // (2/width, 2/height)
} pc;

#ifdef STAGE_VERT
layout(location = 0) in vec2 inPos; // screen pixels, top-left origin
layout(location = 1) in vec2 inUV;
layout(location = 0) out vec2 vUV;
void main() {
    vUV = inUV;
    vec2 ndc = inPos * pc.invScreen - vec2(1.0); // pixels -> NDC (y down)
    gl_Position = vec4(ndc, 0.0, 1.0);
}
#endif

#ifdef STAGE_FRAG
layout(location = 0) in vec2 vUV;
layout(location = 0) out vec4 outColor;
layout(set = 0, binding = 0) uniform sampler2D atlas;
void main() {
    float coverage = texture(atlas, vUV).a;
    outColor = vec4(pc.color.rgb, pc.color.a * coverage);
}
#endif
