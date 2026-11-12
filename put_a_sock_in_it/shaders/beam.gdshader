// A beam of light made visible by the dust in it: an additive cone, bright along its middle,
// fading toward its end and its edges. Cheap stand-in for volumetric light.
shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, unshaded, shadows_disabled;
uniform vec3 color : source_color = vec3(1.0, 0.9, 0.75);
uniform float strength = 0.08;
uniform float flicker = 1.0;
varying float along;
void vertex() { along = UV.y; }
void fragment() {
	float edge = pow(abs(dot(NORMAL, VIEW)), 3.0);
	float fall = pow(1.0 - along, 1.6) * smoothstep(0.0, 0.12, along);
	float n = 0.85 + 0.15 * sin(TIME * 0.7 + UV.x * 40.0 + along * 9.0);
	ALBEDO = color * strength * edge * fall * n * flicker;
}
