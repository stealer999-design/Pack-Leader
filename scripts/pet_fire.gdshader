shader_type spatial;
render_mode unshaded, cull_disabled;
// A pet's glowing fire core (PetModels): flickering flame colours that roll
// upward, seen through gaps in its fur.

uniform vec3 deep : source_color = vec3(0.45, 0.03, 0.0);
uniform vec3 mid : source_color = vec3(1.0, 0.32, 0.02);
uniform vec3 hot : source_color = vec3(1.0, 0.78, 0.25);
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform float speed = 0.6;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = vec2(wpos.x + wpos.z * 0.7, wpos.y) * 1.6;
	float n1 = texture(noise, uv + vec2(0.0, -TIME * speed)).r;
	float n2 = texture(noise, uv * 2.1 + vec2(TIME * 0.13, -TIME * speed * 1.7)).r;
	float f = clamp(n1 * 0.65 + n2 * 0.55 - 0.1, 0.0, 1.0);
	vec3 c = mix(deep, mid, smoothstep(0.2, 0.55, f));
	c = mix(c, hot, smoothstep(0.62, 0.9, f));
	ALBEDO = c;
}
