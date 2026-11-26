shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// The tamer's body (HeroModel): the hero's own painted texture, with his shirt
// (its strong blue) turned to the player's colour so co-op players stand
// apart. Only the hue changes: the shirt keeps its shading, folds and buttons.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 shirt_color : source_color = vec3(0.25, 0.5, 0.95);
uniform float roughness = 0.85;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 lin = texture(albedo_tex, UV).rgb;
	// Judge the paint as it looks (sRGB): the shirt is a well saturated blue
	// (hue about 215 degrees); the jeans' blue-grey is far less saturated.
	vec3 hsv = rgb2hsv(pow(lin, vec3(1.0 / 2.2)));
	float blue = 1.0 - smoothstep(0.07, 0.11, abs(hsv.x - 0.6));
	float shirt = blue * smoothstep(0.38, 0.5, hsv.y) * smoothstep(0.08, 0.16, hsv.z);
	float hue = rgb2hsv(shirt_color).x;
	// Yellow only reads as yellow when it's light (a darker one looks olive).
	float yellow = 1.0 - smoothstep(0.05, 0.12, abs(hue - 0.13));
	vec3 turned = pow(hsv2rgb(vec3(hue, hsv.y * mix(1.0, 0.92, yellow), min(hsv.z * mix(1.0, 1.7, yellow), 1.0))), vec3(2.2));
	ALBEDO = mix(lin, turned, shirt);
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
}
