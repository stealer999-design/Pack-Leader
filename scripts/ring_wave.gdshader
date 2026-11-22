shader_type spatial;
// Eagle Eye's ring (EagleEyeFX): a glowing ring racing outward over the
// ground, drawn on a flat quad. `progress` is its radius (0..1 of the quad's
// half-width); behind it a faint wash of light, and little marks round it.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform float width = 0.035;  // the ring's bright line (share of the radius)
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform vec3 glow : source_color = vec3(1.0, 0.5, 0.08);
uniform vec3 core : source_color = vec3(1.0, 0.92, 0.6);

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float d = r - progress;
	float line = smoothstep(width, 0.0, abs(d));
	float halo = smoothstep(width * 5.0, 0.0, abs(d)) * 0.55;
	float wash = smoothstep(0.0, progress, r) * step(r, progress) * 0.14;  // light left behind it
	float a = atan(p.y, p.x);
	float ticks = step(0.82, fract(a * 36.0 / 6.2831853)) * smoothstep(width * 3.0, 0.0, abs(d + width * 3.5)) * 0.8;
	float v = clamp(line + halo + wash + ticks, 0.0, 1.0);
	ALBEDO = mix(glow, core, line);
	ALPHA = v * fade * step(r, 1.0);
}
