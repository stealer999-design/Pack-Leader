class_name Act2Boss
extends Rival
## The bosses of Act 2's desert, volcano and ice areas, one script with three
## variants (set by the spawn function from the biome's "boss"):
## - the Sand Pharaoh: Curse of the Sands (a warning circle, then damage and
##   blindness) and mummies and scorpions rising from the sand;
## - the Magma Colossus: Eruption (a warning circle, then damage and burning)
##   and fire imps called out of the lava;
## - Sunmane, the Desert Lion: Pounce (a warning circle, then he leaps onto
##   it: damage and a stun) and sand scorpions skittering out at his roar;
## - Dom, a giant orange house cat: by turns, Pounce and Swipe (a small
##   warning circle; he springs onto it, claws everything there and springs
##   back) and Hairball (a warning circle, then a pool of green vomit that
##   hurts anyone standing in it for a while);
## - Koleko, a huge fire dog: Lava Spit (a warning circle, then a burst of
##   fire that burns and leaves the ground ablaze) and fire imps;
## - Pye the Parrot: Feather Flurry (a warning circle, then a storm of
##   feathers: damage and a slow), a big grey parrot with a red tail,, wraiths and a yeti from the blizzard, and
##   he chatters in speech bubbles ("whatcha doin?", "Honk Honk");
## - the Yeti King: Ice Slam (a warning circle, then damage and a freeze) and
##   frost wraiths summoned out of the blizzard.
## Each casts its special every few seconds at a player or pet, and summons its
## monsters at 66% and 33% health.

const VARIANTS := {
	"pharaoh": {
		"title": "Sand Pharaoh", "objective": "the Sand Pharaoh", "color": Color(0.88, 0.75, 0.42),
		"special": "Curse of the Sands", "effect": "blind", "fx": Color(0.95, 0.8, 0.4),
		"summons": [47, 48, 48], "summon_text": "The Sand Pharaoh raises his servants from the sand!",
		"challenge": "The Sand Pharaoh wakes from his tomb!",
	},
	"lion": {
		"title": "Sunmane", "objective": "Sunmane the Desert Lion", "color": Color(0.78, 0.52, 0.24),
		"special": "Pounce", "effect": "pounce", "fx": Color(0.95, 0.75, 0.35),
		"summons": [48, 48, 47], "summon_text": "Sunmane roars, and the desert answers!",
		"challenge": "Sunmane the Desert Lion roars!",
	},
	"cat": {
		"title": "Dom", "objective": "Dom the House Cat", "color": Color(0.98, 0.42, 0.04),
		"special": "Pounce and Swipe", "effect": "swipe", "fx": Color(1.0, 0.75, 0.4),
		"summons": [48, 48, 47], "summon_text": "Dom hisses, and the desert answers!",
		"challenge": "Dom the House Cat stretches, yawns... and pounces!",
	},
	"firedog": {
		"title": "Koleko", "objective": "Koleko the Fire Dog", "color": Color(0.17, 0.13, 0.12),
		"special": "Lava Spit", "effect": "blaze", "fx": Color(1.0, 0.5, 0.12),
		"summons": [49, 49, 49], "summon_text": "Koleko howls, and fire imps leap from the flames!",
		"challenge": "Koleko the Fire Dog bares his burning fangs!",
	},
	"parrot": {
		"title": "Pye", "objective": "Pye the Parrot", "color": Color(0.36, 0.37, 0.4),
		"special": "Feather Flurry", "effect": "flurry", "fx": Color(1.0, 0.85, 0.3),
		"summons": [51, 51, 52], "summon_text": "Pye squawks, and the blizzard brings wraiths!",
		"challenge": "Pye the Parrot swoops down!",
		"phrases": ["whatcha doin?", "Honk Honk"],
	},
	"colossus": {
		"title": "Magma Colossus", "objective": "the Magma Colossus", "color": Color(0.16, 0.13, 0.13),
		"special": "Eruption", "effect": "burn", "fx": Color(1.0, 0.45, 0.1),
		"summons": [49, 49, 50], "summon_text": "The Magma Colossus calls its children out of the lava!",
		"challenge": "The Magma Colossus rises from the caldera!",
	},
	"yeti": {
		"title": "Yeti King", "objective": "the Yeti King", "color": Color(0.9, 0.93, 0.98),
		"special": "Ice Slam", "effect": "freeze", "fx": Color(0.6, 0.9, 1.0),
		"summons": [51, 51, 52], "summon_text": "The Yeti King howls, and the blizzard brings wraiths!",
		"challenge": "The Yeti King roars!",
	},
}

@export var special_interval := 4.5
@export var special_radius := 3.4
@export var special_warning := 1.1

