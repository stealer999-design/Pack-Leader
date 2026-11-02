class_name SoundFX
## The game's sound effects, synthesised in code when first used (no audio
## files): each is a short mono 16-bit sample, cached, and played positionally
## in the world with SoundFX.play(...).
##
##   "hit"        a pet's melee bite or swipe: a short thump and swish
##   "zap"        a wizard's magic bolt: a quick falling "pew"
##   "twang"      an archer's arrow: a plucked bowstring
##   "spell"      a wizard ability: a rising shimmering whoosh
##   "holy"       a paladin ability: a bright bell chord
##   "volley"     an archer ability: a hard twang and a rush of air
##   "venom"      a venomancer ability: a bubbling hiss
##   "power"      any other ability: a rising chord
##   "bing"       an item dropping
##   "bing_rare"  a legendary dropping: two notes, higher
##   "step"       a footstep: a soft, low scuff

const RATE := 22050
## How loud each sound is, in dB.
const VOLUME := {
	"hit": -9.0, "zap": -12.0, "twang": -9.0, "spell": -3.0, "holy": -4.0, "volley": -3.0,
	"venom": -3.0, "power": -4.0, "bing": -6.0, "bing_rare": -4.0, "step": -15.0,
}

static var _cache := {}
static var _rng := RandomNumberGenerator.new()


## Plays `sound_name` at `at` (in the world `context` belongs to), with the
## pitch varied a little each time so repeats don't sound mechanical.
static func play(context: Node, sound_name: String, at: Vector3, pitch_spread := 0.08, volume_offset := 0.0) -> void:
	if context == null or not context.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream(sound_name)
	player.volume_db = VOLUME.get(sound_name, -6.0) + volume_offset
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_spread, pitch_spread)
	# The camera hangs well above the action: keep sounds audible from up there.
	player.unit_size = 14.0
	player.max_distance = 80.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	context.get_tree().current_scene.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


static func stream(sound_name: String) -> AudioStreamWAV:
	if not _cache.has(sound_name):
		_cache[sound_name] = _to_wav(_synth(sound_name))
	return _cache[sound_name]


