#version 450

// The engine's built-in instanced mesh shader (one draw, many instances). Split by
// #ifdef into mesh_instanced.vert.spv / mesh_instanced.frag.spv, loaded by name in
// InstancedPipeline. Per-instance model matrix + color arrive as vertex attributes;
// lighting is the shared helper from common.glsl.
#include "common.glsl"

layout(set = 0, binding = 0) uniform Camera { mat4 viewProj; } cam;

#ifdef STAGE_VERT
// Per-vertex (binding 0).
layout(location = 0) in vec3 inPos;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inUV;
// Per-instance (binding 1): a model matrix (as 4 columns) + a color.
layout(location = 3) in vec4 iModel0;
layout(location = 4) in vec4 iModel1;
layout(location = 5) in vec4 iModel2;
layout(location = 6) in vec4 iModel3;
layout(location = 7) in vec4 iColor;
layout(location = 0) out vec3 vNormal;
layout(location = 1) out vec2 vUV;
layout(location = 2) out vec4 vColor;
void main() {
    mat4 model = mat4(iModel0, iModel1, iModel2, iModel3);
    vNormal = mat3(model) * inNormal;
    vUV = inUV;
    vColor = iColor;
    gl_Position = cam.viewProj * model * vec4(inPos, 1.0);
}
#endif

#ifdef STAGE_FRAG
layout(location = 0) in vec3 vNormal;
layout(location = 1) in vec2 vUV;
layout(location = 2) in vec4 vColor;
layout(location = 0) out vec4 outColor;
layout(set = 1, binding = 0) uniform sampler2D tex[4];
void main() {
    vec3 base = texture(tex[0], vUV).rgb * vColor.rgb;
    outColor = vec4(bbDirLight(base, vNormal), 1.0);
}
#endif
