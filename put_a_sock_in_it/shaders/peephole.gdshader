// A door's peephole (scripts/levels/lobby.gd _peep): the room beyond through a fisheye lens. The
// middle swells, the edges crowd in, the glass is dirty and warm, and outside the circle it's the
// dark of the door. Steady: nothing in here moves on its own.
shader_type canvas_item;

uniform float bulge = 0.55;           // how much the middle swells
uniform vec4 glass = vec4(1.0, 0.92, 0.8, 1.0);
uniform float gain = 2.4;             // the lens gathers what light there is: the dark rooms read

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// fisheye: near the middle, sample close in (swollen); toward the rim, out to the edge
		vec2 q = p * mix(1.0 - bulge, 1.0, r * r);
		vec4 c = texture(TEXTURE, q * 0.5 + 0.5);
		c.rgb = pow(clamp(c.rgb * gain, 0.0, 1.0), vec3(0.8));
		float vig = 1.0 - smoothstep(0.55, 1.0, r) * 0.85;
		// a smear of grease across the glass, and the brass rim catching a little light
		float smear = 0.92 + 0.08 * sin((p.x + p.y * 0.6) * 9.0);
		float rim = smoothstep(0.93, 0.99, r) * (1.0 - smoothstep(0.99, 1.0, r));
		COLOR = vec4(c.rgb * glass.rgb * vig * smear + vec3(0.25, 0.18, 0.08) * rim, 1.0);
	}
}
