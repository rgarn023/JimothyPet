extends Control
## Animated Jimothy — bush rustle, walk/run/jump, form variance, adult short-spine look.

var stage: String = "bush"
var young_form: String = "puff"
var teen_form: String = "bounder"
var adult_form: String = "saint"
var genes: Dictionary = {}
var mood: String = "idle"

var _t: float = 0.0
var _pose_x: float = 0.0
var _pose_y: float = 0.0
var _facing: float = 1.0
var _anim: String = "idle"
var _anim_t: float = 0.0
var _anim_dur: float = 1.2
var _walk_phase: float = 0.0
var _jump_peak: float = 0.0
var _target_x: float = 0.0
var _speed: float = 0.0
var _eat_flash: float = 0.0


func _ready() -> void:
	if PetState:
		PetState.anim_impulse.connect(play_anim)
		PetState.state_changed.connect(_sync_from_state)
		_sync_from_state()


func _sync_from_state() -> void:
	var p: Dictionary = PetState.form_profile()
	stage = str(p.stage)
	young_form = str(p.young_form)
	teen_form = str(p.teen_form)
	adult_form = str(p.adult_form)
	genes = p.genes if typeof(p.genes) == TYPE_DICTIONARY else {}
	if PetState.stubborn:
		mood = "stubborn"
	elif PetState.sick:
		mood = "sick"
	else:
		mood = "idle"
	queue_redraw()


func set_look(_stage: String, _variant: String = "", _mood: String = "idle") -> void:
	# Kept for main.gd compatibility; prefer PetState sync.
	mood = _mood
	_sync_from_state()


func play_anim(kind: String) -> void:
	_anim = kind
	_anim_t = 0.0
	match kind:
		"run":
			_anim_dur = randf_range(1.4, 2.4)
			_speed = randf_range(90.0, 140.0)
			_target_x = randf_range(-70.0, 70.0)
			_facing = signf(_target_x - _pose_x)
			if _facing == 0.0:
				_facing = 1.0
		"walk", "lope":
			_anim_dur = randf_range(1.8, 3.2)
			_speed = randf_range(35.0, 70.0) if kind == "walk" else randf_range(55.0, 95.0)
			_target_x = randf_range(-65.0, 65.0)
			_facing = signf(_target_x - _pose_x)
			if _facing == 0.0:
				_facing = [-1.0, 1.0][randi() % 2]
		"jump":
			_anim_dur = randf_range(0.55, 0.9)
			_jump_peak = randf_range(18.0, 36.0)
			_facing = [-1.0, 1.0][randi() % 2]
			_target_x = clampf(_pose_x + _facing * randf_range(20.0, 50.0), -70.0, 70.0)
		"pop", "stretch":
			_anim_dur = 0.8
		"eat":
			_anim_dur = 0.9
			_eat_flash = 1.0
		"refuse", "scold", "stubborn", "sick":
			_anim_dur = 1.0
		_:
			_anim_dur = randf_range(1.0, 2.0)
			_speed = 0.0


func _process(delta: float) -> void:
	_t += delta
	_anim_t += delta
	_eat_flash = maxf(0.0, _eat_flash - delta)

	if stage == "bush":
		_pose_x = sin(_t * 9.0) * 2.0 + sin(_t * 3.3) * 1.5
		_pose_y = sin(_t * 7.0) * 1.5
		queue_redraw()
		return

	match _anim:
		"walk", "run", "lope":
			var dir := signf(_target_x - _pose_x)
			if dir == 0.0:
				dir = _facing
			_facing = dir
			_pose_x = move_toward(_pose_x, _target_x, _speed * delta)
			_walk_phase += delta * (_speed * 0.12)
			_pose_y = absf(sin(_walk_phase)) * (3.0 if _anim == "walk" else 5.5)
			if absf(_pose_x - _target_x) < 1.5 or _anim_t >= _anim_dur:
				if randf() < 0.45 and _anim_t < _anim_dur:
					_target_x = randf_range(-70.0, 70.0)
					_facing = signf(_target_x - _pose_x)
				else:
					_anim = "idle"
					_pose_y = 0.0
		"jump":
			var u := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_pose_y = -sin(u * PI) * _jump_peak
			_pose_x = lerpf(_pose_x, _target_x, delta * 3.5)
			if u >= 1.0:
				_anim = "idle"
				_pose_y = 0.0
		"pop":
			_pose_y = -ease(_anim_t / _anim_dur, 0.3) * 20.0
			if _anim_t >= _anim_dur:
				_anim = "idle"
				_pose_y = 0.0
		"eat":
			_pose_y = sin(_t * 16.0) * 2.0
			if _anim_t >= _anim_dur:
				_anim = "idle"
		"stubborn", "refuse":
			_pose_x += sin(_t * 18.0) * 0.6
			if _anim_t >= _anim_dur:
				_anim = "idle"
		_:
			_pose_y = sin(_t * 2.2) * 2.0
			# Occasional idle weight-shift
			_pose_x = move_toward(_pose_x, sin(_t * 0.35) * 8.0, 10.0 * delta)

	_pose_x = clampf(_pose_x, -75.0, 75.0)
	queue_redraw()


