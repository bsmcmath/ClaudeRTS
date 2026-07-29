#version 450

// The engine's built-in mesh shader (STAGE_VERT / STAGE_FRAG). Lighting comes from the
// shared helper in common.glsl. Set 0 carries the camera + DDGI globals (probe irradiance
// field); when DDGI is disabled the fragment uses a flat ambient, so rendering is
// unchanged.
#include "common.glsl"

// Camera view-projection + DDGI volume params (set 0, binding 0). ddgiSpacing.x = probe
// spacing, ddgiSpacing.y = enabled (>0.5). The probe L1 SH field (3 vec4 per probe:
// R,G,B) is the storage buffer at binding 1.
layout(set = 0, binding = 0) uniform Camera {
    mat4 viewProj;
    vec4 ddgiOrigin;   // xyz = world position of probe (0,0,0)
    ivec4 ddgiCounts;  // xyz = grid dims
    vec4 ddgiSpacing;  // x = spacing, y = enabled, z = intensity
    ivec4 ddgiBrick;   // x = brick size (probes/side), yzw = brick grid dims
    ivec4 ddgiScroll;  // xyz = origin brick-lattice coord (toroidal window base)
    vec4 ddgiSpacing1; // x = coarse-cascade spacing, y = cascade enabled (>0.5)
    ivec4 ddgiScroll1; // xyz = coarse-cascade origin brick-lattice coord
} cam;
// Sparse probe field: `dsh` is the SH POOL (3 vec4 per probe, indexed by slot*B^3 + local);
// `dslot` maps a brick index -> its pool slot, or -1 when the brick has no storage. Bindings
// 3/4 are the same for the coarse cascade level (shares the brick size + grid dims of level 0).
layout(set = 0, binding = 1, std430) readonly buffer DdgiSh { vec4 dsh[]; };
layout(set = 0, binding = 2, std430) readonly buffer DdgiSlots { int dslot[]; };
layout(set = 0, binding = 3, std430) readonly buffer DdgiSh1 { vec4 dsh1[]; };
layout(set = 0, binding = 4, std430) readonly buffer DdgiSlots1 { int dslot1[]; };
// Fine-level directional occluder-distance moments (mean, mean^2), 6 axis faces = 3 vec4 per
// pool probe, indexed by slot like the SH. Filled by the gather; read here for Chebyshev
// visibility (reject a probe the surface can't see past an occluder) — anti-leak. The coarse
// cascade has no depth pool (it shares the SH dummies), so Chebyshev is applied to level 0 only.
layout(set = 0, binding = 5, std430) readonly buffer DdgiDepth { vec4 ddm[]; };
layout(push_constant) uniform Push { mat4 model; vec4 color; } pc;

#ifdef STAGE_VERT
layout(location = 0) in vec3 inPos;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inUV;
layout(location = 0) out vec3 vNormal;
layout(location = 1) out vec2 vUV;
layout(location = 2) out vec3 vWorld;
void main() {
    vec4 world = pc.model * vec4(inPos, 1.0);
    vNormal = mat3(pc.model) * inNormal;
    vUV = inUV;
    vWorld = world.xyz;
    gl_Position = cam.viewProj * world;
}
#endif

#ifdef STAGE_FRAG
layout(location = 0) in vec3 vNormal;
layout(location = 1) in vec2 vUV;
layout(location = 2) in vec3 vWorld;
layout(location = 0) out vec4 outColor;
layout(set = 1, binding = 0) uniform sampler2D tex[4];

// Cosine-convolved L1 SH irradiance for a normal (Ramamoorthi).
float bbShEval(vec4 c, vec3 n) {
    return max(0.886227 * c.x + 1.023328 * (c.y * n.y + c.z * n.z + c.w * n.x), 0.0);
}

int bbPmod(int a, int b) { return ((a % b) + b) % b; }
ivec3 bbFloorDiv(ivec3 a, int b) { return ivec3(floor(vec3(a) / float(b))); }

// Dominant axis + sign -> face 0..5 (+x,-x,+y,-y,+z,-z). MUST match ddgi_gather.comp's
// axisFace so a moment stored under a ray direction is read back under the same face.
int bbAxisFace(vec3 d) {
    vec3 a = abs(d);
    if (a.x >= a.y && a.x >= a.z) return d.x >= 0.0 ? 0 : 1;
    if (a.y >= a.z) return d.y >= 0.0 ? 2 : 3;
    return d.z >= 0.0 ? 4 : 5;
}
// (mean, mean^2) occluder-distance moment of pool probe `po` in axis `fc`. 6 faces pack into
// 3 vec4 as {f0.xy,f1.zw},{f2,f3},{f4,f5} — the layout ddgi_gather.comp writes.
vec2 bbFaceMoment(int po, int fc) {
    vec4 v = ddm[po * 3 + (fc >> 1)];
    return (fc & 1) == 0 ? v.xy : v.zw;
}
// Chebyshev visibility weight of a probe at world `probeWorld` for a surface point `wp`: 1 if
// the point is in front of the probe's mean occluder along the probe->point axis, tapering to 0
// when a wall sits between them (variance-based upper bound on P(visible)). Cuts light leaking
// through thin geometry that normal-bias/wrap-weight miss. `po` is the probe's pool index.
float bbChebyshev(int po, vec3 probeWorld, vec3 wp) {
    vec3 toPt = wp - probeWorld;      // probe -> surface point
    float dist = length(toPt);
    if (dist < 1e-4) return 1.0;      // sampling essentially at the probe: fully visible
    int fc = bbAxisFace(toPt);        // the probe face pointing at the surface point
    vec2 mm = bbFaceMoment(po, fc);
    if (mm.x <= 0.0) return 1.0;      // no occluder recorded on this face -> visible
    if (dist <= mm.x) return 1.0;     // point is nearer than the mean occluder -> visible
    float var = max(mm.y - mm.x * mm.x, 1e-5);
    float d = dist - mm.x;
    return clamp(var / (var + d * d), 0.0, 1.0);
}

