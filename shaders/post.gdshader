shader_type canvas_item;
// Final pass over the low-resolution 3D render, where the room becomes one of his drawings:
//  - ink: edges traced in dried blood, the way he outlines everything he draws
//  - hatching: the shadows are shaded with pen strokes, not just darkened
//  - grading: sick greens in the dark, jaundiced warmth in the light
//  - grain: old film, never quite still
//  - breath: the vignette breathes, slowly, as if the room were alive
//  - dread / gaze / flash / glitch: driven by the game (his attention, scares, his FILE)
// plus the 15-bit colour and ordered dither of the original pipeline.

uniform float color_levels = 48.0;
uniform float dither_amount = 1.0;
uniform float vignette = 0.35;
uniform float brightness = 1.0;
uniform float contrast = 1.05;
uniform float saturation = 0.95;
uniform float flash = 0.0;          // red hurt flash
uniform float gaze = 0.0;           // he is watching you: the edges of the room go red
uniform float dread = 0.0;          // 0..1: his FILE, the dark, the night wearing on
uniform float glitch = 0.0;         // 0..1: the picture tears (scares, his faults)
uniform float ink_lines = 1.0;      // outline strength
uniform float hatch = 1.0;          // pen hatching in the shadows
uniform float grain = 1.0;
uniform float saw = 0.0;            // 0..1: the bathroom grade: bile-green, crushed blacks, dirty highlights
uniform vec2 src_size = vec2(640.0, 360.0);

const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
const vec3 INK = vec3(0.16, 0.025, 0.02);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 tex(sampler2D t, vec2 uv) {
	return texture(t, uv).rgb;
}

void fragment() {
	vec2 uv = UV;
	// the picture tears: bands of rows slip sideways
	if (glitch > 0.0) {
		float band = floor(uv.y * 24.0 + floor(TIME * 13.0));
		float slip = (hash(vec2(band, floor(TIME * 9.0))) - 0.5) * 0.08 * glitch;
		if (hash(vec2(band * 1.7, floor(TIME * 5.0))) < glitch * 0.6) {
			uv.x += slip;
		}
	}
	vec2 px1 = 1.0 / src_size;
	vec3 c = tex(TEXTURE, uv);
	// colour fringe when it tears
	if (glitch > 0.0) {
		c.r = tex(TEXTURE, uv + vec2(px1.x * 2.0 * glitch, 0.0)).r;
		c.b = tex(TEXTURE, uv - vec2(px1.x * 2.0 * glitch, 0.0)).b;
	}
	c *= brightness;
	c = (c - 0.5) * contrast + 0.5;
	float l = luma(c);
	c = mix(vec3(l), c, saturation * (1.0 - dread * 0.35));

	// grading: shadows to bruise-green, highlights to nicotine yellow
	vec3 shadow_tint = vec3(0.86, 1.0, 0.9);
	vec3 light_tint = vec3(1.06, 0.98, 0.84);
	c *= mix(shadow_tint, light_tint, smoothstep(0.15, 0.7, l));
	if (saw > 0.0) {
		float sl = luma(c);
		vec3 bile = vec3(sl) * vec3(0.84, 1.0, 0.62) + vec3(0.0, 0.015, 0.0);
		// keep a little of the real colour (blood stays red)
		float red = clamp((c.r - max(c.g, c.b)) * 2.5, 0.0, 1.0);
		vec3 g = mix(bile, c * vec3(1.0, 0.9, 0.8), red * 0.7);
		g = smoothstep(vec3(0.04), vec3(0.96), g);
		c = mix(c, g, saw);
	}

	// ink: a Sobel on brightness, traced where the picture changes hard
	float tl = luma(tex(TEXTURE, uv + px1 * vec2(-1.0, -1.0)));
	float tc = luma(tex(TEXTURE, uv + px1 * vec2(0.0, -1.0)));
	float tr = luma(tex(TEXTURE, uv + px1 * vec2(1.0, -1.0)));
	float ml = luma(tex(TEXTURE, uv + px1 * vec2(-1.0, 0.0)));
	float mr = luma(tex(TEXTURE, uv + px1 * vec2(1.0, 0.0)));
	float bl = luma(tex(TEXTURE, uv + px1 * vec2(-1.0, 1.0)));
	float bc = luma(tex(TEXTURE, uv + px1 * vec2(0.0, 1.0)));
	float br = luma(tex(TEXTURE, uv + px1 * vec2(1.0, 1.0)));
	float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
	float gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
	float edge = sqrt(gx * gx + gy * gy);
	float line = smoothstep(0.16, 0.42, edge) * ink_lines;
	// the pen skips: lines are broken now and then
	ivec2 px = ivec2(floor(uv * src_size));
	float skip = step(0.12, hash(vec2(px / 3) + floor(TIME * 2.0) * 0.01));
	c = mix(c, INK + c * 0.25, line * 0.75 * skip);

	// hatching: the darker it is, the more pen strokes over it
	float h1 = float((px.x + px.y) % 4 == 0);
	float h2 = float((px.x - px.y + 4096) % 4 == 0);
	float dark = 1.0 - smoothstep(0.06, 0.32, l);
	float darker = 1.0 - smoothstep(0.02, 0.14, l);
	c = mix(c, c * 0.35 + INK * 0.4, h1 * dark * 0.55 * hatch);
	c = mix(c, c * 0.35 + INK * 0.4, h2 * darker * 0.5 * hatch);

	// ordered dither down to 15-bit colour
	float b = bayer[(px.x % 4) + (px.y % 4) * 4] / 16.0 - 0.5;
	c += b * dither_amount * 0.75 / color_levels;
	c = floor(c * color_levels + 0.5) / color_levels;

	// grain, never quite still
	float g = hash(vec2(px) + fract(TIME * 7.13) * 91.7) - 0.5;
	c += g * 0.045 * grain * (0.6 + dread);

	// the vignette breathes
	vec2 d = UV - 0.5;
	float breath = 1.0 + 0.12 * sin(TIME * 0.7) + dread * 0.6;
	c *= 1.0 - dot(d, d) * vignette * 2.0 * breath;
	float edge_v = smoothstep(0.05, 0.32, dot(d, d));
	c = mix(c, c * vec3(1.25, 0.45, 0.4) + vec3(0.05, 0.0, 0.0), gaze * edge_v);
	c = mix(c, c * vec3(1.1, 0.7, 0.65), dread * edge_v * 0.6);
	c = mix(c, vec3(0.6, 0.05, 0.03), flash);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
