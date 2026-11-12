// The blue goo: glossy, slowly sliding, faintly lit from within.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;
uniform vec3 color : source_color = vec3(0.12, 0.42, 0.95);
uniform vec2 snap_res = vec2(320.0, 180.0);
void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX += NORMAL * 0.012 * sin(TIME * 2.3 + wp.x * 9.0 + wp.z * 7.0);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.xy = floor(clip.xy / clip.w * snap_res * 0.5 + 0.5) / (snap_res * 0.5) * clip.w;
	POSITION = clip;
}
void fragment() {
	float n = sin(UV.x * 30.0 + TIME * 1.5) * sin(UV.y * 22.0 - TIME * 2.0);
	ALBEDO = color * (0.7 + 0.3 * n);
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	EMISSION = color * 0.35;
}
