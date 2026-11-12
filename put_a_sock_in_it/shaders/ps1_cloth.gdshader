// Cloth for Socko and the coat sleeve: the PS1 shader's unfiltered texture and vertex snapping,
// but double-sided (you see the inside of the mouth) and with felt's fuzz: a soft lift where the
// surface turns away from you, which is what makes fabric read as fabric instead of rubber.
// Skinning happens before vertex(), so the snapping follows the deformed cloth.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float fuzz = 0.2;
global uniform vec2 ps1_snap;   // the PS1 wobble (Game.apply_wobble); 0 = off
uniform vec3 glow = vec3(0.0);   // light from inside (the torch in his mouth)
// Socko's contamination (see SockRig._stain_tex): r old blood, g mould, b urine, a speckle, in
// UV2 (wrapped round the arm). Vertex COLOR carries the hints: r faces down, g near a seam/fold.
// Dyes multiply the cloth, so the knit, the stripes, the grime and the folds all show through;
// soaked fibres mat down (less fuzz). stain_amount 0 is a clean cloth (the sleeve, the felt).
uniform sampler2D stain_tex : filter_linear, repeat_enable;
uniform float stain_amount = 0.0;
uniform vec3 stain_mix = vec3(1.0);   // blood, mould, urine
// fresh blood, 0..1 (Kurt's health: Socko is the health bar). It comes up through the knit from
// where the old blood already is and spreads from there; wet, so darker, redder, and matted flat.
uniform float wound = 0.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (ps1_snap.x > 0.0) clip.xy = floor(clip.xy / clip.w * ps1_snap * 0.5 + 0.5) / (ps1_snap * 0.5) * clip.w;
	POSITION = clip;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
		c *= 0.8;    // the inside of the sock: a little in its own shadow
	}
	float matted = 0.0;
	if (stain_amount > 0.0) {
		vec4 m = texture(stain_tex, UV2);
		float lower = COLOR.r;
		float seam = COLOR.g;
		// urine: yellow-brown, soaked into what faces down, tide-marked
		float ur = m.b * mix(0.15, 1.0, lower) * stain_mix.z * stain_amount;
		c *= mix(vec3(1.0), vec3(0.93, 0.80, 0.50), clamp(ur, 0.0, 1.0) * 0.8);
		// mould: grey-green, from the seams outward, speckled through the knit
		float mo = clamp(m.g + seam * 0.5 * (0.4 + m.g), 0.0, 1.0) * stain_mix.y * stain_amount;
		mo *= 0.35 + 0.65 * step(0.45, m.a);
		c *= mix(vec3(1.0), vec3(0.62, 0.69, 0.55), clamp(mo, 0.0, 1.0) * 0.75);
		// old blood: faded rust where thin, dark brown where it pooled and dried
		float bl = m.r * stain_mix.x * stain_amount;
		vec3 old = mix(vec3(0.74, 0.47, 0.40), vec3(0.40, 0.17, 0.13), smoothstep(0.5, 0.95, m.r));
		c *= mix(vec3(1.0), old, clamp(smoothstep(0.0, 0.5, bl), 0.0, 1.0) * 0.72);
		matted = clamp(ur * 0.5 + bl * 0.8 + mo * 0.3, 0.0, 0.8);
	}
	if (wound > 0.0) {
		vec4 m = texture(stain_tex, UV2);
		// where it comes through: the old stains first, then broad patches round the arm, so the
		// red covers about as much of him as Kurt has lost
		float patch = 0.5 + 0.5 * sin(UV2.x * 12.566 + sin(UV2.y * 9.0) * 1.7) * cos(UV2.y * 7.0 + UV2.x * 3.0);
		float seed = clamp(m.r * 0.45 + patch * 0.62 + (m.a - 0.5) * 0.14 + COLOR.r * 0.08, 0.0, 1.0);
		float edge = 1.0 - min(1.0, wound * 1.12);
		float wet = smoothstep(edge, edge + 0.12, seed);
		c *= mix(vec3(1.0), vec3(0.66, 0.05, 0.04), wet * (0.7 + 0.25 * wound));
		matted = max(matted, wet * 0.8);
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5) * (1.0 - matted * 0.6);
	ALBEDO = c * (1.0 + rim * fuzz);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	BACKLIGHT = vec3(fuzz * 0.25);
	EMISSION = glow * c;   // thin cloth lets a little light through
}
