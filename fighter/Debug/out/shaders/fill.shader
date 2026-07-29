#version 450

// Translucent filled-triangle gizmo shader (unlit RGBA vertex color). Companion to line.shader,
// loaded by name in LinePipeline as fill.vert.spv / fill.frag.spv and drawn alpha-blended, so
// gizmo faces (e.g. the nav-mesh surface shading) read as translucent surfaces. The view-projection
// arrives as a push constant; there is no per-object model matrix.
layout(push_constant) uniform Push { mat4 viewProj; } pc;

#ifdef STAGE_VERT
layout(location = 0) in vec3 inPos;
layout(location = 1) in vec4 inColor;
layout(location = 0) out vec4 vColor;
void main() {
    vColor = inColor;
    gl_Position = pc.viewProj * vec4(inPos, 1.0);
}
#endif

#ifdef STAGE_FRAG
layout(location = 0) in vec4 vColor;
layout(location = 0) out vec4 outColor;
void main() {
    outColor = vColor;
}
#endif
