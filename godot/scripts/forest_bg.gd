extends Control
## Layered illustrated forest backdrop for JimothyPet.
## Drawn entirely with CanvasItem primitives so Android/web exports stay light.

var _time: float = 0.0
var _last_day_state: int = -1
var _redraw_accum: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()
	resized.connect(queue_redraw)


func _is_daytime() -> bool:
	var t := Time.get_time_dict_from_system()
	var h := float(t.hour) + float(t.minute) / 60.0
	return h >= 6.0 and h < 20.0


func _process(delta: float) -> void:
	_time += delta
	_redraw_accum += delta
	var day_state := 1 if _is_daytime() else 0
	if day_state != _last_day_state:
		_last_day_state = day_state
		_redraw_accum = 0.0
		queue_redraw()
	elif _redraw_accum >= 0.05:
		# Atmospheric motion at ~20 redraws/sec — light enough for mobile.
		_redraw_accum = 0.0
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	var day := _is_daytime()
	_draw_sky(w, h, day)
	_draw_celestial(w, h, day)
	_draw_distant_hills(w, h, day)
	_draw_tree_layers(w, h, day)
	_draw_forest_floor(w, h, day)
	_draw_atmosphere(w, h, day)
	_draw_vignette(w, h, day)


func _draw_sky(w: float, h: float, day: bool) -> void:
	var top := Color("7fc0e7") if day else Color("071b1c")
	var middle := Color("b8d9b0") if day else Color("123329")
	var bottom := Color("65a875") if day else Color("173a2c")
	for i in 34:
		var t := float(i) / 33.0
		var col := top.lerp(middle, smoothstep(0.0, 0.62, t))
		if t > 0.58:
			col = middle.lerp(bottom, smoothstep(0.58, 1.0, t))
		draw_rect(Rect2(0, h * t, w, h / 32.0 + 2.0), col)


func _draw_celestial(w: float, h: float, day: bool) -> void:
	var p := Vector2(w * 0.79, h * 0.115)
	if day:
		draw_circle(p, 58.0, Color(1.0, 0.91, 0.58, 0.08))
		draw_circle(p, 39.0, Color(1.0, 0.9, 0.46, 0.14))
		draw_circle(p, 23.0, Color("fff1a8"))
		draw_circle(p + Vector2(-7, -8), 8.0, Color(1, 1, 1, 0.25))
	else:
		draw_circle(p, 54.0, Color(0.8, 0.9, 0.76, 0.055))
		draw_circle(p, 34.0, Color(0.92, 0.9, 0.66, 0.1))
		draw_circle(p, 20.0, Color("f2e7b7"))
		draw_circle(p + Vector2(7, -5), 18.0, Color("17342b"))
		for i in 14:
			var sx := fposmod(float(i * 67 + 31), w)
			var sy := h * (0.05 + fmod(float(i) * 0.083, 0.34))
			var pulse := 0.28 + 0.25 * sin(_time * 1.4 + float(i))
			draw_circle(Vector2(sx, sy), 1.2 + float(i % 3) * 0.35, Color(0.92, 0.96, 0.83, pulse))


func _draw_distant_hills(w: float, h: float, day: bool) -> void:
	var far := Color(0.2, 0.47, 0.39, 0.34) if day else Color(0.055, 0.18, 0.16, 0.72)
	var near := Color(0.13, 0.38, 0.28, 0.48) if day else Color(0.035, 0.13, 0.11, 0.88)
	var hill_a := PackedVector2Array([
		Vector2(0, h * 0.43),
		Vector2(w * 0.12, h * 0.34),
		Vector2(w * 0.29, h * 0.40),
		Vector2(w * 0.45, h * 0.31),
		Vector2(w * 0.63, h * 0.40),
		Vector2(w * 0.82, h * 0.33),
		Vector2(w, h * 0.41),
		Vector2(w, h * 0.58),
		Vector2(0, h * 0.58),
	])
	draw_colored_polygon(hill_a, far)
	var hill_b := PackedVector2Array([
		Vector2(0, h * 0.52),
		Vector2(w * 0.18, h * 0.43),
		Vector2(w * 0.38, h * 0.50),
		Vector2(w * 0.57, h * 0.41),
		Vector2(w * 0.76, h * 0.49),
		Vector2(w, h * 0.42),
		Vector2(w, h * 0.63),
		Vector2(0, h * 0.63),
	])
	draw_colored_polygon(hill_b, near)


func _draw_tree_layers(w: float, h: float, day: bool) -> void:
	var far_col := Color(0.13, 0.34, 0.25, 0.55) if day else Color(0.025, 0.09, 0.075, 0.74)
	var mid_col := Color(0.075, 0.27, 0.17, 0.78) if day else Color(0.02, 0.065, 0.055, 0.9)
	var near_col := Color(0.045, 0.20, 0.12, 0.95) if day else Color(0.012, 0.045, 0.038, 1.0)

	for i in 10:
		var x := w * (0.02 + float(i) * 0.108)
		var sway := sin(_time * 0.34 + float(i) * 1.7) * 1.2
		_pine(Vector2(x + sway, h * 0.47), 0.46 + float(i % 3) * 0.08, far_col)
	for i in 7:
		var x := w * (0.04 + float(i) * 0.16)
		var sway := sin(_time * 0.27 + float(i) * 1.2) * 1.5
		_pine(Vector2(x + sway, h * 0.60), 0.72 + float(i % 2) * 0.12, mid_col)
	for i in 6:
		var x := w * (-0.02 + float(i) * 0.21)
		var sway := sin(_time * 0.22 + float(i) * 0.9) * 1.7
		_pine(Vector2(x + sway, h * 0.72), 0.98 + float(i % 3) * 0.09, near_col)