## Set by the spawn function before entering the tree.
var variant := "pharaoh":
	set(v):
		variant = v if VARIANTS.has(v) else "pharaoh"
		color = VARIANTS[variant].color

var _special_timer := 3.0
var _vomit_next := false  ## Dom: alternates Pounce and Swipe with Hairball.
var _leaping := false
var _chatter_timer := 1.5
var _last_phrase := -1
var _bubble: Node3D
var _summon_thresholds: Array[float] = [0.66, 0.33]


func _data() -> Dictionary:
	return VARIANTS[variant]


func _build_model() -> Dictionary:
	match variant:
		"colossus":
			return BossModels.magma_colossus(model, _material)
		"yeti":
			return BossModels.yeti_king(model, _material)
		"lion":
			return BossModels.desert_lion(model, _material)
		"firedog":
			return BossModels.fire_dog(model, _material)
		"parrot":
			return BossModels.parrot(model, _material)
		"cat":
			return BossModels.house_cat(model, _material)
	return BossModels.sand_pharaoh(model, _material)


func title() -> String:
	return _data().title


func objective_name() -> String:
	return _data().objective


func radius() -> float:
	return 1.0


func attack_damage() -> float:
	return 12.0 + 3.0 * (level_number - 1)


func _max_health() -> float:
	return 600.0 + 100.0 * (level_number - 1)


func _challenge_text() -> String:
	return _data().challenge


func _boss_tick(delta: float) -> void:
	_tick_chatter(delta)
	_special_timer -= delta
	if _special_timer <= 0.0:
		_special_timer = special_interval
		_cast_special()
	if not _summon_thresholds.is_empty() and health.fraction() <= _summon_thresholds[0]:
		_summon_thresholds.pop_front()
		_summon()


func _cast_special() -> void:
	var victims := world.enemies_near(self, home, leash_range + 6.0)
	if victims.is_empty():
		return
	if variant == "cat":
		_cat_special(victims)
		return
	var spot: Vector3 = victims.pick_random().global_position
	world.play_telegraph.rpc(spot, special_radius, special_warning)
	if variant == "lion":  # crouches, then springs to land as the warning runs out
		var leap := create_tween()
		leap.tween_interval(special_warning * 0.55)
		var to := world.clamp_to_level(spot)
		to.y = global_position.y
		leap.tween_property(self, "global_position", to, special_warning * 0.45).set_trans(Tween.TRANS_QUAD)
	get_tree().create_timer(special_warning).timeout.connect(func() -> void:
		if not is_instance_valid(self) or health.is_dead():
			return
		var data := _data()
		for enemy in world.enemies_near(self, spot, special_radius):
			enemy.receive_damage(outgoing(attack_damage() * 1.4), self)
			match data.effect:
				"blind":
					if enemy.has_method("blind"):
						enemy.blind(4.0)
				"burn":
					enemy.health.add_venom(outgoing(attack_damage() * 0.3), 4.0, outgoing(attack_damage() * 0.3))
				"blaze":
					enemy.health.add_venom(outgoing(attack_damage() * 0.3), 4.0, outgoing(attack_damage() * 0.3))
				"flurry":
					if enemy.has_method("slow"):
						enemy.slow(2.0, 0.4)
				"pounce":
					if enemy.has_method("stun"):
						enemy.stun(1.0)  # pets are knocked flat
					elif enemy.has_method("slow"):
						enemy.slow(1.2, 0.3)  # tamers stagger
				"freeze":
					if enemy.has_method("slow"):
						enemy.slow(1.5, 0.0)
		world.play_burst.rpc(spot, data.fx, special_radius)
		if data.effect == "blaze":  # the ground stays ablaze for a few seconds
			world.add_zone(self, spot, special_radius, 3.0, outgoing(attack_damage() * 0.35), data.fx))


func _summon() -> void:
	var data := _data()
	world.announce.rpc(data.summon_text, data.fx.lightened(0.2))
	if _parts.has("anim") and _parts.anims.has("summon"):  # e.g. Dom arches his back and hisses
		_taunt_left = 1.0
		_special_anim.rpc("summon")
	var count: int = data.summons.size()
	for i in count:
		var offset := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / count + randf() * 0.5) * 3.5
		var spot := world.clamp_to_level(global_position + offset)
		world.play_burst.rpc(spot, data.fx, 1.2)
		var risen := world.creature_spawner.spawn({
			"species": data.summons[i], "level": World.area_levels(level_number).x + 2, "pos": spot,
		}) as Creature
		risen.target = target


# --- Chatter (bosses with "phrases") ---------------------------------------------

