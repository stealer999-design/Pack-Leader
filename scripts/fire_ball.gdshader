shader_type spatial;
// A ball of fire (FireballFX): a white-hot heart that cools through yellow and
// orange to red at its edge, the flames boiling across it. Also its explosion:
// `erode` eats holes into it as it burns out.
// Normal blending (not additive), so it stays orange on bright ground.
render_mode blend_mix, unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform float heat = 1.0;  // 1 = white-hot core; lower = cooler, redder
uniform float erode : hint_range(0.0, 1.0) = 0.0;
uniform float flicker = 7.0;
uniform float strength = 1.0;
uniform float wisp = 0.0;  // 0 = solid ball; 1 = torn into tongues of flame (explosions)

varying vec3 v_local;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.07 + vec3(3.1, 1.7, 5.3); a *= 0.5; }
	return v;
}

vec3 fire(float h) {
	// red -> orange -> yellow -> white
	vec3 c = mix(vec3(0.5, 0.04, 0.01), vec3(1.0, 0.32, 0.04), smoothstep(0.0, 0.35, h));
	c = mix(c, vec3(1.0, 0.72, 0.2), smoothstep(0.35, 0.7, h));
	return mix(c, vec3(1.0, 0.97, 0.85), smoothstep(0.7, 1.0, h));
}

void vertex() {
	v_local = VERTEX / max(length(VERTEX), 0.001);
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float n = fbm(v_local * 3.0 + vec3(0.0, -TIME * flicker * 0.3, TIME * flicker * 0.2));
	float h = (pow(facing, 1.4) * 0.8 + n * 0.55 - 0.15) * heat;
	float holes = smoothstep(erode - 0.08, erode + 0.08, n + facing * 0.3);
	float a = smoothstep(0.0, 0.45, facing) * holes * strength;
	a *= mix(1.0, smoothstep(0.32, 0.62, n + facing * 0.25), wisp);
	ALBEDO = fire(clamp(h, 0.0, 1.0)) * (0.85 + 0.5 * h);
	ALPHA = clamp(a * (0.55 + 0.6 * h), 0.0, 1.0);
}
