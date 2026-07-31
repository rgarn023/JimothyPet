extends RefCounted
## Shared procedural draw helpers for Jimothy visual polish.
## No textures, plugins, or external assets — CanvasItem primitives only.

const FOOD_FLASH := {
	"berries": Color("6b5aa0"),
	"berry": Color("6b5aa0"),
	"crickets": Color("6a7a48"),
	"fish": Color("8eb4c4"),
	"pizza": Color("e0a04a"),
	"fries": Color("f0c57a"),
}


static func ellipse(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color, points: int = 22) -> void:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * float(i) / float(points)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	ci.draw_colored_polygon(pts, color)


static func round_rect(ci: CanvasItem, r: Rect2, color: Color, radius: float = 3.0) -> void:
	var rr := minf(radius, minf(r.size.x, r.size.y) * 0.45)
	ci.draw_rect(Rect2(r.position + Vector2(rr, 0), Vector2(maxf(1.0, r.size.x - rr * 2.0), r.size.y)), color)
	ci.draw_rect(Rect2(r.position + Vector2(0, rr), Vector2(r.size.x, maxf(1.0, r.size.y - rr * 2.0))), color)
	ci.draw_circle(r.position + Vector2(rr, rr), rr, color)
	ci.draw_circle(r.position + Vector2(r.size.x - rr, rr), rr, color)
	ci.draw_circle(r.position + Vector2(rr, r.size.y - rr), rr, color)
	ci.draw_circle(r.position + Vector2(r.size.x - rr, r.size.y - rr), rr, color)


static func food_flash_color(food_key: String) -> Color:
	return FOOD_FLASH.get(food_key, Color("6b5aa0"))


static func food_effect_line(food_key: String) -> String:
	if PetState == null or not PetState.FOOD.has(food_key):
		return food_key
	var f: Dictionary = PetState.FOOD[food_key]
	var bits: PackedStringArray = []
	bits.append("H%+d" % int(f.hunger))
	bits.append("Mood%+d" % int(f.happy))
	bits.append("HP%+d" % int(f.health))
	if int(f.fitness) != 0:
		bits.append("Fit%+d" % int(f.fitness))
	return "%s  ·  %s" % [str(f.name), " ".join(bits)]


static func draw_berries(ci: CanvasItem, p: Vector2, a: float = 1.0, scale: float = 1.0, bite: float = 0.0) -> void:
	var s := scale
	var berries := [
		[Vector2(-6, 1), 7.0, Color(0.35, 0.28, 0.52, a)],
		[Vector2(6, -2), 7.2, Color(0.42, 0.35, 0.63, a)],
		[Vector2(0, 7), 6.2, Color(0.3, 0.24, 0.45, a)],
		[Vector2(2, -7), 5.0, Color(0.48, 0.4, 0.69, a)],
	]
	# Berries disappear one at a time as bite progresses.
	var remain := int(ceili((1.0 - clampf(bite, 0.0, 1.0)) * float(berries.size())))
	remain = clampi(remain, 0, berries.size())
	for i in remain:
		var b = berries[i]
		_berry(ci, p + b[0] * s, float(b[1]) * s, b[2])
	if remain > 0:
		ci.draw_polyline(
			PackedVector2Array([p + Vector2(-2, -10) * s, p + Vector2(1, -15) * s, p + Vector2(6, -9) * s]),
			Color(0.24, 0.42, 0.31, a),
			1.8 * s,
			true
		)
		ellipse(ci, p + Vector2(-4, -11) * s, Vector2(5, 2.4) * s, Color(0.31, 0.54, 0.38, a * 0.95))
		ellipse(ci, p + Vector2(5, -10) * s, Vector2(4.5, 2.2) * s, Color(0.42, 0.62, 0.4, a * 0.9))


static func draw_crickets(ci: CanvasItem, p: Vector2, a: float = 1.0, scale: float = 1.0) -> void:
	var s := scale
	# Segmented body pair
	for i in 3:
		var ox := (-4.0 + float(i) * 4.0) * s
		ellipse(ci, p + Vector2(ox, 0), Vector2(4.2, 3.2) * s, Color(0.38, 0.45, 0.24, a))
		ellipse(ci, p + Vector2(ox - 0.8 * s, -0.8 * s), Vector2(1.6, 1.1) * s, Color(0.55, 0.62, 0.35, a * 0.7))
	ellipse(ci, p + Vector2(8, -1) * s, Vector2(3.5, 2.8) * s, Color(0.42, 0.48, 0.28, a))
	ci.draw_circle(p + Vector2(10, -2) * s, 1.1 * s, Color(0.12, 0.14, 0.1, a))
	# Jumping legs
	ci.draw_line(p + Vector2(-5, -2) * s, p + Vector2(-12, -9) * s, Color(0.3, 0.35, 0.18, a), 1.8 * s)
	ci.draw_line(p + Vector2(2, 2) * s, p + Vector2(10, 8) * s, Color(0.3, 0.35, 0.18, a), 1.8 * s)
	ci.draw_line(p + Vector2(-2, 2) * s, p + Vector2(-8, 7) * s, Color(0.28, 0.32, 0.16, a), 1.5 * s)
	# Second cricket peek
	ellipse(ci, p + Vector2(-2, 6) * s, Vector2(5.5, 2.8) * s, Color(0.34, 0.4, 0.22, a * 0.9))
	ci.draw_line(p + Vector2(-4, 5) * s, p + Vector2(-9, 1) * s, Color(0.28, 0.32, 0.16, a * 0.85), 1.4 * s)


