shader_type spatial;
// Things held in your hands (cards, dice): unlit, always drawn over the table, never fogged.
render_mode unshaded, cull_disabled, depth_test_disabled, fog_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float shade = 1.0;

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	ALBEDO = t.rgb * albedo.rgb * shade;
	if (t.a * albedo.a < 0.5) { discard; }
}
