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
@onready var btn_heal: Button = %BtnHeal
@onready var btn_ambience: Button = %BtnAmbience
@onready var btn_sfx: Button = %BtnSfx
@onready var btn_alerts: Button = %BtnAlerts
@onready var btn_forms: Button = %BtnForms
@onready var btn_reset: Button = %BtnReset
@onready var utility_row: HBoxContainer = $Margin/VBox/UtilityRow
@onready var brand_label: Label = $Margin/VBox/Brand
@onready var feed_panel: Control = %FeedPanel
@onready var message_panel: Control = %MessagePanel
@onready var message_title: Label = %MessageTitle
@onready var message_body: Label = %MessageBody
@onready var dumpster: Control = %DumpsterDive
@onready var btn_message_ok: Button = %BtnMessageOk

var btn_dev: Button
var _speech_timer: SceneTreeTimer
var _awaiting_new_kit: bool = false
var _forms_panel: ColorRect
var _forms_list: VBoxContainer
var _dev_panel: ColorRect
var _dev_status: Label
var _dev_stat_labels: Dictionary = {}
var _play_pick_panel: ColorRect
var _dice: ColorRect
var _reset_panel: ColorRect
var _brand_tap_times: Array[float] = []


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
	_build_play_pick_panel()
	_build_dice_panel()
	_build_reset_panel()
	_wire_brand_secret()
	_refresh_sound_buttons()
	_refresh_alerts_button()
	_refresh()
	# Dead / leftover saves: land on a fresh rustling bush (no re-ascent).
	if not PetState.alive:
		_start_next_kit_after_ascension()


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
	var built := _build_overlay_panel("Form paths")
	_forms_panel = built.dim
	_forms_list = built.list


func _build_dev_panel() -> void:
	var built := _build_overlay_panel("Developer tools")
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

	var waste_on := Button.new()
	waste_on.text = "Drop waste on screen"
	waste_on.pressed.connect(func(): PetState.dev_set_mess(true); _refresh_dev_panel())
	list.add_child(waste_on)
	var waste_off := Button.new()
	waste_off.text = "Clear waste"
	waste_off.pressed.connect(func(): PetState.dev_set_mess(false); _refresh_dev_panel())
	list.add_child(waste_off)

	var sick_on := Button.new()
	sick_on.text = "Make sick"
	sick_on.pressed.connect(func(): PetState.dev_set_sick(true); _refresh_dev_panel())
	list.add_child(sick_on)
	var sick_off := Button.new()
	sick_off.text = "Clear sick"
	sick_off.pressed.connect(func(): PetState.dev_set_sick(false); _refresh_dev_panel())
	list.add_child(sick_off)

	var stub_on := Button.new()
	stub_on.text = "Make stubborn"
	stub_on.pressed.connect(func(): PetState.dev_set_stubborn(true); _refresh_dev_panel())
	list.add_child(stub_on)
	var stub_off := Button.new()
	stub_off.text = "Clear stubborn"
	stub_off.pressed.connect(func(): PetState.dev_set_stubborn(false); _refresh_dev_panel())
	list.add_child(stub_off)

	var meters_note := Label.new()
	meters_note.text = "Meters — tap − / + (hold values for testing)."
	meters_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meters_note.add_theme_color_override("font_color", Color("9aab9c"))
	meters_note.add_theme_font_size_override("font_size", 12)
	list.add_child(meters_note)

	for stat in ["hunger", "happy", "health", "discipline", "energy", "satiety"]:
		list.add_child(_make_dev_stat_row(stat))

	var note := Label.new()
	note.text = "Stage skips (Dev Mode ON)."
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


