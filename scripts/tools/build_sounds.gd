extends SceneTree
## Writes every sound effect (see SoundFX) to sounds/<name>.wav, so the game
## loads ready-made files instead of synthesising them at startup. Run after
## changing a sound, then let the editor (or --import) re-import them:
##   godot --headless --path . -s res://scripts/tools/build_sounds.gd
##   godot --headless --path . --import


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(SoundFX.FOLDER)
	for sound_name in SoundFX.VOLUME:
		var path := "%s/%s.wav" % [SoundFX.FOLDER, sound_name]
		print(path, ": ", error_string(SoundFX.synthesize(sound_name).save_to_wav(path)))
	quit()
