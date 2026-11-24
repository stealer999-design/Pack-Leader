extends SceneTree
## Bakes a lighter copy of a heavy model (a .glb) with Godot's own mesh
## simplifier: every mesh's level of detail nearest `target` triangles (in
## total, shared out by size) is kept, its unused vertices dropped, and the
## model saved as a scene (.scn) with its materials and textures.
##   godot --headless -s scripts/tools/simplify_model.gd -- <in.glb> <out.scn> <target triangles>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0]
	var dst: String = args[1]
	var target := int(args[2])
	var scene := (load(src) as PackedScene).instantiate() as Node3D
	var parts := scene.find_children("*", "MeshInstance3D", true, false)
	var total := 0
	for m in parts:
		for s in (m as MeshInstance3D).mesh.get_surface_count():
			total += (m as MeshInstance3D).mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
	var share := float(target) / total
	var out := Node3D.new()
	out.name = scene.name
	var kept := 0
	for m in parts:
		var part := m as MeshInstance3D
		var t := Transform3D()
		var up: Node = part
		while up != scene and up != null:
			if up is Node3D:
				t = (up as Node3D).transform * t
			up = up.get_parent()
		var mesh := ArrayMesh.new()
		for s in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(s)
			var im := ImporterMesh.new()
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
			im.generate_lods(25.0, 60.0, [])
			var want := int(arrays[Mesh.ARRAY_INDEX].size() / 3 * share)
			var best: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for l in im.get_surface_lod_count(0):
				var idx := im.get_surface_lod_indices(0, l)
				if absi(idx.size() / 3 - want) < absi(best.size() / 3 - want):
					best = idx
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _compact(arrays, best))
			var mat := part.get_active_material(s)
			if mat:
				mesh.surface_set_material(s, mat)
			kept += best.size() / 3
		var copy := MeshInstance3D.new()
		copy.name = part.name
		copy.mesh = mesh
		copy.transform = t
		out.add_child(copy)
		copy.owner = out
	var packed := PackedScene.new()
	packed.pack(out)
	print("triangles ", total, " -> ", kept, "  save ", ResourceSaver.save(packed, dst))
	quit()


## The arrays with only the vertices `indices` use, renumbered.
func _compact(arrays: Array, indices: PackedInt32Array) -> Array:
	var remap := {}
	var order := PackedInt32Array()
	var new_idx := PackedInt32Array()
	for i in indices:
		if not remap.has(i):
			remap[i] = order.size()
			order.append(i)
		new_idx.append(remap[i])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for k in Mesh.ARRAY_MAX:
		var a = arrays[k]
		if a == null or k == Mesh.ARRAY_INDEX:
			continue
		var per := 1
		if k == Mesh.ARRAY_TANGENT:
			per = 4
		var fresh = a.duplicate()
		fresh.resize(order.size() * per)
		for j in order.size():
			for c in per:
				fresh[j * per + c] = a[order[j] * per + c]
		out[k] = fresh
	out[Mesh.ARRAY_INDEX] = new_idx
	return out
