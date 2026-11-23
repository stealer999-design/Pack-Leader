shader_type spatial;
// A pool on the ground (FXKit.pool): swirling, mottled liquid or dust in two
// colours, soft at its edge, with bubbles swelling and popping across it.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 deep : source_color = vec3(0.1, 0.3, 0.05);
uniform vec3 light : source_color = vec3(0.5, 1.0, 0.3);
uniform float bubbles = 1.0;
uniform float swirl = 0.0;
uniform float seed = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float opacity = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x) + swirl * TIME * (1.0 - r);
	vec2 q = vec2(cos(a), sin(a)) * r * 3.0;
	float n = noise(q + TIME * 0.3) * 0.6 + noise(q * 2.3 - TIME * 0.2) * 0.4;
	vec3 col = mix(deep, light, smoothstep(0.35, 0.8, n));
	// bubbles: cells across the pool, each swelling to a bright ring and popping
	float b = 0.0;
	vec2 g = p * 4.0;
	vec2 cell = floor(g);
	for (int i = -1; i <= 1; i++) for (int j = -1; j <= 1; j++) {
		vec2 c = cell + vec2(float(i), float(j));
		float h = hash(c);
		vec2 centre = c + 0.5 + 0.3 * vec2(hash(c + 3.1) - 0.5, hash(c + 7.7) - 0.5);
		float life = fract(TIME * (0.4 + h * 0.5) + h * 7.0);
		float rad = 0.12 + 0.3 * life;
		float d = length(g - centre);
		b = max(b, smoothstep(0.06, 0.0, abs(d - rad)) * (1.0 - life) * step(0.35, h));
	}
	col = mix(col, light * 1.2, b * bubbles);
	float edge = smoothstep(1.0, 0.75, r + 0.1 * (noise(vec2(atan(p.y, p.x) * 3.0, 1.0)) - 0.5));
	ALBEDO = col;
	ALPHA = edge * (0.8 + 0.2 * n) * fade * opacity;
}