func _make_dev_stat_row(stat: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name := Label.new()
	name.text = stat.capitalize()
	name.custom_minimum_size = Vector2(90, 0)
	name.add_theme_color_override("font_color", Color("9aab9c"))
	name.add_theme_font_size_override("font_size", 13)
	row.add_child(name)
	var minus := Button.new()
	minus.text = "−10"
	minus.pressed.connect(func(): _dev_nudge_stat(stat, -10.0))
	row.add_child(minus)
	var val := Label.new()
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.custom_minimum_size = Vector2(36, 0)
	val.add_theme_color_override("font_color", Color("f0c57a"))
	val.add_theme_font_size_override("font_size", 13)
	row.add_child(val)
	_dev_stat_labels[stat] = val
	var plus := Button.new()
	plus.text = "+10"
	plus.pressed.connect(func(): _dev_nudge_stat(stat, 10.0))
	row.add_child(plus)
	var fill := Button.new()
	fill.text = "100"
	fill.pressed.connect(func(): PetState.dev_set_stat(stat, 100.0); _refresh_dev_panel())
	row.add_child(fill)
	var zero := Button.new()
	zero.text = "0"
	zero.pressed.connect(func(): PetState.dev_set_stat(stat, 0.0); _refresh_dev_panel())
	row.add_child(zero)
	return row


func _dev_nudge_stat(stat: String, delta: float) -> void:
	var cur := 0.0
	match stat:
		"hunger":
			cur = PetState.hunger
		"happy":
			cur = PetState.happy
		"health":
			cur = PetState.health
		"discipline":
			cur = PetState.discipline
		"energy":
			cur = PetState.energy
		"satiety":
			cur = PetState.satiety
	PetState.dev_set_stat(stat, cur + delta)
	_refresh_dev_panel()


func _refresh_forms_panel() -> void:
	for c in _forms_list.get_children():
		c.queue_free()

	var intro := Label.new()
	intro.text = "All forms below, then evolution paths. Adults always stay short-spine Jimothy."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Color("9aab9c"))
	intro.add_theme_font_size_override("font_size", 12)
	_forms_list.add_child(intro)

	_add_form_catalog("Young kits", "young", YOUNG_FORMS)
	_add_form_catalog("Teen kits", "teen", TEEN_FORMS)
	_add_form_catalog("Adult Jimothy", "adult", ADULT_FORMS)

	var path_head := Label.new()
	path_head.text = "Evolution paths"
	path_head.add_theme_color_override("font_color", Color("f0c57a"))
	path_head.add_theme_font_size_override("font_size", 16)
	_forms_list.add_child(path_head)

	# young → [teen options] → adult good / neglect
	var paths := [
		["puff", ["dumpling", "scruff"]],
		["looper", ["bounder", "nightlane"]],
		["shadow", ["nightlane", "scruff"]],
		["nub", ["bounder", "dumpling"]],
	]
	var teen_adult := {
		"dumpling": ["saint", "ballard_blip"],
		"bounder": ["alley_ghost", "legend"],
		"nightlane": ["alley_ghost", "legend"],
		"scruff": ["saint", "ballard_blip"],
	}

	for path in paths:
		var young := str(path[0])
		var teens: Array = path[1]
		var head := Label.new()
		head.text = _form_mark("young", young)
		head.add_theme_color_override("font_color", Color("f0c57a"))
		head.add_theme_font_size_override("font_size", 15)
		_forms_list.add_child(head)
		for teen in teens:
			var adults: Array = teen_adult[str(teen)]
			var row := Label.new()
			row.text = "  → %s → care %s · neglect %s" % [
				_form_mark("teen", str(teen)),
				_form_mark("adult", str(adults[0])),
				_form_mark("adult", str(adults[1])),
			]
			row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_theme_color_override("font_color", Color("eef5ea"))
			row.add_theme_font_size_override("font_size", 12)
			_forms_list.add_child(row)

	var counts := Label.new()
	counts.text = "Unlocked · Young %d/%d · Teen %d/%d · Adult %d/%d" % [
		_unlocked_count("young", YOUNG_FORMS), YOUNG_FORMS.size(),
		_unlocked_count("teen", TEEN_FORMS), TEEN_FORMS.size(),
		_unlocked_count("adult", ADULT_FORMS), ADULT_FORMS.size(),
	]
	counts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	counts.add_theme_color_override("font_color", Color("9aab9c"))
	counts.add_theme_font_size_override("font_size", 12)
	_forms_list.add_child(counts)


