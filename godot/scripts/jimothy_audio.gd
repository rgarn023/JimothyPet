extends Node
## Jimothy raccoon SFX (runtime WAV load). Background ambience removed.

const AUDIO_DIR := "res://audio/"
const FILES := {
	"chitter": "chitter.wav",
	"chirp": "chirp.wav",
	"grumble": "grumble.wav",
	"rustle": "rustle.wav",
	"crunch": "crunch.wav",
	"chew": "chew.wav",
	"cry": "cry.wav",
	"ascend": "ascend.wav",
}

var ambience_on: bool = false
var sfx_on: bool = true
var _streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_i: int = 0
var _accent_cd: float = 4.0
var _cry_player: AudioStreamPlayer


func _ready() -> void:
	_load_streams()
	for i in 5:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)
	_cry_player = _sfx_players[4]

	if PetState:
		ambience_on = false
		PetState.ambience_muted = true
		sfx_on = not bool(PetState.sfx_muted)
		if bool(PetState.sound_muted) and sfx_on:
			sfx_on = false
		PetState.anim_impulse.connect(_on_anim)
		PetState.speech.connect(_on_speech)
		PetState.stage_changed.connect(_on_stage)
		PetState.state_changed.connect(_on_state)


func _process(delta: float) -> void:
	if not sfx_on:
		return
	_accent_cd -= delta
	if _accent_cd > 0.0:
		return
	_accent_cd = randf_range(6.0, 14.0)
	if PetState == null:
		return
	if PetState.is_sleeping():
		return
	if PetState.stage == "bush" and PetState.alive:
		play("rustle", -4.0)
	elif PetState.alive and not PetState.ascending and randf() < 0.35:
		play("chitter", -10.0)


func set_ambience_enabled(_on: bool) -> void:
	ambience_on = false
	if PetState:
		PetState.ambience_muted = true
		PetState.sound_muted = not sfx_on
		PetState.save_game()


func set_sfx_enabled(on: bool) -> void:
	sfx_on = on
	if PetState:
		PetState.sfx_muted = not on
		PetState.sound_muted = not sfx_on
		PetState.save_game()
	if on:
		play("chitter", -8.0)
	else:
		_stop_cry()


func set_enabled(on: bool) -> void:
	set_sfx_enabled(on)
	if on:
		play("chirp", -6.0)


func toggle() -> bool:
	var next := not sfx_on
	set_enabled(next)
	return next


func play(kind: String, volume_db: float = 0.0) -> void:
	if not sfx_on:
		return
	if not _streams.has(kind):
		return
	if kind == "cry":
		_stop_cry()
		_cry_player.stop()
		_cry_player.stream = _streams[kind]
		_cry_player.volume_db = volume_db
		_cry_player.pitch_scale = randf_range(0.96, 1.04)
		_cry_player.play()
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_i]
	_sfx_i = (_sfx_i + 1) % 4
	p.stop()
	p.stream = _streams[kind]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.94, 1.06)
	p.play()


func _stop_cry() -> void:
	if _cry_player and _cry_player.playing:
		_cry_player.stop()


func _on_anim(kind: String) -> void:
	match kind:
		"eat":
			play("chew", -1.5)
			play("crunch", -6.0)
		"refuse":
			play("grumble", -2.0)
		"stubborn":
			play("cry", -1.0)
		"scold":
			_stop_cry()
			play("chitter", -3.0)
		"pop", "stretch":
			play("rustle", -2.0)
			play("chirp", -4.0)
		"ascend":
			play("ascend", -1.0)
		"jump", "hop", "happy":
			play("chirp", -6.0)
		"smile", "nuzzle":
			play("chitter", -5.0)
		"spin":
			play("chirp", -4.0)
			play("chitter", -8.0)
		"rustle":
			play("rustle", -3.0)
		"heal":
			play("chirp", -5.0)
			play("chitter", -7.0)
		_:
			pass


func _on_speech(_text: String) -> void:
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
	ambience_on = false
	PetState.ambience_muted = true
	var want_sfx := not PetState.sfx_muted
	if bool(PetState.sound_muted) and want_sfx:
		want_sfx = false
	sfx_on = want_sfx


func _load_streams() -> void:
	for key in FILES.keys():
		var path: String = AUDIO_DIR + str(FILES[key])
		var stream := _load_wav(path, false)
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
		offset = chunk_end + (chunk_size % 2)

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
