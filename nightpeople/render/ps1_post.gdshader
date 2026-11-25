// Drawn over the low-resolution 3D image as it is scaled up: 15-bit colour (5 bits a channel,
// as the PS1 output) with a 4x4 ordered dither in the low-res pixel grid.
shader_type canvas_item;

uniform bool dither = true;
uniform float levels = 31.0;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (dither) {
		ivec2 px = ivec2(UV * vec2(textureSize(TEXTURE, 0)));
		float t = BAYER[(px.y % 4) * 4 + (px.x % 4)] / 16.0 - 0.5;
		c.rgb = floor(c.rgb * levels + 0.5 + t) / levels;
	}
	COLOR = vec4(c.rgb, 1.0);
}
