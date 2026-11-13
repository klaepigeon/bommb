// The picture, after the 3D: what turns a render into a camera in a dark flat in 1996.
//   grain     strongest in the shadows, like a sensor pushed too far
//   vignette  soft, always
//   dither    the PS1's 15-bit colour, ordered-dithered
//   fringe    colour separating at the edges (concussion, Marta near, the flesh)
//   drain     colour leaving the picture
//   tear      bands of the picture shoved sideways (reality slipping)
//   double    the concussed double image, drifting
//   pulse     the edges of the picture darkening on a heartbeat
//   tint      a wash of colour (the blue of the hole)
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float time_k = 0.0;
uniform float grain = 0.05;
uniform float vignette = 0.45;
uniform float dither = 1.0;
uniform float fringe = 0.0;
uniform float drain = 0.0;
uniform float tear = 0.0;
uniform bool safe = true;          // reduce flashing: no jumping bands, slow warps only
uniform float double_k = 0.0;
uniform float pulse = 0.0;
uniform vec4 tint = vec4(0.0);
uniform float hurt = 0.0;          // Kurt's health gone: the edges dark and a little red (steady)
uniform float fear = 0.0;          // Kurt's nerve: the edges close in and the colour goes (steady: never pulses)
uniform vec2 res = vec2(640.0, 360.0);

float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

const float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	// tearing: a band (or two) of the picture pushed sideways
	if (tear > 0.01) {
		if (safe) {
			// reality slipping, gently: a slow sideways wave through the picture
			uv.x += sin(uv.y * 9.0 + time_k * 1.3) * 0.004 * tear + sin(uv.y * 23.0 - time_k * 0.7) * 0.002 * tear;
		} else {
			float b1 = step(abs(uv.y - fract(time_k * 0.37 + h(vec2(floor(time_k * 3.0))) )), 0.015 + tear * 0.05);
			float b2 = step(abs(uv.y - fract(time_k * 0.71 + 0.5)), 0.006 + tear * 0.02);
			uv.x += (b1 * (h(vec2(floor(time_k * 3.0), 1.0)) - 0.5) * 0.12 + b2 * 0.03) * tear;
		}
	}
	// concussion: the picture drifts apart into two
	vec2 dbl = vec2(sin(time_k * 0.7), cos(time_k * 0.53)) * 0.012 * double_k;
	vec2 d = uv - 0.5;
	vec2 fr = d * fringe * 0.012;
	vec3 c;
	c.r = texture(screen, uv + fr).r;
	c.g = texture(screen, uv).g;
	c.b = texture(screen, uv - fr).b;
	if (double_k > 0.01) {
		vec3 c2 = texture(screen, uv + dbl).rgb;
		c = mix(c, c2, 0.42 * double_k);
	}
	float lu = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(lu), clamp(drain + fear * 0.3, 0.0, 1.0));
	c = mix(c, c * tint.rgb * 1.6 + tint.rgb * 0.05, tint.a);
	// grain, heavier in the dark
	float gt = safe ? floor(time_k * 4.0) : time_k * 60.0;     // (slow: fast grain over a dark frame reads as the picture flickering)
	float n = h(uv * vec2(1280.0, 720.0) + fract(gt * 0.713) * 97.0) - 0.5;
	c += n * grain * (1.25 - lu) * (safe ? 0.5 : 1.0);
	// vignette, and the heartbeat at the edges
	float r = length(d * vec2(1.0, 0.82));
	float v = smoothstep(0.85, 0.2, r * (1.0 + vignette + fear * 0.55));
	c *= mix(1.0, v, 0.85);
	float he = smoothstep(0.2, 0.75, r) * hurt;
	c = mix(c, c * vec3(0.55, 0.12, 0.1), he * 0.8);
	c *= 1.0 - pulse * smoothstep(0.25, 0.75, r) * 0.8;
	// 15-bit colour with ordered dither, at the 3D picture's resolution
	if (dither > 0.0) {
		ivec2 pp = ivec2(uv * res) % 4;
		float t = (bayer[pp.y * 4 + pp.x] / 16.0 - 0.5) / 31.0;
		c = floor((c + t * dither) * 31.0 + 0.5) / 31.0;
	}
	COLOR = vec4(c, 1.0);
}
