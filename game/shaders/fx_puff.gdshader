// Particles that face the camera (dust, steam, smoke, sparks, droplets), lit like everything else:
// dust in the dark stays dark, dust in the torch's beam shows. Soft round edge, fades by the
// particle's colour alpha (the CPUParticles3D colour ramp). self_lit for sparks and embers.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/world.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float softness = 0.5;      // 0 a hard square, 1 a soft blob
uniform float streak = 0.0;        // > 0: stretched (sparks, rain)

void vertex() {
	float sc = length(MODEL_MATRIX[0].xyz);
	mat4 bb = mat4(INV_VIEW_MATRIX[0] * sc, INV_VIEW_MATRIX[1] * sc * (1.0 + streak), INV_VIEW_MATRIX[2] * sc, MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
	vec3 _wp; vec3 _wn;
	world_vertex(VERTEX, vec3(0.0, 0.0, 1.0), bb, MODELVIEW_MATRIX, PROJECTION_MATRIX, _wp, _wn, POSITION);
	v_wp = _wp; v_wn = normalize(INV_VIEW_MATRIX[2].xyz);
}

void fragment() {
	vec4 c = albedo_color * COLOR;
	float r = length(UV - vec2(0.5)) * 2.0;
	float a = 1.0 - smoothstep(1.0 - softness, 1.0, r);
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	ALBEDO = world_light(c.rgb, cam, 1.0);
	ALPHA = c.a * a;
}
