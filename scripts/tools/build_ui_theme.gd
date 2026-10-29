extends SceneTree
## Regenerates resources/ui_theme.tres (the project's default theme, see
## project.godot [gui] theme/custom) from UiTheme. Run after changing UiTheme:
##   godot --headless --path . -s res://scripts/tools/build_ui_theme.gd


func _init() -> void:
	var err := ResourceSaver.save(UiTheme.get_theme(), "res://resources/ui_theme.tres")
	print("Saved resources/ui_theme.tres: ", error_string(err))
	quit()
