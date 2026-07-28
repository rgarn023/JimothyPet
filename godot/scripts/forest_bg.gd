extends Control
## Forest backdrop — day or night from the local clock (6:00–20:00 day).


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	resized.connect(queue_redraw)
	if GraphicStyle:
		GraphicStyle.mode_changed.connect(func(_m): queue_redraw())


func _is_daytime() -> bool:
	var t := Time.get_time_dict_from_system()
	var h := float(t.hour) + float(t.minute) / 60.0
	return h >= 6.0 and h < 20.0


func _draw() -> void:
	var w := size.x
	var h := size.y
	var day := _is_daytime()
	var bands := 24
	if GraphicStyle:
		bands = GraphicStyle.sky_band_count()

	if day:
		for i in bands:
			var t := float(i) / float(maxi(1, bands - 1))
			var col := Color(0.48, 0.72, 0.92).lerp(Color(0.55, 0.78, 0.48), t)
			if GraphicStyle and GraphicStyle.is_cell():
				col = GraphicStyle.posterize(col, 3.0)
			elif GraphicStyle and GraphicStyle.is_realistic():
				col = col.lerp(Color(0.62, 0.82, 0.95), 0.12 * (1.0 - t))
			draw_rect(Rect2(0, h * t / 1.15, w, h / float(bands) + 2.0), col)
		# Sun
		var sun := Vector2(w * 0.78, h * 0.12)
		if GraphicStyle and GraphicStyle.is_realistic():
			_ellipse(sun, Vector2(70, 70), Color(1.0, 0.82, 0.35, 0.14))
			_ellipse(sun, Vector2(40, 40), Color(1.0, 0.9, 0.5, 0.28))
			_ellipse(sun, Vector2(22, 22), Color(1.0, 0.96, 0.78, 0.95))
		elif GraphicStyle and GraphicStyle.is_cell():
			_ellipse(sun, Vector2(24, 24), Color(1.0, 0.92, 0.45, 1.0))
		else:
			draw_circle(sun, 56.0, Color(1.0, 0.85, 0.35, 0.18))
			draw_circle(sun, 32.0, Color(1.0, 0.9, 0.45, 0.28))
			draw_circle(sun, 20.0, Color(1.0, 0.95, 0.7, 0.95))
		# Soft day mist
		_ellipse(Vector2(w * 0.3, h * 0.55), Vector2(w * 0.5, 40), Color(0.75, 0.88, 0.7, 0.14))
		_ellipse(Vector2(w * 0.7, h * 0.62), Vector2(w * 0.45, 36), Color(0.7, 0.85, 0.65, 0.1))
		# Trees (lighter)
		for i in 7:
			var x := w * (0.05 + i * 0.14)
			_pine(Vector2(x, h * 0.42), 0.55 + (i % 3) * 0.12, Color(0.12, 0.32, 0.18, 0.8))
		for i in 5:
			var x := w * (0.1 + i * 0.2)
			_pine(Vector2(x + 10.0, h * 0.5), 0.85 + (i % 2) * 0.15, Color(0.1, 0.28, 0.16, 0.88))
		var ground := Color(0.18, 0.36, 0.2)
		if GraphicStyle and GraphicStyle.is_cell():
			ground = GraphicStyle.posterize(ground, 3.0)
		draw_rect(Rect2(0, h * 0.72, w, h * 0.28), ground)
		_ellipse(Vector2(w * 0.5, h * 0.78), Vector2(w * 0.6, 28), Color(0.22, 0.42, 0.24, 0.45))
		for i in 8:
			var x := float(i) / 7.0 * w
			_bush(Vector2(x, h * 0.74), 0.7 + (i % 3) * 0.15, Color(0.2, 0.45, 0.28, 0.9))
	else:
		for i in bands:
			var t := float(i) / float(maxi(1, bands - 1))
			var col := Color(0.04, 0.08, 0.07).lerp(Color(0.09, 0.16, 0.12), t)
			if GraphicStyle and GraphicStyle.is_cell():
				col = GraphicStyle.posterize(col, 3.0)
			elif GraphicStyle and GraphicStyle.is_realistic():
				col = col.lerp(Color(0.08, 0.12, 0.2), 0.18 * (1.0 - t))
			draw_rect(Rect2(0, h * t / 1.15, w, h / float(bands) + 2.0), col)
		# Moon glow
		var moon := Vector2(w * 0.78, h * 0.12)
		if GraphicStyle and GraphicStyle.is_realistic():
			_ellipse(moon, Vector2(56, 56), Color(0.95, 0.85, 0.45, 0.1))
			_ellipse(moon, Vector2(30, 30), Color(0.98, 0.92, 0.7, 0.2))
			_ellipse(moon, Vector2(18, 18), Color(0.98, 0.94, 0.78, 0.95))
		elif GraphicStyle and GraphicStyle.is_cell():
			_ellipse(moon, Vector2(20, 20), Color(0.95, 0.92, 0.78, 1.0))
		else:
			draw_circle(moon, 48.0, Color(0.95, 0.85, 0.45, 0.08))
			draw_circle(moon, 28.0, Color(0.98, 0.92, 0.7, 0.16))
			draw_circle(moon, 18.0, Color(0.98, 0.94, 0.78, 0.9))
		_ellipse(Vector2(w * 0.3, h * 0.55), Vector2(w * 0.5, 40), Color(0.2, 0.35, 0.28, 0.12))
		_ellipse(Vector2(w * 0.7, h * 0.62), Vector2(w * 0.45, 36), Color(0.15, 0.28, 0.22, 0.1))
		for i in 7:
			var x := w * (0.05 + i * 0.14)
			_pine(Vector2(x, h * 0.42), 0.55 + (i % 3) * 0.12, Color(0.05, 0.1, 0.08, 0.85))
		for i in 5:
			var x := w * (0.1 + i * 0.2)
			_pine(Vector2(x + 10.0, h * 0.5), 0.85 + (i % 2) * 0.15, Color(0.04, 0.09, 0.07, 0.92))
		var ng := Color(0.05, 0.09, 0.07)
		if GraphicStyle and GraphicStyle.is_cell():
			ng = GraphicStyle.posterize(ng, 3.0)
		draw_rect(Rect2(0, h * 0.72, w, h * 0.28), ng)
		_ellipse(Vector2(w * 0.5, h * 0.78), Vector2(w * 0.6, 28), Color(0.08, 0.14, 0.1, 0.5))
		for i in 8:
			var x := float(i) / 7.0 * w
			_bush(Vector2(x, h * 0.74), 0.7 + (i % 3) * 0.15)
		# Fireflies only at night
		for i in 6:
			var fx := fposmod(float(i) * 73.1 + Time.get_ticks_msec() * 0.01, w)
			var fy := h * (0.35 + fmod(float(i) * 0.13, 0.3))
			var pulse := 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() * 0.003 + i))
			_ellipse(Vector2(fx, fy), Vector2(2.2, 2.2), Color(0.95, 0.8, 0.35, pulse * 0.7))


