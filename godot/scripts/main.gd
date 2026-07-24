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

var _speech_timer: SceneTreeTimer


func _ready() -> void:
	PetState.state_changed.connect(_refresh)
	PetState.speech.connect(_on_speech)
	PetState.needs_reset.connect(_on_needs_reset)
	PetState.pet_died.connect(_on_pet_died)
	dumpster.finished.connect(_on_dive_finished)
	feed_panel.visible = false
	message_panel.visible = false
	_refresh()
	if not PetState.alive:
		_show_message("Jimothy wandered off…", "Your last raccoon headed back to the woods. Start a new egg?")


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
	if PetState.stubborn:
		mood = "stubborn"
	elif PetState.sick:
		mood = "sick"
	raccoon.set_look(PetState.stage, PetState.adult_variant, mood)
	mess_mark.visible = PetState.has_mess and PetState.alive

	var alert: Dictionary = PetState.alert_text()
	if alert.is_empty():
		alert_banner.visible = false
	else:
		alert_banner.visible = true
		alert_banner.text = str(alert.text)
		alert_banner.modulate = Color("f0b4a8") if alert.get("danger", false) else Color("f0c57a")

	btn_feed.disabled = not PetState.alive or PetState.stage == "egg"
	btn_play.disabled = not PetState.alive or PetState.stage == "egg"
	btn_scold.disabled = not (PetState.alive and PetState.stubborn)
	btn_clean.disabled = not (PetState.alive and PetState.has_mess)

	if PetState.stage == "egg":
		hint_label.text = "The egg is warming… it will hatch on its own."
	elif not PetState.alive:
		hint_label.text = "Care carefully next time — healthy meals and play raise his path."
	else:
		hint_label.text = "Feed treats or healthy meals, play Dumpster Dive, and scold him if he acts up."


func _format_age(sec: float) -> String:
	var m := int(sec) / 60
	var s := int(sec) % 60
	if m <= 0:
		return "Age %ds" % s
	return "Age %dm" % m


func _on_speech(text: String) -> void:
	speech_label.visible = true
	speech_label.text = text
	if _speech_timer:
		# previous timer ignored; label refreshed
		pass
	_speech_timer = get_tree().create_timer(2.6)
	_speech_timer.timeout.connect(func():
		speech_label.visible = false
	, CONNECT_ONE_SHOT)


func _on_needs_reset() -> void:
	_show_message("Jimothy wandered off…", "Time kept moving while you were away. Start a new egg?")


func _on_pet_died() -> void:
	_refresh()


func _show_message(title: String, body: String) -> void:
	message_title.text = title
	message_body.text = body
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
	if not PetState.alive:
		PetState.reset_pet()
