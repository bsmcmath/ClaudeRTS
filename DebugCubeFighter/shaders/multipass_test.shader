#version 450

// A minimal TWO-pass material shader used to verify multi-pass support:
//   * forward — lit color, alpha blend
//   * shadow  — depth-only (front-face cull, depth write, empty fragment)
// The shared preamble (camera + push constant + params) precedes the first pass
// directive and is prepended to every pass. See bb/ShaderPasses.h.
#include "common.glsl"

//@color tint 1 1 1 1

layout(set = 0, binding = 0) uniform Camera { mat4 viewProj; } cam;
layout(push_constant) uniform Push { mat4 model; vec4 color; } pc;

//@pass forward
//@blend alpha
//@cull  back
#ifdef STAGE_VERT
layout(location = 0) in vec3 inPos;
layout(location = 1) in vec3 inNormal;
layout(location = 0) out vec3 vNormal;
void main() {
    vNormal = mat3(pc.model) * inNormal;
    gl_Position = cam.viewProj * pc.model * vec4(inPos, 1.0);
}
#endif
#ifdef STAGE_FRAG
layout(location = 0) in vec3 vNormal;
layout(location = 0) out vec4 outColor;
layout(set = 1, binding = 1) uniform Params { vec4 p[16]; } P;
void main() {
    vec3 lit = bbDirLight(P.p[0].rgb, vNormal);
    outColor = vec4(lit, 1.0);
}
#endif

//@pass shadow
//@cull  front
//@depth write
#ifdef STAGE_VERT
layout(location = 0) in vec3 inPos;
void main() {
    gl_Position = cam.viewProj * pc.model * vec4(inPos, 1.0);
}
#endif
#ifdef STAGE_FRAG
void main() {}   // depth-only; depth is written by the fixed-function stage
#endif
