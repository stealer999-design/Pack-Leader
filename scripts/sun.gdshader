shader_type spatial;
// Sunburst Arrow's sun (SunburstFX), on a camera-facing quad: a white-hot
// core, a golden body, an orange rim, and a flickering corona of light
// streaming out round it.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;

uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
uniform vec3 core : source_color = vec3(1.0, 0.99, 0.9);
uniform vec3 gold : source_color = vec3(1.0, 0.78, 0.25);
uniform vec3 rim : source_color = vec3(1.0, 0.45, 0.08);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

float hash(float n) { return fract(sin(n * 12.9898 + seed) * 43758.5453); }
float noise(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(hash(i), hash(i + 1.0), f); }

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x) / 6.2831853 + 0.5;
	float body = 0.5;  // the sun's edge
	// the corona: rays of light, flickering, streaming out past the edge
	float rays = noise(a * 40.0 + TIME * 2.0) * 0.6 + noise(a * 13.0 - TIME * 1.3) * 0.4;
	float corona = smoothstep(body + 0.45 * rays, body - 0.05, r) * smoothstep(body - 0.1, body + 0.02, r);
	float disc = smoothstep(body + 0.02, body - 0.02, r);
	float glow = smoothstep(1.0, 0.3, r) * 0.35;
	vec3 col = mix(rim, gold, smoothstep(body, body * 0.55, r));
	col = mix(col, core, smoothstep(body * 0.6, 0.0, r));
	col = mix(col, mix(gold, rim, 0.5), corona * (1.0 - disc));
	ALBEDO = col;
	ALPHA = clamp(disc + corona * 0.85 + glow, 0.0, 1.0) * fade;
}