static func _synth(sound_name: String) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = sound_name.hash()
	match sound_name:
		"hit":
			var out := _buffer(0.11)
			var lp := 0.0
			for i in out.size():
				var t := float(i) / RATE
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.35)
				var thump := sin(TAU * lerpf(140.0, 70.0, t / 0.11) * t) * exp(-t * 45.0)
				out[i] = (lp * 0.9 * exp(-t * 38.0) + thump * 0.8)
			return out
		"zap":
			var out := _buffer(0.13)
			var phase := 0.0
			for i in out.size():
				var t := float(i) / RATE
				phase += TAU * lerpf(1100.0, 380.0, pow(t / 0.13, 0.6)) / RATE
				out[i] = (sin(phase) * 0.7 + signf(sin(phase)) * 0.15) * exp(-t * 22.0)
			return out
		"twang":
			return _pluck(rng, 196.0, 0.22, 0.996)
		"spell":
			var out := _buffer(0.5)
			var phase_a := 0.0
			var phase_b := 0.0
			var lp := 0.0
			for i in out.size():
				var t := float(i) / RATE
				var f := lerpf(280.0, 1250.0, t / 0.5)
				phase_a += TAU * f / RATE
				phase_b += TAU * f * 1.503 / RATE
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.15)
				var env := minf(t / 0.05, 1.0) * exp(-t * 4.5)
				out[i] = (sin(phase_a) * 0.45 + sin(phase_b) * 0.25 * (0.5 + 0.5 * sin(TAU * 18.0 * t)) + lp * 0.5) * env
			return out
		"holy":
			var out := _buffer(0.85)
			for i in out.size():
				var t := float(i) / RATE
				var v := 0.0
				for note in [[523.25, 0.4], [659.25, 0.3], [783.99, 0.3], [1046.5, 0.18], [2093.0, 0.06]]:
					v += sin(TAU * note[0] * t) * note[1]
				out[i] = v * minf(t / 0.008, 1.0) * exp(-t * 4.0)
			return out
		"volley":
			var string := _pluck(rng, 165.0, 0.4, 0.994)
			var out := _buffer(0.4)
			var lp := 0.0
			for i in out.size():
				var t := float(i) / RATE
				lp = lerpf(lp, rng.randf_range(-1, 1), lerpf(0.05, 0.4, t / 0.4))  # a rush of air, brightening
				out[i] = string[i] * 0.9 + lp * 0.55 * sin(PI * t / 0.4)
			return out
		"venom":
			var out := _buffer(0.55)
			var lp := 0.0
			var bubble_t := 0.0
			var bubble_f := 300.0
			for i in out.size():
				var t := float(i) / RATE
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.5)
				bubble_t += 1.0 / RATE
				if bubble_t > 0.06 and rng.randf() < 0.002:
					bubble_t = 0.0
					bubble_f = rng.randf_range(220.0, 520.0)
				var bubble := sin(TAU * bubble_f * (1.0 + bubble_t * 6.0) * bubble_t) * exp(-bubble_t * 40.0)
				var env := minf(t / 0.03, 1.0) * exp(-t * 3.5)
				out[i] = (lp * 0.35 + bubble * 0.7) * env
			return out
		"power":
			var out := _buffer(0.45)
			for i in out.size():
				var t := float(i) / RATE
				var rise := 1.0 + t * 0.8
				var v := sin(TAU * 330.0 * rise * t) * 0.4 + sin(TAU * 495.0 * rise * t) * 0.3 + sin(TAU * 660.0 * rise * t) * 0.2
				out[i] = v * minf(t / 0.02, 1.0) * exp(-t * 5.0)
			return out
		"bing":
			return _bell([[1318.5, 0.5], [2637.0, 0.18], [3955.5, 0.06]], 0.6, 0.0)
		"bing_rare":
			var out := _bell([[1318.5, 0.45], [2637.0, 0.15]], 0.9, 0.0)
			var second := _bell([[1760.0, 0.45], [3520.0, 0.15]], 0.8, 0.12)
			for i in out.size():
				out[i] += second[i] if i < second.size() else 0.0
			return out
		"step":
			var out := _buffer(0.08)
			var lp := 0.0
			for i in out.size():
				var t := float(i) / RATE
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.12)
				out[i] = (lp * 1.6 + sin(TAU * 90.0 * t) * 0.35) * minf(t / 0.004, 1.0) * exp(-t * 55.0)
			return out
	return _buffer(0.05)


static func _buffer(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


## A plucked string (Karplus-Strong): a burst of noise fed round a short delay
## line, softening as it rings.
static func _pluck(rng: RandomNumberGenerator, frequency: float, seconds: float, damping: float) -> PackedFloat32Array:
	var out := _buffer(seconds)
	var period := int(RATE / frequency)
	var line := PackedFloat32Array()
	line.resize(period)
	for i in period:
		line[i] = rng.randf_range(-1, 1)
	for i in out.size():
		var k := i % period
		var next := line[(k + 1) % period]
		out[i] = line[k]
		line[k] = (line[k] + next) * 0.5 * damping
	return out


## A struck bell: sine partials with a sharp attack and a ringing decay,
## starting `delay` seconds in.
static func _bell(partials: Array, seconds: float, delay: float) -> PackedFloat32Array:
	var out := _buffer(seconds + delay)
	for i in out.size():
		var t := float(i) / RATE - delay
		if t < 0.0:
			continue
		var v := 0.0
		for p in partials:
			v += sin(TAU * p[0] * t) * p[1] * exp(-t * (5.0 + p[0] / 600.0))
		out[i] = v * minf(t / 0.003, 1.0)
	return out


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.001
	for v in samples:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / peak * 0.9, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
