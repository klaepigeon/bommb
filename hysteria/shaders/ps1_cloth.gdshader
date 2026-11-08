// Cloth for Socko and the coat sleeve: the PS1 shader's unfiltered texture and vertex snapping,
// but double-sided (you see the inside of the mouth) and with felt's fuzz: a soft lift where the
// surface turns away from you, which is what makes fabric read as fabric instead of rubber.
// Skinning happens before vertex(), so the snapping follows the deformed cloth.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float fuzz = 0.2;
uniform vec2 snap_res = vec2(426.0, 240.0);
uniform vec3 glow = vec3(0.0);   // light from inside (the torch in his mouth)

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.xy = floor(clip.xy / clip.w * snap_res * 0.5 + 0.5) / (snap_res * 0.5) * clip.w;
	POSITION = clip;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
		c *= 0.8;    // the inside of the sock: a little in its own shadow
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = c * (1.0 + rim * fuzz);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	BACKLIGHT = vec3(fuzz * 0.25);
	EMISSION = glow * c;   // thin cloth lets a little light through
}
