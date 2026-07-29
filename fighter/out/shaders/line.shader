#version 450

// The engine's built-in debug-line/gizmo shader (unlit vertex color). Split into
// line.vert.spv / line.frag.spv, loaded by name in LinePipeline. The view-projection
// arrives as a push constant; there is no per-object model matrix.
layout(push_constant) uniform Push { mat4 viewProj; } pc;

#ifdef STAGE_VERT
layout(location = 0) in vec3 inPos;
layout(location = 1) in vec3 inColor;
layout(location = 0) out vec3 vColor;
void main() {
    vColor = inColor;
    gl_Position = pc.viewProj * vec4(inPos, 1.0);
}
#endif

#ifdef STAGE_FRAG
layout(location = 0) in vec3 vColor;
layout(location = 0) out vec4 outColor;
void main() {
    outColor = vec4(vColor, 1.0);
}
#endif
