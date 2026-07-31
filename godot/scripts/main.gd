extends Control
## Main Jimothy pet UI (Godot 4.7.1).

const VisualPolish = preload("res://scripts/visual_polish.gd")

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

var _speech_timer: SceneTreeTimer
var _awaiting_new_kit: bool = false
var _open_schedule_after_message: bool = false
var _stage_celebrating: bool = false
var _pending_stage_title: String = ""
var _pending_stage_body: String = ""
var _was_daytime: int = -1
var _forms_panel: ColorRect
var _forms_list: VBoxContainer
var _play_pick_panel: ColorRect
var _dice: ColorRect
var _reset_panel: ColorRect
var _action_panel: ColorRect
var _sound_panel: ColorRect
var _settings_panel: ColorRect
var _schedule_panel: ColorRect
var _language_panel: ColorRect
var _lang_option: OptionButton
var _wake_option: OptionButton
var _sleep_option: OptionButton
var _settings_title: Label
var _settings_close: Button
var _action_title: Label
var _action_close: Button
var _sound_title: Label
var _sound_copy: Label
var _sound_close: Button
var _btn_language: Button


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
	_build_play_pick_panel()
	_build_dice_panel()
	_build_reset_panel()
	_build_action_panel()
	_build_sound_panel()
	_build_settings_panel()
	_build_schedule_panel()
	_build_language_panel()
	if JimothyI18n:
		JimothyI18n.locale_changed.connect(func(_code: String): _refresh_localized_ui())
	_refresh_sound_buttons()
	_refresh_alerts_button()
	_refresh_localized_ui()
	_apply_day_night_text_colors()
	_add_version_label()
	_refresh()
	# Dead / leftover saves: wait for player to start a new session (no auto bush).
	if PetState.ascending:
		pass  # raccoon_view resumes ascend anim
	elif not PetState.alive:
		_prompt_new_session_after_ascend()
	elif not PetState.schedule_set:
		_open_schedule_panel()



func _add_version_label() -> void:
	var lab := Label.new()
	lab.name = "VersionLabel"
	lab.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "?"))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lab.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", Color(0.75, 0.82, 0.72, 0.55))
	lab.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	lab.offset_left = -120
	lab.offset_top = -28
	lab.offset_right = -10
	lab.offset_bottom = -8
	add_child(lab)


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
		# Stage label sits on the clearing floor — amber alone washes out on dirt/leaves.
		var stage_col := Color("1a1208") if day else Color("fff8e8")
		var stage_outline := Color(1, 1, 1, 0.88) if day else Color(0.05, 0.04, 0.02, 0.92)
		stage_name.add_theme_color_override("font_color", stage_col)
		stage_name.add_theme_color_override("font_outline_color", stage_outline)
		stage_name.add_theme_constant_override("outline_size", 5)
		stage_name.add_theme_color_override("font_shadow_color", stage_outline)
		stage_name.add_theme_constant_override("shadow_offset_x", 0)
		stage_name.add_theme_constant_override("shadow_offset_y", 1)
		stage_name.add_theme_font_size_override("font_size", 17)
	if clock_label:
		clock_label.add_theme_color_override("font_color", brand)
	if age_label:
		age_label.add_theme_color_override("font_color", brand)
	if stage_chip:
		stage_chip.add_theme_color_override("font_color", brand)
	if alert_banner:
		var alert_col := Color("5a3208") if day else Color("ffe7b0")
		alert_banner.add_theme_color_override("font_color", alert_col)
		alert_banner.add_theme_color_override("font_outline_color", hint_shadow)
		alert_banner.add_theme_constant_override("outline_size", 3)
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
	_action_title = built.vbox.get_child(0) as Label
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

	_action_close = Button.new()
	_action_close.text = "Close"
	_action_close.pressed.connect(func(): _action_panel.visible = false)
	vbox.add_child(_action_close)


