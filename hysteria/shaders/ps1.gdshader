// The late-90s look: textures sampled without filtering, vertices snapped to a coarse screen
// grid (so geometry swims a little as you move), and a slight affine wobble on large polygons.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness = 0.9;
uniform vec3 emission = vec3(0.0);
uniform sampler2D emission_tex : source_color, filter_nearest;
uniform bool use_emission_tex = false;
uniform vec2 snap_res = vec2(320.0, 240.0);

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.xy = floor(clip.xy / clip.w * snap_res * 0.5 + 0.5) / (snap_res * 0.5) * clip.w;
	POSITION = clip;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo_color;
	ALBEDO = c.rgb;
	ROUGHNESS = roughness;
	EMISSION = use_emission_tex ? texture(emission_tex, UV).rgb * emission : emission;
}