## Server: now and then, says one of its phrases in a speech bubble.
func _tick_chatter(delta: float) -> void:
	var phrases: Array = _data().get("phrases", [])
	if phrases.is_empty():
		return
	_chatter_timer -= delta
	if _chatter_timer > 0.0:
		return
	_chatter_timer = randf_range(5.0, 9.0)
	_last_phrase = (_last_phrase + 1 + randi() % maxi(phrases.size() - 1, 1)) % phrases.size()  # never the same twice running
	say.rpc(phrases[_last_phrase])


## A speech bubble over its head for a few seconds (every peer).
@rpc("authority", "call_local", "reliable")
func say(text: String) -> void:
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = Node3D.new()
	_bubble.position = Vector3(2.0, -1.0, 0)  # beside his head
	overhead.add_child(_bubble)
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.012
	label.modulate = Color(0.08, 0.08, 0.1)
	label.outline_size = 0
	label.position.z = 0.02
	label.no_depth_test = true
	label.render_priority = 2
	_bubble.add_child(label)
	var width := text.length() * 40 * 0.012 * 0.55 + 0.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 1
	var back := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, 0.8)
	back.mesh = quad
	back.material_override = mat
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble.add_child(back)
	var tail := MeshInstance3D.new()  # the little point down to the speaker
	var point := PrismMesh.new()
	point.size = Vector3(0.4, 0.35, 0.01)
	tail.mesh = point
	tail.material_override = mat
	tail.rotation_degrees.z = 210  # pointing down-left, at his beak
	tail.position = Vector3(-width * 0.3, -0.55, 0)
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble.add_child(tail)
	var fading := _bubble
	fading.scale = Vector3.ONE * 0.3
	var tween := fading.create_tween()
	tween.tween_property(fading, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.8)
	tween.tween_callback(fading.queue_free)


# --- Dom the House Cat ------------------------------------------------------------

const SWIPE_RADIUS := 2.2
const SWIPE_WARNING := 0.7
const VOMIT_RADIUS := 3.0
const VOMIT_TIME := 7.0


## By turns: spring forward, claw and spring back; or be sick on the ground.
func _cat_special(victims: Array) -> void:
	var victim: Node3D = target if target in victims else victims.pick_random()
	var spot := victim.global_position
	_vomit_next = not _vomit_next
	if not _vomit_next:
		_hairball(spot)
		return
	var start := global_position
	var land := world.clamp_to_level(spot + (start - spot).normalized() * 0.8)
	land.y = start.y
	world.play_telegraph.rpc(spot, SWIPE_RADIUS, SWIPE_WARNING)
	_special_anim.rpc("pounce")  # a rigged Dom crouches, wiggles and springs (then swipes on landing)
	var facing := spot - start
	model.rotation.y = atan2(-facing.x, -facing.z)  # eyes on the prey, all the way there and back
	_leaping = true
	var leap := create_tween()
	leap.tween_interval(SWIPE_WARNING * 0.6)  # crouch, wiggle...
	leap.tween_property(self, "global_position", land, SWIPE_WARNING * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	leap.tween_callback(func() -> void:
		if health.is_dead():
			return
		_swing.rpc()
		for enemy in world.enemies_near(self, spot, SWIPE_RADIUS):
			enemy.receive_damage(outgoing(attack_damage() * 1.5), self)
		world.play_burst.rpc(spot, _data().fx, SWIPE_RADIUS))
	leap.tween_interval(0.25)
	var back := world.clamp_to_level(start)
	back.y = start.y
	leap.tween_property(self, "global_position", back, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	leap.tween_callback(func() -> void: _leaping = false)


## Hairball: a warning circle, then a pool of green vomit that hurts whoever
## stands in it for VOMIT_TIME seconds.
func _hairball(spot: Vector3) -> void:
	world.announce.rpc("Dom coughs up a hairball!", Color(0.6, 0.95, 0.4))
	world.play_telegraph.rpc(spot, VOMIT_RADIUS, special_warning)
	if _parts.has("anim"):  # a rigged Dom stops, hunches and retches it up
		_taunt_left = special_warning
		_special_anim.rpc("retch")
	else:
		_swing.rpc()
	get_tree().create_timer(special_warning).timeout.connect(func() -> void:
		if not is_instance_valid(self) or health.is_dead():
			return
		world.play_burst.rpc(spot, Color(0.45, 0.85, 0.2), VOMIT_RADIUS * 0.6)
		world.add_zone(self, spot, VOMIT_RADIUS, VOMIT_TIME, outgoing(attack_damage() * 0.45), Color(0.35, 0.85, 0.15)))


func _is_busy() -> bool:
	return _leaping or super()
