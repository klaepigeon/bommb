// The one material for everything: unfiltered texture with mipmaps (no shimmer), vertex colour
// for baked darkening, optional PS1 vertex snapping. Lit per pixel; no specular, so no sparkle.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 glow : source_color = vec3(0.0);
uniform float snap = 160.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (snap > 0.0) {
		vec2 grid = vec2(snap * 1.7778, snap);
		clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * tint * COLOR;
	ALBEDO = c.rgb;
	EMISSION = glow * c.rgb;
	ROUGHNESS = 1.0;
}