static func draw_fish(ci: CanvasItem, p: Vector2, a: float = 1.0, scale: float = 1.0, bite: float = 0.0) -> void:
	var s := scale
	var shorten := clampf(bite, 0.0, 1.0) * 10.0
	ellipse(ci, p + Vector2(shorten * 0.35, 0), Vector2(16 - shorten * 0.55, 7.5) * s, Color(0.55, 0.7, 0.77, a))
	ellipse(ci, p + Vector2(-4 + shorten * 0.2, -2) * s, Vector2(7, 2.6) * s, Color(1, 1, 1, 0.28 * a))
	for i in 4:
		var sx := (-4.0 + float(i) * 4.0 + shorten * 0.15) * s
		ci.draw_arc(p + Vector2(sx, 1.0 * s), 2.4 * s, -0.8, 0.8, 6, Color(0.7, 0.85, 0.9, 0.45 * a), 1.0, true)
	if bite < 0.7:
		ci.draw_colored_polygon(PackedVector2Array([
			p + Vector2(12, 0) * s,
			p + Vector2(22, -7) * s,
			p + Vector2(19, 0) * s,
			p + Vector2(22, 7) * s,
		]), Color(0.35, 0.58, 0.68, a))
	ci.draw_colored_polygon(PackedVector2Array([
		p + Vector2(-1, -7) * s, p + Vector2(4, -12) * s, p + Vector2(7, -5) * s
	]), Color(0.49, 0.78, 0.83, a * (1.0 - bite * 0.3)))
	ci.draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, 6) * s, p + Vector2(5, 11) * s, p + Vector2(8, 5) * s
	]), Color(0.42, 0.65, 0.72, a * 0.9))
	# Bite reduction notch near the head
	if bite > 0.15:
		ellipse(ci, p + Vector2(-10, 0) * s, Vector2(4.5 + bite * 3.0, 3.5) * s, Color(0.2, 0.28, 0.32, 0.35 * a))
	ci.draw_circle(p + Vector2(-9, -1) * s, 1.6 * s, Color(0.1, 0.14, 0.16, a))
	ci.draw_circle(p + Vector2(-9.5, -1.4) * s, 0.55 * s, Color(1, 1, 1, 0.55 * a))


static func draw_pizza(ci: CanvasItem, p: Vector2, a: float = 1.0, scale: float = 1.0, bite: float = 0.0) -> void:
	var s := scale
	var crust := PackedVector2Array([
		p + Vector2(0, -15) * s, p + Vector2(16, 13) * s, p + Vector2(-16, 13) * s
	])
	ci.draw_colored_polygon(crust, Color(0.54, 0.29, 0.16, a))
	ci.draw_polyline(
		PackedVector2Array([p + Vector2(-14, 11) * s, p + Vector2(0, 14) * s, p + Vector2(14, 11) * s]),
		Color(0.62, 0.38, 0.2, a),
		3.2 * s,
		true
	)
	var cheese := PackedVector2Array([
		p + Vector2(0, -12) * s, p + Vector2(13, 10) * s, p + Vector2(-13, 10) * s
	])
	ci.draw_colored_polygon(cheese, Color(0.88, 0.63, 0.29, a))
	ci.draw_line(p + Vector2(-10, -2) * s, p + Vector2(10, -2) * s, Color(0.77, 0.36, 0.29, a), 3.2 * s)
	ci.draw_circle(p + Vector2(-4, 3) * s, 2.6 * s, Color(0.54, 0.18, 0.18, a))
	ci.draw_circle(p + Vector2(5, 5) * s, 2.1 * s, Color(0.54, 0.18, 0.18, a))
	ci.draw_circle(p + Vector2(1, 0) * s, 1.6 * s, Color(0.48, 0.16, 0.16, a))
	ci.draw_colored_polygon(PackedVector2Array([
		p + Vector2(-2, -8) * s, p + Vector2(4, -2) * s, p + Vector2(-1, -1) * s
	]), Color(1, 1, 1, 0.28 * a))
	# Visible bite marks as pizza is eaten.
	if bite > 0.12:
		ellipse(ci, p + Vector2(-3, -10) * s, Vector2(4.5, 3.5) * s, Color(0.2, 0.12, 0.08, 0.55 * a * minf(1.0, bite * 2.0)))
		ellipse(ci, p + Vector2(3, -9) * s, Vector2(4.0, 3.2) * s, Color(0.2, 0.12, 0.08, 0.5 * a * minf(1.0, bite * 2.0)))
	if bite > 0.45:
		ellipse(ci, p + Vector2(0, -4) * s, Vector2(7.0, 5.0) * s, Color(0.18, 0.1, 0.07, 0.45 * a))
	if bite > 0.75:
		ellipse(ci, p + Vector2(-5, 2) * s, Vector2(6.0, 4.0) * s, Color(0.16, 0.09, 0.06, 0.5 * a))


