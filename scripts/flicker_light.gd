class_name FlickerLight
extends OmniLight3D
## A torch's light: its brightness wavers like a flame (two slow waves and a
## quick jitter, each torch out of step with the others).

var base_energy := 1.0
var _phase := 0.0


func _ready() -> void:
	base_energy = light_energy
	_phase = randf() * 100.0


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 + _phase
	light_energy = base_energy * (0.86 + 0.08 * sin(t * 7.3) + 0.05 * sin(t * 13.1 + 1.3) + 0.04 * sin(t * 23.7))