func _process(_delta: float) -> void:
	queue_redraw()


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	if GraphicStyle:
		GraphicStyle.draw_ellipse(self, center, radii, color, 20)
		return
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func _pine(base: Vector2, scale: float, color: Color) -> void:
	var trunk_h := 28.0 * scale
	var trunk_col := color.darkened(0.2)
	if GraphicStyle and GraphicStyle.is_cell():
		draw_rect(Rect2(base.x - 4.0 * scale, base.y - 1.0, 8.0 * scale, trunk_h + 2.0), GraphicStyle.outline_for(trunk_col))
	draw_rect(Rect2(base.x - 3.0 * scale, base.y, 6.0 * scale, trunk_h), trunk_col)
	var tiers: Array[Vector2] = [
		Vector2(36, 40),
		Vector2(28, 32),
		Vector2(20, 24),
	]
	var y := base.y
	for t in tiers:
		var half: float = t.x * scale
		var tall: float = t.y * scale
		var tri := PackedVector2Array([
			Vector2(base.x, y - tall * 0.15),
			Vector2(base.x - half, y + tall * 0.55),
			Vector2(base.x + half, y + tall * 0.55),
		])
		if GraphicStyle:
			GraphicStyle.draw_poly(self, tri, color)
		else:
			draw_colored_polygon(tri, color)
		y -= tall * 0.35


func _bush(base: Vector2, scale: float, color: Color = Color(0.12, 0.28, 0.18, 0.9)) -> void:
	_ellipse(base + Vector2(-10 * scale, 0), Vector2(16 * scale, 12 * scale), color)
	_ellipse(base + Vector2(8 * scale, -2 * scale), Vector2(14 * scale, 11 * scale), color.lightened(0.05))
	_ellipse(base + Vector2(0, -8 * scale), Vector2(12 * scale, 10 * scale), color.lightened(0.08))
