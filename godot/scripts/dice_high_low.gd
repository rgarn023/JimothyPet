extends ColorRect
## High or Low — spinning d20 guess game (self-contained overlay).

signal finished(correct: bool, roll: int, guess: String)

var _status: Label
var _num: Label
var _btn_low: Button
var _btn_high: Button
var _btn_again: Button
var _btn_done: Button
var _die: Control
var _picks: HBoxContainer

var _rolling := false
var _guess := ""
var _result := 0
var _spin_t := 0.0
var _spin_dur := 2.4
var _landed := false
var _correct := false
var _reported := false
var _rx := -18.0
var _ry := 22.0
var _scale := 1.0


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.03, 0.05, 0.04, 0.82)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -180
	card.offset_right = 180
	card.offset_top = -260
	card.offset_bottom = 260
	add_child(card)

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
	title.text = "High or Low"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("f0c57a"))
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	_status = Label.new()
	_status.text = "Guess High (11–20) or Low (1–10), then watch the d20 tumble."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color("9aab9c"))
	_status.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_status)

	_die = Control.new()
	_die.custom_minimum_size = Vector2(0, 180)
	_die.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_die.draw.connect(_on_die_draw)
	vbox.add_child(_die)

	_num = Label.new()
	_num.text = "?"
	_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_num.add_theme_color_override("font_color", Color("f0c57a"))
	_num.add_theme_font_size_override("font_size", 42)
	vbox.add_child(_num)

	_picks = HBoxContainer.new()
	_picks.add_theme_constant_override("separation", 8)
	vbox.add_child(_picks)

	_btn_low = Button.new()
	_btn_low.text = "Low · 1–10"
	_btn_low.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_low.pressed.connect(_on_low)
	_picks.add_child(_btn_low)

	_btn_high = Button.new()
	_btn_high.text = "High · 11–20"
	_btn_high.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_high.pressed.connect(_on_high)
	_picks.add_child(_btn_high)

	_btn_again = Button.new()
	_btn_again.text = "Roll again"
	_btn_again.visible = false
	_btn_again.pressed.connect(_on_again)
	vbox.add_child(_btn_again)

	_btn_done = Button.new()
	_btn_done.text = "Done"
	_btn_done.pressed.connect(_on_done)
	vbox.add_child(_btn_done)


func start_game() -> void:
	_reset()
	visible = true


func _reset() -> void:
	_rolling = false
	_guess = ""
	_result = 0
	_spin_t = 0.0
	_landed = false
	_correct = false
	_reported = false
	_rx = -18.0
	_ry = 22.0
	_scale = 1.0
	_picks.visible = true
	_btn_again.visible = false
	_num.text = "?"
	_num.add_theme_color_override("font_color", Color("f0c57a"))
	_status.text = "Guess High (11–20) or Low (1–10), then watch the d20 tumble."
	_die.queue_redraw()


func _on_low() -> void:
	_pick("low")


func _on_high() -> void:
	_pick("high")


func _pick(guess: String) -> void:
	if _rolling:
		return
	_guess = guess
	_result = randi_range(1, 20)
	_rolling = true
	_landed = false
	_reported = false
	_spin_t = 0.0
	_picks.visible = false
	_btn_again.visible = false
	_status.text = "You called High (11–20)…" if guess == "high" else "You called Low (1–10)…"


func _process(delta: float) -> void:
	if not visible:
		return
	if _rolling:
		_spin_t += delta / _spin_dur
		var u := clampf(_spin_t, 0.0, 1.0)
		if u < 0.85:
			_num.text = str(randi_range(1, 20))
		else:
			_num.text = str(_result)
		var wobble := (1.0 - u) * 28.0
		var tms := Time.get_ticks_msec() * 0.001
		_rx = sin(tms * 20.0) * wobble + u * 1080.0
		_ry = cos(tms * 17.0) * wobble + u * 1440.0
		_scale = 1.0 + sin(u * PI) * 0.18
		_die.queue_redraw()
		if u >= 1.0:
			_finish()
	elif visible:
		_die.queue_redraw()


func _finish() -> void:
	_rolling = false
	_landed = true
	_rx = -18.0
	_ry = 22.0
	_scale = 1.0
	_num.text = str(_result)
	var is_high := _result >= 11
	_correct = (_guess == "high" and is_high) or (_guess == "low" and not is_high)
	var band := "High" if is_high else "Low"
	if _correct:
		_status.text = "d20 shows %d — %s! Jimothy is thrilled." % [_result, band]
		_num.add_theme_color_override("font_color", Color("b8e0c0"))
	else:
		_status.text = "d20 shows %d — %s. Jimothy droops." % [_result, band]
		_num.add_theme_color_override("font_color", Color("f0b4a8"))
	_btn_again.visible = true
	_die.queue_redraw()
	if not _reported:
		_reported = true
		finished.emit(_correct, _result, _guess)


func _on_again() -> void:
	_reset()


func _on_done() -> void:
	visible = false
	_rolling = false


func _on_die_draw() -> void:
	var c := _die.size * 0.5 + Vector2(0, 8)
	# Shadow
	_die.draw_colored_polygon(_ellipse_pts(c + Vector2(0, 62), Vector2(48, 10)), Color(0, 0, 0, 0.35))

	var col_a := Color("6b5aa0")
	var col_b := Color("3a2f5c")
	if _landed:
		col_a = Color("6fbf84") if _correct else Color("c45c4a")
		col_b = col_a.darkened(0.35)

	var s := 50.0 * _scale
	var pts := PackedVector2Array([
		c + Vector2(0, -s),
		c + Vector2(s * 0.95, -s * 0.25),
		c + Vector2(s * 0.6, s * 0.85),
		c + Vector2(-s * 0.6, s * 0.85),
		c + Vector2(-s * 0.95, -s * 0.25),
	])
	var shear := sin(deg_to_rad(_ry)) * (8.0 if not _landed else 2.0)
	for i in pts.size():
		pts[i] += Vector2(shear, sin(deg_to_rad(_rx) + float(i) * 0.7) * (5.0 if not _landed else 0.0))

	_die.draw_colored_polygon(pts, col_a)
	_die.draw_polyline(pts + PackedVector2Array([pts[0]]), Color("f0c57a"), 2.2, true)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c.lerp(p, 0.7))
	_die.draw_colored_polygon(inner, col_b)
	if not _landed:
		_die.draw_line(pts[0], pts[2], Color(1, 1, 1, 0.18), 2.0)
		_die.draw_line(pts[1], pts[3], Color(1, 1, 1, 0.12), 2.0)


func _ellipse_pts(center: Vector2, radii: Vector2, n: int = 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts
