shader_type spatial;
// A protective dome (FXKit.dome): glassy, bright at its rim, with a glowing
// honeycomb of hexagons over it and a band of light sweeping up.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.85, 0.4);
uniform float fade : hint_range(0.0, 1.0) = 1.0;

float hexline(vec2 p) {
	p.x *= 1.1547; p.y += mod(floor(p.x), 2.0) * 0.5;
	p = abs(fract(p) - 0.5);
	return abs(max(p.x * 1.5 + p.y, p.y * 2.0) - 1.0);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 2.0);
	float hx = smoothstep(0.12, 0.0, hexline(UV * vec2(24.0, 8.0)));
	float sweep = smoothstep(0.08, 0.0, abs(fract(UV.y * 1.0 - TIME * 0.8) - 0.5) - 0.42);
	float a = 0.03 + rim * 0.45 + hx * 0.22 + sweep * 0.15;
	ALBEDO = mix(tint, vec3(1.0), hx * 0.5 + rim * 0.3);
	ALPHA = clamp(a, 0.0, 0.9) * fade;
}
