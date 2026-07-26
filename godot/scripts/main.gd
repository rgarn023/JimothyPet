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
@onready var btn_action: Button = %BtnAction
@onready var btn_settings: Button = %BtnSettings
var btn_clean: Button
var btn_sound: Button
var btn_alerts: Button
var btn_reset: Button
var btn_feed: Button
var btn_play: Button
var btn_scold: Button
var btn_heal: Button
var btn_sfx: Button
@onready var utility_row: HBoxContainer = $Margin/VBox/UtilityRow
@onready var brand_label: Label = $Margin/VBox/Brand
@onready var feed_panel: Control = %FeedPanel
@onready var message_panel: Control = %MessagePanel
@onready var message_title: Label = %MessageTitle
@onready var message_body: Label = %MessageBody
@onready var dumpster: Control = %DumpsterDive
@onready var btn_message_ok: Button = %BtnMessageOk
@onready var device_panel: PanelContainer = $Margin/VBox/Device
@onready var screen_panel: PanelContainer = $Margin/VBox/Device/DeviceMargin/DeviceVBox/Screen

var btn_dev: Button
var _speech_timer: SceneTreeTimer
var _awaiting_new_kit: bool = false
var _open_schedule_after_message: bool = false
var _stage_celebrating: bool = false
var _pending_stage_title: String = ""
var _pending_stage_body: String = ""
var _was_daytime: int = -1
var _forms_panel: ColorRect
var _forms_list: VBoxContainer
var _dev_panel: ColorRect
var _dev_status: Label
var _dev_stat_labels: Dictionary = {}
var _play_pick_panel: ColorRect
var _dice: ColorRect
var _reset_panel: ColorRect
var _action_panel: ColorRect
var _sound_panel: ColorRect
var _settings_panel: ColorRect
var _schedule_panel: ColorRect
var _wake_option: OptionButton
var _sleep_option: OptionButton
var _brand_tap_times: Array[float] = []


func _ready() -> void:
	_make_panels_transparent()
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
	if _forms_panel:
		_forms_panel.visible = false
	_build_dev_panel()
	_build_play_pick_panel()
	_build_dice_panel()
	_build_reset_panel()
	_build_action_panel()
	_build_sound_panel()
	_build_settings_panel()
	_build_schedule_panel()
	_wire_brand_secret()
	_refresh_sound_buttons()
	_refresh_alerts_button()
	_apply_day_night_text_colors()
	_refresh()
	# Dead / leftover saves: wait for player to start a new session (no auto bush).
	if PetState.ascending:
		pass  # raccoon_view resumes ascend anim
	elif not PetState.alive:
		_prompt_new_session_after_ascend()
	elif not PetState.schedule_set:
		_open_schedule_panel()


func _is_daytime() -> bool:
	var t := Time.get_time_dict_from_system()
	var h := float(t.hour) + float(t.minute) / 60.0
	return h >= 6.0 and h < 20.0


func _apply_day_night_text_colors() -> void:
	var day := _is_daytime()
	var brand := Color("6a3f0c") if day else Color("f0c57a")
	var muted := Color("2f4536") if day else Color("a8b8aa")
	var ink := Color("15241a") if day else Color("eef5ea")
	# Hint sits on the live forest backdrop — need stronger contrast than muted UI text.
	var hint_col := Color("102018") if day else Color("f4f7f0")
	var hint_shadow := Color(1, 1, 1, 0.82) if day else Color(0.02, 0.05, 0.03, 0.9)
	if brand_label:
		brand_label.add_theme_color_override("font_color", brand)
	var tagline := get_node_or_null("Margin/VBox/Tagline") as Label
	if tagline:
		tagline.add_theme_color_override("font_color", muted)
	if hint_label:
		hint_label.add_theme_color_override("font_color", hint_col)
		hint_label.add_theme_color_override("font_shadow_color", hint_shadow)
		hint_label.add_theme_constant_override("shadow_offset_x", 0)
		hint_label.add_theme_constant_override("shadow_offset_y", 1)
		hint_label.add_theme_constant_override("outline_size", 4)
		hint_label.add_theme_color_override("font_outline_color", hint_shadow)
		hint_label.add_theme_font_size_override("font_size", 15)
	if stage_name:
		stage_name.add_theme_color_override("font_color", brand)
	if clock_label:
		clock_label.add_theme_color_override("font_color", brand)
	if age_label:
		age_label.add_theme_color_override("font_color", brand)
	if stage_chip:
		stage_chip.add_theme_color_override("font_color", brand)
	if alert_banner:
		alert_banner.add_theme_color_override("font_color", brand)
	for path in [
		"Margin/VBox/Device/DeviceMargin/DeviceVBox/Screen/ScreenMargin/ScreenVBox/Meters/HungerRow/L",
		"Margin/VBox/Device/DeviceMargin/DeviceVBox/Screen/ScreenMargin/ScreenVBox/Meters/HappyRow/L",
		"Margin/VBox/Device/DeviceMargin/DeviceVBox/Screen/ScreenMargin/ScreenVBox/Meters/HealthRow/L",
		"Margin/VBox/Device/DeviceMargin/DeviceVBox/Screen/ScreenMargin/ScreenVBox/Meters/DisciplineRow/L",
	]:
		var lab := get_node_or_null(path) as Label
		if lab:
			lab.add_theme_color_override("font_color", muted if day else Color("9aab9c"))
	if speech_label:
		if day:
			speech_label.add_theme_color_override("font_color", ink)
			speech_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.75))
		else:
			speech_label.add_theme_color_override("font_color", Color("1b2a22"))
			speech_label.add_theme_color_override("font_shadow_color", Color(0.91, 0.937, 0.894, 1))


