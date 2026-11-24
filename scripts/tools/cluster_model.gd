extends SceneTree
## Bakes a very light copy of a model for pieces repeated hundreds of times
## (the crypt's crown moulding): all its meshes merged (node transforms baked
## in), vertices snapped to a grid of `cells` steps across the model's longest
## side and merged, collapsed and repeated triangles dropped, flat normals
## made again. Texture coordinates are dropped: for models drawn with a
## world-mapped (triplanar) material.
##   godot --headless -s scripts/tools/cluster_model.gd -- <in.glb> <out.res> <cells>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scene := (load(args[0]) as PackedScene).instantiate() as Node3D
	var cells := int(args[2])
	var verts := PackedVector3Array()
	var tris := PackedInt32Array()
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		var part := m as MeshInstance3D
		var t := Transform3D()
		var up: Node = part
		while up != scene and up != null:
			if up is Node3D:
				t = (up as Node3D).transform * t
			up = up.get_parent()
		for s in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx = arrays[Mesh.ARRAY_INDEX]
			if idx == null:
				idx = PackedInt32Array(range(v.size()))
			var base := verts.size()
			for p in v:
				verts.append(t * p)
			for i in idx:
				tris.append(base + i)
	var box := AABB(verts[0], Vector3.ZERO)
	for p in verts:
		box = box.expand(p)
	var step := maxf(box.size.x, maxf(box.size.y, box.size.z)) / cells
	var cell_of := {}
	var sums: Array[Vector3] = []
	var counts: Array[int] = []
	var remap := PackedInt32Array()
	remap.resize(verts.size())
	for i in verts.size():
		var c := Vector3i(((verts[i] - box.position) / step).floor())
		if not cell_of.has(c):
			cell_of[c] = sums.size()
			sums.append(Vector3.ZERO)
			counts.append(0)
		var k: int = cell_of[c]
		sums[k] += verts[i]
		counts[k] += 1
		remap[i] = k
	var seen := {}
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var kept := 0
	for i in range(0, tris.size(), 3):
		var a := remap[tris[i]]
		var b := remap[tris[i + 1]]
		var c := remap[tris[i + 2]]
		if a == b or b == c or a == c:
			continue
		var key := [a, b, c]
		key.sort()
		if seen.has(key):
			continue
		seen[key] = true
		for k in [a, b, c]:
			st.add_vertex(sums[k] / counts[k])
		kept += 1
	st.generate_normals()  # unindexed: flat, so its edges stay crisp
	var mesh := st.commit()
	print("triangles ", tris.size() / 3, " -> ", kept, "  save ", ResourceSaver.save(mesh, args[1]))
	quit()
