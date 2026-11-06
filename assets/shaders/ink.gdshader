// RATFORMER surface shader (docs/STYLE.md): "Midnight Caper", Art 4.0 (a storybook
// cartoon in solid, touchable 3D).
// One shader for the whole house and everyone in it, so the look is cohesive:
//   - lighting is drawn, not simulated: a cool moon with a soft toon ramp, a sky/floor
//     ambient, and warm lamp pools read from a small lamp table (LampField)
//   - every texture carries a height map in its alpha channel; it's turned into surface
//     relief here (bump mapping from screen-space derivatives: no tangents needed), so
//     grout sinks, wood grain ridges and carpet pile catch the light
//   - shiny things (tile, metal, plastic, porcelain) get a soft moonlit highlight
//   - bevelled edges (vertex alpha 0) are drawn as ink lines, fading with distance
//   - textures are smooth-filtered with mipmaps and anisotropy (no crawling texels)
//   - world-space texture projection is chosen per triangle from its true face normal,
//     so bevels and chewed voxel faces never smear a texture across two projections
//   - "retro" (Settings > PS1 LOOK, off by default) brings back the old vertex wobble and
//     15-bit ordered dither; "saturation" pushes colour; "halftone" adds comic dots in shadow
//   - "detail" (the quality preset) turns relief and highlights off on LOW
// No real lights are used, so there is no per-object light limit and nothing pops.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Texture repeats per world unit (world-space UVs). 0 = use the mesh's own UVs.
uniform float tiles_per_meter = 0.5;
uniform bool world_uv = true;
// Things that move as a whole (a nook's planets turn under you): project the texture in
// the mesh's own space instead, so it stays stuck to the surface.
uniform bool object_uv = false;
uniform vec2 uv_scale = vec2(1.0);
// Characters: a cool rim so silhouettes read against dark rooms.
uniform float rim = 0.0;
// How strongly bevel edges are inked (0 for things that shouldn't be outlined).
uniform float edge_ink = 1.0;
// Relief depth from the texture's height (alpha), as a fraction of one texture repeat.
uniform float bump = 0.035;
// 0 = matte, 1 = glazed tile / polished metal.
uniform float gloss = 0.0;
// Pickups spin about their own up axis and bob, here on the GPU (radians a second, and
// units), so a thousand crumbs cost no script time. Phase comes from where they stand.
uniform float spin = 0.0;
uniform float bob = 0.0;

// Set by LampField every frame.
global uniform sampler2D lamp_data : filter_nearest;
global uniform int lamp_count;
global uniform vec3 moon_dir;
global uniform vec4 moon_color;
global uniform vec4 ambient_color;
global uniform vec4 ink_color;
global uniform float retro;
global uniform float saturation;
// Pulls every colour a little toward one warm, lamp-lit grade, so the rooms' paints and
// plastics sit in the same picture instead of clashing (0 = off).
global uniform float grade;
global uniform float halftone;
global uniform float detail;

varying vec3 v_world;
varying vec3 v_normal;
varying vec3 v_obj;     // object-space position (object_uv)

void vertex() {
	if (spin != 0.0 || bob != 0.0) {
		float ph = MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.23;
		float a = TIME * spin + ph;
		mat2 r = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
		VERTEX.xz = r * VERTEX.xz;
		NORMAL.xz = r * NORMAL.xz;
		VERTEX.y += sin(TIME * 3.0 + ph) * bob;
	}
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_obj = VERTEX;
	if (!world_uv) {
		UV = UV * uv_scale;
	}
	// The PS1 wobble (optional): snap the projected vertex to a coarse grid. A shader that
	// writes POSITION anywhere must write it always (Godot then skips its own projection).
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (retro > 0.0) {
		vec2 grid = vec2(240.0 * VIEWPORT_SIZE.x / max(VIEWPORT_SIZE.y, 1.0), 240.0) * 0.5;
		clip.xy = clip.w > 0.0 ? round(clip.xy / clip.w * grid) / grid * clip.w : clip.xy;
	}
	POSITION = clip;
}

// Planar projection picked from the triangle's own face normal `fn`.
vec2 project(vec3 p, vec3 fn) {
	vec3 a = abs(fn);
	if (a.y >= a.x && a.y >= a.z) {
		return p.xz;
	} else if (a.x >= a.z) {
		return vec2(p.z, -p.y);
	}
	return vec2(p.x, -p.y);
}

float toon(float x) {
	// Soft-edged bands: cartoon, but no hard stair-steps.
	float b = clamp(x, 0.0, 1.0) * 3.0;
	float f = fract(b);
	return (floor(b) + smoothstep(0.35, 0.65, f)) / 3.0;
}

