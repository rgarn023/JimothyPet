extends ColorRect
## High or Low — true 3D icosahedron d20 (projected), spinning guess game.

signal finished(correct: bool, roll: int, guess: String)

const PHI := 1.61803398875
const FACE_NUMS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11]

var _status: Label
var _btn_low: Button
var _btn_high: Button
var _btn_again: Button
var _btn_done: Button
var _die: Control
var _picks: HBoxContainer

var _verts: Array[Vector3] = []
var _faces: Array = [] # Array of PackedInt32Array
var _normals: Array[Vector3] = []

var _rolling := false
var _guess := ""
var _result := 0
var _spin_t := 0.0
var _spin_dur := 2.6
var _landed := false
var _correct := false
var _reported := false
var _idle := false

var _rot := Vector3(-0.35, 0.45, 0.1)
var _target_rot := Vector3(-0.35, 0.45, 0.1)
var _start_rot := Vector3.ZERO
var _tumble := Vector3.ZERO
var _land_fx_t := 0.0
var _sparkles: Array = []


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.03, 0.05, 0.04, 0.82)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_mesh()
	_build()


func _build_mesh() -> void:
	var raw: Array[Vector3] = [
		Vector3(0, 1, PHI), Vector3(0, -1, PHI), Vector3(0, 1, -PHI), Vector3(0, -1, -PHI),
		Vector3(1, PHI, 0), Vector3(-1, PHI, 0), Vector3(1, -PHI, 0), Vector3(-1, -PHI, 0),
		Vector3(PHI, 0, 1), Vector3(-PHI, 0, 1), Vector3(PHI, 0, -1), Vector3(-PHI, 0, -1),
	]
	_verts.clear()
	for v in raw:
		_verts.append(v.normalized())

	var face_idx := [
		[0, 1, 8], [0, 8, 4], [0, 4, 5], [0, 5, 9], [0, 9, 1],
		[1, 9, 7], [1, 7, 6], [1, 6, 8], [8, 6, 10], [8, 10, 4],
		[4, 10, 2], [4, 2, 5], [5, 2, 11], [5, 11, 9], [9, 11, 7],
		[3, 6, 7], [3, 7, 11], [3, 11, 2], [3, 2, 10], [3, 10, 6],
	]
	_faces.clear()
	_normals.clear()
	for f in face_idx:
		var a: Vector3 = _verts[f[0]]
		var b: Vector3 = _verts[f[1]]
		var c: Vector3 = _verts[f[2]]
		var n := (b - a).cross(c - a).normalized()
		var center := (a + b + c) / 3.0
		if n.dot(center) < 0.0:
			n = -n
		_faces.append(PackedInt32Array([f[0], f[1], f[2]]))
		_normals.append(n)


func _build() -> void:
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -180
	card.offset_right = 180
	card.offset_top = -270
	card.offset_bottom = 270
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
	_die.custom_minimum_size = Vector2(0, 260)
	_die.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_die.draw.connect(_on_die_draw)
	vbox.add_child(_die)

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
	_idle = true
	set_process(true)
	# Ensure die control has a drawable size before first paint.
	if _die:
		_die.custom_minimum_size = Vector2(260, 260)
		_die.queue_redraw()


func _reset() -> void:
	_rolling = false
	_guess = ""
	_result = 0
	_spin_t = 0.0
	_landed = false
	_correct = false
	_reported = false
	_land_fx_t = 0.0
	_sparkles.clear()
	_rot = Vector3(-0.35, 0.45, 0.1)
	_picks.visible = true
	_btn_again.visible = false
	_btn_low.disabled = false
	_btn_high.disabled = false
	_status.text = "Guess High (11–20) or Low (1–10), then watch the d20 tumble."
	_idle = true
	_die.queue_redraw()


func _on_low() -> void:
	_pick("low")


func _on_high() -> void:
	_pick("high")


