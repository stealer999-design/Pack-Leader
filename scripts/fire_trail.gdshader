shader_type spatial;
// A fireball's flame tendrils (FireballFX): ribbons spiralling back from the
// ball, twisting as it flies. The mesh is a template: UV.x = how far back
// along the trail (0 at the ball, 1 at the tail), UV.y = across the ribbon.
// The vertex shader lays each ribbon on its helix (in the node's space, -Z
// forward) and turns it to face the camera.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, world_vertex_coords;

uniform float trail_length = 3.0;
uniform float radius = 0.4;  // helix radius (0 = a straight central plume)
uniform float width = 0.45;
uniform float phase = 0.0;
uniform float twist = 7.0;  // turns per trail length, in radians
uniform float spin = 9.0;
uniform float strength = 1.0;

varying vec2 v_uv;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 4; i++) { v += a * noise(p); p = turn * p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}

vec3 helix(float s) {
	float a = phase + s * twist - TIME * spin;
	// tight round the ball, swelling out behind it, drawing in at the tail
	float r = radius * (0.85 + 0.9 * sin(3.14159 * min(s * 1.4, 1.0)));
	return vec3(cos(a) * r, sin(a) * r, s * trail_length);
}

void vertex() {
	float s = UV.x;
	vec3 c = (MODEL_MATRIX * vec4(helix(s), 1.0)).xyz;
	vec3 ahead = (MODEL_MATRIX * vec4(helix(s + 0.01), 1.0)).xyz;
	vec3 tangent = normalize(ahead - c);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - c);
	vec3 side = normalize(cross(tangent, to_cam));
	float w = width * mix(1.0, 0.25, s) * (0.7 + 0.3 * sin(s * 9.0 - TIME * 14.0 + phase));
	VERTEX = c + side * w * (UV.y - 0.5) * 2.0;
	v_uv = UV;
}

void fragment() {
	float s = v_uv.x;
	float across = abs(v_uv.y - 0.5) * 2.0;
	float n = fbm(vec2(s * 7.0 - TIME * 9.0 + phase, v_uv.y * 2.5));
	float body = pow(1.0 - across, 1.6) * pow(1.0 - s, 1.2) * smoothstep(0.0, 0.05, s);
	float heat = clamp((1.0 - s) * 0.75 + (n - 0.5) * 0.6 + (1.0 - across) * 0.15, 0.0, 1.0);
	vec3 c = mix(vec3(0.55, 0.05, 0.01), vec3(1.0, 0.36, 0.05), smoothstep(0.0, 0.4, heat));
	c = mix(c, vec3(1.0, 0.78, 0.28), smoothstep(0.4, 0.75, heat));
	c = mix(c, vec3(1.0, 0.97, 0.85), smoothstep(0.75, 1.0, heat));
	float a = body * smoothstep(0.15, 0.55, n + (1.0 - s) * 0.35) * strength;
	ALBEDO = c * 1.15;
	ALPHA = clamp(a * 1.5, 0.0, 1.0);
}
