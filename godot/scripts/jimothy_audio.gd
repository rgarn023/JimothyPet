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
	"discipline": "discipline.wav",
	"ascend": "ascend.wav",
	"sick": "sick.wav",
	"heal": "heal.wav",
	"sleep": "sleep.wav",
	"lights": "lights.wav",
}
const CRY_SEC := 5.0

var ambience_on: bool = false
var sfx_on: bool = true
var _streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_i: int = 0
var _accent_cd: float = 4.0
var _cry_player: AudioStreamPlayer
var _cry_left: float = 0.0
var _cry_busy: bool = false


func _ready() -> void:
	# Ensure the mix bus isn't stuck silent after an Android export / focus change.
	if AudioServer.get_bus_count() > 0:
		AudioServer.set_bus_mute(0, false)
		if AudioServer.get_bus_volume_db(0) < -40.0:
			AudioServer.set_bus_volume_db(0, 0.0)

	_load_streams()
	for i in 5:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		p.bus = "Master"
		# Keep players active while the app is backgrounded so queued care SFX still mix.
		p.process_mode = Node.PROCESS_MODE_ALWAYS
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

	if _streams.is_empty():
		push_error("JimothyAudio: no SFX streams loaded — Android/web export will be silent.")
	elif sfx_on:
		# Prove audio path on boot (also warms Android audio focus after install).
		call_deferred("play", "chirp", -12.0)


func _process(delta: float) -> void:
	if _cry_busy:
		_cry_left -= delta
		if _cry_left <= 0.0:
			_stop_cry()
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
		_play_cry(volume_db)
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_i]
	_sfx_i = (_sfx_i + 1) % 4
	p.stop()
	p.stream = _streams[kind]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.94, 1.06)
	p.play()


func _play_cry(volume_db: float = -1.0) -> void:
	# One 5s cry per acting-up bout — ignore ambient stubborn pulses.
	if _cry_busy:
		return
	if not _streams.has("cry"):
		return
	_cry_player.stop()
	_cry_player.stream = _streams["cry"]
	_cry_player.volume_db = volume_db
	_cry_player.pitch_scale = 1.0
	_cry_player.play()
	_cry_busy = true
	_cry_left = CRY_SEC


func _stop_cry() -> void:
	if _cry_player and _cry_player.playing:
		_cry_player.stop()
	_cry_busy = false
	_cry_left = 0.0


func _on_anim(kind: String) -> void:
	match kind:
		"eat":
			play("chew", -1.5)
			play("crunch", -6.0)
		"refuse", "grumble":
			play("grumble", -2.0)
		"stubborn":
			_play_cry(-1.0)
		"scold":
			_stop_cry()
			play("discipline", -1.5)
		"sick":
			play("sick", -2.0)
		"lights":
			play("lights", -3.0)
		"fallAsleep":
			# Ambient "sleep" pose pulses intentionally silent.
			play("sleep", -2.0)
			play("rustle", -8.0)
		"pop", "stretch":
			play("rustle", -2.0)
			play("chirp", -4.0)
		"stageUp":
			play("chirp", -1.0)
			play("chitter", -3.0)
			play("rustle", -5.0)
		"ascend":
			play("ascend", -1.0)
		"jump", "hop", "happy", "play", "chirp":
			play("chirp", 1.5)
			play("chitter", -1.0)
			if kind == "play":
				play("rustle", -3.0)
		"sad":
			play("grumble", -3.0)
		"smile", "nuzzle", "pet", "sniff":
			# Tap reactions — loud so pets read clearly.
			play("chitter", 2.0)
			play("chirp", 0.5)
		"spin":
			play("chirp", 1.5)
			play("chitter", 0.0)
		"rustle", "clean":
			play("rustle", 0.0)
			play("chitter", -2.0)
			if kind == "clean":
				pass
		"heal":
			play("heal", -2.0)
			play("chirp", -8.0)
		_:
			if _streams.has(kind):
				play(kind, -3.0)


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
	# Prefer ResourceLoader — required on Android/web exports where res:// WAVs are
	# remapped to imported .sample data (manual RIFF parsing then finds no PCM).
	for key in FILES.keys():
		var path: String = AUDIO_DIR + str(FILES[key])
		var stream: AudioStream = null
		if ResourceLoader.exists(path):
			var res: Resource = ResourceLoader.load(path, "AudioStream", ResourceLoader.CACHE_MODE_REUSE)
			if res is AudioStream:
				stream = res as AudioStream
		if stream == null:
			stream = _load_wav(path, false)
		if stream:
			_streams[key] = stream
		else:
			push_warning("JimothyAudio: missing/unloadable SFX: %s" % path)
	print("JimothyAudio: loaded %d/%d SFX streams" % [_streams.size(), FILES.size()])


func _load_wav(path: String, loop: bool = false) -> AudioStreamWAV:
	# Fallback for editor/dev if an import remap isn't ready yet.
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var bytes := file.get_buffer(file.get_length())
	if bytes.size() < 44:
		return null
	if _ascii(bytes, 0, 4) != "RIFF" or _ascii(bytes, 8, 4) != "WAVE":
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
