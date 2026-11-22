shader_type spatial;
// Prism Shot's crystal (PrismFX): see-through glass whose colour shifts
// through the rainbow with the angle it is seen at and with time, bright at
// its edges, a white glint sweeping up it.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float shift = 0.0;  // turns the rainbow (animated)

vec3 rainbow(float h) {
	return clamp(abs(fract(h + vec3(0.0, 0.667, 0.333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 1.5);
	vec3 local = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = facing * 1.3 + local.y * 0.35 + shift;
	vec3 col = mix(rainbow(h), vec3(1.0), 0.35);
	float glint = smoothstep(0.08, 0.0, abs(fract(local.y * 0.6 - shift * 1.5) - 0.5)) * 0.8;
	ALBEDO = mix(col, vec3(1.0), clamp(rim * 0.6 + glint, 0.0, 1.0));
	ALPHA = clamp(0.38 + rim * 0.5 + glint, 0.0, 0.9) * fade;
}