func _make_panels_transparent() -> void:
	var empty := StyleBoxEmpty.new()
	if device_panel:
		device_panel.add_theme_stylebox_override("panel", empty)
	if screen_panel:
		screen_panel.add_theme_stylebox_override("panel", empty)


func _process(_delta: float) -> void:
	clock_label.text = Time.get_time_string_from_system().substr(0, 5)
	var day_i := 1 if _is_daytime() else 0
	if day_i != _was_daytime:
		_was_daytime = day_i
		_apply_day_night_text_colors()


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

	var sleep_on := Button.new()
	sleep_on.text = "Put to sleep"
	sleep_on.pressed.connect(func(): PetState.dev_set_sleep(true); _refresh_dev_panel())
	list.add_child(sleep_on)
	var sleep_off := Button.new()
	sleep_off.text = "Wake up"
	sleep_off.pressed.connect(func(): PetState.dev_set_sleep(false); _refresh_dev_panel())
	list.add_child(sleep_off)

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
		_dev_status.text = "Dev Mode: %s · Waste: %s · Sick: %s · Stubborn: %s · Sleep: %s\nStage: %s · %s" % [
			"ON" if PetState.dev_mode else "OFF",
			"%d/%d" % [PetState.mess_count, PetState.MAX_MESS],
			"yes" if PetState.sick else "no",
			"yes" if PetState.stubborn else "no",
			"yes" if PetState.is_sleeping() else "no",
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
	body.text = "Are you sure you want to proceed? Starts a new rustling bush. Unlocked forms stay."
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
	ok.text = "Yes, reset"
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_confirm_reset)
	row.add_child(ok)


func _build_menu_panel(title_text: String) -> Dictionary:
	var dim := ColorRect.new()
	dim.visible = false
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.05, 0.04, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -150
	card.offset_right = 150
	card.offset_top = -150
	card.offset_bottom = 150
	dim.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
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
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	return {"dim": dim, "vbox": vbox}


func _build_action_panel() -> void:
	var built := _build_menu_panel("Actions")
	_action_panel = built.dim
	var vbox: VBoxContainer = built.vbox

	btn_feed = Button.new()
	btn_feed.text = "Feed"
	btn_feed.pressed.connect(_on_feed_pressed)
	vbox.add_child(btn_feed)

	btn_play = Button.new()
	btn_play.text = "Play"
	btn_play.pressed.connect(_on_play_pressed)
	vbox.add_child(btn_play)

	btn_scold = Button.new()
	btn_scold.text = "Scold"
	btn_scold.disabled = true
	btn_scold.tooltip_text = "Scold him when he’s acting up"
	btn_scold.pressed.connect(_on_scold_pressed)
	vbox.add_child(btn_scold)

	btn_heal = Button.new()
	btn_heal.text = "Heal"
	btn_heal.disabled = true
	btn_heal.tooltip_text = "Heal him when he’s sick"
	btn_heal.pressed.connect(_on_heal_pressed)
	vbox.add_child(btn_heal)

	btn_clean = Button.new()
	btn_clean.text = "Clean"
	btn_clean.disabled = true
	btn_clean.tooltip_text = "Clean one waste pile"
	btn_clean.pressed.connect(_on_clean_pressed)
	vbox.add_child(btn_clean)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): _action_panel.visible = false)
	vbox.add_child(close)