func _draw_forest_floor(w: float, h: float, day: bool) -> void:
	var floor_col := Color("285e3a") if day else Color("09231a")
	var deep_col := Color("173f2b") if day else Color("061812")
	draw_rect(Rect2(0, h * 0.63, w, h * 0.37), floor_col)

	# Soft central clearing that frames Jimothy.
	_ellipse(Vector2(w * 0.5, h * 0.73), Vector2(w * 0.43, h * 0.12), Color(0.48, 0.69, 0.43, 0.22) if day else Color(0.18, 0.34, 0.24, 0.28))
	_ellipse(Vector2(w * 0.5, h * 0.82), Vector2(w * 0.35, h * 0.075), Color(0.73, 0.74, 0.48, 0.11) if day else Color(0.22, 0.25, 0.16, 0.16))

	draw_rect(Rect2(0, h * 0.90, w, h * 0.10), deep_col)
	for i in 11:
		var x := float(i) / 10.0 * w
		var scale := 0.72 + float(i % 4) * 0.11
		_bush(Vector2(x, h * 0.91), scale, Color(0.08, 0.28, 0.16, 0.95) if day else Color(0.02, 0.11, 0.075, 1.0))

	for i in 12:
		var lx := fposmod(float(i * 79 + 25), w)
		var ly := h * (0.69 + fmod(float(i) * 0.071, 0.18))
		var leaf_col := Color(0.45, 0.66, 0.34, 0.34) if day else Color(0.38, 0.55, 0.32, 0.18)
		draw_colored_polygon(PackedVector2Array([
			Vector2(lx - 3, ly), Vector2(lx + 1, ly - 2), Vector2(lx + 4, ly + 1), Vector2(lx, ly + 3)
		]), leaf_col)


func _draw_atmosphere(w: float, h: float, day: bool) -> void:
	var drift := sin(_time * 0.12) * 24.0
	var mist := Color(0.9, 0.96, 0.83, 0.08) if day else Color(0.45, 0.63, 0.54, 0.045)
	_ellipse(Vector2(w * 0.28 + drift, h * 0.53), Vector2(w * 0.36, 24), mist)
	_ellipse(Vector2(w * 0.72 - drift * 0.7, h * 0.61), Vector2(w * 0.31, 19), mist)

	if not day:
		for i in 9:
			var fx := fposmod(float(i) * 83.0 + _time * (7.0 + float(i % 3) * 2.0), w)
			var fy := h * (0.38 + fmod(float(i) * 0.093, 0.34)) + sin(_time * 1.4 + i) * 5.0
			var pulse := 0.25 + 0.55 * absf(sin(_time * 2.2 + float(i) * 1.5))
			draw_circle(Vector2(fx, fy), 1.4, Color(0.98, 0.87, 0.38, pulse))
			draw_circle(Vector2(fx, fy), 4.0, Color(0.98, 0.87, 0.38, pulse * 0.08))


func _draw_vignette(w: float, h: float, day: bool) -> void:
	var edge := Color(0.02, 0.10, 0.06, 0.055) if day else Color(0.0, 0.02, 0.015, 0.14)
	for i in 6:
		var a := edge.a * (1.0 - float(i) / 6.0)
		draw_rect(Rect2(i * 5.0, i * 5.0, w - i * 10.0, h - i * 10.0), Color(edge.r, edge.g, edge.b, a), false, 7.0)


func _ellipse(center: Vector2, radii: Vector2, color: Color, points: int = 28) -> void:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * float(i) / float(points)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func _pine(base: Vector2, scale: float, color: Color) -> void:
	var trunk := color.darkened(0.28)
	draw_rect(Rect2(base.x - 3.2 * scale, base.y - 3.0 * scale, 6.4 * scale, 33.0 * scale), trunk)
	var y := base.y
	for tier in 4:
		var tier_scale := 1.0 - float(tier) * 0.13
		var half := 34.0 * scale * tier_scale
		var tall := 32.0 * scale * tier_scale
		var tri := PackedVector2Array([
			Vector2(base.x, y - tall),
			Vector2(base.x - half, y + tall * 0.34),
			Vector2(base.x + half, y + tall * 0.34),
		])
		draw_colored_polygon(tri, color.lightened(float(tier) * 0.018))
		y -= tall * 0.44


func _bush(base: Vector2, scale: float, color: Color) -> void:
	_ellipse(base + Vector2(-18 * scale, 2), Vector2(22 * scale, 15 * scale), color)
	_ellipse(base + Vector2(0, -5 * scale), Vector2(24 * scale, 18 * scale), color.lightened(0.045))
	_ellipse(base + Vector2(20 * scale, 2), Vector2(21 * scale, 14 * scale), color.darkened(0.035))
