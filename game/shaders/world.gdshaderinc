// HYSTERIA's lighting. Every surface in the game is lit here, by the eight lamps the light engine
// (scripts/render/lights.gd) chose for this frame, and Socko's torch. There are no Light3D nodes, so
// there's no per-object light limit to run into, no shadow atlas, nothing for a phone driver to drop.
// A lamp lights a surface only if the surface's zone is one the lamp reaches (its room, and rooms
// joined to it by an open door): light doesn't come through walls.
global uniform vec4 l0_pos; global uniform vec4 l0_col; global uniform vec4 l0_zone;
global uniform vec4 l1_pos; global uniform vec4 l1_col; global uniform vec4 l1_zone;
global uniform vec4 l2_pos; global uniform vec4 l2_col; global uniform vec4 l2_zone;
global uniform vec4 l3_pos; global uniform vec4 l3_col; global uniform vec4 l3_zone;
global uniform vec4 l4_pos; global uniform vec4 l4_col; global uniform vec4 l4_zone;
global uniform vec4 l5_pos; global uniform vec4 l5_col; global uniform vec4 l5_zone;
global uniform vec4 l6_pos; global uniform vec4 l6_col; global uniform vec4 l6_zone;
global uniform vec4 l7_pos; global uniform vec4 l7_col; global uniform vec4 l7_zone;
global uniform vec4 torch_pos;   // xyz, range
global uniform vec4 torch_dir;   // xyz, cos of the cone's edge
global uniform vec4 torch_col;   // rgb * energy
global uniform vec4 fog;         // rgb, distance at which it's total
global uniform vec4 world_tint;  // rgb multiply, a = saturation
global uniform vec2 snap_res;

uniform float zone = -1.0;                    // -1: lit by every lamp (things that move between rooms)
uniform vec3 ambient = vec3(0.1, 0.095, 0.1);
uniform float snap = 1.0;                     // PS1 vertex wobble (0 for things held up to the eye)
uniform float self_lit = 0.0;                 // 1 = paints its own colour (screens, the white outside)

varying vec3 v_wp;
varying vec3 v_wn;
#define WORLD_VERTEX vec3 _wp; vec3 _wn; world_vertex(VERTEX, NORMAL, MODEL_MATRIX, MODELVIEW_MATRIX, PROJECTION_MATRIX, _wp, _wn, POSITION); v_wp = _wp; v_wn = _wn;

void world_vertex(vec3 vtx, vec3 nrm, mat4 model, mat4 modelview, mat4 proj, out vec3 wp, out vec3 wn, inout vec4 position) {
	wp = (model * vec4(vtx, 1.0)).xyz;
	wn = normalize((model * vec4(nrm, 0.0)).xyz);
	vec4 clip = proj * (modelview * vec4(vtx, 1.0));
	if (snap > 0.0 && clip.w > 0.05) {
		vec2 g = snap_res * 0.5;
		vec2 ndc = clip.xy / clip.w;
		clip.xy = mix(ndc, floor(ndc * g + 0.5) / g, snap) * clip.w;
	}
	position = clip;
}

vec3 one_lamp(vec4 p, vec4 c, vec4 z, vec3 wp, vec3 n) {
	if (z.x < -1.5) return vec3(0.0);
	if (!(z.x < -0.5 || zone < -0.5 || any(equal(vec4(zone), z)))) return vec3(0.0);
	vec3 d = p.xyz - wp;
	float dist2 = dot(d, d);
	float r2 = p.w * p.w;
	float att = clamp(1.0 - dist2 / r2, 0.0, 1.0);
	att = att * att / (1.0 + dist2 * 0.35);
	float ndl = dot(n, d * inversesqrt(max(dist2, 1e-4)));
	ndl = max(ndl * 0.7 + 0.3, 0.0);
	return c.rgb * att * ndl;
}

vec3 world_light(vec3 albedo, vec3 cam, float flip) {
	vec3 n = normalize(v_wn) * flip;
	vec3 wp = v_wp;
	vec3 light = ambient;
	light += one_lamp(l0_pos, l0_col, l0_zone, wp, n);
	light += one_lamp(l1_pos, l1_col, l1_zone, wp, n);
	light += one_lamp(l2_pos, l2_col, l2_zone, wp, n);
	light += one_lamp(l3_pos, l3_col, l3_zone, wp, n);
	light += one_lamp(l4_pos, l4_col, l4_zone, wp, n);
	light += one_lamp(l5_pos, l5_col, l5_zone, wp, n);
	light += one_lamp(l6_pos, l6_col, l6_zone, wp, n);
	light += one_lamp(l7_pos, l7_col, l7_zone, wp, n);
	vec3 tl = torch_pos.xyz - wp;
	float td = length(tl);
	if (torch_pos.w > 0.0 && td < torch_pos.w) {
		vec3 tv = tl / max(td, 1e-3);
		float c = dot(-tv, torch_dir.xyz);
		float cone = smoothstep(torch_dir.w - 0.06, 1.0, c);
		cone = cone * cone * (3.0 - 2.0 * cone) * 0.8 + smoothstep(torch_dir.w - 0.12, torch_dir.w + 0.05, c) * 0.2;
		float ta = 1.0 - td / torch_pos.w;
		light += torch_col.rgb * cone * ta * ta * max(dot(n, tv) * 0.75 + 0.25, 0.0) / (1.0 + td * td * 0.08);
	}
	light = min(light, vec3(1.6));
	vec3 col = mix(albedo * light, albedo, self_lit);
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(g), col, world_tint.a) * world_tint.rgb;
	float f = clamp(length(wp - cam) / max(fog.w, 0.1), 0.0, 1.0);
	return mix(col, fog.rgb, f * f * (1.0 - self_lit * 0.7));
}