func _pick(guess: String) -> void:
	if _rolling:
		return
	_idle = false
	_guess = guess
	_result = randi_range(1, 20)
	_rolling = true
	_landed = false
	_reported = false
	_spin_t = 0.0
	_start_rot = _rot
	_tumble = _start_rot + Vector3(
		TAU * randf_range(3.0, 5.0),
		TAU * randf_range(4.0, 6.0),
		TAU * randf_range(1.0, 2.0)
	)
	var face_i := FACE_NUMS.find(_result)
	if face_i < 0:
		face_i = 0
	_target_rot = _rotation_for_face(face_i)
	_picks.visible = true
	_btn_low.disabled = true
	_btn_high.disabled = true
	_btn_again.visible = false
	_status.text = "You called High (11–20)… rolling!" if guess == "high" else "You called Low (1–10)… rolling!"


func _rotation_for_face(face_index: int) -> Vector3:
	var n: Vector3 = _normals[face_index]
	var yaw := atan2(n.x, n.z)
	var hyp := sqrt(n.x * n.x + n.z * n.z)
	var pitch := -atan2(n.y, hyp)
	return Vector3(pitch + 0.12, -yaw + 0.08, 0.05)


func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


func _process(delta: float) -> void:
	if not visible:
		return
	if _landed:
		_land_fx_t += delta
	if _sparkles.size() > 0:
		var keep: Array = []
		for sp in _sparkles:
			sp.t = float(sp.t) + delta
			if float(sp.t) < float(sp.life):
				keep.append(sp)
		_sparkles = keep
	if _rolling:
		_spin_t += delta / _spin_dur
		var u := clampf(_spin_t, 0.0, 1.0)
		if u < 0.72:
			var p := u / 0.72
			var chaos := 1.0 - p
			var tms := Time.get_ticks_msec() * 0.001
			_rot.x = lerpf(_start_rot.x, _tumble.x, p) + sin(tms * 30.0) * chaos * 0.8
			_rot.y = lerpf(_start_rot.y, _tumble.y, p) + cos(tms * 25.0) * chaos * 0.9
			_rot.z = lerpf(_start_rot.z, _tumble.z, p) + sin(tms * 20.0) * chaos * 0.5
		else:
			var s := _ease_out((u - 0.72) / 0.28)
			_rot = _tumble.lerp(_target_rot, s)
		_die.queue_redraw()
		if u >= 1.0:
			_finish()
	elif _idle:
		_rot.y += delta * 0.7
		_rot.x = -0.35 + sin(Time.get_ticks_msec() * 0.001) * 0.08
		_die.queue_redraw()
	else:
		_die.queue_redraw()


func _finish() -> void:
	_rolling = false
	_landed = true
	_land_fx_t = 0.0
	_rot = _target_rot
	var is_high := _result >= 11
	_correct = (_guess == "high" and is_high) or (_guess == "low" and not is_high)
	var band := "High" if is_high else "Low"
	var call_txt := "High" if _guess == "high" else "Low"
	if _correct:
		_status.text = "Call: %s  ·  d20 = %d (%s)  ·  Correct! Jimothy is thrilled." % [call_txt, _result, band]
	else:
		_status.text = "Call: %s  ·  d20 = %d (%s)  ·  Miss. Jimothy droops." % [call_txt, _result, band]
	_btn_again.visible = true
	_picks.visible = true
	_burst_sparkles()
	_die.queue_redraw()
	if not _reported:
		_reported = true
		finished.emit(_correct, _result, _guess)


func _burst_sparkles() -> void:
	_sparkles.clear()
	for i in 12:
		_sparkles.append({
			"a": TAU * float(i) / 12.0 + randf() * 0.2,
			"r": randf_range(18.0, 36.0),
			"t": 0.0,
			"life": randf_range(0.55, 0.95),
			"sz": randf_range(1.6, 3.2),
		})


func _on_again() -> void:
	_reset()


func _on_done() -> void:
	visible = false
	_rolling = false
	_idle = false
	set_process(false)


func _rotate_vec(v: Vector3, r: Vector3) -> Vector3:
	var out := v
	# X
	var y1 := out.y * cos(r.x) - out.z * sin(r.x)
	var z1 := out.y * sin(r.x) + out.z * cos(r.x)
	out = Vector3(out.x, y1, z1)
	# Y
	var x2 := out.x * cos(r.y) + out.z * sin(r.y)
	var z2 := -out.x * sin(r.y) + out.z * cos(r.y)
	out = Vector3(x2, out.y, z2)
	# Z
	var x3 := out.x * cos(r.z) - out.y * sin(r.z)
	var y3 := out.x * sin(r.z) + out.y * cos(r.z)
	return Vector3(x3, y3, out.z)


