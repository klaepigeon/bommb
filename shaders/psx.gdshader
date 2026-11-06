shader_type spatial;
// PS1-style surface: vertices snap to a coarse screen grid, textures are mapped affinely
// (no perspective correction). Lighting is plain Lambert. Over the colour, the Caller's
// pen-work: a tileable sheet of ink (grain, hatching, cracks, tile edges) drawn in dried
// blood, so every surface in the hall looks like something he drew.
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ink_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float ink_amount = 0.0;
uniform float ink_scale = 1.0;
uniform vec3 ink_color : source_color = vec3(0.30, 0.04, 0.03);
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float snap_res = 160.0;      // vertex grid in screen space (lower = wobblier)
uniform float affine = 0.0;          // 0 = perspective-correct, 1 = full PS1 warp (off: big surfaces near the camera swam)
uniform vec4 emission : source_color = vec4(0.0);
uniform float emission_energy = 0.0;
uniform bool use_vertex_color = true;
uniform float roughness_val = 1.0;

varying vec2 aff_uv;
varying float aff_w;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = vec2(snap_res * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap_res);
	if (snap_res > 0.0) {
		clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	}
	POSITION = clip;
	aff_w = mix(1.0, clip.w, affine);
	aff_uv = UV * uv_scale * aff_w;
}

void fragment() {
	vec2 uv = aff_uv / aff_w;
	vec4 t = texture(albedo_tex, uv);
	vec3 c = t.rgb * albedo.rgb;
	if (use_vertex_color) {
		c *= COLOR.rgb;
	}
	if (ink_amount > 0.0) {
		float ink = texture(ink_tex, uv * ink_scale).r * ink_amount;
		c = mix(c, ink_color * (0.55 + 0.45 * c), clamp(ink, 0.0, 1.0));
	}
	ALBEDO = c;
	ROUGHNESS = roughness_val;
	EMISSION = emission.rgb * emission_energy;
	if (t.a * albedo.a < 0.5) {
		discard;
	}
}