func _build_settings_panel() -> void:
	var built := _build_menu_panel("Settings")
	_settings_panel = built.dim
	_settings_title = built.vbox.get_child(0) as Label
	var vbox: VBoxContainer = built.vbox

	btn_sound = Button.new()
	btn_sound.text = "Sound"
	btn_sound.tooltip_text = "Jimothy sounds"
	btn_sound.pressed.connect(_on_sound_pressed)
	vbox.add_child(btn_sound)

	_btn_language = Button.new()
	_btn_language.text = "Language"
	_btn_language.pressed.connect(_on_language_pressed)
	vbox.add_child(_btn_language)

	btn_alerts = Button.new()
	btn_alerts.text = "Alerts: Off"
	btn_alerts.pressed.connect(_on_alerts_pressed)
	vbox.add_child(btn_alerts)

	btn_reset = Button.new()
	btn_reset.text = "Reset"
	btn_reset.tooltip_text = "Start a new bush (keeps unlocked forms)"
	btn_reset.pressed.connect(_on_reset_pressed)
	vbox.add_child(btn_reset)

	_settings_close = Button.new()
	_settings_close.text = "Close"
	_settings_close.pressed.connect(func(): _settings_panel.visible = false)
	vbox.add_child(_settings_close)


func _build_sound_panel() -> void:
	var built := _build_menu_panel("Sound")
	_sound_panel = built.dim
	_sound_title = built.vbox.get_child(0) as Label
	var vbox: VBoxContainer = built.vbox

	_sound_copy = Label.new()
	_sound_copy.text = "Toggle Jimothy’s raccoon sounds."
	_sound_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sound_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sound_copy.add_theme_color_override("font_color", Color("9aab9c"))
	_sound_copy.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_sound_copy)

	btn_sfx = Button.new()
	btn_sfx.text = "Jimothy: On"
	btn_sfx.tooltip_text = "Jimothy raccoon sounds"
	btn_sfx.pressed.connect(_on_sfx_pressed)
	vbox.add_child(btn_sfx)

	_sound_close = Button.new()
	_sound_close.text = "Close"
	_sound_close.pressed.connect(func(): _sound_panel.visible = false)
	vbox.add_child(_sound_close)


func _build_language_panel() -> void:
	var built := _build_menu_panel("Language")
	_language_panel = built.dim
	var vbox: VBoxContainer = built.vbox

	var copy := Label.new()
	copy.name = "LangCopy"
	copy.text = "Choose the app language. Matches Google Play storefront languages."
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_color_override("font_color", Color("9aab9c"))
	copy.add_theme_font_size_override("font_size", 13)
	vbox.add_child(copy)

	_lang_option = OptionButton.new()
	_lang_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if JimothyI18n:
		for entry in JimothyI18n.locales():
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var code := str(entry.get("code", ""))
			var name := str(entry.get("name", code))
			_lang_option.add_item(name)
			_lang_option.set_item_metadata(_lang_option.item_count - 1, code)
	vbox.add_child(_lang_option)
	_sync_language_option()

	var apply_btn := Button.new()
	apply_btn.name = "LangApply"
	apply_btn.text = "Save"
	apply_btn.pressed.connect(_on_language_apply)
	vbox.add_child(apply_btn)

	var close := Button.new()
	close.name = "LangClose"
	close.text = "Close"
	close.pressed.connect(func(): _language_panel.visible = false)
	vbox.add_child(close)


func _sync_language_option() -> void:
	if _lang_option == null:
		return
	var want := ""
	if PetState:
		want = str(PetState.locale_code)
	for i in _lang_option.item_count:
		if str(_lang_option.get_item_metadata(i)) == want:
			_lang_option.select(i)
			return
	if _lang_option.item_count > 0:
		_lang_option.select(0)


func _on_language_pressed() -> void:
	_sync_language_option()
	if _language_panel:
		_language_panel.visible = true


