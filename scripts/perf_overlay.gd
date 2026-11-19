extends CanvasLayer
## F3: a performance overlay for tracking down slowdowns. Shows the frame rate,
## where the frame time goes and how much is being drawn, and while it's on,
## writes a line every half second (plus one for any frame slower than 33 ms)
## to perf_log.csv in the game's user folder, so a slow patch can be studied.

const LOG_PATH := "user://perf_log.csv"
const SAMPLE_EVERY := 0.5

var _label: Label
var _file: FileAccess
var _since := 0.0
var _last_us := 0
var _worst_ms := 0.0
var _start_ms := 0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(12, 190)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)
	visible = false
	set_process(false)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F3:
		_toggle()


func _toggle() -> void:
	visible = not visible
	set_process(visible)
	if visible:
		var fresh := not FileAccess.file_exists(LOG_PATH)
		_file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if not fresh else FileAccess.WRITE)
		if _file:
			_file.seek_end()
			if fresh:
				_file.store_line("time_s,kind,fps,frame_ms,worst_ms,script_ms,physics_ms,draw_calls,objects,primitives,video_mb,level,creatures,on_screen,chasing")
		_start_ms = Time.get_ticks_msec()
		_last_us = Time.get_ticks_usec()
	elif _file:
		_file.close()
		_file = null


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _last_us) / 1000.0
	_last_us = now
	_worst_ms = maxf(_worst_ms, frame_ms)
	if frame_ms > 33.0:
		_write("slow", frame_ms)
	_since += delta
	if _since < SAMPLE_EVERY:
		return
	_since = 0.0
	var line := _write("sample", frame_ms)
	var p := line.split(",")
	_label.text = "F3 performance (logging to %s)\nFPS %s   frame %s ms   worst %s ms\nscripts %s ms   physics %s ms\ndraw calls %s   objects %s   triangles %s   video %s MB\nlevel %s   creatures %s (on screen %s, chasing you %s)" % [
		ProjectSettings.globalize_path(LOG_PATH), p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9], p[10], p[11], p[12], p[13], p[14]]
	_worst_ms = 0.0


func _write(kind: String, frame_ms: float) -> String:
	var P := Performance
	var level := -1
	var creatures := 0
	var on_screen := 0
	var chasing := 0
	var world := get_tree().get_first_node_in_group("world")
	if world:
		level = world.level_number
		var cam := get_viewport().get_camera_3d()
		for c in world.creatures_root.get_children():
			creatures += 1
			if cam and cam.is_position_in_frustum(c.global_position):
				on_screen += 1
			if c is Creature and (c as Creature).is_wild() and is_instance_valid((c as Creature).target):
				chasing += 1
	var line := "%.1f,%s,%d,%.1f,%.1f,%.1f,%.1f,%d,%d,%d,%d,%d,%d,%d,%d" % [
		(Time.get_ticks_msec() - _start_ms) / 1000.0, kind, Engine.get_frames_per_second(), frame_ms, _worst_ms,
		P.get_monitor(P.TIME_PROCESS) * 1000.0, P.get_monitor(P.TIME_PHYSICS_PROCESS) * 1000.0,
		P.get_monitor(P.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), P.get_monitor(P.RENDER_TOTAL_OBJECTS_IN_FRAME),
		P.get_monitor(P.RENDER_TOTAL_PRIMITIVES_IN_FRAME), P.get_monitor(P.RENDER_VIDEO_MEM_USED) / 1048576.0,
		level, creatures, on_screen, chasing]
	if _file:
		_file.store_line(line)
		_file.flush()
	return line
