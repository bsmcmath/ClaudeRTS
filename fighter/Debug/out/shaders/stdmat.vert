#version 450

// Standard material vertex shader (same as the built-in mesh vert). Camera at
// set 0, per-object model matrix + color as push constants.
layout(location = 0) in vec3 inPos;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inUV;

layout(set = 0, binding = 0) uniform Camera {
    mat4 viewProj;
} cam;

layout(push_constant) uniform Push {
    mat4 model;
    vec4 color;
} pc;

layout(location = 0) out vec3 vNormal;
layout(location = 1) out vec2 vUV;

void main() {
    vNormal = mat3(pc.model) * inNormal;
    vUV = inUV;
    gl_Position = cam.viewProj * pc.model * vec4(inPos, 1.0);
}