// One cascade level's trilinear sample. Toroidal: probes live on a fixed GLOBAL world lattice;
// a corner maps to its lattice brick, and only if that brick is inside the level's scroll
// window [ob, ob+brickCounts) does it wrap to a storage brick -> pool slot. `level` selects the
// fine (0) or coarse (1) buffers. `covered` returns the summed weight — 0 = this level doesn't
// cover the point, so a cascade falls through to the coarser level.
vec3 bbDdgiLevel(vec3 wp, vec3 n, float spacing, ivec3 ob, int level, out float covered) {
    int B = cam.ddgiBrick.x;
    ivec3 bc = cam.ddgiBrick.yzw;
    // Normal-bias the sample point off the surface (fraction of this level's spacing) so a
    // probe just behind the wall doesn't leak through / self-shadow the surface.
    vec3 g = (wp + n * cam.ddgiSpacing.w * spacing) / spacing;
    ivec3 base = ivec3(floor(g));
    vec3 f = g - vec3(base);
    vec3 sum = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < 8; ++i) {
        ivec3 o = ivec3(i & 1, (i >> 1) & 1, (i >> 2) & 1);
        ivec3 pl = base + o;
        ivec3 bl = bbFloorDiv(pl, B);
        if (any(lessThan(bl, ob)) || any(greaterThanEqual(bl, ob + bc))) continue;
        ivec3 bs = ivec3(bbPmod(bl.x, bc.x), bbPmod(bl.y, bc.y), bbPmod(bl.z, bc.z));
        int bIdx = (bs.z * bc.y + bs.y) * bc.x + bs.x;
        int slot = (level == 0) ? dslot[bIdx] : dslot1[bIdx];
        if (slot < 0) continue;
        ivec3 lp = pl - bl * B;
        int po = slot * (B * B * B) + (lp.z * B + lp.y) * B + lp.x;
        vec3 w3 = mix(1.0 - f, f, vec3(o));
        float w = w3.x * w3.y * w3.z;
        // Wrap weight: a probe on the FRONT side of the surface (in the normal's hemisphere)
        // counts fully; one behind it (the far side of a thin wall) counts far less, cutting
        // light leak. wsum renormalises, so no darkening where the front probes suffice.
        vec3 toProbe = vec3(pl) * spacing - wp;
        float d2 = dot(toProbe, toProbe);
        // dw=1 when sampling exactly at the probe (avoid normalize(0) -> NaN).
        float dw = d2 > 1e-6 ? (dot(toProbe, n) * inversesqrt(d2) * 0.5 + 0.5) : 1.0;
        w *= dw * dw + 0.05;
        // Chebyshev occlusion (fine level only — the coarse cascade has no depth pool): fade
        // out a probe the surface can't see past a wall. `toProbe = probeWorld - wp`, so the
        // probe's world position is wp + toProbe.
        if (level == 0) w *= bbChebyshev(po, wp + toProbe, wp);
        vec3 e = (level == 0)
                     ? vec3(bbShEval(dsh[po * 3 + 0], n), bbShEval(dsh[po * 3 + 1], n),
                            bbShEval(dsh[po * 3 + 2], n))
                     : vec3(bbShEval(dsh1[po * 3 + 0], n), bbShEval(dsh1[po * 3 + 1], n),
                            bbShEval(dsh1[po * 3 + 2], n));
        sum += w * e;
        wsum += w;
    }
    covered = wsum;
    return wsum > 0.0 ? sum / wsum : vec3(0.0);
}

// THE APPLY: use the FINEST cascade level covering the point. `cov0` is the fine level's
// coverage fraction (1 in its interior, tapering to 0 past its window edge), so when a coarse
// level exists we CROSS-FADE fine->coarse by cov0 — no hard seam at the boundary. This is the
// brick-size hierarchy: fine detail near the focus, coarse wide coverage beyond it.
vec3 bbDdgiIrradiance(vec3 wp, vec3 n) {
    float cov0;
    vec3 e0 = bbDdgiLevel(wp, n, cam.ddgiSpacing.x, cam.ddgiScroll.xyz, 0, cov0);
    if (cam.ddgiSpacing1.y > 0.5) { // a coarse cascade level exists
        float cov1;
        vec3 e1 = bbDdgiLevel(wp, n, cam.ddgiSpacing1.x, cam.ddgiScroll1.xyz, 1, cov1);
        if (cov1 > 0.0) return mix(e1, e0, clamp(cov0, 0.0, 1.0)); // fine over coarse
    }
    return cov0 > 0.0 ? e0 : vec3(0.0);
}

void main() {
    vec3 base = texture(tex[0], vUV).rgb * pc.color.rgb;
    vec3 n = normalize(vNormal);
    vec3 L = normalize(vec3(0.4, 1.0, 0.3));
    float diff = max(dot(n, L), 0.0);
    vec3 lit;
    if (cam.ddgiSpacing.y > 0.5) {
        // DDGI indirect replaces the flat ambient (diffuse = albedo * irradiance / pi).
        // ddgiSpacing.z scales the indirect contribution (artist intensity control).
        vec3 indirect = base * bbDdgiIrradiance(vWorld, n) * 0.3183099 * cam.ddgiSpacing.z;
        lit = base * (0.7 * diff) + indirect;
    } else {
        lit = bbDirLight(base, n); // flat 0.3 ambient + directional (unchanged)
    }
    outColor = vec4(lit, 1.0);
}
#endif