func _build_settings_panel() -> void:
	var built := _build_menu_panel("Settings")
	_settings_panel = built.dim
	var vbox: VBoxContainer = built.vbox

	btn_sound = Button.new()
	btn_sound.text = "Sound"
	btn_sound.tooltip_text = "Jimothy sounds"
	btn_sound.pressed.connect(_on_sound_pressed)
	vbox.add_child(btn_sound)

	btn_alerts = Button.new()
	btn_alerts.text = "Alerts: Off"
	btn_alerts.pressed.connect(_on_alerts_pressed)
	vbox.add_child(btn_alerts)

	btn_reset = Button.new()
	btn_reset.text = "Reset"
	btn_reset.tooltip_text = "Start a new bush (keeps unlocked forms)"
	btn_reset.pressed.connect(_on_reset_pressed)
	vbox.add_child(btn_reset)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): _settings_panel.visible = false)
	vbox.add_child(close)


func _build_sound_panel() -> void:
	var built := _build_menu_panel("Sound")
	_sound_panel = built.dim
	var vbox: VBoxContainer = built.vbox

	var copy := Label.new()
	copy.text = "Toggle Jimothy’s raccoon sounds."
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_color_override("font_color", Color("9aab9c"))
	copy.add_theme_font_size_override("font_size", 13)
	vbox.add_child(copy)

	btn_sfx = Button.new()
	btn_sfx.text = "Jimothy: On"
	btn_sfx.tooltip_text = "Jimothy raccoon sounds"
	btn_sfx.pressed.connect(_on_sfx_pressed)
	vbox.add_child(btn_sfx)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): _sound_panel.visible = false)
	vbox.add_child(close)


func _hour_label(h: int) -> String:
	var hr := ((h % 24) + 24) % 24
	var suffix := "PM" if hr >= 12 else "AM"
	var twelve := 12 if hr % 12 == 0 else hr % 12
	return "%d:00 %s" % [twelve, suffix]


func _build_schedule_panel() -> void:
	var built := _build_menu_panel("Jimothy’s schedule")
	_schedule_panel = built.dim
	var vbox: VBoxContainer = built.vbox

	var copy := Label.new()
	copy.text = "Set when he wakes and when he sleeps. He’ll doze during sleep hours."
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_color_override("font_color", Color("9aab9c"))
	copy.add_theme_font_size_override("font_size", 13)
	vbox.add_child(copy)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var wake_box := VBoxContainer.new()
	var wake_l := Label.new()
	wake_l.text = "Wake"
	wake_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wake_box.add_child(wake_l)
	_wake_option = OptionButton.new()
	for h in 24:
		_wake_option.add_item(_hour_label(h), h)
	wake_box.add_child(_wake_option)
	row.add_child(wake_box)

	var sleep_box := VBoxContainer.new()
	var sleep_l := Label.new()
	sleep_l.text = "Sleep"
	sleep_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sleep_box.add_child(sleep_l)
	_sleep_option = OptionButton.new()
	for h in 24:
		_sleep_option.add_item(_hour_label(h), h)
	sleep_box.add_child(_sleep_option)
	row.add_child(sleep_box)

	var save_btn := Button.new()
	save_btn.text = "Save schedule"
	save_btn.pressed.connect(_on_schedule_save)
	vbox.add_child(save_btn)


func _open_schedule_panel() -> void:
	if _wake_option:
		_wake_option.select(PetState.wake_hour)
	if _sleep_option:
		_sleep_option.select(PetState.sleep_hour)
	if _schedule_panel:
		_schedule_panel.visible = true


