// The flat's surfaces (the exported apartment): unfiltered textures, vertices snapped to a
// coarse screen grid, painted relief and roughness, emission for fittings. Detail is calmed as
// texels shrink below a pixel so it doesn't sparkle on a phone.
// `flesh` (0..1) turns the surface to meat in place: the paint and paper stay underneath, veins
// come up through them, the colour goes red and wet, and the surface breathes. Level 2 is the
// same flat with this turned up.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness = 0.9;
uniform float specular = 0.4;
uniform sampler2D roughness_tex : hint_default_white, filter_nearest_mipmap, repeat_enable;
uniform bool use_roughness_tex = false;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal_tex = false;
uniform float normal_depth = 0.1;
uniform vec3 emission = vec3(0.0);
uniform sampler2D emission_tex : source_color, filter_nearest;
uniform bool use_emission_tex = false;
uniform bool use_alpha_cut = false;
uniform vec2 ps1_snap = vec2(640.0, 360.0);   // the PS1 wobble (Game.apply_wobble sets it on every material); 0 = off
uniform float flesh = 0.0;
uniform float flesh_seed = 0.0;
// the meat's colours: dark, light, the veins, and the glow in them (level 2: the blue of the hole)
uniform vec3 meat_dark : source_color = vec3(0.42, 0.09, 0.1);
uniform vec3 meat_light : source_color = vec3(0.78, 0.36, 0.33);
uniform vec3 meat_vein : source_color = vec3(0.2, 0.04, 0.16);
uniform vec3 meat_glow = vec3(0.25, 0.02, 0.12);
uniform vec3 paint_tint = vec3(1.0, 0.7, 0.68);
varying vec3 wp;
varying vec3 wn;

float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { return vnoise(p) * 0.55 + vnoise(p * 2.1) * 0.3 + vnoise(p * 4.3) * 0.15; }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (flesh > 0.0) {
		float b = sin(TIME * 1.4 + wp.x * 1.3 + wp.y * 0.9 + wp.z * 1.7) * 0.5 + 0.5;
		VERTEX += NORMAL * flesh * (0.006 + 0.01 * b) * fbm(wp * 3.0 + flesh_seed);
	}
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (ps1_snap.x > 0.0) clip.xy = floor(clip.xy / clip.w * ps1_snap * 0.5 + 0.5) / (ps1_snap * 0.5) * clip.w;
	POSITION = clip;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo_color;
	vec2 duv = fwidth(UV) * vec2(textureSize(albedo_tex, 0));
	float far = clamp(log2(max(max(duv.x, duv.y), 1.0)) / 3.0, 0.0, 1.0);
	if (use_alpha_cut && c.a < 0.5 * (1.0 - far)) discard;
	float rough = roughness * (use_roughness_tex ? texture(roughness_tex, UV).g : 1.0);
	vec3 col = c.rgb;
	float spec = specular;
	if (flesh > 0.0) {
		// meat coming up through the paint: patches, then veins over everything
		vec3 q = wp * 1.7 + flesh_seed;
		float patch = smoothstep(0.35, 0.65, fbm(q) + flesh * 0.45 - 0.25);
		float n = fbm(wp * 6.0 + flesh_seed);
		vec3 meat = mix(meat_dark, meat_light, n);
		float v1 = abs(fbm(wp * vec3(2.2, 0.9, 2.2) + 7.0) - 0.5);
		float vein = 1.0 - smoothstep(0.0, 0.03, v1);
		meat = mix(meat, meat_vein, vein * 0.85);
		float k = clamp(patch * flesh * 1.2, 0.0, 1.0);
		col = mix(col * mix(vec3(1.0), paint_tint, flesh), meat, k);
		rough = mix(rough, 0.25, k);            // wet
		spec = mix(spec, 0.8, k);
		EMISSION = meat_glow * vein * k * (0.6 + 0.4 * sin(TIME * 1.4 + wp.x));
	}
	ALBEDO = col;
	float curve = length(fwidth(NORMAL));
	ROUGHNESS = clamp(max(mix(rough, 1.0, far * 0.65), min(curve * 1.5, 1.0)), 0.0, 1.0);
	SPECULAR = spec * (1.0 - far * 0.6);
	if (use_normal_tex) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_depth * (1.0 - far * 0.75);
	}
	EMISSION += use_emission_tex ? texture(emission_tex, UV).rgb * emission : emission;
}
