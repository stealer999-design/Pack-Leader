shader_type spatial;
// Burning ground where a meteor struck (FireballFX): a blackened splash with
// glowing cracks of fire through it that flicker, cool and fade (`fade`).
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 4; i++) { v += a * noise(p); p = turn * p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float n = fbm(p * 2.5 + seed);
	// a ragged splash, not a perfect disc
	float edge = 1.0 - smoothstep(0.55, 0.95, r + (n - 0.5) * 0.5);
	// cracks: thin ridges of the noise, radiating from the middle
	float ridge = 1.0 - abs(fbm(vec2(atan(p.y, p.x) * 2.2 + seed, r * 3.0)) * 2.0 - 1.0);
	float cracks = smoothstep(0.82, 0.97, ridge) * (1.0 - smoothstep(0.2, 0.85, r));
	float hot = clamp(cracks + (1.0 - smoothstep(0.0, 0.35, r)) * 0.8, 0.0, 1.0);
	float flicker = 0.75 + 0.25 * sin(TIME * 12.0 + n * 9.0);
	float heat = hot * flicker * fade;
	vec3 fire = mix(vec3(0.9, 0.22, 0.03), vec3(1.0, 0.75, 0.3), smoothstep(0.5, 1.0, heat));
	vec3 char = mix(vec3(0.05, 0.03, 0.025), vec3(0.18, 0.08, 0.04), n);
	ALBEDO = mix(char, fire, smoothstep(0.1, 0.6, heat));
	ALPHA = clamp(edge * (0.75 + heat * 0.25) * min(fade * 2.5, 1.0), 0.0, 1.0);
}