func _add_form_catalog(title: String, bucket: String, forms: Array) -> void:
	var head := Label.new()
	head.text = title
	head.add_theme_color_override("font_color", Color("f0c57a"))
	head.add_theme_font_size_override("font_size", 15)
	_forms_list.add_child(head)
	var row := Label.new()
	var bits: PackedStringArray = []
	for f in forms:
		bits.append(_form_mark(bucket, str(f)))
	row.text = " · ".join(bits)
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_theme_color_override("font_color", Color("eef5ea"))
	row.add_theme_font_size_override("font_size", 12)
	_forms_list.add_child(row)


func _unlocked_count(bucket: String, forms: Array) -> int:
	var n := 0
	for f in forms:
		if PetState.is_form_unlocked(bucket, str(f)):
			n += 1
	return n


func _form_mark(bucket: String, form_id: String) -> String:
	var unlocked := PetState.is_form_unlocked(bucket, form_id)
	var pretty := form_id.replace("_", " ").capitalize()
	pretty = pretty.replace("Alley ghost", "Alley Ghost").replace("Ballard blip", "Ballard Blip")
	var current := false
	match bucket:
		"young":
			current = PetState.stage not in ["bush", "baby"] and PetState.young_form == form_id
		"teen":
			current = PetState.teen_form == form_id
		"adult":
			current = PetState.adult_form == form_id
	var mark := pretty
	if current:
		mark = "[%s]" % pretty
	elif not unlocked:
		mark = "·%s·" % pretty
	return mark


func _refresh_dev_panel() -> void:
	if _dev_status:
		_dev_status.text = "Dev Mode: %s · Waste: %s · Sick: %s · Stubborn: %s\nStage: %s · %s" % [
			"ON" if PetState.dev_mode else "OFF",
			"yes" if PetState.has_mess else "no",
			"yes" if PetState.sick else "no",
			"yes" if PetState.stubborn else "no",
			PetState.stage_label(),
			_format_age(PetState.age_sec),
		]
	for stat in _dev_stat_labels.keys():
		var lbl: Label = _dev_stat_labels[stat]
		var cur := 0.0
		match str(stat):
			"hunger":
				cur = PetState.hunger
			"happy":
				cur = PetState.happy
			"health":
				cur = PetState.health
			"discipline":
				cur = PetState.discipline
			"energy":
				cur = PetState.energy
			"satiety":
				cur = PetState.satiety
		lbl.text = str(int(round(cur)))
	_refresh_dev_button()


func _ensure_dev_button() -> void:
	if btn_dev != null and is_instance_valid(btn_dev):
		return
	if utility_row == null:
		return
	btn_dev = Button.new()
	btn_dev.text = "Dev"
	btn_dev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_dev.pressed.connect(_on_dev_pressed)
	utility_row.add_child(btn_dev)


func _refresh_dev_button() -> void:
	# Only inject the Dev button after the secret unlock (never in the base layout).
	if not PetState.dev_unlocked:
		if btn_dev != null and is_instance_valid(btn_dev):
			btn_dev.visible = false
		return
	_ensure_dev_button()
	btn_dev.visible = true
	btn_dev.text = "Dev mode ✓" if PetState.dev_mode else "Dev"


func _wire_brand_secret() -> void:
	if brand_label == null:
		return
	brand_label.mouse_filter = Control.MOUSE_FILTER_STOP
	brand_label.gui_input.connect(_on_brand_gui_input)


func _on_brand_gui_input(event: InputEvent) -> void:
	var tapped := false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
	if not tapped:
		return
	var now := Time.get_ticks_msec() / 1000.0
	_brand_tap_times = _brand_tap_times.filter(func(t: float): return now - t < 2.5)
	_brand_tap_times.append(now)
	if _brand_tap_times.size() < 5:
		return
	_brand_tap_times.clear()
	PetState.unlock_dev_access()
	_refresh_dev_button()
	PetState.speech.emit("Dev tools unlocked.")
	_refresh_dev_panel()
	_dev_panel.visible = true