func _on_language_apply() -> void:
	if _lang_option == null or JimothyI18n == null:
		return
	var idx := _lang_option.selected
	var code := str(_lang_option.get_item_metadata(idx))
	JimothyI18n.apply_locale(code, true)
	if _language_panel:
		_language_panel.visible = false
	PetState.speech.emit(JimothyI18n.t("LANGUAGE", "Language"))


func _t(key: String, fallback: String) -> String:
	if JimothyI18n:
		return JimothyI18n.t(key, fallback)
	return fallback


func _refresh_localized_ui() -> void:
	if btn_action:
		btn_action.text = _t("ACTION", "Action")
	if btn_settings:
		btn_settings.text = _t("SETTINGS", "Settings")
	if _settings_title:
		_settings_title.text = _t("SETTINGS", "Settings")
	if btn_sound:
		btn_sound.text = _t("SOUND", "Sound")
	if _btn_language:
		_btn_language.text = _t("LANGUAGE", "Language")
	if btn_reset:
		btn_reset.text = _t("RESET", "Reset")
	if _settings_close:
		_settings_close.text = _t("CLOSE", "Close")
	if _action_title:
		_action_title.text = _t("ACTION", "Action")
	if btn_feed:
		btn_feed.text = _t("FEED", "Feed")
	if btn_play:
		btn_play.text = _t("PLAY", "Play")
	if btn_scold:
		btn_scold.text = _t("SCOLD", "Scold")
	if btn_heal:
		btn_heal.text = _t("HEAL", "Heal")
	if btn_clean and PetState:
		if PetState.mess_count > 1:
			btn_clean.text = "%s (%d)" % [_t("CLEAN", "Clean"), PetState.mess_count]
		else:
			btn_clean.text = _t("CLEAN", "Clean")
	elif btn_clean:
		btn_clean.text = _t("CLEAN", "Clean")
	if _action_close:
		_action_close.text = _t("CLOSE", "Close")
	if _sound_title:
		_sound_title.text = _t("SOUND", "Sound")
	if _sound_copy:
		_sound_copy.text = _t("SOUND_COPY", "Toggle Jimothy’s raccoon sounds.")
	if _sound_close:
		_sound_close.text = _t("CLOSE", "Close")
	if _language_panel:
		var lang_title_lbl: Label = null
		# Title is the first Label inside the card vbox.
		for child in _language_panel.find_children("*", "Label", true, false):
			if child.name == "LangCopy":
				child.text = _t(
					"LANGUAGE_COPY",
					"Choose the app language. Matches Google Play storefront languages."
				)
			elif lang_title_lbl == null:
				lang_title_lbl = child
				lang_title_lbl.text = _t("LANGUAGE", "Language")
		var apply_btn := _language_panel.find_child("LangApply", true, false)
		if apply_btn:
			apply_btn.text = "OK"
		var close_btn := _language_panel.find_child("LangClose", true, false)
		if close_btn:
			close_btn.text = _t("CLOSE", "Close")
	_refresh_sound_buttons()
	_refresh_alerts_button()
	_refresh()


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
	elif PetState.is_sleeping():
		# Sleep wins over stage celebration — hatch-at-night stays a nest nap.
		mood = "sleep"
	elif _stage_celebrating:
		mood = "stageUp"
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
		btn_clean.text = _t("CLEAN", "Clean")
	if PetState.mess_count > 1:
		btn_clean.text = "%s (%d)" % [_t("CLEAN", "Clean"), PetState.mess_count]
	if btn_heal:
		btn_heal.disabled = not can_heal
	_refresh_sound_buttons()

	if PetState.ascending:
		hint_label.text = "Watch… Jimothy grows wings and rises into the sky."
	elif PetState.stage == "bush":
		hint_label.text = "Tap the bush — it rustles. Something’s waking…"
	elif _awaiting_new_kit:
		stage_name.text = "Ascended"
		hint_label.text = _t(
			"HINT_ASCENDED",
			"Jimothy has ascended. Start a new session when you’re ready."
		)
	elif not PetState.alive:
		hint_label.text = "His cryptid life is complete. You can raise another kit."
	elif PetState.is_sleeping():
		hint_label.text = _t(
			"HINT_SLEEP",
			"Shh — Jimothy is sleeping. He’ll wake on his schedule."
		)
	elif PetState.sick:
		hint_label.text = "He’s under the weather — open Action → Heal."
	elif PetState.stubborn:
		hint_label.text = "He’s acting up — open Action → Scold."
	elif PetState.mess_count > 0:
		hint_label.text = "Waste in the nest — open Action → Clean."
	elif PetState.stage == "baby":
		hint_label.text = "Tap Jimothy for smiles and hops. Too tiny for full games yet."
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
	# Hatch during sleep hours: no awake celebration choreography.
	if stage == "baby" and PetState.is_sleeping():
		_refresh()
		_show_message(
			"Baby Kit!",
			"Jimothy burst from the bush during sleep hours and went straight to nest."
		)
		btn_message_ok.text = "OK"
		return
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
		btn_sfx.text = _t("JIMOTHY_ON", "Jimothy: On") if sfx_on else _t("JIMOTHY_OFF", "Jimothy: Off")


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
	if not PetState.alerts_enabled:
		btn_alerts.text = _t("ALERTS_OFF", "Alerts: Off")
		return
	if JimothyNotify and JimothyNotify.has_method("os_permission_granted") \
			and not JimothyNotify.os_permission_granted():
		btn_alerts.text = _t("ALERTS_ALLOW", "Alerts: Allow")
	else:
		btn_alerts.text = _t("ALERTS_ON", "Alerts: On")


