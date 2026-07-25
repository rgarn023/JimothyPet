extends Control
## Painted night forest backdrop behind the pet device.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Night sky gradient
	for i in 24:
		var t := float(i) / 23.0
		var col := Color(0.04, 0.08, 0.07).lerp(Color(0.09, 0.16, 0.12), t)
		draw_rect(Rect2(0, h * t / 1.15, w, h / 22.0 + 2.0), col)

	# Moon glow
	var moon := Vector2(w * 0.78, h * 0.12)
	draw_circle(moon, 48.0, Color(0.95, 0.85, 0.45, 0.08))
	draw_circle(moon, 28.0, Color(0.98, 0.92, 0.7, 0.16))
	draw_circle(moon, 18.0, Color(0.98, 0.94, 0.78, 0.9))

	# Distant mist
	_ellipse(Vector2(w * 0.3, h * 0.55), Vector2(w * 0.5, 40), Color(0.2, 0.35, 0.28, 0.12))
	_ellipse(Vector2(w * 0.7, h * 0.62), Vector2(w * 0.45, 36), Color(0.15, 0.28, 0.22, 0.1))

	# Tree silhouettes (back row)
	for i in 7:
		var x := w * (0.05 + i * 0.14)
		_pine(Vector2(x, h * 0.42), 0.55 + (i % 3) * 0.12, Color(0.05, 0.1, 0.08, 0.85))

	# Mid trees
	for i in 5:
		var x := w * (0.1 + i * 0.2)
		_pine(Vector2(x + 10.0, h * 0.5), 0.85 + (i % 2) * 0.15, Color(0.04, 0.09, 0.07, 0.92))

	# Ground
	draw_rect(Rect2(0, h * 0.72, w, h * 0.28), Color(0.05, 0.09, 0.07))
	_ellipse(Vector2(w * 0.5, h * 0.78), Vector2(w * 0.6, 28), Color(0.08, 0.14, 0.1, 0.5))

	# Near brush
	for i in 8:
		var x := float(i) / 7.0 * w
		_bush(Vector2(x, h * 0.74), 0.7 + (i % 3) * 0.15)

	# Fireflies
	for i in 6:
		var fx := fposmod(float(i) * 73.1 + Time.get_ticks_msec() * 0.01, w)
		var fy := h * (0.35 + fmod(float(i) * 0.13, 0.3))
		var pulse := 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() * 0.003 + i))
		draw_circle(Vector2(fx, fy), 2.0, Color(0.95, 0.8, 0.35, pulse * 0.7))


func _process(_delta: float) -> void:
	queue_redraw()


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func _pine(base: Vector2, scale: float, color: Color) -> void:
	var trunk_h := 28.0 * scale
	draw_rect(Rect2(base.x - 3.0 * scale, base.y, 6.0 * scale, trunk_h), color.darkened(0.2))
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
		draw_colored_polygon(tri, color)
		y -= tall * 0.35


func _bush(base: Vector2, scale: float) -> void:
	var c := Color(0.12, 0.28, 0.18, 0.9)
	_ellipse(base + Vector2(-10 * scale, 0), Vector2(16 * scale, 12 * scale), c)
	_ellipse(base + Vector2(8 * scale, -2 * scale), Vector2(14 * scale, 11 * scale), c.lightened(0.05))
	_ellipse(base + Vector2(0, -8 * scale), Vector2(12 * scale, 10 * scale), c.lightened(0.08))
