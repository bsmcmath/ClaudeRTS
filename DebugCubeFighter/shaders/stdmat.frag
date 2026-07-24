#version 450

// Standard material fragment shader. The material's editable parameters are
// DECLARED HERE via //@ annotations — the editor reads them to build the material
// inspector, and packs the value params (in this order) into the constants block
// as one vec4 each: p[0]=tint, p[1]=emissive, p[2].x=roughness.
//
//@tex   albedo 0
//@color tint 1 1 1 1
//@color emissive 0 0 0 0
//@float roughness 0.5

layout(location = 0) in vec3 vNormal;
layout(location = 1) in vec2 vUV;
layout(location = 0) out vec4 outColor;

layout(set = 1, binding = 0) uniform sampler2D tex[4];
layout(set = 1, binding = 1) uniform Params { vec4 p[16]; } P;

layout(push_constant) uniform Push {
    mat4 model;
    vec4 color;
} pc;

void main() {
    vec3 n = normalize(vNormal);
    float diff = max(dot(n, normalize(vec3(0.4, 1.0, 0.3))), 0.0);
    vec3 base = texture(tex[0], vUV).rgb * P.p[0].rgb * pc.color.rgb; // albedo * tint
    vec3 lit = base * (0.25 + 0.75 * diff) + P.p[1].rgb;             // + emissive
    outColor = vec4(lit, 1.0);
}
