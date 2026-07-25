extends Control
## Organic raccoon waste pile (not a brown square).


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(44, 32)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5 + Vector2(0, 4)
	# Soft ground stain
	_blob(c + Vector2(0, 8), Vector2(18, 6), Color(0.12, 0.1, 0.06, 0.35))
	# Irregular clumps
	_blob(c + Vector2(-6, 2), Vector2(11, 8), Color(0.32, 0.22, 0.12))
	_blob(c + Vector2(5, 0), Vector2(10, 7), Color(0.28, 0.18, 0.1))
	_blob(c + Vector2(-1, -4), Vector2(8, 6), Color(0.36, 0.24, 0.14))
	_blob(c + Vector2(8, 4), Vector2(6, 5), Color(0.25, 0.16, 0.09))
	# Specular / moisture hint
	_blob(c + Vector2(-4, -2), Vector2(3, 2), Color(0.45, 0.32, 0.18, 0.45))
	# Tiny flies
	var t := Time.get_ticks_msec() * 0.004
	draw_circle(c + Vector2(sin(t) * 10.0, -12.0 + cos(t * 1.3) * 3.0), 1.2, Color(0.1, 0.1, 0.1, 0.55))
	draw_circle(c + Vector2(cos(t * 1.1) * 8.0, -10.0 + sin(t) * 2.0), 1.0, Color(0.1, 0.1, 0.1, 0.4))


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _blob(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	var n := 14
	for i in n:
		var a := TAU * float(i) / float(n)
		var wobble := 0.85 + 0.2 * sin(a * 3.0 + center.x)
		pts.append(center + Vector2(cos(a) * radii.x * wobble, sin(a) * radii.y * wobble))
	draw_colored_polygon(pts, color)
