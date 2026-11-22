shader_type spatial;
// Arrow Cone's golden dome (ConeFX): a sector of a dome swept out from the
// archer. UV.x runs across the fan (0..1), UV.y from the ground up to its top.
// Glassy and faint in the middle, bright along its rim and outer edges, with
// streaks of light racing outward across it.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform vec3 gold : source_color = vec3(1.0, 0.72, 0.22);
uniform vec3 hot : source_color = vec3(1.0, 0.95, 0.7);

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	// rim: the dome's edge seen side-on glows (fresnel), and its borders
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 2.0);
	float edge = smoothstep(0.08, 0.0, UV.x) + smoothstep(0.92, 1.0, UV.x) + smoothstep(0.1, 0.0, UV.y) * 0.6;
	// streaks: thin bright lines across the fan, flickering
	float lane = floor(UV.x * 40.0 + UV.y * 6.0);
	float streak = smoothstep(0.45, 0.5, abs(fract(UV.x * 40.0 + UV.y * 6.0) - 0.5)) * step(0.6, hash(lane + floor(TIME * 12.0)));
	float a = 0.16 + 0.55 * rim + 0.5 * edge + 0.3 * streak;
	a *= smoothstep(1.0, 0.75, UV.y);  // softening towards the top
	ALBEDO = mix(gold, hot, clamp(rim + edge * 0.6 + streak, 0.0, 1.0));
	ALPHA = clamp(a, 0.0, 0.85) * fade;
}
