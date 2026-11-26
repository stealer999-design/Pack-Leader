extends SceneTree
## Renders the pets' pictures (textures/icons/pets/<species>.png, for
## PetIcons) from the pets themselves: each species built as the game builds
## it (its Meshy model in its standing pose, or its code-built body in a
## tamer's pets' anime style), seen from the front three-quarter and a little
## above, lit like the gear icons on a clear background, with the same dark
## outline. Every species gets one (the monsters too).
## Needs a display (it renders):
##   godot --path . --rendering-driver opengl3 -s res://scripts/tools/pet_icons.gd

const OUT := "res://textures/icons/pets/"
const RENDER := 384  ## Rendered this big, outlined, then shrunk to SIZE.
const SIZE := 160
const OUTLINE := 5  ## (pixels at RENDER) the dark outline's width.
const INK := Color(0.08, 0.08, 0.08)
## Looking at it from its front, a little to one side and above (pets face -Z).
const VIEW := Vector3(0.7, 0.5, -1.0)

var viewport: SubViewport
var camera: Camera3D


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
	env.environment.ambient_light_energy = 0.8
	viewport.add_child(env)
	var key := DirectionalLight3D.new()  # from above, in front, to one side
	key.light_energy = 1.25
	key.rotation = Vector3(-0.75, 2.6, 0.0)
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()  # a soft light from the other side
	fill.light_energy = 0.4
	fill.rotation = Vector3(-0.3, -2.4, 0.0)
	viewport.add_child(fill)
	var rim := DirectionalLight3D.new()  # from behind, lighting its outline
	rim.light_energy = 0.55
	rim.rotation = Vector3(-0.5, 0.2, 0.0)
	viewport.add_child(rim)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	camera.current = true
	for index in SpeciesDB.all().size():
		await _icon(SpeciesDB.get_species(index))
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _icon(species: CreatureSpecies) -> void:
	var holder := Node3D.new()
	viewport.add_child(holder)
	var body := MeshInstance3D.new()
	holder.add_child(body)
	if PetModels.has_model(species):
		var player := PetModels.build(body, species)
		if player:  # its standing pose
			var pose := "Idle" if player.has_animation("Idle") else ("Walk" if player.has_animation("Walk") else "")
			if pose != "":
				player.play(pose)
				player.seek(minf(0.3, player.get_animation(pose).length * 0.25), true)
				player.pause()
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = species.color
		CreatureModel.build(body, species.body_type, mat, species.color, species.feature, true)
		AnimeLook.apply(body, 0.035)
	await _frames(3)
	_frame(_bounds(holder))
	var path := OUT + species.display_name.to_lower().replace(" ", "_") + ".png"
	await _save(path)
	holder.queue_free()
	await _frames(1)


## Everything drawn under `root`, as posed (world space).
func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		for p in _points(mesh):
			box = AABB(p, Vector3.ZERO) if first else box.expand(p)
			first = false
	return box


## A mesh's points as drawn: skinned by its skeleton if it has one.
func _points(mesh: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var sk: Skeleton3D = mesh.get_node_or_null(mesh.skeleton) as Skeleton3D if mesh.skin else null
	for s in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if sk == null or arrays[Mesh.ARRAY_BONES] == null:
			for v in range(0, verts.size(), 3):
				out.append(mesh.global_transform * verts[v])
			continue
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / verts.size()
		for v in range(0, verts.size(), 3):
			var at := Vector3.ZERO
			for j in per:
				var w := weights[v * per + j]
				if w > 0.0:
					var bind := bones[v * per + j]
					var bone := mesh.skin.get_bind_bone(bind)
					if bone < 0:
						bone = sk.find_bone(mesh.skin.get_bind_name(bind))
					at += (sk.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind) * verts[v]) * w
			out.append(sk.global_transform * at)
	return out


## Points the camera at `box` from VIEW, filling the picture.
func _frame(box: AABB) -> void:
	var center := box.get_center()
	camera.global_position = center + VIEW.normalized() * 8.0
	camera.look_at(center)
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var half := 0.0
	for i in 8:
		var corner := box.get_endpoint(i) - center
		half = maxf(half, maxf(absf(corner.dot(right)), absf(corner.dot(up))))
	camera.size = half * 2.0 * 1.08


## Renders the picture, outlines it, shrinks it to SIZE and saves it.
func _save(path: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var icon := _outlined(image)
	icon.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	print("pet_icons: %s %s" % [path, error_string(icon.save_png(path))])


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
