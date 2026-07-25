extends Control
## Main Jimothy pet UI (Godot 4.7.1).

const YOUNG_FORMS := ["puff", "looper", "shadow", "nub"]
const TEEN_FORMS := ["dumpling", "bounder", "nightlane", "scruff"]
const ADULT_FORMS := ["saint", "legend", "alley_ghost", "ballard_blip"]

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
@onready var mess_mark: Control = %MessMark
@onready var btn_feed: Button = %BtnFeed
@onready var btn_play: Button = %BtnPlay
@onready var btn_scold: Button = %BtnScold
@onready var btn_clean: Button = %BtnClean
@onready var btn_forms: Button = %BtnForms
@onready var btn_dev: Button = %BtnDev
@onready var feed_panel: Control = %FeedPanel
@onready var message_panel: Control = %MessagePanel
@onready var message_title: Label = %MessageTitle
@onready var message_body: Label = %MessageBody
@onready var dumpster: Control = %DumpsterDive
@onready var btn_message_ok: Button = %BtnMessageOk

var _speech_timer: SceneTreeTimer
var _awaiting_new_kit: bool = false
var _forms_panel: ColorRect
var _forms_list: VBoxContainer
var _dev_panel: ColorRect
var _dev_status: Label


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
	_build_forms_panel()
	_build_dev_panel()
	_refresh()
	if not PetState.alive:
		if raccoon.has_method("play_anim"):
			raccoon.play_anim("ascend")
		else:
			_offer_new_kit()


func _process(_delta: float) -> void:
	clock_label.text = Time.get_time_string_from_system().substr(0, 5)


func _build_overlay_panel(title_text: String) -> Dictionary:
	var dim := ColorRect.new()
	dim.visible = false
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.05, 0.04, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -180
	card.offset_right = 180
	card.offset_top = -240
	card.offset_bottom = 240
	dim.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("f0c57a"))
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 280)
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): dim.visible = false)
	vbox.add_child(close)

	return {"dim": dim, "list": list, "title": title}


func _build_forms_panel() -> void:
	var built := _build_overlay_panel("Forms unlocked")
	_forms_panel = built.dim
	_forms_list = built.list


func _build_dev_panel() -> void:
	var built := _build_overlay_panel("Developer mode")
	_dev_panel = built.dim
	var list: VBoxContainer = built.list

	_dev_status = Label.new()
	_dev_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dev_status.add_theme_color_override("font_color", Color("9aab9c"))
	_dev_status.add_theme_font_size_override("font_size", 13)
	list.add_child(_dev_status)

	var toggle := Button.new()
	toggle.text = "Toggle Dev Mode ON/OFF"
	toggle.pressed.connect(func():
		PetState.set_dev_mode(not PetState.dev_mode)
		_refresh_dev_panel()
	)
	list.add_child(toggle)

	var note := Label.new()
	note.text = "Fast-forward wall-clock age to each stage (for testing)."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("9aab9c"))
	note.add_theme_font_size_override("font_size", 12)
	list.add_child(note)

	for pair in [
		["bush", "Bush"],
		["baby", "Baby kit"],
		["young", "Young kit"],
		["teen", "Teen kit"],
		["adult", "Adult"],
		["ascend", "Ascend finale"],
	]:
		var b := Button.new()
		b.text = "Skip → %s" % pair[1]
		var key := str(pair[0])
		b.pressed.connect(func():
			if not PetState.dev_mode:
				PetState.speech.emit("Turn Dev Mode ON first.")
				return
			PetState.dev_skip_to(key)
			_dev_panel.visible = false
		)
		list.add_child(b)


func _refresh_forms_panel() -> void:
	for c in _forms_list.get_children():
		c.queue_free()

	_add_form_section("Young kit", "young", YOUNG_FORMS)
	_add_form_section("Teen kit", "teen", TEEN_FORMS)
	_add_form_section("Adult", "adult", ADULT_FORMS)

	var tip := Label.new()
	tip.text = "Raise kits with different care to unlock more forms. Adults keep the short-spine Jimothy silhouette."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_color_override("font_color", Color("9aab9c"))
	tip.add_theme_font_size_override("font_size", 12)
	_forms_list.add_child(tip)


func _add_form_section(label: String, bucket: String, forms: Array) -> void:
	var h := Label.new()
	h.text = label
	h.add_theme_color_override("font_color", Color("f0c57a"))
	h.add_theme_font_size_override("font_size", 16)
	_forms_list.add_child(h)
	for f in forms:
		var unlocked := PetState.is_form_unlocked(bucket, str(f))
		var row := Label.new()
		var pretty := str(f).replace("_", " ").capitalize()
		if bucket == "adult":
			pretty = pretty.replace("Alley ghost", "Alley Ghost").replace("Ballard blip", "Ballard Blip")
		row.text = ("✓  %s" % pretty) if unlocked else ("🔒  %s" % pretty)
		row.add_theme_color_override("font_color", Color("eef5ea") if unlocked else Color(0.45, 0.5, 0.46))
		row.add_theme_font_size_override("font_size", 14)
		_forms_list.add_child(row)


func _refresh_dev_panel() -> void:
	if _dev_status:
		_dev_status.text = "Dev Mode: %s\nCurrent stage: %s · age %s" % [
			"ON" if PetState.dev_mode else "OFF",
			PetState.stage_label(),
			_format_age(PetState.age_sec),
		]
	btn_dev.text = "Dev mode ✓" if PetState.dev_mode else "Dev mode"


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
	mess_mark.visible = PetState.has_mess and PetState.alive and not PetState.ascending

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
	_refresh_dev_panel()

	if PetState.ascending:
		hint_label.text = "Watch… Jimothy grows wings and rises into the sky."
	elif PetState.stage == "bush":
		hint_label.text = "A forest bush is rustling. In about a minute, a baby kit may pop out."
	elif not PetState.alive:
		hint_label.text = "His cryptid life is complete. You can raise another kit."
	else:
		hint_label.text = "Good care lengthens his days. Check Forms unlocked for variants you’ve seen."


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


func _on_forms_pressed() -> void:
	_refresh_forms_panel()
	_forms_panel.visible = true


func _on_dev_pressed() -> void:
	_refresh_dev_panel()
	_dev_panel.visible = true


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