func _ellipse(center: Vector2, radii: Vector2, color: Color, points: int = 26) -> void:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * float(i) / float(points)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func _g(key: String, fallback: float = 0.5) -> float:
	return float(genes.get(key, fallback))


func _fur() -> Color:
	var g := _g("gray", 0.5)
	var base := Color(0.42 + g * 0.08, 0.42 + g * 0.06, 0.46 + g * 0.05)
	if stage == "adult" and adult_form == "alley_ghost":
		base = base.darkened(0.1)
	return base


func _draw() -> void:
	var c := size * 0.5 + Vector2(_pose_x, _pose_y)
	if stage == "bush":
		_draw_bush(size * 0.5)
		return

	# Mirror facing by flipping x offsets via scale trick in drawing
	var face := _facing if _facing != 0.0 else 1.0
	match stage:
		"baby":
			_draw_baby(c, face)
		"young":
			_draw_young(c, face)
		"teen":
			_draw_teen(c, face)
		"adult":
			_draw_adult(c, face)
		_:
			_draw_baby(c, face)

	if _eat_flash > 0.0:
		_ellipse(c + Vector2(0, 10), Vector2(8, 4), Color(0.88, 0.63, 0.29, _eat_flash * 0.5))


func _draw_bush(c: Vector2) -> void:
	var rustle := sin(_t * 10.0) * 3.0
	var rustle2 := cos(_t * 7.5) * 2.0
	# Ground shadow
	_ellipse(c + Vector2(0, 46), Vector2(48, 10), Color(0, 0, 0, 0.25))
	# Layered foliage
	_ellipse(c + Vector2(-18 + rustle, 18), Vector2(26, 22), Color("2f5a3c"))
	_ellipse(c + Vector2(16 + rustle2, 20), Vector2(28, 24), Color("3d6b4f"))
	_ellipse(c + Vector2(0, 8 + rustle * 0.3), Vector2(34, 28), Color("355f44"))
	_ellipse(c + Vector2(-8, -6 + rustle2), Vector2(18, 16), Color("4a8a5e"))
	_ellipse(c + Vector2(12, -2 + rustle), Vector2(16, 14), Color("6fbf84").darkened(0.25))
	# Occasional eye glint in the leaves near reveal
	if age_hint() > 0.7:
		draw_circle(c + Vector2(-4 + rustle, 6), 2.2, Color(0.98, 0.96, 0.9, 0.55))
		draw_circle(c + Vector2(6 + rustle2, 8), 2.2, Color(0.98, 0.96, 0.9, 0.45))


func age_hint() -> float:
	# 0..1 through bush stage for tease glints
	if stage != "bush":
		return 1.0
	return clampf(PetState.age_sec / 60.0, 0.0, 1.0)


func _leg(a: Vector2, b: Vector2, width: float, phase: float, amp: float) -> void:
	var kick := sin(phase) * amp
	var mid := (a + b) * 0.5 + Vector2(0, kick)
	draw_line(a, mid, Color("4f4f58"), width)
	draw_line(mid, b + Vector2(0, absf(kick) * 0.3), Color("4f4f58"), width)
	_ellipse(b + Vector2(0, absf(kick) * 0.3), Vector2(7, 4), Color("3a3a44"))


