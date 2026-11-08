// The late-90s look: textures sampled without filtering and vertices snapped to a coarse screen
// grid (so geometry swims a little as you move). Lighting is still the JS build's: the painted
// bump relief (as a normal map), roughness maps, and a real specular so wet tile and enamel catch
// the light.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness = 0.9;
uniform sampler2D roughness_tex : hint_default_white, filter_nearest_mipmap, repeat_enable;
uniform bool use_roughness_tex = false;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal_tex = false;
uniform float normal_depth = 1.0;
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
	ROUGHNESS = roughness * (use_roughness_tex ? texture(roughness_tex, UV).g : 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	if (use_normal_tex) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
	EMISSION = use_emission_tex ? texture(emission_tex, UV).rgb * emission : emission;
}
