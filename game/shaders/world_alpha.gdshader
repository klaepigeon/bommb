shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/world.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform vec3 emission = vec3(0.0);

void vertex() {
	WORLD_VERTEX
}

void fragment() {
	vec4 t = texture(albedo_tex, UV) * albedo_color * COLOR;
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	ALBEDO = world_light(t.rgb, cam, FRONT_FACING ? 1.0 : -1.0) + emission;
	ALPHA = t.a;
}
