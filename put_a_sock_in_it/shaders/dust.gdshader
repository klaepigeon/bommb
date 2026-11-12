// Dust in the air: tiny motes drifting, invisible until light falls on them (a lamp, the torch,
// the glow of the hole). Additive, lit only by real lights, so dark rooms stay dark.
shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, specular_disabled, shadows_disabled, ambient_light_disabled;
uniform float size = 0.004;
uniform vec3 color : source_color = vec3(1.0, 0.95, 0.85);
void vertex() {
	float s = float(INSTANCE_ID) * 0.6180339;
	vec3 drift = vec3(sin(TIME * (0.07 + fract(s) * 0.05) + s * 40.0) * 0.25,
		sin(TIME * (0.05 + fract(s * 3.0) * 0.04) + s * 17.0) * 0.12,
		cos(TIME * (0.06 + fract(s * 7.0) * 0.05) + s * 23.0) * 0.25);
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz + drift;
	// billboard: the quad faces the camera
	vec3 right = INV_VIEW_MATRIX[0].xyz; vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 w = centre + (right * VERTEX.x + up * VERTEX.y) * size * (0.6 + fract(s * 11.0));
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
	NORMAL = (VIEW_MATRIX * vec4(INV_VIEW_MATRIX[2].xyz, 0.0)).xyz;
}
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	ALBEDO = color;
	ALPHA = 1.0;
	EMISSION = vec3(0.0);
	ROUGHNESS = 1.0;
}
void light() {
	float r = length(UV - 0.5) * 2.0;
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR * smoothstep(1.0, 0.0, r) * 0.12;
}