func _on_alerts_pressed() -> void:
	# If alerts are on but OS permission is missing, tapping retries the prompt
	# instead of turning alerts off.
	if PetState.alerts_enabled and JimothyNotify \
			and JimothyNotify.has_method("os_permission_granted") \
			and not JimothyNotify.os_permission_granted():
		if JimothyNotify.has_method("request_permission"):
			JimothyNotify.request_permission()
		PetState.speech.emit("Allow notifications on the permission prompt (or enable them in phone Settings).")
		_refresh_alerts_button()
		return

	PetState.alerts_enabled = not PetState.alerts_enabled
	if PetState.alerts_enabled:
		if JimothyNotify and JimothyNotify.has_method("request_permission"):
			JimothyNotify.request_permission()
		elif JimothyNotify and JimothyNotify.has_method("request_permission_web"):
			JimothyNotify.request_permission_web()
		PetState.speech.emit(
			"Care alerts on — form changes, mess, boredom, and acting up (not hunger, health, or ascending)."
		)
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


func _on_feed_pressed() -> void:
	if btn_feed and btn_feed.disabled:
		return
	if _action_panel:
		_action_panel.visible = false
	if JimothyAudio:
		JimothyAudio.play("chitter", -6.0)
	_refresh_feed_menu_effects()
	feed_panel.visible = true


func _on_feed_close() -> void:
	feed_panel.visible = false


func _on_food(food_key: String) -> void:
	PetState.try_feed(food_key)
	feed_panel.visible = false


func _refresh_feed_menu_effects() -> void:
	# Exact PetState FOOD effects on each button — balance unchanged.
	var map := {
		"BtnBerries": "berries",
		"BtnCrickets": "crickets",
		"BtnFish": "fish",
		"BtnPizza": "pizza",
		"BtnFries": "fries",
	}
	for btn_name in map.keys():
		var btn := feed_panel.find_child(str(btn_name), true, false) as Button
		if btn == null:
			continue
		btn.text = VisualPolish.food_effect_line(str(map[btn_name]))
	var copy := feed_panel.find_child("FeedCopy", true, false) as Label
	if copy:
		copy.text = "Real forage fills him properly. Alley junk lifts mood but taxes health. He won’t eat if already stuffed. Numbers show exact Hunger / Mood / Health / Fitness deltas."


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