func _on_schedule_save() -> void:
	var wake := _wake_option.get_selected_id() if _wake_option else 7
	var sleep := _sleep_option.get_selected_id() if _sleep_option else 22
	if not PetState.set_schedule(wake, sleep):
		PetState.speech.emit("Wake and sleep can’t be the same hour.")
		return
	if _schedule_panel:
		_schedule_panel.visible = false
	PetState.speech.emit(
		"Schedule set — wakes %s, sleeps %s." % [_hour_label(wake), _hour_label(sleep)]
	)
	_refresh()


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
	elif _stage_celebrating:
		mood = "stageUp"
	elif PetState.is_sleeping():
		mood = "sleep"
	elif PetState.sick:
		mood = "sick"
	elif PetState.stubborn:
		mood = "stubborn"
	raccoon.set_look(PetState.stage, PetState.adult_form, mood)
	PetState.sync_sleep_transition()
	if mess_mark and mess_mark.has_method("set_pile_count"):
		var piles := PetState.mess_count if PetState.alive and not PetState.ascending else 0
		mess_mark.set_pile_count(piles)
	else:
		mess_mark.visible = PetState.has_mess and PetState.alive and not PetState.ascending

	var alert: Dictionary = PetState.alert_text()
	if alert.is_empty():
		alert_banner.visible = false
	else:
		alert_banner.visible = true
		alert_banner.text = str(alert.text)
		alert_banner.modulate = Color("f0b4a8") if alert.get("danger", false) else Color("f0c57a")

	var can_care := PetState.alive and PetState.stage != "bush" and not PetState.ascending
	var can_scold := PetState.alive and PetState.stubborn
	var can_heal := PetState.alive and PetState.sick and PetState.stage != "bush" and not PetState.ascending
	var can_clean := PetState.alive and PetState.mess_count > 0
	if btn_feed:
		btn_feed.disabled = not can_care
	if btn_play:
		btn_play.disabled = not PetState.alive or PetState.stage in ["bush", "baby"] or PetState.ascending
	if btn_scold:
		btn_scold.disabled = not can_scold
	if btn_clean:
		btn_clean.disabled = not can_clean
		btn_clean.text = "Clean (%d)" % PetState.mess_count if PetState.mess_count > 1 else "Clean"
	if btn_heal:
		btn_heal.disabled = not can_heal
	_refresh_sound_buttons()
	_refresh_dev_panel()

	if PetState.ascending:
		hint_label.text = "Watch… Jimothy grows wings and rises into the sky."
	elif PetState.stage == "bush":
		hint_label.text = "Tap the bush — it rustles. Something’s waking…"
	elif not PetState.alive:
		hint_label.text = "His cryptid life is complete. You can raise another kit."
	elif _awaiting_new_kit or (not PetState.alive and not PetState.ascending):
		stage_name.text = "Ascended"
		hint_label.text = "Jimothy has ascended. Start a new session when you’re ready."
	elif PetState.is_sleeping():
		hint_label.text = "Sleep hours — Jimothy is dozing in his nest. He’ll wake at his wake time."
	elif PetState.sick:
		hint_label.text = "He’s under the weather — open Action → Heal."
	elif PetState.stubborn:
		hint_label.text = "He’s acting up — open Action → Scold."
	elif PetState.mess_count > 0:
		hint_label.text = "Waste in the nest — open Action → Clean."
	elif PetState.stage == "baby":
		hint_label.text = "Tap Jimothy for smiles and hops. Too tiny for a full night run yet."
	else:
		hint_label.text = "Tap Jimothy to pet him. Good care lengthens his days."


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
	var title := ""
	var body := ""
	match stage:
		"baby":
			title = "Baby Kit!"
			body = "Jimothy burst from the bush. Keep him fed and cozy."
		"young":
			title = "Young Kit!"
			body = "Form: %s. His teen/adult path is already leaning this way." % PetState.young_form.capitalize()
		"teen":
			title = "Teen Kit!"
			body = "Form: %s. Keep caring — he keeps growing." % PetState.teen_form.capitalize()
		"adult":
			title = "Adult Cryptid!"
			body = "%s Jimothy — care well and he may linger longer; neglect shortens his sky-bound days." % PetState.adult_form_title()
		_:
			return
	_begin_stage_celebration(title, body)


func _begin_stage_celebration(title: String, body: String) -> void:
	_stage_celebrating = true
	_pending_stage_title = title
	_pending_stage_body = body
	_refresh()
	var timer := get_tree().create_timer(10.0)
	timer.timeout.connect(_end_stage_celebration, CONNECT_ONE_SHOT)


func _end_stage_celebration() -> void:
	_stage_celebrating = false
	var title := _pending_stage_title
	var body := _pending_stage_body
	_pending_stage_title = ""
	_pending_stage_body = ""
	_refresh()
	if title != "":
		_show_message(title, body)
		btn_message_ok.text = "OK"


func _on_pet_died(_reason: String) -> void:
	_refresh()
	_awaiting_new_kit = false


func _on_ascend_finished() -> void:
	# Wait until he’s fully gone, then ask — don’t auto-start a new kit.
	_prompt_new_session_after_ascend()


func _death_why() -> String:
	match PetState.death_reason:
		"neglect":
			return "Poor care shortened his time."
		"lifespan":
			return "He lived out his cryptid span."
		_:
			return "His story has ended."


## Ascend finished: Jimothy disappeared. Ask to start a new session (schedule after OK).
func _prompt_new_session_after_ascend() -> void:
	PetState.ascending = false
	if raccoon.has_method("clear_ascend"):
		raccoon.clear_ascend()
	_awaiting_new_kit = true
	_open_schedule_after_message = true
	_refresh()
	_show_message(
		"Jimothy ascended",
		"%s He grew wings and rose into the sky.\n\nStart a new session when you’re ready." % _death_why()
	)
	btn_message_ok.text = "Start new session"


