shader_type spatial;
// A spiky burst of light (PierceFX: where Piercing Shot tears through an
// enemy), drawn on a camera-facing quad: a white-hot centre and jagged rays of
// uneven length, gold to orange at their tips.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;

uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
uniform vec3 hot : source_color = vec3(1.0, 0.98, 0.88);
uniform vec3 warm : source_color = vec3(1.0, 0.62, 0.15);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

float hash(float n) { return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453); }

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x) / 6.2831853 + 0.5;
	float n = 22.0;
	float cell = floor(a * n);
	float f = fract(a * n) - 0.5;
	float len = mix(0.35, 1.0, hash(cell));  // each ray its own length
	float width = 0.5 * (1.0 - r / len);  // tapering to a point
	float ray = smoothstep(width, width * 0.4, abs(f)) * step(r, len);
	float core = smoothstep(0.32, 0.0, r);
	float glow = smoothstep(0.7, 0.0, r) * 0.45;
	float v = clamp(max(ray, core) + glow, 0.0, 1.0);
	ALBEDO = mix(warm, hot, clamp(core * 1.5 + (1.0 - r) * 0.6, 0.0, 1.0));
	ALPHA = v * fade;
}
