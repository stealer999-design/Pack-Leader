extends SceneTree
## Renders the tamer's clothing icons from the clothes themselves
## (textures/icons/gear/<kind>_<level>.png, for ItemIcons): each garment
## (HeroModel.GEAR, in its ItemDB.OUTFIT_COLORS) as it hangs on the hero
## standing (his body hidden; for a jacket his arms a little out), seen from
## the front three-quarter and a little above, lit like a product shot on a
## clear background, with a dark outline like the drawn icons'. And the shop
## bats (BatModels, shop_bat_<tier>.png), lying across the picture.
## Needs a display (it renders):
##   godot --path . --rendering-driver opengl3 -s res://scripts/tools/gear_icons.gd

const OUT := "res://textures/icons/gear/"
const RENDER := 384  ## Rendered this big, outlined, then shrunk to SIZE.
const SIZE := 128
const OUTLINE := 5  ## (pixels at RENDER) the dark outline's width.
const INK := Color(0.08, 0.08, 0.08)
## Looking at him from his front, a little to his right and above (he faces -Z).
const VIEW := Vector3(0.55, 0.42, -1.0)
## A jacket's arms raised this far from his sides (radians), so the sleeves show.
const ARMS_OUT := 0.38

var viewport: SubViewport
var camera: Camera3D
var hero: HeroModel


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	viewport = SubViewport.new()
	viewport.size = Vector2i(RENDER, RENDER)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.64, 0.7)
	env.environment.ambient_light_energy = 0.75
	viewport.add_child(env)
	var key := DirectionalLight3D.new()  # from above, front and to the left
	key.light_energy = 1.25
	key.rotation = Vector3(-0.75, -0.5, 0.0)
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()  # a soft light from the other side
	fill.light_energy = 0.4
	fill.rotation = Vector3(-0.3, 2.4, 0.0)
	viewport.add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	camera.current = true
	var mat := StandardMaterial3D.new()
	hero = HeroModel.new()
	viewport.add_child(hero)
	hero.build(mat)
	hero._body.visible = false
	await _frames(3)
	hero._tree.active = false  # hold the standing pose (no breathing)
	for kind: String in HeroModel.OUTFIT:
		for level in range(1, (HeroModel.GEAR[kind] as Array).size() + 1):
			await _icon(kind, level)
	hero.visible = false
	for tier in BatModels.BATS.size():
		await _bat_icon(tier)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _icon(kind: String, level: int) -> void:
	var outfit := PackedInt32Array([0, 0, 0, 0])
	outfit[HeroModel.OUTFIT.find(kind)] = level
	hero.set_outfit(outfit)
	_arms(ARMS_OUT if kind == "jacket" else 0.0)
	await _frames(2)
	var part: MeshInstance3D = hero._gear[kind]
	_frame(_posed_bounds(part), VIEW)
	await _save(OUT + "%s_%d.png" % [kind, level])


## A shop bat, lying across the picture: the handle low on the left, the end
## up on the right, turned a little towards us.
func _bat_icon(tier: int) -> void:
	var bat := BatModels.build(tier)
	viewport.add_child(bat)
	bat.basis = Basis.looking_at(Vector3(1.0, 1.0, 0.35).normalized(), Vector3(0, 0, 1))
	await _frames(2)
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in bat.find_children("*", "MeshInstance3D", true, false):
		for i in 8:
			var at := mesh.global_transform * mesh.get_aabb().get_endpoint(i)
			box = AABB(at, Vector3.ZERO) if first else box.expand(at)
			first = false
	_frame(box, Vector3(0.0, 0.0, 1.0))
	await _save(OUT + "shop_bat_%d.png" % tier)
	bat.queue_free()


## Renders the picture, outlines it, shrinks it to SIZE and saves it.
func _save(path: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var icon := _outlined(image)
	icon.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	print("gear_icons: %s %s" % [path, error_string(icon.save_png(path))])


## Raises the arms out from his sides by `angle` (from the standing pose).
func _arms(angle: float) -> void:
	var sk := hero._skeleton
	for side in [["Left", 1.0], ["Right", -1.0]]:
		var b := sk.find_bone("mixamorig_%sArm" % side[0])
		var rest: Quaternion = sk.get_meta("arm_%s" % side[0], sk.get_bone_pose_rotation(b))
		sk.set_meta("arm_%s" % side[0], rest)
		sk.set_bone_pose_rotation(b, rest)
		sk.force_update_all_bone_transforms()
		var parent := sk.get_bone_global_pose(sk.get_bone_parent(b)).basis.orthonormalized()
		var now := sk.get_bone_global_pose(b).basis.orthonormalized()
		# He faces +Z in his own space; out from his side is about that axis.
		var raised := Basis(Vector3.BACK, angle * float(side[1])) * now
		sk.set_bone_pose_rotation(b, (parent.inverse() * raised).get_rotation_quaternion())
	sk.force_update_all_bone_transforms()


## A skinned mesh's bounds as posed (world space).
func _posed_bounds(part: MeshInstance3D) -> AABB:
	var sk := hero._skeleton
	var box := AABB()
	var first := true
	for s in part.mesh.get_surface_count():
		var arrays := part.mesh.surface_get_arrays(s)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for v in range(0, points.size(), 2):
			var at := Vector3.ZERO
			for j in 4:
				var w := weights[v * 4 + j]
				if w > 0.0:
					var bind := bones[v * 4 + j]
					var bone := sk.find_bone(part.skin.get_bind_name(bind))
					at += (sk.get_bone_global_pose(bone) * part.skin.get_bind_pose(bind) * points[v]) * w
			at = sk.global_transform * at
			box = AABB(at, Vector3.ZERO) if first else box.expand(at)
			first = false
	return box


## Points the camera at `box` from `view`, filling the picture.
func _frame(box: AABB, view: Vector3) -> void:
	var center := box.get_center()
	camera.global_position = center + view.normalized() * 6.0
	camera.look_at(center)
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var half := 0.0
	for i in 8:
		var corner := box.get_endpoint(i) - center
		half = maxf(half, maxf(absf(corner.dot(right)), absf(corner.dot(up))))
	camera.size = half * 2.0 * 1.1


## The picture with a dark outline round its shape.
func _outlined(image: Image) -> Image:
	var n := image.get_width()
	var solid := PackedByteArray()
	solid.resize(n * n)
	for y in n:
		for x in n:
			solid[y * n + x] = 1 if image.get_pixel(x, y).a > 0.4 else 0
	var out := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var near := false
			for dy in range(-OUTLINE, OUTLINE + 1):
				var yy := y + dy
				if yy < 0 or yy >= n:
					continue
				for dx in range(-OUTLINE, OUTLINE + 1):
					var xx := x + dx
					if xx >= 0 and xx < n and dx * dx + dy * dy <= OUTLINE * OUTLINE and solid[yy * n + xx]:
						near = true
						break
				if near:
					break
			var c := image.get_pixel(x, y)
			if near:
				out.set_pixel(x, y, Color(INK.lerp(Color(c.r, c.g, c.b), c.a), 1.0))
	return out