func _show_message(title: String, body: String) -> void:
	message_title.text = title
	message_body.text = body
	if not _awaiting_new_kit:
		btn_message_ok.text = "OK"
	message_panel.visible = true


func _refresh_sound_buttons() -> void:
	var sfx_on := true
	if JimothyAudio:
		sfx_on = JimothyAudio.sfx_on
	elif PetState:
		sfx_on = not PetState.sfx_muted
	if btn_sfx:
		btn_sfx.text = "Jimothy: On" if sfx_on else "Jimothy: Off"


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
		if JimothyNotify and JimothyNotify.has_method("request_permission"):
			JimothyNotify.request_permission()
		elif JimothyNotify and JimothyNotify.has_method("request_permission_web"):
			JimothyNotify.request_permission_web()
		var where := "phone / browser notifications"
		if OS.get_name() == "Android":
			where = "Android notifications — allow the permission prompt if shown (or enable in system Settings)"
		elif OS.has_feature("web"):
			where = "browser notifications (allow the permission prompt)"
		PetState.speech.emit("Care alerts on — %s for hunger, play, acting up, waste, and new forms." % where)
		if JimothyNotify:
			JimothyNotify.check_now()
	else:
		PetState.speech.emit("Care alerts off.")
	PetState.save_game()
	_refresh_alerts_button()


func _on_forms_pressed() -> void:
	_refresh_forms_panel()
	_forms_panel.visible = true


func _on_action_pressed() -> void:
	if JimothyAudio:
		JimothyAudio.play("chirp", -6.0)
	if _action_panel:
		_action_panel.visible = true


func _on_settings_pressed() -> void:
	_refresh_alerts_button()
	if _settings_panel:
		_settings_panel.visible = true


func _on_sound_pressed() -> void:
	if _settings_panel:
		_settings_panel.visible = false
	_refresh_sound_buttons()
	if _sound_panel:
		_sound_panel.visible = true


func _on_reset_pressed() -> void:
	if _settings_panel:
		_settings_panel.visible = false
	if _reset_panel:
		_reset_panel.visible = true


func _confirm_reset() -> void:
	if _reset_panel:
		_reset_panel.visible = false
	PetState.reset_pet()
	if raccoon and raccoon.has_method("clear_ascend"):
		raccoon.clear_ascend()
	if raccoon and raccoon.has_method("reveal"):
		raccoon.reveal()
	_refresh()
	_open_schedule_panel()


func _on_dev_pressed() -> void:
	if not PetState.dev_unlocked:
		return
	# Opening tools implies access; enable cheats if toggle was off.
	if not PetState.dev_mode:
		PetState.set_dev_mode(true)
	_refresh_dev_panel()
	_dev_panel.visible = true


func _on_feed_pressed() -> void:
	if btn_feed and btn_feed.disabled:
		return
	if _action_panel:
		_action_panel.visible = false
	if JimothyAudio:
		JimothyAudio.play("chitter", -6.0)
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
	if btn_play and btn_play.disabled:
		return
	if _action_panel:
		_action_panel.visible = false
	if PetState.can_start_play(true) != "ok":
		return
	if JimothyAudio:
		JimothyAudio.play("rustle", -4.0)
		JimothyAudio.play("chitter", -6.0)
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
	if _action_panel:
		_action_panel.visible = false


func _on_clean_pressed() -> void:
	PetState.clean_mess()
	if _action_panel:
		_action_panel.visible = false
	if JimothyAudio:
		JimothyAudio.play("rustle", -5.0)


func _on_heal_pressed() -> void:
	PetState.treat_illness()
	if _action_panel:
		_action_panel.visible = false


func _on_message_ok() -> void:
	message_panel.visible = false
	btn_message_ok.text = "OK"
	# After ascend: start a new session, then ask for wake/sleep times.
	if _awaiting_new_kit or not PetState.alive:
		_awaiting_new_kit = false
		PetState.reset_pet()
		# Reveal AFTER reset so clear_ascend/reveal see an alive bush kit.
		if raccoon and raccoon.has_method("clear_ascend"):
			raccoon.clear_ascend()
		if raccoon and raccoon.has_method("reveal"):
			raccoon.reveal()
		_refresh()
		_open_schedule_after_message = false
		_open_schedule_panel()
		return
	if _open_schedule_after_message or not PetState.schedule_set:
		_open_schedule_after_message = false
		_open_schedule_panel()
