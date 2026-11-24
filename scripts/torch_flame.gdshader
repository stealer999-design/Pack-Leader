shader_type spatial;
// A torch flame (DungeonBuilder._flame): a card that always faces the camera,
// drawn as rising turbulent fire. Layered noise scrolls upward and bends a
// teardrop shape, so the flame licks and flickers; a white-yellow core fades
// through orange to deep red at the edges and tips. Added onto what's behind
// it (glowing), unlit. `seed` keeps two cards of one flame from moving alike.
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform float seed = 0.0;
uniform float speed = 1.0;
uniform vec4 core : source_color = vec4(1.0, 0.93, 0.7, 1.0);
uniform vec4 mid : source_color = vec4(1.0, 0.55, 0.12, 1.0);
uniform vec4 rim : source_color = vec4(0.75, 0.16, 0.03, 1.0);
uniform float intensity = 2.2;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 13.7) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}

void vertex() {
	// Face the camera (keeping the card's size).
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale.x, vec4(0.0, scale.y, 0.0, 0.0), INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);  // y: 0 at the flame's foot, 1 at its tip
	float t = TIME * 1.7 * speed + seed * 4.0;
	float n = fbm(vec2(uv.x * 2.2, uv.y * 1.6 - t));
	float n2 = fbm(vec2(uv.x * 4.5 + 3.1, uv.y * 3.0 - t * 1.6));
	float x = (uv.x - 0.5) * 2.0;
	x += (n - 0.5) * 0.9 * uv.y;  // the flame sways more towards its tip
	float width = mix(0.62, 0.04, pow(uv.y, 0.75));
	float body = 1.0 - smoothstep(width * 0.45, width, abs(x));
	body *= smoothstep(0.0, 0.1, uv.y);
	float heat = body * (1.25 - uv.y * 1.15) - (n2 - 0.45) * 0.75 * uv.y;
	heat = clamp(heat * 1.5, 0.0, 1.0);
	vec3 col = mix(rim.rgb, mid.rgb, smoothstep(0.08, 0.45, heat));
	col = mix(col, core.rgb, smoothstep(0.55, 0.95, heat));
	ALBEDO = col * intensity * heat;
	ALPHA = heat;
}
