extends Control
## Draws Jimothy by growth stage (adult = viral short-spine silhouette).

var stage: String = "egg"
var adult_variant: String = "noble"
var mood: String = "idle"
var _bob_t: float = 0.0


func _process(delta: float) -> void:
	_bob_t += delta
	queue_redraw()


func set_look(p_stage: String, p_variant: String = "noble", p_mood: String = "idle") -> void:
	stage = p_stage
	adult_variant = p_variant
	mood = p_mood
	queue_redraw()


func _ellipse(center: Vector2, radii: Vector2, color: Color, points: int = 28) -> void:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * float(i) / float(points)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func _draw() -> void:
	var c := size * 0.5
	var bob := sin(_bob_t * 2.2) * 4.0
	if mood == "stubborn":
		bob = sin(_bob_t * 14.0) * 3.0
		c.x += sin(_bob_t * 12.0) * 3.0
	elif stage == "adult" and mood == "idle":
		bob = sin(_bob_t * 5.5) * 6.0
		c.x += sin(_bob_t * 2.8) * 2.0

	c.y += bob
	match stage:
		"egg":
			_draw_egg(c)
		"hatchling":
			_draw_hatchling(c)
		"kit":
			_draw_kit(c)
		"teen":
			_draw_teen(c)
		"adult":
			_draw_adult(c)
		_:
			_draw_egg(c)


func _shadow(c: Vector2, rx: float) -> void:
	_ellipse(c + Vector2(0, 48), Vector2(rx, 7), Color(0, 0, 0, 0.22))


func _draw_egg(c: Vector2) -> void:
	_shadow(c, 26)
	_ellipse(c + Vector2(0, 8), Vector2(28, 34), Color("e8dcc0"))
	_ellipse(c + Vector2(-8, -5), Vector2(8, 5), Color(1, 0.96, 0.89, 0.55))
	draw_line(c + Vector2(-8, -18), c + Vector2(-2, -8), Color("6b5a3e"), 2.5)
	draw_line(c + Vector2(-2, -8), c + Vector2(-6, -2), Color("6b5a3e"), 2.5)
	draw_line(c + Vector2(-6, -2), c + Vector2(2, 8), Color("6b5a3e"), 2.5)


func _draw_hatchling(c: Vector2) -> void:
	_shadow(c, 22)
	_ellipse(c + Vector2(0, 18), Vector2(26, 22), Color("6b6b72"))
	draw_circle(c + Vector2(0, -6), 20.0, Color("75757d"))
	_ears(c + Vector2(0, -6), 15.0, 10.0)
	_mask_face(c + Vector2(0, -4), 16.0, 10.0, 3.2)


func _draw_kit(c: Vector2) -> void:
	_shadow(c, 28)
	_tail(c + Vector2(28, 10), 0.85)
	_ellipse(c + Vector2(0, 16), Vector2(32, 26), Color("6f6f78"))
	draw_circle(c + Vector2(0, -12), 24.0, Color("7a7a84"))
	_ears(c + Vector2(0, -12), 20.0, 13.0)
	_mask_face(c + Vector2(0, -8), 20.0, 12.0, 4.0)


func _draw_teen(c: Vector2) -> void:
	_shadow(c, 30)
	_tail(c + Vector2(26, 4), 0.9)
	_leg(c + Vector2(-18, 12), c + Vector2(-24, 42), 5.5)
	_leg(c + Vector2(-6, 14), c + Vector2(-10, 44), 5.5)
	_leg(c + Vector2(6, 14), c + Vector2(12, 44), 5.5)
	_leg(c + Vector2(18, 12), c + Vector2(26, 42), 5.5)
	_ellipse(c + Vector2(0, 2), Vector2(30, 26), Color("6a6a74"))
	draw_circle(c + Vector2(0, -8), 22.0, Color("767680"))
	_ears(c + Vector2(0, -8), 18.0, 12.0)
	_mask_face(c + Vector2(0, -6), 18.0, 12.0, 4.0)


func _draw_adult(c: Vector2) -> void:
	_shadow(c, 34)
	_tail(c + Vector2(28, 0), 1.0)
	_leg(c + Vector2(-20, 8), c + Vector2(-32, 48), 6.0)
	_leg(c + Vector2(-8, 12), c + Vector2(-14, 50), 6.0)
	_leg(c + Vector2(8, 12), c + Vector2(14, 50), 6.0)
	_leg(c + Vector2(20, 8), c + Vector2(34, 48), 6.0)
	_ellipse(c + Vector2(0, -2), Vector2(34, 30), Color("6a6a74"))
	_ears(c + Vector2(0, -2), 22.0, 26.0)
	_mask_face(c + Vector2(0, -4), 22.0, 13.0, 5.0)
	if adult_variant == "rascal":
		var pts := PackedVector2Array([
			c + Vector2(18, -14),
			c + Vector2(28, 0),
			c + Vector2(16, 2),
		])
		draw_colored_polygon(pts, Color("e0a04a"))
		draw_line(c + Vector2(20, -8), c + Vector2(28, -8), Color("c45c4a"), 2.0)
	else:
		_ellipse(c + Vector2(18, -18), Vector2(7, 4), Color("6fbf84"))


func _ears(c: Vector2, spread: float, up: float) -> void:
	_ellipse(c + Vector2(-spread, -up), Vector2(8, 12), Color("4a4a54"))
	_ellipse(c + Vector2(spread, -up), Vector2(8, 12), Color("4a4a54"))
	_ellipse(c + Vector2(-spread, -up), Vector2(4.5, 7), Color("e2cdb2"))
	_ellipse(c + Vector2(spread, -up), Vector2(4.5, 7), Color("e2cdb2"))


func _mask_face(c: Vector2, rx: float, ry: float, eye: float) -> void:
	_ellipse(c, Vector2(rx, ry), Color("1c1c22"))
	draw_circle(c + Vector2(-eye * 1.4, -1), eye, Color("faf6ec"))
	draw_circle(c + Vector2(eye * 1.4, -1), eye, Color("faf6ec"))
	draw_circle(c + Vector2(-eye * 1.2, -0.4), eye * 0.48, Color("101014"))
	draw_circle(c + Vector2(eye * 1.6, -0.4), eye * 0.48, Color("101014"))
	_ellipse(c + Vector2(0, eye * 1.2), Vector2(eye * 1.2, eye * 0.75), Color("c9a292"))


func _leg(a: Vector2, b: Vector2, width: float) -> void:
	draw_line(a, b, Color("4f4f58"), width)
	_ellipse(b, Vector2(8, 4.5), Color("3a3a44"))


func _tail(base: Vector2, scale: float) -> void:
	var tip := base + Vector2(28 * scale, -8 * scale)
	var mid := base + Vector2(18 * scale, 10 * scale)
	draw_line(base, tip, Color("5a5a64"), 10.0 * scale)
	draw_line(base + Vector2(4, 2), mid, Color("b0b0ba"), 3.0)
