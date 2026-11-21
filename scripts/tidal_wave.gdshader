shader_type spatial;
// Tidal Wave's wall of water (see tidal_wave_fx.gd). The mesh is a template:
// VERTEX.x = how far forward this point of the wave's profile sits and
// VERTEX.y = how high (both in wave heights), UV.x = across the arc (0..1),
// UV.y = along the profile (0 = the back foot, 1 = the curling lip).
// The shader bends it onto an arc `dist` away from the caster.
// depth_prepass_alpha: only the nearest layer of the curl blends, so folds
// of the same sheet don't stack into dark blotches
render_mode blend_mix, unshaded, cull_disabled, depth_prepass_alpha, shadows_disabled;

uniform float dist = 1.0;
uniform float height = 2.0;
uniform float half_angle = 0.5;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
uniform float brightness = 1.0;
uniform vec3 deep : source_color = vec3(0.03, 0.16, 0.3);
uniform vec3 shallow : source_color = vec3(0.2, 0.62, 0.85);
uniform vec3 glow : source_color = vec3(0.55, 0.85, 1.0);

varying float v_t;
varying float v_across;
varying vec3 v_world;

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
	// lower towards the ends of the arc, so its sides roll off into spray
	float taper = pow(sin(3.14159 * UV.x), 0.6);
	float h = height * (0.35 + 0.65 * taper);
	float r = dist + VERTEX.x * h;
	vec3 n = NORMAL;
	VERTEX = vec3(sin(a) * r, VERTEX.y * h, -cos(a) * r);
	NORMAL = normalize(vec3(sin(a) * n.x, n.y, -cos(a) * n.x));
	// churning water: the surface heaves and boils, most at the crest
	float boil = fbm(vec2(UV.x * 7.0 + seed, UV.y * 4.0 - TIME * 2.2)) - 0.5;
	VERTEX += NORMAL * boil * h * (0.1 + 0.2 * UV.y) * (1.0 - smoothstep(0.7, 0.9, UV.y));
	v_t = UV.y;
	v_across = UV.x;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = v_t;
	// water racing up the back of the wave and over the crest
	vec2 flow = vec2(v_across * 9.0 + t * 2.3 + seed, t * 3.0 - v_across * 1.7 - TIME * 2.6);
	float n = fbm(flow);
	float streaks = fbm(vec2(v_across * 22.0, t * 1.4 - TIME * 3.4));
	// dark deep water at the foot, clearer turquoise up the face
	vec3 water = mix(deep, shallow, smoothstep(0.05, 0.9, t + (n - 0.5) * 0.4));
	water *= 0.8 + 0.4 * n;
	// white foam only on the crest and the lip, torn by the noise
	float foam = smoothstep(0.78, 0.92, t + (n - 0.5) * 0.5);
	float spume = smoothstep(0.62, 0.68, fbm(vec2(v_across * 30.0, t * 8.0 - TIME * 4.0))) * smoothstep(0.35, 0.8, t);
	foam = max(max(foam, spume * 0.55), smoothstep(0.84, 0.94, t));
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
	// arcane streaks of light racing up through the water
	float energy = (smoothstep(0.66, 0.86, streaks) * 1.3 + pow(streaks, 6.0) * 7.0 + rim * 0.3) * brightness;
	if (!FRONT_FACING) {
		water = mix(water, shallow, 0.55);  // the inside of the curl, lit through the water
	}
	ALBEDO = mix(water, vec3(0.93, 0.98, 1.0), foam);
	ALBEDO += glow * energy * (1.0 - foam * 0.6);
	// ragged lip, soft ends, sunk into the ground at the foot
	float lip = 1.0 - smoothstep(0.9 - n * 0.22, 1.0 - n * 0.12, t);
	float ends = smoothstep(0.0, 0.1, v_across) * smoothstep(1.0, 0.9, v_across);
	float foot = smoothstep(0.0, 0.14, t);
	float ground = smoothstep(0.0, 0.25, v_world.y);
	ALPHA = clamp((0.92 + foam * 0.1 + energy * 0.1) * lip * ends * foot * max(ground, 0.35) * fade, 0.0, 1.0);
}
