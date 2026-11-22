shader_type spatial;
// Hunter's Mark (MarkFX), drawn on a camera-facing quad. `kind` 0: the arcane
// sigil that flares beside the caster (a double ring of runes round a
// hexagram, pale green-white). `kind` 1: the crosshair reticle over a marked
// enemy (a ring with four ticks through it, an inner broken ring, a centre
// point, red with a white-hot core, pulsing).
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;

uniform int kind = 0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float spin = 0.0;  // radians (the sigil's turn)
uniform vec3 glow : source_color = vec3(0.6, 1.0, 0.7);
uniform vec3 core : source_color = vec3(0.95, 1.0, 0.95);

void vertex() {
	// face the camera, keeping the node's scale
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

float line(float d, float w) { return smoothstep(w, 0.0, abs(d)); }
vec2 rot(vec2 p, float a) { float c = cos(a); float s = sin(a); return vec2(c * p.x - s * p.y, s * p.x + c * p.y); }

// one triangle's edges (circumradius R), as glowing lines
float triangle(vec2 p, float R, float a0, float w) {
	float v = 0.0;
	for (int k = 0; k < 3; k++) {
		float a = a0 + float(k) * 2.0943951;
		vec2 n = vec2(cos(a), sin(a));
		vec2 t = vec2(-n.y, n.x);
		float along = dot(p, t);
		v = max(v, line(dot(p, n) - R * 0.5, w) * step(abs(along), R * 0.866));
	}
	return v;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float lines = 0.0;  // crisp lines (white core)
	float haze = 0.0;  // soft glow round them
	if (kind == 0) {
		vec2 q = rot(p, spin);
		vec2 o = rot(p, -spin * 0.6);
		float ao = atan(o.y, o.x);
		lines += line(r - 0.93, 0.03) + line(r - 0.8, 0.022);
		// the rune band: little marks round between the outer rings
		float cell = fract(ao * 28.0 / 6.2831853);
		float rune = step(0.25, cell) * step(cell, 0.6) * line(r - 0.865, 0.04) * (0.6 + 0.4 * step(0.5, fract(ao * 7.0 / 6.2831853)));
		lines += rune;
		// the hexagram, two interlocked triangles
		lines += triangle(q, 0.78, 1.5708, 0.026) + triangle(q, 0.78, -1.5708, 0.026);
		lines += line(r - 0.45, 0.02);
		// a small four-point star at the heart
		vec2 s = abs(rot(q, 0.785));
		lines += smoothstep(0.03, 0.0, min(s.x, s.y)) * smoothstep(0.2, 0.0, r);
		haze = smoothstep(1.0, 0.3, r) * 0.22;
	} else {
		float pulse = 0.8 + 0.2 * sin(TIME * 7.0);
		vec2 q = rot(p, TIME * 0.8);
		float a = atan(q.y, q.x);
		lines += line(r - 0.62, 0.055);
		// four ticks through the ring, along the axes
		vec2 ap = abs(p);
		float tick = max(line(p.x, 0.05) * step(0.42, ap.y) * step(ap.y, 0.95), line(p.y, 0.05) * step(0.42, ap.x) * step(ap.x, 0.95));
		lines += tick;
		// an inner ring broken into four arcs, turning
		lines += line(r - 0.3, 0.04) * step(0.3, abs(sin(a * 2.0)));
		lines += smoothstep(0.09, 0.03, r);  // the centre point
		lines *= pulse;
		haze = smoothstep(0.75, 0.5, r) * smoothstep(0.35, 0.6, r) * 0.25 * pulse;  // a faint glow round the ring, the enemy left clear
	}
	lines = clamp(lines, 0.0, 1.0);
	// drawn over the scene (not added to it), so it stays red on bright sand
	ALBEDO = mix(glow, core, lines * lines * 0.8);
	ALPHA = clamp(lines + haze, 0.0, 1.0) * fade;
}
