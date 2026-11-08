// Over the whole low-resolution frame, in this order (as the JS build's post pass, then the PS1):
// film grain that's strongest in the shadows, a heavy soft vignette, then 15-bit colour with an
// ordered dither. Grain and dither are per low-res pixel, so they sit on the same grid as the image.
shader_type canvas_item;
uniform float levels = 32.0;
uniform float dither_amount = 1.0;
uniform float shrink = 3.0;
uniform float grain = 0.045;     // post.js amount
uniform float vig = 0.42;        // post.js vig
uniform float decay = 0.0;       // reality slipping (0..1), for later
uniform float bw = 0.0;          // dread: time spent in a room with it (0 colour .. 1 black and white)
const mat4 BAYER = mat4(vec4(0.0, 8.0, 2.0, 10.0), vec4(12.0, 4.0, 14.0, 6.0), vec4(3.0, 11.0, 1.0, 9.0), vec4(15.0, 7.0, 13.0, 5.0));
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	vec2 dd = (uv - 0.5) * decay * 0.006;
	vec3 c = vec3(texture(TEXTURE, uv + dd).r, texture(TEXTURE, uv).g, texture(TEXTURE, uv - dd).b);
	float lu = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(lu), decay * 0.55);
	// dread: the colour goes out of the room; contrast hardens and the grain thickens as it does,
	// like old film
	c = mix(c, vec3(lu), bw);
	c = mix(c, (c - 0.5) * (1.0 + 0.25 * bw) + 0.5 - 0.03 * bw, bw);
	lu = dot(c, vec3(0.299, 0.587, 0.114));
	vec2 px = floor(FRAGCOORD.xy / shrink);
	float n = h(px + fract(TIME * 7.13) * 97.0) - 0.5;
	c += n * grain * (1.6 + 1.4 * bw) * (1.2 - lu);
	vec2 d = uv - 0.5;
	float v = smoothstep(0.85, 0.2, length(d * vec2(1.0, 0.85)) * (1.0 + vig));
	c *= mix(1.0, v, 0.85);
	ivec2 p = ivec2(px) % 4;
	float dt = (BAYER[p.x][p.y] / 16.0 - 0.5) * dither_amount / levels;
	COLOR = vec4(floor((max(c, 0.0) + dt) * levels + 0.5) / levels, 1.0);
}
