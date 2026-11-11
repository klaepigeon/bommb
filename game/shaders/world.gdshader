shader_type spatial;
render_mode unshaded, fog_disabled, cull_back, depth_draw_opaque;
#include "res://shaders/world.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform sampler2D emission_tex : source_color, filter_nearest, hint_default_white;
uniform vec3 emission = vec3(0.0);
uniform float alpha_cut = 0.0;
uniform vec2 uv_scale = vec2(1.0);
uniform bool two_sided = false;
uniform vec3 hole_a = vec3(0.0);   // a hole cut through this surface (world box); the broken edge is geometry
uniform vec3 hole_b = vec3(0.0);

void vertex() {
	WORLD_VERTEX
}

void fragment() {
	if (hole_b.x > hole_a.x && all(greaterThan(v_wp, hole_a)) && all(lessThan(v_wp, hole_b))) discard;
	vec4 t = texture(albedo_tex, UV * uv_scale) * albedo_color * COLOR;
	if (alpha_cut > 0.0 && t.a < alpha_cut) discard;
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	ALBEDO = world_light(t.rgb, cam, (two_sided && !FRONT_FACING) ? -1.0 : 1.0) + emission * texture(emission_tex, UV).rgb;
}
