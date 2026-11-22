shader_type spatial;
// A wall that breathes (the Lab's BREATH room, docs/LAB.md): it swells in along its normal, most
// in the middle of the wall and not at all at its edges, by `close` (0..1), and rises and falls
// with `breath` (set from the level, slow: a breath every few seconds at the most). Only the
// shape moves; the light on it doesn't, so nothing flickers.
render_mode cull_back, diffuse_lambert, specular_disabled;
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 ps1_snap = vec2(0.0);
uniform float close = 0.0;       // how far in (0..1)
uniform float reach = 1.2;       // m at close = 1, mid-wall
uniform float breath = 0.0;      // -1..1, from the level
uniform float breath_amp = 0.05;
uniform vec4 flush : source_color = vec4(0.55, 0.12, 0.12, 1.0);

void vertex() {
	vec2 e = UV * 2.0 - 1.0;                              // -1..1 across the wall
	float mid = (1.0 - e.x * e.x) * (1.0 - e.y * e.y);    // 1 mid-wall, 0 at its edges
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ripple = sin(wp.x * 1.3 + wp.y * 2.1 + wp.z * 1.7) * 0.5 + 0.5;
	VERTEX += NORMAL * mid * (close * reach + breath * breath_amp * (0.6 + 0.8 * ripple) * (1.0 + 2.0 * close));
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (ps1_snap.x > 0.0) clip.xy = floor(clip.xy / clip.w * ps1_snap * 0.5 + 0.5) / (ps1_snap * 0.5) * clip.w;
	POSITION = clip;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV * uv_scale).rgb * albedo_color.rgb;
	ALBEDO = mix(c, c * flush.rgb * 1.8, close * 0.6);
	ROUGHNESS = 0.6 - close * 0.3;
}
