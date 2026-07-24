#version 450

// Procedural gradient skybox. Drawn as a fullscreen triangle (fullscreen.vert) at
// the START of a scene pass, before geometry, with depth test/write OFF — so it
// fills the whole background and any geometry drawn afterwards overwrites it. The
// per-pixel world-space view direction is reconstructed from the inverse
// view-projection, then the color is a top/horizon/ground gradient by its height.
layout(location = 0) in vec2 vUV;
layout(location = 0) out vec4 outColor;

layout(push_constant) uniform P {
    mat4 invViewProj; // clip -> world (inverse of the camera's viewProj)
    vec4 top;         // color at the zenith (looking straight up)
    vec4 horizon;     // color at the horizon line
    vec4 ground;      // color at the nadir (looking straight down)
} p;

void main() {
    // Reconstruct the NDC that produced this fragment, then unproject two points on
    // its clip-space ray and take the normalized world-space direction between them.
    vec2 ndc = vUV * 2.0 - 1.0;
    vec4 near = p.invViewProj * vec4(ndc, 0.0, 1.0);
    vec4 far  = p.invViewProj * vec4(ndc, 1.0, 1.0);
    vec3 dir = normalize(far.xyz / far.w - near.xyz / near.w);

    // dir.y: +1 up, 0 at horizon, -1 down. sqrt() thickens the band near the
    // horizon so the transition reads naturally rather than linearly.
    float h = dir.y;
    vec3 col = (h > 0.0) ? mix(p.horizon.rgb, p.top.rgb, sqrt(h))
                         : mix(p.horizon.rgb, p.ground.rgb, sqrt(-h));
    outColor = vec4(col, 1.0);
}
