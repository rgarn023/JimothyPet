extends Node
## Night ambience + raccoon SFX for Jimothy (runtime WAV load, no editor import required).

const AUDIO_DIR := "res://audio/"
const FILES := {
	"night": "night_ambience.wav",
	"chitter": "chitter.wav",
	"chirp": "chirp.wav",
	"grumble": "grumble.wav",
	"rustle": "rustle.wav",
	"crunch": "crunch.wav",
	"ascend": "ascend.wav",
	"hoot": "hoot.wav",
}

var enabled: bool = true
var _streams: Dictionary = {}
var _ambience: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_i: int = 0
var _accent_cd: float = 4.0
var _bootstrapped: bool = false


func _ready() -> void:
	_load_streams()
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "Ambience"
	_ambience.volume_db = -10.0
	_ambience.bus = "Master"
	add_child(_ambience)
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)

	if PetState:
		enabled = not bool(PetState.sound_muted)
		PetState.anim_impulse.connect(_on_anim)
		PetState.speech.connect(_on_speech)
		PetState.stage_changed.connect(_on_stage)
		PetState.state_changed.connect(_on_state)

	_apply_ambience()


func _process(delta: float) -> void:
	if not enabled:
		return
	_accent_cd -= delta
	if _accent_cd > 0.0:
		return
	_accent_cd = randf_range(6.0, 14.0)
	if PetState == null:
		return
	if PetState.stage == "bush" and PetState.alive:
		play("rustle", -4.0)
	elif PetState.alive and not PetState.ascending and randf() < 0.45:
		play("hoot", -8.0)
	elif PetState.alive and not PetState.ascending and randf() < 0.35:
		play("chitter", -10.0)


func set_enabled(on: bool) -> void:
	enabled = on
	if PetState:
		PetState.sound_muted = not on
		PetState.save_game()
	_apply_ambience()
	if on:
		# Soft confirm chirp when turning sound back on.
		play("chirp", -6.0)


func toggle() -> bool:
	set_enabled(not enabled)
	return enabled


func play(kind: String, volume_db: float = 0.0) -> void:
	if not enabled:
		return
	if not _streams.has(kind):
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx_players.size()
	p.stop()
	p.stream = _streams[kind]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.94, 1.06)
	p.play()


func _apply_ambience() -> void:
	if _ambience == null:
		return
	if enabled and _streams.has("night"):
		if _ambience.stream != _streams["night"]:
			_ambience.stream = _streams["night"]
		if not _ambience.playing:
			_ambience.play()
	else:
		_ambience.stop()


func _on_anim(kind: String) -> void:
	match kind:
		"eat":
			play("crunch", -2.0)
			play("chitter", -6.0)
		"refuse", "stubborn":
			play("grumble", -2.0)
		"scold":
			play("chitter", -3.0)
		"pop", "stretch":
			play("rustle", -2.0)
			play("chirp", -4.0)
		"ascend":
			play("ascend", -1.0)
		"jump":
			if randf() < 0.4:
				play("chirp", -10.0)
		_:
			pass


func _on_speech(_text: String) -> void:
	# Action anims already carry the main raccoon SFX; keep speech mostly quiet.
	pass


func _on_stage(stage: String) -> void:
	match stage:
		"baby":
			play("rustle", -1.0)
			play("chirp", -2.0)
		"young", "teen", "adult":
			play("chirp", -3.0)
			play("chitter", -6.0)
		"bush":
			play("rustle", -2.0)


func _on_state() -> void:
	if PetState == null:
		return
	var want := not PetState.sound_muted
	if want != enabled:
		enabled = want
		_apply_ambience()


func _load_streams() -> void:
	for key in FILES.keys():
		var path: String = AUDIO_DIR + str(FILES[key])
		var stream := _load_wav(path, key == "night")
		if stream:
			_streams[key] = stream


func _load_wav(path: String, loop: bool = false) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		push_warning("Missing audio: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var bytes := file.get_buffer(file.get_length())
	if bytes.size() < 44:
		return null
	# RIFF/WAVE little-endian parse
	if _ascii(bytes, 0, 4) != "RIFF":
		return null
	if _ascii(bytes, 8, 4) != "WAVE":
		return null

	var offset := 12
	var channels := 1
	var sample_rate := 22050
	var bits := 16
	var data := PackedByteArray()
	while offset + 8 <= bytes.size():
		var chunk_id := _ascii(bytes, offset, 4)
		var chunk_size := _u32(bytes, offset + 4)
		var chunk_start := offset + 8
		var chunk_end := chunk_start + chunk_size
		if chunk_end > bytes.size():
			break
		if chunk_id == "fmt ":
			channels = _u16(bytes, chunk_start + 2)
			sample_rate = _u32(bytes, chunk_start + 4)
			bits = _u16(bytes, chunk_start + 14)
		elif chunk_id == "data":
			data = bytes.slice(chunk_start, chunk_end)
			break
		offset = chunk_end + (chunk_size % 2) # word align

	if data.is_empty() or bits != 16:
		push_warning("Unsupported WAV: %s" % path)
		return null

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = channels > 1
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(data.size() / (2 * channels))
	return stream


func _ascii(bytes: PackedByteArray, from: int, length: int) -> String:
	var s := ""
	for i in length:
		s += String.chr(bytes[from + i])
	return s


func _u16(bytes: PackedByteArray, i: int) -> int:
	return bytes[i] | (bytes[i + 1] << 8)


func _u32(bytes: PackedByteArray, i: int) -> int:
	return bytes[i] | (bytes[i + 1] << 8) | (bytes[i + 2] << 16) | (bytes[i + 3] << 24)
