// Over the whole low-resolution frame: 15-bit colour with an ordered dither, as the hardware did.
shader_type canvas_item;
uniform float levels = 32.0;
uniform float dither_amount = 1.0;
const mat4 BAYER = mat4(vec4(0.0, 8.0, 2.0, 10.0), vec4(12.0, 4.0, 14.0, 6.0), vec4(3.0, 11.0, 1.0, 9.0), vec4(15.0, 7.0, 13.0, 5.0));
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	ivec2 p = ivec2(FRAGCOORD.xy / 3.0) % 4;
	float d = (BAYER[p.x][p.y] / 16.0 - 0.5) * dither_amount / levels;
	COLOR = vec4(floor((c.rgb + d) * levels + 0.5) / levels, 1.0);
}
