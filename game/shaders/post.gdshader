// The screen: the 3D view arrives here at a fraction of screen resolution (nearest-upscaled by the
// SubViewportContainer). This pass adds the rest of the PS1 / bad-VHS look and the infection.
//  - 15-bit colour with ordered dither
//  - film grain, crushed vignette
//  - infection: chromatic split, slow warp, a dark pulse, desaturation toward flesh
shader_type canvas_item;

uniform float grain = 1.0;
uniform float brightness = 1.0;
uniform float hurt = 0.0;         // red-black edge after being caught / hit
uniform float blackout = 0.0;     // 0..1 fade to black (cuts, waking)
uniform float wake = 0.0;         // blurry doubled vision while coming round
uniform float wrong = 0.0;        // the Backrooms' grade
global uniform float infection;
global uniform float world_time;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 uv = UV;
	float inf = infection;
	if (inf > 0.25) {
		float w = (inf - 0.25) * 0.012;
		uv += vec2(sin(uv.y * 9.0 + world_time * 0.7), cos(uv.x * 7.0 + world_time * 0.5)) * w;
	}
	if (wake > 0.0) {
		uv += vec2(sin(world_time * 1.7) * 0.01, cos(world_time * 1.3) * 0.006) * wake;
	}
	vec3 c = texture(TEXTURE, uv).rgb;
	if (wake > 0.0) {
		vec3 d = texture(TEXTURE, uv + vec2(0.012, 0.004) * wake).rgb;
		c = mix(c, (c + d) * 0.5, wake);
	}
	float split = max(inf - 0.4, 0.0) * 0.006 + hurt * 0.004;
	if (split > 0.0) {
		c.r = texture(TEXTURE, uv + vec2(split, 0.0)).r;
		c.b = texture(TEXTURE, uv - vec2(split, 0.0)).b;
	}
	c *= brightness;
	// grade
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), 0.15 + inf * 0.25);
	c = mix(c, c * vec3(1.06, 1.0, 0.78), wrong * 0.5);
	c = mix(c, c * vec3(1.15, 0.85, 0.85), inf * 0.4);
	// vignette and the pulse
	vec2 q = UV - 0.5;
	float vig = smoothstep(0.85, 0.2, length(q * vec2(1.0, 1.25)));
	float pulse = inf > 0.55 ? (0.5 + 0.5 * sin(world_time * 2.4)) * (inf - 0.55) * 0.8 : 0.0;
	c *= mix(1.0, vig, 0.55 + pulse + hurt * 0.4);
	c = mix(c, vec3(0.25, 0.0, 0.0) * vig, hurt * (1.0 - vig) * 0.8);
	// grain
	float g = hash(UV * 731.0 + fract(world_time * 7.31)) - 0.5;
	c += g * 0.07 * grain * (0.6 + inf);
	// 15-bit colour, ordered dither
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float th = (BAYER[p.y * 4 + p.x] / 16.0 - 0.5) / 31.0;
	c = floor((c + th) * 31.0 + 0.5) / 31.0;
	c *= 1.0 - blackout;
	COLOR = vec4(c, 1.0);
}