static func draw_fries(ci: CanvasItem, p: Vector2, a: float = 1.0, scale: float = 1.0, bite: float = 0.0) -> void:
	var s := scale
	ci.draw_colored_polygon(PackedVector2Array([
		p + Vector2(-12, 2) * s, p + Vector2(12, 2) * s,
		p + Vector2(9, 16) * s, p + Vector2(-9, 16) * s
	]), Color(0.77, 0.36, 0.29, a))
	round_rect(ci, Rect2(p + Vector2(-11, 0) * s, Vector2(22, 4) * s), Color(0.83, 0.42, 0.34, a), 1.5 * s)
	var fries := [
		[-7.0, -13.0, 3.0, 17.0, Color("e0a04a")],
		[-2.5, -15.0, 3.2, 19.0, Color("f0c57a")],
		[2.0, -12.0, 2.9, 16.0, Color("d4923a")],
		[6.5, -14.0, 2.7, 18.0, Color("e8b45a")],
		[0.5, -11.0, 2.4, 14.0, Color("f4d08a")],
	]
	# Fries disappear individually from the top of the carton.
	var remain := int(ceili((1.0 - clampf(bite, 0.0, 1.0)) * float(fries.size())))
	remain = clampi(remain, 0, fries.size())
	for i in remain:
		var f = fries[i]
		var fr := Rect2(p + Vector2(float(f[0]), float(f[1])) * s, Vector2(float(f[2]), float(f[3])) * s)
		round_rect(ci, fr, Color(f[4].r, f[4].g, f[4].b, a), 1.2 * s)
		ci.draw_rect(Rect2(fr.position + Vector2(0.5, 1) * s, Vector2(maxf(1.0, fr.size.x * 0.35), fr.size.y - 2.0 * s)), Color(1, 1, 1, 0.22 * a))


static func draw_food(ci: CanvasItem, food_key: String, p: Vector2, a: float = 1.0, scale: float = 1.0, bite: float = 0.0) -> void:
	match food_key:
		"pizza":
			draw_pizza(ci, p, a, scale, bite)
		"fries":
			draw_fries(ci, p, a, scale, bite)
		"fish":
			draw_fish(ci, p, a, scale, bite)
		"crickets":
			draw_crickets(ci, p, a, scale)
		_:
			draw_berries(ci, p, a, scale, bite)


static func _berry(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ellipse(ci, c, Vector2(r, r), col.darkened(0.1))
	ellipse(ci, c + Vector2(-r * 0.28, -r * 0.32), Vector2(r * 0.42, r * 0.35), col.lightened(0.28))
	ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.16, Color(1, 1, 1, col.a * 0.4))


static func draw_label(ci: CanvasItem, p: Vector2, text: String, color: Color, font_size: int = 13) -> void:
	var font := ThemeDB.fallback_font
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	ellipse(ci, p + Vector2(0, -2), Vector2(tw * 0.55 + 8.0, 9.0), Color(0.05, 0.08, 0.06, color.a * 0.55))
	ci.draw_string(font, p + Vector2(-tw * 0.5, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


static func draw_vignette(ci: CanvasItem, size: Vector2, strength: float = 0.45) -> void:
	var w := size.x
	var h := size.y
	var band := 28.0
	ci.draw_rect(Rect2(0, 0, w, band), Color(0, 0, 0, strength * 0.55))
	ci.draw_rect(Rect2(0, h - band, w, band), Color(0, 0, 0, strength * 0.65))
	ci.draw_rect(Rect2(0, 0, band * 0.7, h), Color(0, 0, 0, strength * 0.4))
	ci.draw_rect(Rect2(w - band * 0.7, 0, band * 0.7, h), Color(0, 0, 0, strength * 0.4))
