shader_type spatial;
// Cyclone's whirlwind (CycloneFX): one layer of the funnel, an open cone of
// dusty wind streaks racing round. UV.x goes round it, UV.y down it (0 = top).
// Also its dust on the ground (`ground`: a flat ring, UV from a plane).
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float speed = 6.0;  // radians per second
uniform float twist = 2.5;  // how much the streaks lean as they climb
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float ground = 0.0;
uniform float seed = 0.0;
uniform vec3 dust : source_color = vec3(0.93, 0.91, 0.86);
uniform vec3 shadow : source_color = vec3(0.32, 0.28, 0.24);

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

void fragment() {
	float a;
	float h;
	float r = 0.0;
	if (ground > 0.5) {
		vec2 p = (UV - 0.5) * 2.0;
		r = length(p);
		a = atan(p.y, p.x) + TIME * speed * 0.6 + r * 2.0;
		h = r;
	} else {
		a = UV.x * 6.2831853 + TIME * speed + UV.y * twist;
		h = UV.y;
	}
	// streaks: smooth going round, tight going up (sampled on a circle, so no seam)
	float n = fbm(vec3(cos(a) * 2.2 + seed, sin(a) * 2.2, h * (ground > 0.5 ? 6.0 : 11.0)));
	float streak = smoothstep(0.4, 0.66, n);
	float dark = smoothstep(0.42, 0.3, n);  // darker gusts between the bright streaks
	float body = ground > 0.5
		? smoothstep(1.0, 0.55, r) * smoothstep(0.1, 0.35, r)
		: smoothstep(0.0, 0.18, h) * smoothstep(1.0, 0.75, h);
	ALBEDO = mix(shadow, dust, streak);
	ALPHA = clamp(max(streak, dark * 0.45) * body * (ground > 0.5 ? 0.6 : 0.95) * fade, 0.0, 1.0);
}
