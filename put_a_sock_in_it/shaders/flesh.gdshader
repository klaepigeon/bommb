// The inhabitants' skin (docs/PEOPLE.md). The sculpt paints each vertex (COLOR); UV and UV2.x
// carry the vertex's rest position, so the fine detail here (pores, the grain of the skin,
// sweat) stays on the skin when the body moves instead of swimming through it. UV2.y is how wet
// that skin is: sweat, spit, the folds, the eyes. Wrapped diffuse for something like light under
// the skin; the PS1 vertex snap like everything else. Nothing animates in time: no shimmer.
shader_type spatial;
render_mode cull_back, diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 ps1_snap = vec2(0.0);
uniform float wet_gain = 1.0;
uniform float grain = 1.0;
uniform float hurt = 0.0;          // 0..1: how much of him is wounds now

varying vec3 rest;
varying float wet;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	rest = vec3(UV.x, UV.y, UV2.x);
	wet = UV2.y;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (ps1_snap.x > 0.0) clip.xy = floor(clip.xy / clip.w * ps1_snap * 0.5 + 0.5) / (ps1_snap * 0.5) * clip.w;
	POSITION = clip;
}

void fragment() {
	float pores = noise(rest * 140.0);
	float blotch = noise(rest * 60.0);
	vec3 c = COLOR.rgb * tint.rgb;
	c *= 1.0 + grain * ((pores - 0.5) * 0.12 + (blotch - 0.5) * 0.1);
	// wounds (the hurt uniform): darkening where the grain says so
	float w = smoothstep(1.0 - hurt * 0.6, 1.0 - hurt * 0.6 + 0.08, noise(rest * 18.0));
	c = mix(c, vec3(0.22, 0.02, 0.02), w * 0.8);
	ALBEDO = c;
	float wt = clamp(wet * wet_gain + w * 0.6, 0.0, 1.0);
	// the skin's grain on the light: bump from the pores, in screen space
	float hgt = pores * 0.6 + blotch * 0.4;
	vec3 dpx = dFdx(VERTEX);
	vec3 dpy = dFdy(VERTEX);
	float dhx = dFdx(hgt);
	float dhy = dFdy(hgt);
	vec3 r1 = cross(dpy, NORMAL);
	vec3 r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * 0.0012 * grain);
	ROUGHNESS = mix(0.85, 0.32, wt);
	SPECULAR = mix(0.25, 0.6, wt);
	METALLIC = 0.0;
}
