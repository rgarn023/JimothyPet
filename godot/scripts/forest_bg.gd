extends Control
## Forest backdrop — day or night from the local clock (6:00–20:00 day).
## Realistic mode keeps the same trees/bushes/sky and softens them with depth.


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
	var realistic := GraphicStyle != null and GraphicStyle.is_realistic()

	if day:
		for i in bands:
			var t := float(i) / float(maxi(1, bands - 1))
			var col := Color(0.48, 0.72, 0.92).lerp(Color(0.55, 0.78, 0.48), t)
			if GraphicStyle and GraphicStyle.is_cell():
				col = GraphicStyle.posterize(col, 3.0)
			elif realistic:
				# Soft atmospheric haze — still the same sky gradient.
				col = col.lerp(Color(0.72, 0.86, 0.95), 0.16 * (1.0 - t))
				col = col.lerp(Color(0.9, 0.86, 0.7), 0.05 * t)
			draw_rect(Rect2(0, h * t / 1.15, w, h / float(bands) + 2.0), col)
		# Sun
		var sun := Vector2(w * 0.78, h * 0.12)
		if realistic:
			_ellipse(sun, Vector2(88, 88), Color(1.0, 0.78, 0.32, 0.08))
			_ellipse(sun, Vector2(58, 58), Color(1.0, 0.85, 0.4, 0.14))
			_ellipse(sun, Vector2(36, 36), Color(1.0, 0.92, 0.55, 0.28))
			_ellipse(sun, Vector2(20, 20), Color(1.0, 0.97, 0.82, 0.95))
		elif GraphicStyle and GraphicStyle.is_cell():
			_ellipse(sun, Vector2(24, 24), Color(1.0, 0.92, 0.45, 1.0))
		else:
			draw_circle(sun, 56.0, Color(1.0, 0.85, 0.35, 0.18))
			draw_circle(sun, 32.0, Color(1.0, 0.9, 0.45, 0.28))
			draw_circle(sun, 20.0, Color(1.0, 0.95, 0.7, 0.95))
		# Soft day mist
		_ellipse(Vector2(w * 0.3, h * 0.55), Vector2(w * 0.5, 40), Color(0.75, 0.88, 0.7, 0.14))
		_ellipse(Vector2(w * 0.7, h * 0.62), Vector2(w * 0.45, 36), Color(0.7, 0.85, 0.65, 0.1))
		if realistic:
			_ellipse(Vector2(w * 0.5, h * 0.48), Vector2(w * 0.55, 28), Color(0.85, 0.9, 0.78, 0.08))
		# Trees (lighter) — same pines, richer depth in realistic.
		for i in 7:
			var x := w * (0.05 + i * 0.14)
			var pine_col := Color(0.12, 0.32, 0.18, 0.8)
			if realistic:
				pine_col = Color(0.1, 0.28, 0.16, 0.72).lerp(Color(0.18, 0.38, 0.2, 0.85), float(i % 3) / 3.0)
			_pine(Vector2(x, h * 0.42), 0.55 + (i % 3) * 0.12, pine_col)
		for i in 5:
			var x := w * (0.1 + i * 0.2)
			var pine_col2 := Color(0.1, 0.28, 0.16, 0.88)
			if realistic:
				pine_col2 = Color(0.08, 0.24, 0.14, 0.9)
			_pine(Vector2(x + 10.0, h * 0.5), 0.85 + (i % 2) * 0.15, pine_col2)
		var ground := Color(0.18, 0.36, 0.2)
		if GraphicStyle and GraphicStyle.is_cell():
			ground = GraphicStyle.posterize(ground, 3.0)
		elif realistic:
			ground = Color(0.16, 0.32, 0.18)
		draw_rect(Rect2(0, h * 0.72, w, h * 0.28), ground)
		_ellipse(Vector2(w * 0.5, h * 0.78), Vector2(w * 0.6, 28), Color(0.22, 0.42, 0.24, 0.45))
		if realistic:
			# Soft sun patches / leaf dapple on the clearing floor.
			_ellipse(Vector2(w * 0.35, h * 0.8), Vector2(42, 12), Color(0.35, 0.5, 0.28, 0.18))
			_ellipse(Vector2(w * 0.62, h * 0.82), Vector2(36, 10), Color(0.32, 0.48, 0.26, 0.14))
			_ellipse(Vector2(w * 0.48, h * 0.86), Vector2(55, 8), Color(0.12, 0.2, 0.1, 0.16))
		for i in 8:
			var x := float(i) / 7.0 * w
			var bush_col := Color(0.2, 0.45, 0.28, 0.9)
			if realistic:
				bush_col = Color(0.18, 0.4, 0.24, 0.92).lerp(Color(0.26, 0.5, 0.3, 0.88), float(i % 3) / 3.0)
			_bush(Vector2(x, h * 0.74), 0.7 + (i % 3) * 0.15, bush_col)
	else:
		for i in bands:
			var t := float(i) / float(maxi(1, bands - 1))
			var col := Color(0.04, 0.08, 0.07).lerp(Color(0.09, 0.16, 0.12), t)
			if GraphicStyle and GraphicStyle.is_cell():
				col = GraphicStyle.posterize(col, 3.0)
			elif realistic:
				col = col.lerp(Color(0.06, 0.1, 0.18), 0.2 * (1.0 - t))
			draw_rect(Rect2(0, h * t / 1.15, w, h / float(bands) + 2.0), col)
		# Moon glow
		var moon := Vector2(w * 0.78, h * 0.12)
		if realistic:
			_ellipse(moon, Vector2(70, 70), Color(0.85, 0.9, 1.0, 0.06))
			_ellipse(moon, Vector2(48, 48), Color(0.95, 0.88, 0.55, 0.1))
			_ellipse(moon, Vector2(28, 28), Color(0.98, 0.93, 0.72, 0.22))
			_ellipse(moon, Vector2(17, 17), Color(0.98, 0.95, 0.82, 0.95))
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
		if realistic:
			_ellipse(Vector2(w * 0.5, h * 0.84), Vector2(w * 0.4, 10), Color(0.02, 0.04, 0.03, 0.28))
		for i in 8:
			var x := float(i) / 7.0 * w
			_bush(Vector2(x, h * 0.74), 0.7 + (i % 3) * 0.15)
		# Fireflies only at night
		for i in 6:
			var fx := fposmod(float(i) * 73.1 + Time.get_ticks_msec() * 0.01, w)
			var fy := h * (0.35 + fmod(float(i) * 0.13, 0.3))
			var pulse := 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() * 0.003 + i))
			if realistic:
				_ellipse(Vector2(fx, fy), Vector2(4.5, 4.5), Color(0.95, 0.85, 0.4, pulse * 0.18))
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
	var realistic := GraphicStyle != null and GraphicStyle.is_realistic()
	if GraphicStyle and GraphicStyle.is_cell():
		draw_rect(Rect2(base.x - 4.0 * scale, base.y - 1.0, 8.0 * scale, trunk_h + 2.0), GraphicStyle.outline_for(trunk_col))
	if realistic:
		# Soft organic trunk capsule — not a hard rectangle.
		GraphicStyle.draw_limb(
			self,
			base + Vector2(0, trunk_h * 0.08),
			base + Vector2(0, trunk_h),
			6.2 * scale,
			trunk_col
		)
		# Organic layered canopy (soft lobes) instead of stacked triangles.
		var canopy_y := base.y
		var tiers: Array[Vector2] = [
			Vector2(34, 36),
			Vector2(26, 28),
			Vector2(18, 22),
		]
		for i in tiers.size():
			var t: Vector2 = tiers[i]
			var half: float = t.x * scale
			var tall: float = t.y * scale
			var cy := canopy_y + tall * 0.12
			_ellipse(
				Vector2(base.x, cy),
				Vector2(half * 0.92, tall * 0.42),
				color.darkened(0.04 * float(i))
			)
			_ellipse(
				Vector2(base.x - half * 0.28, cy + tall * 0.08),
				Vector2(half * 0.48, tall * 0.3),
				color.lightened(0.03)
			)
			_ellipse(
				Vector2(base.x + half * 0.26, cy + tall * 0.1),
				Vector2(half * 0.44, tall * 0.28),
				color.darkened(0.06)
			)
			# Soft tip mass so the silhouette still reads as a pine.
			if i == tiers.size() - 1:
				_ellipse(Vector2(base.x, cy - tall * 0.22), Vector2(half * 0.38, tall * 0.28), color.lightened(0.05))
			canopy_y -= tall * 0.32
		return
	draw_rect(Rect2(base.x - 3.0 * scale, base.y, 6.0 * scale, trunk_h), trunk_col)
	var tiers_n: Array[Vector2] = [
		Vector2(36, 40),
		Vector2(28, 32),
		Vector2(20, 24),
	]
	var y := base.y
	for t in tiers_n:
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
	if GraphicStyle and GraphicStyle.is_realistic():
		# Fuse the three bush lobes into one soft mass.
		GraphicStyle.draw_joint_blend(self, base + Vector2(-2 * scale, -3 * scale), Vector2(14 * scale, 10 * scale), color)
