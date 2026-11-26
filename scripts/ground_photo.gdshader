shader_type spatial;
// A photo-scanned ground (textures/ground/<style>_*.png) laid on the floor by
// world position. Two copies at different sizes are blended by a slow noise,
// so the tile doesn't show as a grid across a big level. Surface detail comes
// from the normal map, applied to faces that point up (the floor's top).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_gray, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D emission_tex : source_color, hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float emission_strength = 0.0;  // glowing parts (lava), when the set has an _emission.png
uniform sampler2D blend_noise : filter_linear_mipmap, repeat_enable;
uniform float tile_a = 5.0;   // world units one tile covers
uniform float tile_b = 13.3;  // the second, larger copy
uniform float blend_size = 45.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float normal_strength = 1.0;
uniform float wetness = 0.0;  // 0 dry .. 1 slick: lowers roughness so it shines (the bog's slime)
// How much softer than its finest the photo is drawn (a mip level bias): fine,
// noisy detail (moss, grass) otherwise crawls and fizzes as the camera moves.
uniform float soften = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv_a = world_pos.xz / tile_a;
	vec2 uv_b = world_pos.xz / tile_b + (tile_b == tile_a ? vec2(0.0) : vec2(0.37, 0.71));  // equal sizes: one pattern
	float b = smoothstep(0.38, 0.62, texture(blend_noise, world_pos.xz / blend_size).r);
	ALBEDO = mix(texture(albedo_tex, uv_a, soften).rgb, texture(albedo_tex, uv_b, soften).rgb, b) * tint;
	EMISSION = mix(texture(emission_tex, uv_a).rgb, texture(emission_tex, uv_b).rgb, b) * emission_strength;
	float rough = mix(texture(rough_tex, uv_a, soften).r, texture(rough_tex, uv_b, soften).r, b);
	// Wet ground: glossier, slicker in patches (the slow noise), a touch darker.
	float wet = wetness * mix(0.7, 1.0, texture(blend_noise, world_pos.xz / (blend_size * 0.4)).r);
	ROUGHNESS = mix(rough, 0.12, wet);
	SPECULAR = mix(0.5, 1.0, wet);
	ALBEDO *= mix(1.0, 0.7, wet);
	// Normal map (OpenGL: red along +x, green along +z of the ground), in world space.
	vec2 n = mix(texture(normal_tex, uv_a, soften).rg, texture(normal_tex, uv_b, soften).rg, b) * 2.0 - 1.0;
	// Steepened by normal_strength, but never tipped flat on its side (a flat
	// normal faces away from the sun and shows as a black speck that flickers
	// as the camera moves).
	float rise = max(sqrt(max(1.0 - dot(n, n), 0.0)), 0.3);
	vec3 bumped = normalize(vec3(n.x * normal_strength, rise, n.y * normal_strength));
	float up = smoothstep(0.7, 0.95, world_normal.y);
	vec3 wn = normalize(mix(world_normal, bumped, up));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	// Where the bumps change faster than a pixel can show (the glossy wet mud
	// most of all), the ground is a little rougher instead of glinting on and
	// off as the camera moves.
	vec3 dn = fwidth(wn);
	ROUGHNESS = sqrt(clamp(ROUGHNESS * ROUGHNESS + dot(dn, dn) * 4.0, 0.0, 1.0));
}
