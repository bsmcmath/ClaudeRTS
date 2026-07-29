#version 450

// A single-file material shader: vertex + geometry + fragment stages in ONE
// `.shader`, split by `#ifdef STAGE_VERT / STAGE_GEOM / STAGE_FRAG` (the build
// compiles it once per stage it defines -> glass.vert.spv / glass.geom.spv /
// glass.frag.spv, which the engine loads exactly as before). Vertex + fragment
// are the minimum; the others are optional. Directives + params live here too.
#include "common.glsl"

//@blend alpha
//@depth test
//@cull  none
//@tex   albedo 0
//@color tint 0.3 0.7 1.0 0.4

// ---- shared across stages ----
layout(set = 0, binding = 0) uniform Camera { mat4 viewProj; } cam;
layout(push_constant) uniform Push { mat4 model; vec4 color; } pc;

#ifdef STAGE_VERT
layout(location = 0) in vec3 inPos;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inUV;
layout(location = 0) out vec3 vNormal;
layout(location = 1) out vec2 vUV;
void main() {
    vNormal = mat3(pc.model) * inNormal;
    vUV = inUV;
    gl_Position = cam.viewProj * pc.model * vec4(inPos, 1.0);
}
#endif

#ifdef STAGE_GEOM
layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;
layout(location = 0) in vec3 vNormal[];
layout(location = 1) in vec2 vUV[];
layout(location = 0) out vec3 gNormal;
layout(location = 1) out vec2 gUV;
void main() {
    for (int i = 0; i < 3; ++i) {
        gl_Position = gl_in[i].gl_Position;
        gNormal = vNormal[i];
        gUV = vUV[i];
        EmitVertex();
    }
    EndPrimitive();
}
#endif

#ifdef STAGE_FRAG
layout(location = 0) in vec3 gNormal;
layout(location = 1) in vec2 gUV;
layout(location = 0) out vec4 outColor;
layout(set = 1, binding = 0) uniform sampler2D tex[4];
layout(set = 1, binding = 1) uniform Params { vec4 p[16]; } P;
void main() {
    vec4 tint = P.p[0];                              // rgb color, a = opacity
    vec3 base = texture(tex[0], gUV).rgb * tint.rgb; // albedo * tint
    vec3 lit = bbDirLight(base, gNormal);            // shared helper from common.glsl
    outColor = vec4(lit, tint.a);                    // alpha drives the blend
}
#endif
