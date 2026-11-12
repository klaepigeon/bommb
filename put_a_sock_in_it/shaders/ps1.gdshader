// World surfaces: unfiltered low-res textures and vertices snapped to a coarse screen grid, so
// geometry swims slightly as you move, like a 1997 console. Optional pulse for living flesh.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 ps1_snap = vec2(0.0);   // the PS1 wobble (Game.apply_wobble sets it on every material); 0 = off
uniform float roughness = 0.95;
uniform vec3 emission = vec3(0.0);
uniform float pulse = 0.0;        // flesh: vertices breathe along their normals
uniform float pulse_speed = 1.3;
uniform bool use_vertex_color = false;

void vertex() {
	if (pulse > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		VERTEX += NORMAL * pulse * sin(TIME * pulse_speed + wp.x * 2.1 + wp.y * 1.7 + wp.z * 2.9);
	}
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (ps1_snap.x > 0.0) clip.xy = floor(clip.xy / clip.w * ps1_snap * 0.5 + 0.5) / (ps1_snap * 0.5) * clip.w;
	POSITION = clip;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV * uv_scale);
	vec3 c = t.rgb * albedo_color.rgb;
	if (use_vertex_color) c *= COLOR.rgb;
	ALBEDO = c;
	ROUGHNESS = roughness;
	EMISSION = emission * c;
}
