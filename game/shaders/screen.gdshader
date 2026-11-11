// The picture, finished: 15-bit colour with an ordered dither (the PS1's), a little grain, a soft
// vignette, the player's brightness setting, and a red edge when Kurt's hurt.
shader_type canvas_item;
uniform float gamma = 1.0;
uniform float grain = 0.035;
uniform float hurt = 0.0;
uniform float dark = 0.0;      // blackout / waking
uniform float time_s = 0.0;

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int idx = i.x + i.y * 4;
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(m[idx]) / 16.0 - 0.5;
}

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	c = pow(max(c, vec3(0.0)), vec3(1.0 / gamma));
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	c += bayer4(px) / 31.0;
	c = floor(c * 31.0 + 0.5) / 31.0;
	float n = fract(sin(dot(floor(px) + floor(time_s * 24.0) * 7.13, vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;
	vec2 q = UV - 0.5;
	float v = 1.0 - dot(q, q) * 0.9;
	c *= v;
	c = mix(c, vec3(0.35, 0.0, 0.0), hurt * smoothstep(0.15, 0.5, length(q)));
	c *= 1.0 - dark;
	COLOR = vec4(c, 1.0);
}
