shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// The tamer's clothes (HeroModel): the item's colour, shaded by the creases,
// seams and wear of the hero's own clothes underneath (folds.png, made by
// tools/hero_gear.gd; 0.5 = no change), seen from both sides (inside a sleeve).

uniform vec3 color : source_color = vec3(0.5);
uniform sampler2D folds : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float fold_strength = 0.0;  // 0 for shapes with their own UVs (hats)
uniform float roughness = 0.85;
uniform float specular = 0.35;

void fragment() {
	float crease = texture(folds, UV).r - 0.5;
	ALBEDO = color * clamp(1.0 + crease * fold_strength, 0.35, 1.6);
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
