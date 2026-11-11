// Socko's cloth and Kurt's sleeve, lit by the game's own lamps (world.gdshaderinc): double-sided
// (you see inside his mouth), felt's fuzzy rim, and his contamination in UV2 (r old blood, g
// mould, b urine, a speckle; COLOR.r faces down, COLOR.g near a seam).
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
#include "res://shaders/world.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float fuzz = 0.2;
uniform vec3 glow = vec3(0.0);
uniform sampler2D stain_tex : filter_linear, repeat_enable, hint_default_black;
uniform float stain_amount = 0.0;
uniform vec3 stain_mix = vec3(1.0);

void vertex() {
	WORLD_VERTEX
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	if (!FRONT_FACING) c *= 0.8;
	float matted = 0.0;
	if (stain_amount > 0.0) {
		vec4 m = texture(stain_tex, UV2);
		float ur = m.b * mix(0.15, 1.0, COLOR.r) * stain_mix.z * stain_amount;
		c *= mix(vec3(1.0), vec3(0.93, 0.80, 0.50), clamp(ur, 0.0, 1.0) * 0.8);
		float mo = clamp(m.g + COLOR.g * 0.5 * (0.4 + m.g), 0.0, 1.0) * stain_mix.y * stain_amount;
		mo *= 0.35 + 0.65 * step(0.45, m.a);
		c *= mix(vec3(1.0), vec3(0.62, 0.69, 0.55), clamp(mo, 0.0, 1.0) * 0.75);
		float bl = m.r * stain_mix.x * stain_amount;
		vec3 old = mix(vec3(0.74, 0.47, 0.40), vec3(0.40, 0.17, 0.13), smoothstep(0.5, 0.95, m.r));
		c *= mix(vec3(1.0), old, clamp(smoothstep(0.0, 0.5, bl), 0.0, 1.0) * 0.72);
		matted = clamp(ur * 0.5 + bl * 0.8 + mo * 0.3, 0.0, 0.8);
	}
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 lit = world_light(c, cam, FRONT_FACING ? 1.0 : -1.0);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5) * (1.0 - matted * 0.6);
	ALBEDO = lit * (1.0 + rim * fuzz) + glow * c;
}
