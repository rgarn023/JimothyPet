extends Node
## Promo footage driver. Only active when JIMOTHY_PROMO=1.
## Records real in-game raccoon_view / UI via Godot --write-movie.

var _main: Node = null


func _ready() -> void:
	if OS.get_environment("JIMOTHY_PROMO") != "1":
		queue_free()
		return
	print("PromoDemo: armed")
	call_deferred("_boot")


func _boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_main = get_tree().current_scene
	if PetState == null:
		push_error("PromoDemo: PetState missing")
		return
	# Enable in-game SFX for the promo soundtrack; keep alerts off.
	PetState.sfx_muted = false
	PetState.ambience_muted = true
	PetState.sound_muted = false
	PetState.alerts_enabled = false
	PetState.set_schedule(7, 22)
	PetState.schedule_set = true
	# Force awake regardless of wall-clock hour.
	var hour := int(Time.get_time_dict_from_system().hour)
	PetState.wake_hour = hour
	PetState.sleep_hour = (hour + 1) % 24
	PetState.schedule_set = true
	_hide_blocking_ui()
	if JimothyAudio and JimothyAudio.has_method("set_sfx_enabled"):
		JimothyAudio.set_sfx_enabled(true)
	# Soft forest bed under SFX (promo-only; game ambience stays off normally).
	_start_promo_ambience()
	await _run_sequence()


func _start_promo_ambience() -> void:
	var path := "res://audio/night_ambience.wav"
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.name = "PromoAmbience"
	p.stream = stream
	p.bus = "Master"
	p.volume_db = -18.0
	add_child(p)
	p.finished.connect(func():
		if is_instance_valid(p):
			p.play()
	)
	p.play()


func _hide_blocking_ui() -> void:
	if _main == null:
		return
	for name in ["_schedule_panel", "_settings_panel", "_action_panel", "_message_panel",
			"_forms_panel", "_play_pick_panel", "_reset_panel", "_sound_panel", "_language_panel", "_graphic_panel",
			"_dice", "_stage_celebrating"]:
		if name == "_stage_celebrating":
			if name in _main:
				_main.set("_stage_celebrating", false)
			continue
		if name in _main:
			var n = _main.get(name)
			if n is CanvasItem:
				n.visible = false
	if "message_panel" in _main and _main.message_panel is CanvasItem:
		_main.message_panel.visible = false
	if "feed_panel" in _main and _main.feed_panel is CanvasItem:
		_main.feed_panel.visible = false
	if _main.has_node("%MessagePanel"):
		_main.get_node("%MessagePanel").visible = false
	if _main.has_node("%FeedPanel"):
		_main.get_node("%FeedPanel").visible = false


func _run_sequence() -> void:
	# --- Bush (real rustle) ---
	_force_stage("bush", 20.0)
	await _wait(0.8)
	for _i in 4:
		PetState.interact_tap()
		await _wait(0.55)
	await _wait(0.6)

	# --- Baby kit ---
	_force_stage("baby", 120.0)
	await _wait(0.5)
	for _i in 3:
		PetState.interact_tap()
		await _wait(0.7)
	await _wait(0.5)

	# --- Young kit ---
	_force_stage("young", 4000.0)
	PetState.young_form = "puff"
	PetState.unlock_current_form()
	PetState.state_changed.emit()
	PetState.stage_changed.emit("young")
	await _wait(0.4)
	PetState.interact_tap()
	await _wait(1.2)
	PetState.interact_tap()
	await _wait(1.0)

	# --- Adult Jimothy ---
	_force_stage("adult", 200000.0)
	PetState.adult_form = "saint"
	PetState.young_form = "puff"
	PetState.teen_form = "dumpling"
	PetState.hunger = 55.0
	PetState.happy = 70.0
	PetState.health = 95.0
	PetState.energy = 80.0
	PetState.mess_count = 0
	PetState.sick = false
	PetState.stubborn = false
	PetState.unlock_current_form()
	PetState.state_changed.emit()
	PetState.stage_changed.emit("adult")
	if _main and _main.has_node("%RaccoonView"):
		var rv = _main.get_node("%RaccoonView")
		if rv.has_method("play_anim"):
			rv.play_anim("stageUp")
	await _wait(1.4)
	PetState.interact_tap()
	await _wait(1.0)
	# Feed animation if available
	if PetState.has_method("try_feed"):
		PetState.try_feed("berries")
	await _wait(1.6)
	PetState.interact_tap()
	await _wait(1.2)
	if _main and _main.has_node("%RaccoonView"):
		var rv2 = _main.get_node("%RaccoonView")
		if rv2.has_method("play_anim"):
			rv2.play_anim("walk")
	await _wait(2.0)
	PetState.interact_tap()
	await _wait(1.5)
	print("PromoDemo: sequence complete")


func _force_stage(stage: String, age: float) -> void:
	PetState.alive = true
	PetState.ascending = false
	PetState.stage = stage
	PetState.age_sec = age
	PetState.schedule_set = true
	var hour := int(Time.get_time_dict_from_system().hour)
	PetState.wake_hour = hour
	PetState.sleep_hour = (hour + 1) % 24
	PetState.state_changed.emit()
	PetState.stage_changed.emit(stage)
	await get_tree().process_frame
	_hide_blocking_ui()
	# Stage-up dialogs steal the frame — dismiss immediately for clean footage.
	await get_tree().create_timer(0.05).timeout
	_hide_blocking_ui()


func _wait(sec: float) -> void:
	# Fixed-fps movie mode: use timers tied to engine time.
	await get_tree().create_timer(sec).timeout