func _ears(c: Vector2, spread: float, up: float, face: float) -> void:
	var flare := 1.0 + _g("ear_flare") * 0.35
	_ellipse(c + Vector2(-spread * face, -up), Vector2(7 * flare, 11 * flare), Color("4a4a54"))
	_ellipse(c + Vector2(spread * face, -up), Vector2(7 * flare, 11 * flare), Color("4a4a54"))
	_ellipse(c + Vector2(-spread * face, -up), Vector2(4, 6), Color("e2cdb2"))
	_ellipse(c + Vector2(spread * face, -up), Vector2(4, 6), Color("e2cdb2"))


func _mask(c: Vector2, rx: float, ry: float, eye: float, face: float) -> void:
	var mask_c := Color("1c1c22").lightened((1.0 - _g("mask")) * 0.15)
	_ellipse(c, Vector2(rx, ry), mask_c)
	draw_circle(c + Vector2(-eye * 1.35 * face, -1), eye, Color("faf6ec"))
	draw_circle(c + Vector2(eye * 1.35 * face, -1), eye, Color("faf6ec"))
	draw_circle(c + Vector2(-eye * 1.15 * face, -0.3), eye * 0.45, Color("101014"))
	draw_circle(c + Vector2(eye * 1.55 * face, -0.3), eye * 0.45, Color("101014"))
	_ellipse(c + Vector2(0, eye * 1.15), Vector2(eye * 1.1, eye * 0.7), Color("c9a292"))


func _tail(base: Vector2, scale: float, face: float) -> void:
	var tip := base + Vector2(26 * scale * -face, -6 * scale)
	draw_line(base, tip, Color("5a5a64"), 9.0 * scale)
	draw_line(base + Vector2(3 * -face, 2), base + Vector2(14 * scale * -face, 8 * scale), Color("b0b0ba"), 2.5)


func _draw_baby(c: Vector2, face: float) -> void:
	_ellipse(c + Vector2(0, 40), Vector2(18, 5), Color(0, 0, 0, 0.2))
	var wobble := sin(_walk_phase) * 2.0
	_ellipse(c + Vector2(0, 14 + wobble), Vector2(18, 14), _fur())
	draw_circle(c + Vector2(0, -2), 14.0, _fur().lightened(0.05))
	_ears(c + Vector2(0, -2), 11.0, 10.0, face)
	_mask(c + Vector2(0, 0), 11.0, 7.0, 2.6, face)
	# Tiny stubby paws
	_ellipse(c + Vector2(-10, 24), Vector2(5, 3), Color("3a3a44"))
	_ellipse(c + Vector2(10, 24), Vector2(5, 3), Color("3a3a44"))


func _draw_young(c: Vector2, face: float) -> void:
	_ellipse(c + Vector2(0, 44), Vector2(24, 6), Color(0, 0, 0, 0.2))
	var roundness := _g("roundness")
	var legs := 0.7 + _g("legginess") * 0.8
	var body_rx := 22.0 + roundness * 8.0
	var body_ry := 16.0 + (1.0 - roundness) * 4.0
	if young_form == "puff":
		body_rx += 4.0
		body_ry += 3.0
	elif young_form == "looper":
		legs += 0.35
	elif young_form == "shadow":
		pass
	elif young_form == "nub":
		body_rx -= 2.0
		legs -= 0.15

	_tail(c + Vector2(18 * -face, 8), 0.75, face)
	var phase := _walk_phase
	_leg(c + Vector2(-12, 10), c + Vector2(-14, 10 + 22 * legs), 4.5, phase, 3.0)
	_leg(c + Vector2(-4, 12), c + Vector2(-2, 10 + 24 * legs), 4.5, phase + 1.2, 3.0)
	_leg(c + Vector2(4, 12), c + Vector2(6, 10 + 24 * legs), 4.5, phase + 3.0, 3.0)
	_leg(c + Vector2(12, 10), c + Vector2(16, 10 + 22 * legs), 4.5, phase + 4.2, 3.0)
	_ellipse(c + Vector2(0, 6), Vector2(body_rx, body_ry), _fur())
	draw_circle(c + Vector2(0, -8), 16.0 + roundness * 3.0, _fur().lightened(0.04))
	_ears(c + Vector2(0, -8), 14.0, 12.0, face)
	_mask(c + Vector2(0, -6), 14.0, 9.0, 3.3, face)


