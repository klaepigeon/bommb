// HYSTERIA environment surface. One shader for every wall, floor and piece of furniture in both
// apartments.
//  - Baked light: room fixtures are baked into vertex colours (cheap on phones, PS1-faithful) and
//    scaled by `power` (the room's circuit: off, on, flickering) — EMISSION, so it ignores lights.
//  - Real-time lights (the torch, a muzzle flash) still light the albedo through the normal path.
//  - PS1: unfiltered texels, vertices snapped to a coarse grid.
//  - The Backrooms: `wrong` (0..1) drifts the hue toward sick yellow-green, adds damp and mould,
//    and lets the pattern slide; global `infection` makes surfaces breathe.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D mould_tex : hint_default_black, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float power = 1.0;              // the room's baked light, 0 = circuit off
uniform vec3 flat_light = vec3(-1.0);   // props: a light colour instead of vertex colours
uniform float ambient = 0.025;          // never fully black (phones crush blacks)
uniform float wrong = 0.0;
uniform float mould = 0.0;
uniform float emission_k = 0.0;         // self-lit (bulbs, the sticky note glow)
uniform bool emission_powered = false;  // bulbs: the glow follows the circuit
uniform vec2 snap_res = vec2(320.0, 180.0);
uniform vec2 uv_scale = vec2(1.0);
uniform bool breathe = false;
global uniform float infection;
global uniform float world_time;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (breathe && infection > 0.35) {
		float k = (infection - 0.35) * 0.04;
		VERTEX += NORMAL * sin(world_time * 1.3 + wpos.x * 2.1 + wpos.z * 1.7) * k;
	}
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.xy = floor(clip.xy / clip.w * snap_res * 0.5 + 0.5) / (snap_res * 0.5) * clip.w;
	POSITION = clip;
}

vec3 hue_drift(vec3 c, float k) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 sick = vec3(l * 1.08, l * 1.02, l * 0.62);
	return mix(c, sick, k);
}

void fragment() {
	vec2 uv = UV * uv_scale;
	if (wrong > 0.0) {
		// the pattern doesn't sit still: slow per-surface slide
		uv += vec2(sin(wpos.y * 1.7 + world_time * 0.05), cos(wpos.x * 1.3)) * 0.04 * wrong;
	}
	vec3 a = texture(albedo_tex, uv).rgb * tint.rgb;
	if (wrong > 0.0) a = hue_drift(a, wrong * 0.7);
	float m = mould;
	if (m > 0.0) {
		float mk = texture(mould_tex, wpos.xz * 0.37 + wpos.y * 0.21).r;
		// damp climbs from the floor
		mk *= smoothstep(1.6, 0.0, wpos.y - floor(wpos.y / 2.7) * 2.7) * 0.7 + 0.3;
		a = mix(a, a * vec3(0.18, 0.2, 0.12), clamp(mk * m, 0.0, 0.85));
	}
	vec3 baked = flat_light.r >= 0.0 ? flat_light : COLOR.rgb;
	ALBEDO = a;
	ROUGHNESS = 1.0;
	EMISSION = a * (baked * power + vec3(ambient)) + a * emission_k * (emission_powered ? power : 1.0);
}
