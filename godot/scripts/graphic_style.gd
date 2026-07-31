extends Node
## Shared look-and-feel for Normal / Cell-shaded / Realistic graphic modes.
## Realistic keeps the same designs but softens them into organic, painted forms
## with depth and texture — no stacked perfect circles / triangles / boxes.

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


## Soft junction so overlapping body parts read as one mass (Realistic only).
func draw_joint_blend(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	if not is_realistic() or color.a <= 0.001:
		return
	var lit := style_fill(color)
	lit.a = color.a * 0.55
	_poly_organic(ci, center, radii * 1.15, lit, 18, 0.12)
	var soft := lit.lightened(0.04)
	soft.a = color.a * 0.28
	_poly_organic(ci, center + LIGHT_DIR * Vector2(radii.x, radii.y) * 0.12, radii * 0.7, soft, 14, 0.1)


## Organic capsule for legs / tails in Realistic — avoids stick + circle look.
func draw_limb(ci: CanvasItem, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	if color.a <= 0.001:
		return
	if not is_realistic():
		ci.draw_line(a, b, color, width)
		return
	var lit := style_fill(color)
	var dir := b - a
	var len := dir.length()
	if len < 0.5:
		draw_ellipse(ci, a, Vector2(width * 0.55, width * 0.4), lit, 14)
		return
	var n := dir.normalized()
	var perp := Vector2(-n.y, n.x)
	var half := width * 0.55
	var bulge := width * 0.12
	# Soft under-shadow for contact with body.
	var ao := Color(0.04, 0.05, 0.06, lit.a * 0.22)
	var ao_pts := PackedVector2Array([
		a + perp * (half * 1.15) + Vector2(0.6, 1.2),
		a - perp * (half * 1.15) + Vector2(0.6, 1.2),
		b - perp * (half * 0.95) + Vector2(0.6, 1.2),
		b + perp * (half * 0.95) + Vector2(0.6, 1.2),
	])
	ci.draw_colored_polygon(_round_poly(ao_pts, 1), ao)

	var mid := (a + b) * 0.5
	var pts := PackedVector2Array([
		a + perp * half,
		mid + perp * (half + bulge) + n * len * 0.02,
		b + perp * (half * 0.85),
		b - perp * (half * 0.85),
		mid - perp * (half + bulge * 0.6) + n * len * 0.02,
		a - perp * half,
	])
	var body := _round_poly(pts, 2)
	ci.draw_colored_polygon(body, lit.darkened(0.06))
	# Lit edge
	var hi := lit.lightened(0.1)
	hi.a = lit.a * 0.45
	var hi_pts := PackedVector2Array([
		a + perp * half * 0.35 + LIGHT_DIR * 1.5,
		mid + perp * (half * 0.55) + LIGHT_DIR * 2.0,
		b + perp * half * 0.25 + LIGHT_DIR * 1.2,
		b - perp * half * 0.1,
		mid - perp * half * 0.15,
		a - perp * half * 0.1,
	])
	ci.draw_colored_polygon(_round_poly(hi_pts, 1), hi)
	# Soft paw tip mass
	draw_ellipse(ci, b, Vector2(width * 0.72, width * 0.42), lit.darkened(0.08), 14)


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
	## Organic painted mass: irregular silhouette, soft depth, fur grain.
	## Avoid nested perfect ellipses that read as stacked balls.
	var min_r := minf(radii.x, radii.y)
	var lit := style_fill(color)
	var n := maxi(14, points + 4)

	# Contact / ambient occlusion under the form (organic, not a hard oval).
	if color.a > 0.22 and min_r > 2.2:
		var ao := Color(0.04, 0.05, 0.06, color.a * 0.22)
		_poly_organic(
			ci,
			center + Vector2(0.6, radii.y * 0.18),
			radii * Vector2(1.12, 0.82),
			ao,
			n,
			0.1
		)

	# Soft under-bleed so overlapping parts fuse instead of showing circle seams.
	if color.a > 0.28 and min_r > 3.5:
		var bleed := lit
		bleed.a = lit.a * 0.32
		_poly_organic(ci, center, radii * 1.08, bleed, n, 0.14)

	# Core organic silhouette.
	var core := lit.darkened(0.05)
	_poly_organic(ci, center, radii, core, n, 0.16)

	# Broad soft form shadow — irregular, low-contrast so it doesn't look like a second ball.
	if color.a > 0.28 and min_r > 3.0:
		var form_sh := lit.darkened(0.18)
		form_sh.a = lit.a * 0.28
		_poly_organic(
			ci,
			center - LIGHT_DIR * Vector2(radii.x, radii.y) * 0.18,
			radii * Vector2(0.78, 0.74),
			form_sh,
			maxi(12, n - 4),
			0.2
		)

	# Soft mid-tone lift toward the key — organic blob, low alpha.
	var mid := lit.lightened(0.06)
	mid.a = lit.a * 0.38
	_poly_organic(
		ci,
		center + LIGHT_DIR * Vector2(radii.x, radii.y) * 0.18,
		radii * 0.62,
		mid,
		maxi(12, n - 6),
		0.18
	)

	# Warm subsurface / bounce near the lit rim.
	if color.a > 0.32 and min_r > 4.0:
		var bounce := Color(
			minf(1.0, lit.r * 1.06 + 0.03),
			minf(1.0, lit.g * 0.98 + 0.015),
			minf(1.0, lit.b * 0.9),
			lit.a * 0.16
		)
		_poly_organic(
			ci,
			center + LIGHT_DIR * Vector2(radii.x, radii.y) * 0.42,
			radii * Vector2(0.42, 0.34),
			bounce,
			maxi(10, n / 2),
			0.22
		)

	# Diffuse rim darkening so the edge isn't a crisp oval cutout.
	if color.a > 0.35 and min_r > 5.0:
		_draw_soft_rim(ci, center, radii, lit, n)

	# Fine fur / surface grain inside the silhouette.
	if color.a > 0.4 and min_r > 6.5:
		_draw_fur_grain(ci, center, radii, lit)


func _draw_poly_realistic(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	var lit := style_fill(color)
	var organic := _organicize_poly(pts, 0.14)
	var c := _poly_centroid(organic)

	# Soft AO under the shape.
	if color.a > 0.25:
		var ao_pts := _grow_poly(organic, 1.4)
		var ao := Color(0.04, 0.05, 0.06, color.a * 0.18)
		var shifted := PackedVector2Array()
		for p in ao_pts:
			shifted.append(p + Vector2(0.5, 1.2))
		if shifted.size() >= 3:
			ci.draw_colored_polygon(_round_poly(shifted, 1), ao)

	# Soft under-bleed for seams with neighbors.
	if color.a > 0.3:
		var bleed := lit
		bleed.a = lit.a * 0.28
		ci.draw_colored_polygon(_grow_poly(organic, 1.0), bleed)

	ci.draw_colored_polygon(organic, lit.darkened(0.05))

	# Soft lit half — organic, not a hard wedge.
	var hi := lit.lightened(0.1)
	hi.a = lit.a * 0.38
	var soft := PackedVector2Array()
	var toward := c + LIGHT_DIR * 5.0
	for i in organic.size():
		var p: Vector2 = organic[i]
		var bias := 0.22 if (p - c).dot(LIGHT_DIR) > 0.0 else 0.06
		soft.append(p.lerp(toward, bias))
	if soft.size() >= 3:
		ci.draw_colored_polygon(_round_poly(soft, 1), hi)

	# Cool shade on the away side — rounded, low contrast.
	if color.a > 0.35 and organic.size() >= 3:
		var shade := lit.darkened(0.16)
		shade.a = lit.a * 0.26
		var away := c - LIGHT_DIR * 4.0
		var band := PackedVector2Array([
			away,
			organic[0],
			organic[mini(organic.size() - 1, maxi(1, organic.size() / 2))],
		])
		ci.draw_colored_polygon(_round_poly(band, 2), shade)

	# Light surface grain on larger polys (trees, food wedges).
	var extent := 0.0
	for p in organic:
		extent = maxf(extent, p.distance_to(c))
	if color.a > 0.4 and extent > 10.0:
		_draw_surface_grain(ci, c, extent, lit)


func _draw_soft_rim(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color, points: int) -> void:
	## Darken the outer rim slightly so the silhouette feels volumetric, not cut out.
	var rim := color.darkened(0.2)
	rim.a = color.a * 0.12
	var outer := _organic_pts(center, radii * 1.02, points, 0.12)
	var inner := _organic_pts(center, radii * 0.82, points, 0.1)
	# Draw as a ring of thin wedges.
	var n := mini(outer.size(), inner.size())
	for i in n:
		var j := (i + 1) % n
		var quad := PackedVector2Array([outer[i], outer[j], inner[j], inner[i]])
		ci.draw_colored_polygon(quad, rim)


func _draw_fur_grain(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	## Subtle directional fur ticks — reads as coat texture, keeps the same shape.
	var grain := color.darkened(0.18)
	grain.a = color.a * 0.14
	var hi_grain := color.lightened(0.1)
	hi_grain.a = color.a * 0.09
	var count := clampi(int(minf(radii.x, radii.y) * 0.65), 8, 22)
	for i in count:
		var seed := float(i) * 2.399 + center.x * 0.13 + center.y * 0.07
		var ang := fmod(seed * 1.7, TAU)
		var u := 0.22 + 0.58 * absf(sin(seed * 3.1))
		var v := 0.18 + 0.52 * absf(cos(seed * 2.4))
		# Keep ticks inside organic silhouette.
		var wobble := 0.92 + 0.1 * sin(ang * 3.0 + seed)
		var local := Vector2(cos(ang) * radii.x * u * wobble, sin(ang) * radii.y * v * wobble)
		var along := LIGHT_DIR.rotated(0.35 + 0.15 * sin(seed))
		var p0 := center + local
		var p1 := p0 + along * Vector2(radii.x, radii.y) * 0.07
		var stroke := hi_grain if local.dot(LIGHT_DIR) > 0.0 else grain
		ci.draw_line(p0, p1, stroke, 1.0)


func _draw_surface_grain(ci: CanvasItem, center: Vector2, extent: float, color: Color) -> void:
	var grain := color.darkened(0.14)
	grain.a = color.a * 0.1
	var count := clampi(int(extent * 0.35), 4, 12)
	for i in count:
		var seed := float(i) * 1.7 + center.x * 0.09 + center.y * 0.05
		var ang := fmod(seed * 2.1, TAU)
		var d := extent * (0.25 + 0.45 * absf(sin(seed * 2.7)))
		var p0 := center + Vector2(cos(ang), sin(ang)) * d
		var p1 := p0 + LIGHT_DIR.rotated(sin(seed)) * extent * 0.08
		ci.draw_line(p0, p1, grain, 1.0)


func _poly_ellipse(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color, points: int) -> void:
	var n := maxi(8, points)
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * float(i) / float(n)
		pts[i] = center + Vector2(cos(a) * radii.x, sin(a) * radii.y)
	ci.draw_colored_polygon(pts, color)


func _poly_organic(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color, points: int, amp: float) -> void:
	var pts := _organic_pts(center, radii, points, amp)
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, color)


func _organic_pts(center: Vector2, radii: Vector2, points: int, amp: float) -> PackedVector2Array:
	## Irregular silhouette so masses don't read as perfect circles.
	var n := maxi(10, points)
	var pts := PackedVector2Array()
	pts.resize(n)
	var seed := center.x * 0.17 + center.y * 0.11 + radii.x * 0.03
	for i in n:
		var a := TAU * float(i) / float(n)
		# Multi-harmonic wobble — soft lobes, not star spikes.
		var wobble := 1.0 \
			+ amp * 0.55 * sin(a * 2.0 + seed) \
			+ amp * 0.35 * sin(a * 3.0 - seed * 1.3) \
			+ amp * 0.18 * sin(a * 5.0 + seed * 0.7)
		wobble = clampf(wobble, 0.78, 1.22)
		pts[i] = center + Vector2(cos(a) * radii.x * wobble, sin(a) * radii.y * wobble)
	return pts


func _organicize_poly(pts: PackedVector2Array, amp: float) -> PackedVector2Array:
	## Push polygon vertices outward unevenly and round sharp corners (triangles → soft leaves).
	if pts.size() < 3:
		return pts
	var c := _poly_centroid(pts)
	var warped := PackedVector2Array()
	for i in pts.size():
		var p: Vector2 = pts[i]
		var d := p - c
		var len := d.length()
		if len < 0.001:
			warped.append(p)
			continue
		var seed := float(i) * 1.9 + c.x * 0.08 + c.y * 0.05
		var f := 1.0 + amp * sin(seed) * 0.9 + amp * 0.35 * cos(seed * 1.7)
		warped.append(c + d * clampf(f, 0.82, 1.18))
	# Extra mid-edge points so triangles don't stay sharp wedges.
	var denser := PackedVector2Array()
	for i in warped.size():
		var a: Vector2 = warped[i]
		var b: Vector2 = warped[(i + 1) % warped.size()]
		denser.append(a)
		var mid := a.lerp(b, 0.5)
		var outward := (mid - c).normalized() if mid.distance_to(c) > 0.001 else Vector2.ZERO
		denser.append(mid + outward * (amp * 4.0))
	return _round_poly(denser, 2)


func _round_poly(pts: PackedVector2Array, passes: int = 1) -> PackedVector2Array:
	## Chaikin-ish corner cutting for soft organic outlines.
	var cur := pts
	for _p in maxi(1, passes):
		if cur.size() < 3:
			break
		var nxt := PackedVector2Array()
		for i in cur.size():
			var a: Vector2 = cur[i]
			var b: Vector2 = cur[(i + 1) % cur.size()]
			nxt.append(a.lerp(b, 0.25))
			nxt.append(a.lerp(b, 0.75))
		cur = nxt
	return cur


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
