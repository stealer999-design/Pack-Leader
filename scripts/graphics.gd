extends Node
## Autoload `Graphics`: the 3D resolution. On a big screen (4K) drawing the 3D
## scene at full size costs the graphics card four times what 1080p does, so
## the scene is drawn at fewer pixels and upscaled with AMD FSR; the menus and
## text stay sharp at the screen's own resolution. Chosen in the pause menu and
## remembered in user://settings.cfg:
##   auto (default)  3D at no more than 1440p's worth of pixels (4K: 67%)
##   full            3D at the screen's own resolution
##   performance     3D at no more than 1080p's worth of pixels (4K: 50%)
## The web build keeps its own fixed settings (project.godot's .web overrides).

const SETTINGS_PATH := "user://settings.cfg"
const MODES := ["auto", "full", "performance"]
const TARGET_PIXELS := {"auto": 2560 * 1440, "full": 0, "performance": 1920 * 1080}
const LABELS := {"auto": "Auto (up to 1440p, upscaled)", "full": "Full (native)", "performance": "Performance (up to 1080p, upscaled)"}

var mode := "auto"


func _ready() -> void:
	if OS.has_feature("web"):
		return
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		mode = settings.get_value("graphics", "resolution_3d", "auto")
		if not MODES.has(mode):
			mode = "auto"
	get_tree().root.size_changed.connect(apply)
	apply()


## Cycles to the next mode, saves it and applies it; returns its label.
func next_mode() -> String:
	mode = MODES[(MODES.find(mode) + 1) % MODES.size()]
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)  # keep the other settings (camera zoom)
	settings.set_value("graphics", "resolution_3d", mode)
	settings.save(SETTINGS_PATH)
	apply()
	return label()


func label() -> String:
	return "3D resolution: " + LABELS[mode]


## The share of the screen's resolution (on each side) the 3D scene is drawn at.
func scale_for(size: Vector2i) -> float:
	var target: int = TARGET_PIXELS[mode]
	var pixels := float(maxi(size.x * size.y, 1))
	if target <= 0 or pixels <= target:
		return 1.0
	return clampf(sqrt(target / pixels), 0.5, 1.0)


func apply() -> void:
	if OS.has_feature("web"):
		return
	var root := get_tree().root
	var scale := scale_for(root.size)
	root.scaling_3d_scale = scale
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	root.fsr_sharpness = 0.25
