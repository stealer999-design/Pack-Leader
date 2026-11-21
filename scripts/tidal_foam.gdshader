shader_type spatial;
// The churned foam a Tidal Wave leaves on the ground behind it (see
// tidal_wave_fx.gd): a flat arc from the caster out to the wave, UV.x across
// the arc, UV.y from the caster (0) to the wave (1).
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float near = 0.5;
uniform float dist = 1.0;
uniform float half_angle = 0.5;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform vec3 water : source_color = vec3(0.12, 0.4, 0.6);
uniform vec3 glow : source_color = vec3(0.55, 0.85, 1.0);

varying vec2 v_uv;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));  // rotate each octave, so no grid shows
	for (int i = 0; i < 4; i++) { v += a * noise(p); p = turn * p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}

void vertex() {
	float a = mix(-half_angle, half_angle, UV.x);
	float r = mix(near, dist, UV.y);
	VERTEX = vec3(sin(a) * r, 0.0, -cos(a) * r);
	v_uv = vec2(UV.x * (half_angle * 2.0 * r), r);  // world-ish units, so the foam doesn't stretch
}

void fragment() {
	float n = fbm(v_uv * 1.6 + vec2(0.0, -TIME * 1.8));
	float bubbles = smoothstep(0.55, 0.72, fbm(v_uv * 4.5 + vec2(TIME * 0.4, -TIME * 2.2)));
	float along = clamp((v_uv.y - near) / max(dist - near, 0.01), 0.0, 1.0);
	ALBEDO = mix(water, vec3(0.9, 0.96, 1.0), bubbles * 0.8 + smoothstep(0.75, 1.0, along) * 0.5);
	ALBEDO += glow * pow(n, 3.0) * 1.2;
	float ends = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	ALPHA = clamp((0.35 + n * 0.5 + bubbles * 0.45) * smoothstep(0.0, 0.35, along) * ends * fade, 0.0, 1.0);
}
