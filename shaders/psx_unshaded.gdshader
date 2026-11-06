shader_type spatial;
// Unlit PS1 surface for glowing things: eyes, bulbs, candle flames, screens.
render_mode unshaded, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float snap_res = 160.0;
uniform bool use_vertex_color = true;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = vec2(snap_res * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap_res);
	if (snap_res > 0.0) {
		clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	vec3 c = t.rgb * albedo.rgb;
	if (use_vertex_color) { c *= COLOR.rgb; }
	ALBEDO = c;
	if (t.a * albedo.a < 0.5) { discard; }
}