func _build_reset_panel() -> void:
	var dim := ColorRect.new()
	dim.visible = false
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.05, 0.04, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_reset_panel = dim

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -150
	card.offset_right = 150
	card.offset_top = -90
	card.offset_bottom = 90
	dim.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Reset Jimothy?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("f0c57a"))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var body := Label.new()
	body.text = "Starts a new rustling bush. Unlocked forms stay."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", Color("9aab9c"))
	body.add_theme_font_size_override("font_size", 13)
	vbox.add_child(body)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func(): _reset_panel.visible = false)
	row.add_child(cancel)

	var ok := Button.new()
	ok.text = "Reset"
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_confirm_reset)
	row.add_child(ok)


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
	if btn_heal:
		btn_heal.disabled = not (PetState.alive and PetState.sick and PetState.stage != "bush" and not PetState.ascending)
	_refresh_sound_buttons()
	_refresh_dev_panel()

	if PetState.ascending:
		hint_label.text = "Watch… Jimothy grows wings and rises into the sky."
	elif PetState.stage == "bush":
		hint_label.text = "Tap the bush — it rustles. In about a minute, a baby kit may pop out."
	elif not PetState.alive:
		hint_label.text = "His cryptid life is complete. You can raise another kit."
	elif PetState.stage == "baby":
		hint_label.text = "Tap Jimothy for smiles and hops. Too tiny for a full night run yet."
	else:
		hint_label.text = "Tap Jimothy to pet him. Good care lengthens his days — check Form paths."


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
	_speech_timer = get_tree().create_timer(5.2)
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
	_start_next_kit_after_ascension()


func _death_why() -> String:
	match PetState.death_reason:
		"neglect":
			return "Poor care shortened his time."
		"lifespan":
			return "He lived out his cryptid span."
		_:
			return "His story has ended."


## Clear ascend visuals, spawn the rustling bush immediately, then show farewell.
func _start_next_kit_after_ascension() -> void:
	var why := _death_why()
	PetState.ascending = false
	PetState.reset_pet()
	if raccoon.has_method("clear_ascend"):
		raccoon.clear_ascend()
	_awaiting_new_kit = false
	_refresh()
	_show_message(
		"Jimothy ascended",
		"%s He grew wings and rose into the sky.\n\nA new bush is rustling…" % why
	)
	btn_message_ok.text = "OK"


func _show_message(title: String, body: String) -> void:
	message_title.text = title
	message_body.text = body
	if not _awaiting_new_kit:
		btn_message_ok.text = "OK"
	message_panel.visible = true


func _refresh_sound_buttons() -> void:
	var bg_on := true
	var sfx_on := true
	if JimothyAudio:
		bg_on = JimothyAudio.ambience_on
		sfx_on = JimothyAudio.sfx_on
	elif PetState:
		bg_on = not PetState.ambience_muted
		sfx_on = not PetState.sfx_muted
	if btn_ambience:
		btn_ambience.text = "BG: On" if bg_on else "BG: Off"
	if btn_sfx:
		btn_sfx.text = "Jimothy: On" if sfx_on else "Jimothy: Off"


func _on_ambience_pressed() -> void:
	if JimothyAudio:
		JimothyAudio.set_ambience_enabled(not JimothyAudio.ambience_on)
	elif PetState:
		PetState.ambience_muted = not PetState.ambience_muted
		PetState.sound_muted = PetState.ambience_muted and PetState.sfx_muted
		PetState.save_game()
	_refresh_sound_buttons()


func _on_sfx_pressed() -> void:
	if JimothyAudio:
		JimothyAudio.set_sfx_enabled(not JimothyAudio.sfx_on)
	elif PetState:
		PetState.sfx_muted = not PetState.sfx_muted
		PetState.sound_muted = PetState.ambience_muted and PetState.sfx_muted
		PetState.save_game()
	_refresh_sound_buttons()


func _refresh_alerts_button() -> void:
	if btn_alerts == null:
		return
	btn_alerts.text = "Alerts: On" if PetState.alerts_enabled else "Alerts: Off"


