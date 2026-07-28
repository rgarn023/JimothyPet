extends Node
## Shared look-and-feel for Normal / Cell-shaded / Realistic graphic modes.

signal mode_changed(mode: String)

const MODE_NORMAL := "normal"
const MODE_CELL := "cell_shaded"
const MODE_REALISTIC := "realistic"

const MODES := [MODE_NORMAL, MODE_CELL, MODE_REALISTIC]

## Soft key light from upper-left (screen space).
const LIGHT_DIR := Vector2(-0.45, -0.75)


func mode() -> String:
	if PetState == null:
		return MODE_NORMAL
	var m := str(PetState.graphic_mode)
	if m in MODES:
		return m
	return MODE_NORMAL


func is_cell() -> bool:
	return mode() == MODE_CELL


func is_realistic() -> bool:
	return mode() == MODE_REALISTIC


func set_mode(m: String, save: bool = true) -> void:
	var next := str(m)
	if next not in MODES:
		next = MODE_NORMAL
	if PetState == null:
		return
	if PetState.graphic_mode == next:
		mode_changed.emit(next)
		return
	PetState.graphic_mode = next
	if save:
		PetState.save_game()
	PetState.state_changed.emit()
	mode_changed.emit(next)


func posterize(c: Color, steps: float = 4.0) -> Color:
	var s := maxf(2.0, steps)
	return Color(
		roundf(c.r * s) / s,
		roundf(c.g * s) / s,
		roundf(c.b * s) / s,
		c.a
	)


func style_fill(c: Color) -> Color:
	match mode():
		MODE_CELL:
			return posterize(c, 3.5)
		MODE_REALISTIC:
			return c.lerp(Color(c.r * 0.92, c.g * 0.94, c.b * 0.9), 0.12)
		_:
			return c


func outline_for(c: Color) -> Color:
	var o := c.darkened(0.62).lerp(Color(0.05, 0.05, 0.07), 0.35)
	o.a = minf(1.0, c.a + 0.15)
	return posterize(o, 3.0)


func draw_ellipse(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color, points: int = 26) -> void:
	if color.a <= 0.001:
		return
	match mode():
		MODE_CELL:
			_draw_ellipse_cell(ci, center, radii, color, points)
		MODE_REALISTIC:
			_draw_ellipse_realistic(ci, center, radii, color, points)
		_:
			_poly_ellipse(ci, center, radii, color, points)


