extends Node
## Shared look-and-feel for Normal / Cell-shaded / Realistic graphic modes.
## Realistic keeps the same 2D silhouettes/designs and softens them with
## richer lighting, depth, and material shading — no replacement meshes.

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
			# Slightly warmer, denser pigments — same hue family.
			return c.lerp(Color(c.r * 1.02, c.g * 0.99, c.b * 0.94), 0.14)
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
			_draw_poly_realistic(ci, pts, color)
		_:
			ci.draw_colored_polygon(pts, color)


func face_lit(base: Color, n_z: float) -> Color:
	## Dice / projected-mesh lighting tuned per graphic mode.
	match mode():
		MODE_CELL:
			var band := 0.4 if n_z < 0.35 else (0.7 if n_z < 0.7 else 1.0)
			return posterize(Color(base.r * band, base.g * band, base.b * band, base.a), 3.0)
		MODE_REALISTIC:
			var soft := 0.34 + 0.66 * pow(maxf(0.0, n_z), 1.15)
			var col := Color(base.r * soft, base.g * soft, base.b * soft, base.a)
			# Warm key + cool fill, still readable as the same die.
			col = col.lerp(Color(base.r * 1.05, base.g * 0.98, base.b * 0.88, base.a), 0.12 * n_z)
			col = col.lerp(Color(base.r * 0.58, base.g * 0.64, base.b * 0.72, base.a), 0.14 * (1.0 - n_z))
			return col
		_:
			var lit := 0.35 + 0.65 * maxf(0.0, n_z)
			return Color(base.r * lit, base.g * lit, base.b * lit, base.a)


func edge_color(default_col: Color) -> Color:
	match mode():
		MODE_CELL:
			return Color(0.08, 0.08, 0.1, 0.95)
		MODE_REALISTIC:
			var e := default_col.darkened(0.22)
			e.a = 0.42
			return e
		_:
			return default_col


func sky_band_count() -> int:
	match mode():
		MODE_CELL:
			return 8
		MODE_REALISTIC:
			return 48
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
	## Same silhouette as Normal, painted with soft volume, AO, and fur grain.
	var min_r := minf(radii.x, radii.y)
	var lit := style_fill(color)

	# Contact / ambient occlusion under the form (does not change outline).
	if color.a > 0.22 and min_r > 2.2:
		var ao := Color(0.04, 0.05, 0.06, color.a * 0.28)
		_poly_ellipse(
			ci,
			center + Vector2(0.8, radii.y * 0.22),
			radii * Vector2(1.08, 0.78),
			ao,
			points
		)

	# Core body mass — slightly denser base so highlights read.
	var core := lit.darkened(0.08)
	_poly_ellipse(ci, center, radii, core, points)

	# Soft form shadow opposite the key light.
	if color.a > 0.28 and min_r > 3.0:
		var form_sh := lit.darkened(0.22)
		form_sh.a = lit.a * 0.42
		_poly_ellipse(
			ci,
			center - LIGHT_DIR * Vector2(radii.x, radii.y) * 0.22,
			radii * Vector2(0.72, 0.68),
			form_sh,
			maxi(12, points - 4)
		)

	# Mid-tone lift toward the key.
	var mid := lit.lightened(0.05)
	mid.a = lit.a * 0.82
	_poly_ellipse(
		ci,
		center + LIGHT_DIR * Vector2(radii.x, radii.y) * 0.16,
		radii * 0.72,
		mid,
		points
	)

	# Warm subsurface / bounce near the lit rim.
	if color.a > 0.32 and min_r > 4.0:
		var bounce := Color(
			minf(1.0, lit.r * 1.08 + 0.04),
			minf(1.0, lit.g * 0.98 + 0.02),
			minf(1.0, lit.b * 0.9),
			lit.a * 0.22
		)
		_poly_ellipse(
			ci,
			center + LIGHT_DIR * Vector2(radii.x, radii.y) * 0.48,
			radii * Vector2(0.48, 0.4),
			bounce,
			maxi(10, points / 2)
		)

	# Soft specular — small and diffuse so it stays “painted”, not plastic.
	if color.a > 0.35 and min_r > 5.0:
		var spec := Color(1.0, 0.98, 0.94, lit.a * 0.18)
		_poly_ellipse(
			ci,
			center + LIGHT_DIR * Vector2(radii.x, radii.y) * 0.38,
			radii * Vector2(0.22, 0.16),
			spec,
			maxi(8, points / 3)
		)

	# Fine fur / surface grain — tiny ticks inside the silhouette only.
	if color.a > 0.4 and min_r > 7.0:
		_draw_fur_grain(ci, center, radii, lit)


func _draw_poly_realistic(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	var lit := style_fill(color)
	var c := _poly_centroid(pts)

	# Soft AO blob under the poly.
	if color.a > 0.25:
		var ao_pts := _grow_poly(pts, 1.2)
		var ao := Color(0.04, 0.05, 0.06, color.a * 0.2)
		# Offset downward slightly.
		var shifted := PackedVector2Array()
		for p in ao_pts:
			shifted.append(p + Vector2(0.6, 1.4))
		if shifted.size() >= 3:
			ci.draw_colored_polygon(shifted, ao)

	ci.draw_colored_polygon(pts, lit.darkened(0.06))

	# Lit half toward key light.
	var hi := lit.lightened(0.12)
	hi.a = lit.a * 0.5
	var soft := PackedVector2Array()
	var toward := c + LIGHT_DIR * 6.0
	for i in pts.size():
		var p: Vector2 = pts[i]
		var bias := 0.28 if (p - c).dot(LIGHT_DIR) > 0.0 else 0.08
		soft.append(p.lerp(toward, bias))
	if soft.size() >= 3:
		ci.draw_colored_polygon(soft, hi)

	# Cool shade wedge on the opposite side.
	if color.a > 0.35 and pts.size() >= 3:
		var shade := lit.darkened(0.2)
		shade.a = lit.a * 0.35
		var away := c - LIGHT_DIR * 5.0
		var band := PackedVector2Array([away, pts[0], pts[mini(pts.size() - 1, maxi(1, pts.size() / 2))]])
		if band.size() >= 3:
			ci.draw_colored_polygon(band, shade)


func _draw_fur_grain(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	## Subtle directional fur ticks — reads as coat texture, keeps the same shape.
	var grain := color.darkened(0.18)
	grain.a = color.a * 0.16
	var hi_grain := color.lightened(0.1)
	hi_grain.a = color.a * 0.1
	var count := clampi(int(minf(radii.x, radii.y) * 0.55), 6, 18)
	for i in count:
		var seed := float(i) * 2.399 + center.x * 0.13 + center.y * 0.07
		var ang := fmod(seed * 1.7, TAU)
		var u := 0.25 + 0.55 * absf(sin(seed * 3.1))
		var v := 0.2 + 0.5 * absf(cos(seed * 2.4))
		var local := Vector2(cos(ang) * radii.x * u, sin(ang) * radii.y * v)
		# Bias grain with light so lit side is finer/brighter.
		var along := LIGHT_DIR.rotated(0.35 + 0.15 * sin(seed))
		var p0 := center + local
		var p1 := p0 + along * Vector2(radii.x, radii.y) * 0.08
		var stroke := hi_grain if local.dot(LIGHT_DIR) > 0.0 else grain
		ci.draw_line(p0, p1, stroke, 1.0)


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
