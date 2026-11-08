// The late-90s look: textures sampled without filtering and vertices snapped to a coarse screen
// grid (so geometry swims a little as you move). Lighting is still the JS build's: the painted
// bump relief (as a normal map), roughness maps, and a real specular so wet tile and enamel catch
// the light.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness = 0.9;
uniform float specular = 0.5;
uniform sampler2D roughness_tex : hint_default_white, filter_nearest_mipmap, repeat_enable;
uniform bool use_roughness_tex = false;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal_tex = false;
uniform float normal_depth = 1.0;
uniform vec3 emission = vec3(0.0);
uniform sampler2D emission_tex : source_color, filter_nearest;
uniform bool use_emission_tex = false;
uniform vec2 snap_res = vec2(320.0, 240.0);
uniform bool use_vertex_color = false;
uniform vec2 uv_scale = vec2(1.0);
uniform bool use_alpha_cut = false;     // pierced carving: holes where the texture's alpha is 0
// a hole knocked in a wall (the gap behind the bedroom wardrobe): fragments inside the box are
// cut away, with a ragged edge. w = 1 when it's open.
global uniform vec4 hole_min;
global uniform vec4 hole_max;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.xy = floor(clip.xy / clip.w * snap_res * 0.5 + 0.5) / (snap_res * 0.5) * clip.w;
	POSITION = clip;
}

float hole_hash(vec2 p) { return fract(sin(dot(floor(p), vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	if (hole_max.w > 0.5) {
		vec3 lo = hole_min.xyz; vec3 hi = hole_max.xyz;
		if (all(greaterThan(world_pos, lo)) && all(lessThan(world_pos, hi))) {
			// ragged: the edge eats in by up to 9 cm in 4 cm chunks of plaster
			vec2 q = world_pos.zy;
			float e = min(min(q.x - lo.z, hi.z - q.x), min(q.y - lo.y, hi.y - q.y));
			if (e > hole_hash(q * 25.0) * 0.09) discard;
		}
	}
	vec4 c = texture(albedo_tex, UV * uv_scale) * albedo_color;
	if (use_alpha_cut && c.a < 0.5) discard;
	if (use_vertex_color) { c.rgb *= COLOR.rgb; }
	ALBEDO = c.rgb;
	ROUGHNESS = roughness * (use_roughness_tex ? texture(roughness_tex, UV * uv_scale).g : 1.0);
	METALLIC = 0.0;
	SPECULAR = specular;
	if (use_normal_tex) {
		NORMAL_MAP = texture(normal_tex, UV * uv_scale).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
	EMISSION = use_emission_tex ? texture(emission_tex, UV).rgb * emission : emission;
}
