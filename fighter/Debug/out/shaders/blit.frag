#version 450

// Copy a single input texture to the output (used to present a graph target).
layout(location = 0) in vec2 vUV;
layout(location = 0) out vec4 outColor;

layout(set = 0, binding = 0) uniform sampler2D inTex[8];

void main() {
    outColor = texture(inTex[0], vUV);
}