func draw_circle_styled(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	draw_ellipse(ci, center, Vector2(radius, radius), color, 22)


func draw_poly(ci: CanvasItem, pts: PackedVector2Array, color: Color, outline: bool = true) -> void:
	if pts.size() < 3 or color.a <= 0.001:
		return
	match mode():
		MODE_CELL:
			var fill := posterize(color, 3.5)
			if outline and color.a > 0.35:
				var grown := _grow_poly(pts, 1.8)
				ci.draw_colored_polygon(grown, outline_for(color))
			ci.draw_colored_polygon(pts, fill)
			# Flat shade wedge
			if color.a > 0.4 and pts.size() >= 3:
				var shade := fill.darkened(0.22)
				shade.a = fill.a * 0.45
				var c := _poly_centroid(pts)
				var band := PackedVector2Array([c, pts[0], pts[mini(1, pts.size() - 1)]])
				if band.size() >= 3:
					ci.draw_colored_polygon(band, shade)
		MODE_REALISTIC:
			var base := color.darkened(0.06)
			ci.draw_colored_polygon(pts, base)
			var hi := color.lightened(0.18)
			hi.a = color.a * 0.55
			var c2 := _poly_centroid(pts) + LIGHT_DIR * 4.0
			var soft := PackedVector2Array()
			for i in mini(pts.size(), 6):
				soft.append(pts[i].lerp(c2, 0.35))
			if soft.size() >= 3:
				ci.draw_colored_polygon(soft, hi)
		_:
			ci.draw_colored_polygon(pts, color)


func face_lit(base: Color, n_z: float) -> Color:
	## Dice / projected-mesh lighting tuned per graphic mode.
	match mode():
		MODE_CELL:
			var band := 0.4 if n_z < 0.35 else (0.7 if n_z < 0.7 else 1.0)
			return posterize(Color(base.r * band, base.g * band, base.b * band, base.a), 3.0)
		MODE_REALISTIC:
			var soft := 0.28 + 0.72 * pow(maxf(0.0, n_z), 1.35)
			var col := Color(base.r * soft, base.g * soft, base.b * soft, base.a)
			# Cool fill from below
			col = col.lerp(Color(base.r * 0.55, base.g * 0.62, base.b * 0.7, base.a), 0.12 * (1.0 - n_z))
			return col
		_:
			var lit := 0.35 + 0.65 * maxf(0.0, n_z)
			return Color(base.r * lit, base.g * lit, base.b * lit, base.a)


func edge_color(default_col: Color) -> Color:
	match mode():
		MODE_CELL:
			return Color(0.08, 0.08, 0.1, 0.95)
		MODE_REALISTIC:
			var e := default_col.darkened(0.15)
			e.a = 0.35
			return e
		_:
			return default_col


func sky_band_count() -> int:
	match mode():
		MODE_CELL:
			return 8
		MODE_REALISTIC:
			return 40
		_:
			return 24


func _draw_ellipse_cell(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color, points: int) -> void:
	var fill := posterize(color, 3.5)
	if color.a > 0.25:
		_poly_ellipse(ci, center, radii + Vector2(2.0, 2.0), outline_for(color), points)
	_poly_ellipse(ci, center, radii, fill, points)
	if color.a > 0.35 and minf(radii.x, radii.y) > 3.0:
		var shade := fill.darkened(0.28)
		shade.a = fill.a * 0.5
		_poly_ellipse(
			ci,
			center + Vector2(radii.x * 0.18, radii.y * 0.22),
			radii * Vector2(0.62, 0.5),
			shade,
			maxi(10, points / 2)
		)
		var hi := fill.lightened(0.2)
		hi.a = fill.a * 0.35
		_poly_ellipse(
			ci,
			center + LIGHT_DIR * Vector2(radii.x, radii.y) * 0.35,
			radii * Vector2(0.35, 0.28),
			hi,
			maxi(8, points / 3)
		)


func _draw_ellipse_realistic(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color, points: int) -> void:
	if color.a > 0.2 and minf(radii.x, radii.y) > 2.5:
		var sh := Color(0.02, 0.03, 0.04, color.a * 0.22)
		_poly_ellipse(ci, center + Vector2(1.2, radii.y * 0.18), radii * Vector2(1.06, 0.88), sh, points)
	var base := color.darkened(0.1)
	_poly_ellipse(ci, center, radii, base, points)
	var mid := color.lightened(0.06)
	mid.a = color.a * 0.88
	_poly_ellipse(
		ci,
		center + LIGHT_DIR * Vector2(radii.x, radii.y) * 0.18,
		radii * 0.78,
		mid,
		points
	)
	if color.a > 0.3 and minf(radii.x, radii.y) > 4.0:
		var rim := color.lightened(0.12)
		rim.a = color.a * 0.25
		_poly_ellipse(
			ci,
			center - LIGHT_DIR * Vector2(radii.x, radii.y) * 0.55,
			radii * Vector2(0.55, 0.42),
			rim,
			maxi(10, points / 2)
		)
		var spec := Color(1.0, 0.98, 0.94, color.a * 0.3)
		_poly_ellipse(
			ci,
			center + LIGHT_DIR * Vector2(radii.x, radii.y) * 0.42,
			radii * Vector2(0.26, 0.2),
			spec,
			maxi(8, points / 3)
		)


func _poly_ellipse(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color, points: int) -> void:
	var n := maxi(8, points)
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * float(i) / float(n)
		pts[i] = center + Vector2(cos(a) * radii.x, sin(a) * radii.y)
	ci.draw_colored_polygon(pts, color)


func _poly_centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / float(pts.size())


func _grow_poly(pts: PackedVector2Array, amount: float) -> PackedVector2Array:
	var c := _poly_centroid(pts)
	var out := PackedVector2Array()
	for p in pts:
		var d := p - c
		var len := d.length()
		if len < 0.001:
			out.append(p)
		else:
			out.append(c + d * ((len + amount) / len))
	return out