func _draw_teen(c: Vector2, face: float) -> void:
	_ellipse(c + Vector2(0, 48), Vector2(28, 6), Color(0, 0, 0, 0.22))
	var form := teen_form if teen_form != "" else "bounder"
	var legs := 1.0 + _g("legginess") * 0.7
	var roundness := _g("roundness")
	if form == "bounder":
		legs += 0.4
	elif form == "dumpling":
		roundness = maxf(roundness, 0.7)
		legs -= 0.1
	elif form == "nightlane":
		legs += 0.2
	elif form == "scruff":
		roundness *= 0.8

	_tail(c + Vector2(22 * -face, 4), 0.9, face)
	var phase := _walk_phase
	_leg(c + Vector2(-16, 8), c + Vector2(-20, 8 + 28 * legs), 5.2, phase, 4.0)
	_leg(c + Vector2(-6, 10), c + Vector2(-8, 8 + 30 * legs), 5.2, phase + 1.1, 4.0)
	_leg(c + Vector2(6, 10), c + Vector2(10, 8 + 30 * legs), 5.2, phase + 2.8, 4.0)
	_leg(c + Vector2(16, 8), c + Vector2(22, 8 + 28 * legs), 5.2, phase + 4.0, 4.0)
	# Body shortening begins (teen foreshadow)
	_ellipse(c + Vector2(0, 2), Vector2(26 + roundness * 6.0, 20 + (1.0 - roundness) * 3.0), _fur())
	draw_circle(c + Vector2(0, -10), 18.0, _fur().lightened(0.03))
	_ears(c + Vector2(0, -10), 16.0, 14.0, face)
	_mask(c + Vector2(0, -8), 16.0, 10.0, 3.8, face)


func _draw_adult(c: Vector2, face: float) -> void:
	# Viral short-spine Jimothy: round body, long legs, almost no neck — with form flair.
	_ellipse(c + Vector2(0, 52), Vector2(34, 7), Color(0, 0, 0, 0.22))
	var legs := 1.25 + _g("legginess") * 0.45
	var roundness := 0.7 + _g("roundness") * 0.3
	var body_rx := 30.0 + roundness * 8.0
	var body_ry := 26.0 + roundness * 4.0

	_tail(c + Vector2(24 * -face, 0), 1.05, face)
	var phase := _walk_phase
	var amp := 5.0 if _anim in ["run", "lope"] else 3.5
	_leg(c + Vector2(-18, 6), c + Vector2(-30, 6 + 36 * legs), 6.0, phase, amp)
	_leg(c + Vector2(-8, 10), c + Vector2(-12, 6 + 38 * legs), 6.0, phase + 1.0, amp)
	_leg(c + Vector2(8, 10), c + Vector2(14, 6 + 38 * legs), 6.0, phase + 2.7, amp)
	_leg(c + Vector2(18, 6), c + Vector2(32, 6 + 36 * legs), 6.0, phase + 3.9, amp)

	# One fused potato body
	_ellipse(c + Vector2(0, -2), Vector2(body_rx, body_ry), _fur())
	_ears(c + Vector2(0, -2), 20.0, 24.0, face)
	_mask(c + Vector2(0, -4), 20.0, 12.0, 4.6, face)

	# Adult flair still reads as Jimothy
	match adult_form:
		"saint":
			_ellipse(c + Vector2(16 * face, -18), Vector2(7, 4), Color("6fbf84"))
		"legend":
			var pts := PackedVector2Array([
				c + Vector2(16 * face, -14),
				c + Vector2(28 * face, 0),
				c + Vector2(14 * face, 2),
			])
			draw_colored_polygon(pts, Color("e0a04a"))
		"alley_ghost":
			draw_circle(c + Vector2(18 * face, -8), 3.0, Color(0.85, 0.9, 0.95, 0.55))
		"ballard_blip":
			_ellipse(c + Vector2(0, 8), Vector2(10, 5), Color(0.88, 0.63, 0.29, 0.35))