func _project(v: Vector3, scale: float, cx: float, cy: float) -> Vector3:
	var dist := 3.2
	var z := v.z + dist
	var f := (scale * dist) / z
	return Vector3(cx + v.x * f, cy - v.y * f, z)


func _on_die_draw() -> void:
	var size := _die.size
	var cx := size.x * 0.5
	var cy := size.y * 0.48
	var scale := 96.0

	# Ritual / tabletop circle
	var ring_col := Color(0.55, 0.42, 0.75, 0.35)
	if _landed:
		ring_col = Color(0.45, 0.75, 0.5, 0.45) if _correct else Color(0.75, 0.4, 0.38, 0.45)
	_die.draw_arc(Vector2(cx, cy + 8.0), 92.0, 0.0, TAU, 48, ring_col, 2.2, true)
	_die.draw_arc(Vector2(cx, cy + 8.0), 78.0, 0.0, TAU, 40, Color(ring_col.r, ring_col.g, ring_col.b, ring_col.a * 0.55), 1.2, true)
	for i in 8:
		var ang := float(i) * TAU / 8.0 + Time.get_ticks_msec() * 0.0004
		var rp := Vector2(cx, cy + 8.0) + Vector2(cos(ang), sin(ang)) * 85.0
		_die.draw_circle(rp, 1.6, Color(0.94, 0.77, 0.48, 0.35))

	# Table shadow
	_die.draw_colored_polygon(_ellipse_pts(Vector2(cx, size.y - 18.0), Vector2(64, 13)), Color(0, 0, 0, 0.38))

	# Roll streaks while tumbling
	if _rolling and _spin_t < 0.72:
		for i in 5:
			var ang2 := float(i) * 0.7 + _spin_t * 14.0
			var len := 28.0 + (1.0 - _spin_t / 0.72) * 40.0
			var a0 := Vector2(cx, cy) + Vector2(cos(ang2), sin(ang2)) * 20.0
			var a1 := Vector2(cx, cy) + Vector2(cos(ang2), sin(ang2)) * len
			_die.draw_line(a0, a1, Color(0.94, 0.77, 0.48, 0.22 * (1.0 - _spin_t / 0.72)), 2.0)

	var rotated: Array[Vector3] = []
	for v in _verts:
		rotated.append(_rotate_vec(v, _rot))

	var draw_faces: Array = []
	for i in _faces.size():
		var face: PackedInt32Array = _faces[i]
		var pts: Array[Vector3] = [
			_project(rotated[face[0]], scale, cx, cy),
			_project(rotated[face[1]], scale, cx, cy),
			_project(rotated[face[2]], scale, cx, cy),
		]
		var n := _rotate_vec(_normals[i], _rot)
		if n.z <= 0.02:
			continue
		var avg_z := (pts[0].z + pts[1].z + pts[2].z) / 3.0
		draw_faces.append({
			"i": i,
			"pts": pts,
			"n": n,
			"z": avg_z,
			"num": FACE_NUMS[i],
		})

	draw_faces.sort_custom(func(a, b): return a.z > b.z)

	for f in draw_faces:
		var lit := 0.32 + 0.68 * maxf(0.0, f.n.z)
		var base := Color("5a4a8a")
		if _landed:
			if int(f.num) == _result:
				base = Color("6fbf84") if _correct else Color("c45c4a")
			else:
				base = Color("466450") if _correct else Color("5a464e")
		var col := Color(base.r * lit, base.g * lit, base.b * lit, 1.0)
		var poly := PackedVector2Array([
			Vector2(f.pts[0].x, f.pts[0].y),
			Vector2(f.pts[1].x, f.pts[1].y),
			Vector2(f.pts[2].x, f.pts[2].y),
		])
		# Beveled / inset face: dark outer, lighter inset
		_die.draw_colored_polygon(poly, col.darkened(0.18))
		var mx: float = (float(f.pts[0].x) + float(f.pts[1].x) + float(f.pts[2].x)) / 3.0
		var my: float = (float(f.pts[0].y) + float(f.pts[1].y) + float(f.pts[2].y)) / 3.0
		var inset := PackedVector2Array()
		for pt in poly:
			inset.append(pt.lerp(Vector2(mx, my), 0.18))
		var hi := Color(
			minf(1.0, col.r * 1.18 + 0.05),
			minf(1.0, col.g * 1.15 + 0.04),
			minf(1.0, col.b * 1.12 + 0.03),
			1.0
		)
		_die.draw_colored_polygon(inset, hi)
		# Specular glint on brightest faces
		if float(f.n.z) > 0.55:
			_die.draw_colored_polygon(PackedVector2Array([
				inset[0].lerp(Vector2(mx, my), 0.35),
				inset[1].lerp(Vector2(mx, my), 0.55),
				Vector2(mx, my),
			]), Color(1, 1, 1, 0.16 + float(f.n.z) * 0.12))
		var edge := Color("f0c57a")
		edge.a = 0.55 if not (_landed and int(f.num) == _result) else 0.95
		_die.draw_polyline(poly + PackedVector2Array([poly[0]]), edge, 1.6 if int(f.num) != _result else 2.6, true)
		_die.draw_polyline(inset + PackedVector2Array([inset[0]]), Color(0.1, 0.12, 0.14, 0.35), 1.0, true)

		var font_size: int = int(13.0 + maxf(0.0, float(f.n.z)) * 12.0)
		var num_col := Color("f0c57a")
		if _landed and int(f.num) == _result:
			num_col = Color("eef5ea") if _correct else Color("fff0ec")
		var label := str(f.num)
		var tw := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		# Number shadow for readability
		_die.draw_string(
			ThemeDB.fallback_font,
			Vector2(mx - tw * 0.5 + 1.0, my + 5 + 1.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color(0, 0, 0, 0.45)
		)
		_die.draw_string(
			ThemeDB.fallback_font,
			Vector2(mx - tw * 0.5, my + 5),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			num_col
		)

	# Landing rings
	if _landed and _land_fx_t < 0.9:
		var lt := _land_fx_t / 0.9
		var rr := lerpf(20.0, 70.0, lt)
		var lc := Color(0.55, 0.9, 0.55, 0.65 * (1.0 - lt)) if _correct else Color(0.9, 0.45, 0.4, 0.6 * (1.0 - lt))
		_die.draw_arc(Vector2(cx, cy), rr, 0.0, TAU, 36, lc, 2.4, true)
		_die.draw_arc(Vector2(cx, cy), rr * 0.72, 0.0, TAU, 28, Color(lc.r, lc.g, lc.b, lc.a * 0.6), 1.5, true)

	# Result sparkles
	for sp in _sparkles:
		var u := float(sp.t) / float(sp.life)
		var rad := float(sp.r) * (0.4 + u)
		var p := Vector2(cx, cy) + Vector2(cos(float(sp.a)), sin(float(sp.a))) * rad
		var sc := Color(0.98, 0.86, 0.45, 0.85 * (1.0 - u)) if _correct else Color(0.95, 0.7, 0.55, 0.7 * (1.0 - u))
		_die.draw_circle(p, float(sp.sz) * (1.0 - u * 0.4), sc)

	# Call / result chip under die
	if _guess != "":
		var call_txt := "Call: High" if _guess == "high" else "Call: Low"
		if _landed:
			call_txt += "  ·  %s" % ("Correct!" if _correct else "Incorrect")
		var font := ThemeDB.fallback_font
		var fs := 14
		var tw2 := font.get_string_size(call_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var chip_c := Color(0.08, 0.12, 0.1, 0.72)
		_die.draw_colored_polygon(_ellipse_pts(Vector2(cx, size.y - 8.0), Vector2(tw2 * 0.55 + 16.0, 12.0)), chip_c)
		var tc := Color("f0c57a")
		if _landed:
			tc = Color("8fdf9a") if _correct else Color("e08a7a")
		_die.draw_string(font, Vector2(cx - tw2 * 0.5, size.y - 3.0), call_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)


func _ellipse_pts(center: Vector2, radii: Vector2, n: int = 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts
