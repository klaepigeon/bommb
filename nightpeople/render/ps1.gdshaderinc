// NIGHT PEOPLE's one world shader. Everything in the 3D world (generated architecture,
// Kenney props, Quaternius characters) is drawn with it so mismatched sources read as one game:
// vertex snapping to a coarse screen grid, partly affine (warping) texture mapping, nearest
// filtering, per-vertex lighting (project-wide force_vertex_shading), no specular.
global uniform float ps1_snap;     // grid lines per screen height; lower = wobblier
global uniform float ps1_affine;   // 0 = perspective-correct, 1 = full PS1 warp

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_texture = false;
uniform bool use_vertex_color = false;
uniform vec2 uv_scale = vec2(1.0);
uniform vec3 emission : source_color = vec3(0.0);

varying vec3 affine_uv;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (clip.w > 0.05) {
		vec2 grid = vec2(ps1_snap * VIEWPORT_SIZE.x / max(VIEWPORT_SIZE.y, 1.0), ps1_snap);
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	UV *= uv_scale;
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, ps1_affine);
	vec4 c = albedo;
	if (use_texture) {
		c *= texture(albedo_tex, uv);
	}
	if (use_vertex_color) {
		c *= COLOR;
	}
	ALBEDO = c.rgb;
#ifdef CUTOUT
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
#endif
	EMISSION = emission;
}
