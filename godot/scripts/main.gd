extends Control
## Main Jimothy pet UI (Godot 4.7.1).

@onready var clock_label: Label = %ClockLabel
@onready var age_label: Label = %AgeLabel
@onready var stage_chip: Label = %StageChip
@onready var stage_name: Label = %StageName
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var happy_bar: ProgressBar = %HappyBar
@onready var health_bar: ProgressBar = %HealthBar
@onready var discipline_bar: ProgressBar = %DisciplineBar
@onready var alert_banner: Label = %AlertBanner
@onready var speech_label: Label = %SpeechLabel
@onready var hint_label: Label = %HintLabel
@onready var raccoon: Control = %RaccoonView
@onready var mess_mark: ColorRect = %MessMark
@onready var btn_feed: Button = %BtnFeed
@onready var btn_play: Button = %BtnPlay
@onready var btn_scold: Button = %BtnScold
@onready var btn_clean: Button = %BtnClean
@onready var feed_panel: Control = %FeedPanel
@onready var message_panel: Control = %MessagePanel
@onready var message_title: Label = %MessageTitle
@onready var message_body: Label = %MessageBody
@onready var dumpster: Control = %DumpsterDive
@onready var btn_message_ok: Button = %BtnMessageOk

var _speech_timer: SceneTreeTimer
var _awaiting_new_kit: bool = false


func _ready() -> void:
	PetState.state_changed.connect(_refresh)
	PetState.speech.connect(_on_speech)
	PetState.pet_died.connect(_on_pet_died)
	PetState.stage_changed.connect(_on_stage_changed)
	if raccoon.has_signal("ascend_finished"):
		raccoon.ascend_finished.connect(_on_ascend_finished)
	dumpster.finished.connect(_on_dive_finished)
	feed_panel.visible = false
	message_panel.visible = false
	_refresh()
	if not PetState.alive:
		# Resume finale if save ended mid-death.
		if raccoon.has_method("play_anim"):
			raccoon.play_anim("ascend")
		else:
			_offer_new_kit()


func _process(_delta: float) -> void:
	clock_label.text = Time.get_time_string_from_system().substr(0, 5)


func _refresh() -> void:
	age_label.text = _format_age(PetState.age_sec)
	stage_chip.text = PetState.stage_label()
	stage_name.text = PetState.stage_name()
	hunger_bar.value = PetState.hunger
	happy_bar.value = PetState.happy
	health_bar.value = PetState.health
	discipline_bar.value = PetState.discipline

	var mood := "idle"
	if PetState.ascending:
		mood = "ascend"
	elif PetState.stubborn:
		mood = "stubborn"
	elif PetState.sick:
		mood = "sick"
	raccoon.set_look(PetState.stage, PetState.adult_form, mood)
	mess_mark.visible = PetState.has_mess and PetState.alive

	var alert: Dictionary = PetState.alert_text()
	if alert.is_empty():
		alert_banner.visible = false
	else:
		alert_banner.visible = true
		alert_banner.text = str(alert.text)
		alert_banner.modulate = Color("f0b4a8") if alert.get("danger", false) else Color("f0c57a")

	var can_care := PetState.alive and PetState.stage != "bush" and not PetState.ascending
	btn_feed.disabled = not can_care
	btn_play.disabled = not PetState.alive or PetState.stage in ["bush", "baby"] or PetState.ascending
	btn_scold.disabled = not (PetState.alive and PetState.stubborn)
	btn_clean.disabled = not (PetState.alive and PetState.has_mess)

	if PetState.ascending:
		hint_label.text = "Watch… Jimothy grows wings and rises into the sky."
	elif PetState.stage == "bush":
		hint_label.text = "Watch the bush. In about a minute, a baby kit may pop out."
	elif not PetState.alive:
		hint_label.text = "His cryptid life is complete. You can raise another kit."
	else:
		hint_label.text = "Good care lengthens his days. Neglect shortens them."


func _format_age(sec: float) -> String:
	var s := int(sec)
	var days := s / 86400
	var hours := (s % 86400) / 3600
	var mins := (s % 3600) / 60
	if days > 0:
		return "Age %dd %dh" % [days, hours]
	if hours > 0:
		return "Age %dh %dm" % [hours, mins]
	if mins > 0:
		return "Age %dm" % mins
	return "Age %ds" % s


func _on_speech(text: String) -> void:
	speech_label.visible = true
	speech_label.text = text
	_speech_timer = get_tree().create_timer(2.8)
	_speech_timer.timeout.connect(func():
		speech_label.visible = false
	, CONNECT_ONE_SHOT)


func _on_stage_changed(stage: String) -> void:
	match stage:
		"baby":
			_show_message("Baby Kit!", "Jimothy burst from the bush. Keep him fed — young kit in ~1 hour.")
		"young":
			_show_message("Young Kit!", "Form: %s. His teen/adult path is already leaning this way." % PetState.young_form.capitalize())
		"teen":
			_show_message("Teen Kit!", "Form: %s. Adult Jimothy arrives in 1–3 real days." % PetState.teen_form.capitalize())
		"adult":
			_show_message(
				"Adult Cryptid!",
				"%s Jimothy — care well and he may linger longer; neglect shortens his sky-bound days." % PetState.adult_form_title()
			)


func _on_pet_died(_reason: String) -> void:
	_refresh()
	_awaiting_new_kit = false
	# Ascension animation plays via PetState.anim_impulse("ascend")


func _on_ascend_finished() -> void:
	PetState.ascending = false
	PetState.save_game()
	_offer_new_kit()


func _offer_new_kit() -> void:
	_awaiting_new_kit = true
	var why := ""
	match PetState.death_reason:
		"neglect":
			why = "Poor care shortened his time."
		"lifespan":
			why = "He lived out his cryptid span."
		_:
			why = "His story has ended."
	_show_message(
		"Jimothy’s life is over",
		"%s He grew wings and rose into the sky. Raise another kit?" % why
	)
	btn_message_ok.text = "Raise another kit"


func _show_message(title: String, body: String) -> void:
	message_title.text = title
	message_body.text = body
	if not _awaiting_new_kit:
		btn_message_ok.text = "OK"
	message_panel.visible = true


func _on_feed_pressed() -> void:
	if btn_feed.disabled:
		return
	feed_panel.visible = true


func _on_feed_close() -> void:
	feed_panel.visible = false


func _on_food(food_key: String) -> void:
	PetState.try_feed(food_key)
	feed_panel.visible = false


func _on_play_pressed() -> void:
	if btn_play.disabled:
		return
	if PetState.can_start_play() != "ok":
		return
	dumpster.start_game()


func _on_dive_finished(score: int, stars: int, completed: bool) -> void:
	PetState.apply_play_result(score, stars, completed)


func _on_scold_pressed() -> void:
	PetState.discipline_pet()


func _on_clean_pressed() -> void:
	PetState.clean_mess()


func _on_message_ok() -> void:
	message_panel.visible = false
	if _awaiting_new_kit or not PetState.alive:
		_awaiting_new_kit = false
		btn_message_ok.text = "OK"
		PetState.reset_pet()