func _on_alerts_pressed() -> void:
	PetState.alerts_enabled = not PetState.alerts_enabled
	if PetState.alerts_enabled:
		if JimothyNotify and JimothyNotify.has_method("request_permission_web"):
			JimothyNotify.request_permission_web()
		PetState.speech.emit("Care alerts on — care needs, waste, and new forms.")
		if JimothyNotify:
			JimothyNotify.check_now()
	else:
		PetState.speech.emit("Care alerts off.")
	PetState.save_game()
	_refresh_alerts_button()


func _on_forms_pressed() -> void:
	_refresh_forms_panel()
	_forms_panel.visible = true


func _on_reset_pressed() -> void:
	if _reset_panel:
		_reset_panel.visible = true


func _confirm_reset() -> void:
	if _reset_panel:
		_reset_panel.visible = false
	if raccoon and raccoon.has_method("clear_ascend"):
		raccoon.clear_ascend()
	PetState.reset_pet()
	_refresh()


func _on_dev_pressed() -> void:
	if not PetState.dev_unlocked:
		return
	# Opening tools implies access; enable cheats if toggle was off.
	if not PetState.dev_mode:
		PetState.set_dev_mode(true)
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


func _build_play_pick_panel() -> void:
	_play_pick_panel = ColorRect.new()
	_play_pick_panel.visible = false
	_play_pick_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_play_pick_panel.color = Color(0.03, 0.05, 0.04, 0.82)
	_play_pick_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_play_pick_panel)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -170
	card.offset_right = 170
	card.offset_top = -180
	card.offset_bottom = 180
	_play_pick_panel.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Play with Jimothy"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("f0c57a"))
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var copy := Label.new()
	copy.text = "Dumpster Dive is a night forage. High or Low is a quick d20 gamble."
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_color_override("font_color", Color("9aab9c"))
	copy.add_theme_font_size_override("font_size", 13)
	vbox.add_child(copy)

	var dive := Button.new()
	dive.text = "Dumpster Dive"
	dive.pressed.connect(_start_dumpster)
	vbox.add_child(dive)

	var dice_btn := Button.new()
	dice_btn.text = "High or Low (d20)"
	dice_btn.pressed.connect(_start_dice)
	vbox.add_child(dice_btn)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): _play_pick_panel.visible = false)
	vbox.add_child(close)


func _build_dice_panel() -> void:
	var script := load("res://scripts/dice_high_low.gd")
	_dice = script.new()
	add_child(_dice)
	_dice.finished.connect(_on_dice_finished)


func _on_play_pressed() -> void:
	if btn_play.disabled:
		return
	if PetState.can_start_play(true) != "ok":
		return
	_play_pick_panel.visible = true


func _start_dumpster() -> void:
	_play_pick_panel.visible = false
	if PetState.can_start_play(false) != "ok":
		return
	if JimothyAudio:
		JimothyAudio.play("rustle", -3.0)
		JimothyAudio.play("chitter", -6.0)
	dumpster.start_game()


func _start_dice() -> void:
	_play_pick_panel.visible = false
	if PetState.can_start_play(false) != "ok":
		return
	if JimothyAudio:
		JimothyAudio.play("chitter", -6.0)
	if _dice and _dice.has_method("start_game"):
		_dice.start_game()


func _on_dive_finished(score: int, stars: int, completed: bool) -> void:
	PetState.apply_play_result(score, stars, completed)
	if JimothyAudio and completed:
		JimothyAudio.play("chirp", -4.0)


func _on_dice_finished(correct: bool, roll: int, _guess: String) -> void:
	PetState.apply_dice_result(correct, roll)
	if JimothyAudio:
		JimothyAudio.play("chirp" if correct else "grumble", -4.0)


func _on_scold_pressed() -> void:
	PetState.discipline_pet()


func _on_clean_pressed() -> void:
	PetState.clean_mess()
	if JimothyAudio and not PetState.has_mess:
		JimothyAudio.play("rustle", -5.0)


func _on_heal_pressed() -> void:
	PetState.treat_illness()


func _on_message_ok() -> void:
	message_panel.visible = false
	btn_message_ok.text = "OK"
	# Legacy path: only reset if somehow still dead when dismissing.
	if _awaiting_new_kit or not PetState.alive:
		_awaiting_new_kit = false
		PetState.reset_pet()
		_refresh()
