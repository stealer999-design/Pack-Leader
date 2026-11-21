shader_type spatial;
// Thunderstorm's cloud (StormFX): a dark vortex of storm cloud wheeling over
// the spot, its arms spiralling into a darker eye, lit from inside by
// flickers of lightning (`flash`).
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float flash = 0.0;
uniform float seed = 0.0;
uniform float ice = 0.0;  // 1 = Hailstorm: a pale, frosty vortex instead of a dark storm

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = turn * p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	// twist the noise round the middle, faster near the eye
	float ang = atan(p.y, p.x) + 2.2 / (r + 0.35) - TIME * 0.9;
	vec2 q = vec2(cos(ang), sin(ang)) * r;
	float n = fbm(q * 2.6 + seed);
	float arms = smoothstep(0.35, 0.75, n + 0.25 * sin(ang * 3.0 + r * 6.0));
	vec3 cloud = mix(vec3(0.07, 0.08, 0.11), vec3(0.32, 0.36, 0.45), arms);
	cloud = mix(cloud, vec3(0.03, 0.03, 0.05), smoothstep(0.35, 0.0, r));  // the dark eye
	cloud += vec3(0.5, 0.7, 1.0) * flash * arms * (1.0 - r) * 1.2;  // lightning inside
	vec3 frost = mix(vec3(0.42, 0.55, 0.68), vec3(0.93, 0.97, 1.0), arms);
	frost = mix(frost, vec3(0.3, 0.42, 0.55), smoothstep(0.35, 0.0, r));
	cloud = mix(cloud, frost, ice);
	float edge = 1.0 - smoothstep(0.55, 1.0, r + (n - 0.5) * 0.35);
	ALBEDO = cloud;
	ALPHA = clamp(edge * (0.75 + 0.25 * arms) * fade, 0.0, 1.0);
}