void fragment() {
	vec3 n = normalize(v_normal);
	vec3 dpx = dFdx(v_world);
	vec3 dpy = dFdy(v_world);
	vec2 uv = UV;
	if (world_uv) {
		vec3 pp = object_uv ? v_obj : v_world;
		vec3 fn = object_uv ? cross(dFdx(v_obj), dFdy(v_obj)) : cross(dpx, dpy);
		if (dot(fn, fn) < 1e-12) {
			fn = n;
		}
		uv = project(pp, fn) * tiles_per_meter;
	}
	vec4 tx = texture(albedo_tex, uv);
	vec3 base = tx.rgb * tint.rgb * COLOR.rgb;

	// Relief: the height in alpha bends the normal (Mikkelsen, "Bump Mapping Unparametrized
	// Surfaces on the GPU"). World depth is a fraction of one texture repeat.
	float depth = world_uv ? bump / max(tiles_per_meter, 0.01) : bump * 2.0;
	if (detail > 0.0 && depth > 0.0) {
		float h = tx.a * depth;
		float dhx = dFdx(h);
		float dhy = dFdy(h);
		vec3 r1 = cross(dpy, n);
		vec3 r2 = cross(n, dpx);
		float det = dot(dpx, r1);
		vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
		vec3 bn = normalize(abs(det) * n - grad);
		n = normalize(mix(n, bn, clamp(detail, 0.0, 1.0)));
	}
	// Crevices (low height) sit in their own shadow a little.
	float cavity = mix(1.0, 0.72 + 0.28 * tx.a, detail * step(0.001, bump));

	vec3 view = normalize(CAMERA_POSITION_WORLD - v_world);
	vec3 l = -normalize(moon_dir);
	float ndl = dot(n, l);
	// Sky above, a dim bounce from below: shapes read round even in shadow.
	vec3 amb = ambient_color.rgb * mix(0.72, 1.12, n.y * 0.5 + 0.5);
	vec3 light = amb + moon_color.rgb * (0.22 + 0.78 * toon(ndl * 0.85 + 0.15)) * smoothstep(-0.35, -0.05, ndl);

	// Lamp pools: warm, smooth falloff with a soft ring at the edge.
	vec3 spec_l = vec3(0.0);
	for (int i = 0; i < 16; i++) {
		if (i >= lamp_count) {
			break;
		}
		vec4 a = texelFetch(lamp_data, ivec2(i, 0), 0);   // xyz position, w range
		vec4 c = texelFetch(lamp_data, ivec2(i, 1), 0);   // rgb colour * energy, a fade
		vec3 to = a.xyz - v_world;
		float d = length(to);
		float k = 1.0 - d / a.w;
		if (k <= 0.0) {
			continue;
		}
		vec3 ld = to / max(d, 0.001);
		float facing = clamp(dot(n, ld) * 0.6 + 0.5, 0.0, 1.0);
		float fall = toon(k * k * facing * 1.3);
		light += c.rgb * c.a * fall;
		spec_l += c.rgb * c.a * k * pow(max(dot(reflect(-ld, n), view), 0.0), 24.0);
	}

	vec3 col = base * light * cavity;

	// Highlights: the moon on glaze and metal, and the nearest lamps.
	if (gloss > 0.0 && detail > 0.0) {
		float s = pow(max(dot(reflect(-l, n), view), 0.0), mix(8.0, 48.0, gloss));
		col += (moon_color.rgb * smoothstep(0.35, 0.6, s) * 0.55 + spec_l * 0.6) * gloss;
	}

	// Halftone: ink dots printed on surfaces in the dark (stuck to the world).
	float lum = dot(light, vec3(0.3, 0.5, 0.2));
	float dark = clamp((0.5 - lum) / 0.5, 0.0, 1.0);
	float dist = length(CAMERA_POSITION_WORLD - v_world);
	if (world_uv && halftone > 0.0) {
		vec2 g = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * (uv / max(tiles_per_meter, 0.01)) / 0.45;
		vec2 cell = fract(g) - 0.5;
		float in_dot = 1.0 - step(dark * 0.42, length(cell));
		float near = clamp(1.8 - dist / 18.0, 0.0, 1.0);
		col = mix(col, col * ink_color.rgb * 2.5, in_dot * 0.35 * step(0.35, dark) * near * halftone);
	}

	// Rim (characters): a soft moonlit edge.
	float fres = 1.0 - max(dot(n, view), 0.0);
	col += moon_color.rgb * rim * smoothstep(0.5, 0.8, fres);

	// Ink edges on bevels, fading out with distance so thin lines don't shimmer.
	float edge = (1.0 - COLOR.a) * edge_ink * clamp(1.6 - dist / 45.0, 0.0, 1.0);
	col = mix(col, ink_color.rgb, edge * 0.85);

	col += emission_color.rgb * tx.rgb;
	// Cartoon-bright colour.
	float luma = dot(col, vec3(0.3, 0.59, 0.11));
	col = max(mix(vec3(luma), col, saturation), vec3(0.0));
	col = mix(col, vec3(luma) * vec3(1.06, 0.97, 0.86), grade);
	// A soft shoulder: pale tile and cream walls keep their colour instead of washing
	// out to white under the bright cartoon light.
	vec3 over = max(col - 0.72, vec3(0.0));
	col = min(col, vec3(0.72)) + over / (1.0 + over / 0.3);
	// 15-bit colour with a 4x4 ordered dither, like the PlayStation's (PS1 look only).
	if (retro > 0.0) {
		ivec2 px = ivec2(FRAGCOORD.xy) % 4;
		int bayer[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
		float th = (float(bayer[px.y * 4 + px.x]) + 0.5) / 16.0 - 0.5;
		col = floor(col * 31.0 + th + 0.5) / 31.0;
	}
	ALBEDO = col;
}
