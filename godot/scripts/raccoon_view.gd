extends Control
## Animated Jimothy — bush rustle, walk/run/jump, form variance, adult short-spine look.

signal ascend_finished

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
var _eat_food: String = "berry"
var _head_dip: float = 0.0
var _body_squash: float = 1.0
var _smile: float = 0.0
var _wing_span: float = 0.0
var _fade: float = 1.0
var _ascend_done_emitted: bool = false
var _tap_cooldown: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	if PetState:
		PetState.anim_impulse.connect(play_anim)
		PetState.state_changed.connect(_sync_from_state)
		_sync_from_state()
		# Only resume an in-progress ascension — never replay for a dead save.
		if PetState.ascending and not PetState.alive:
			play_anim("ascend")


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_try_tap()
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_tap()
		accept_event()


func _try_tap() -> void:
	if _tap_cooldown > 0.0:
		return
	if PetState == null:
		return
	if PetState.ascending or not PetState.alive:
		return
	# Don't interrupt eat / ascend mid-motion
	if _anim in ["eat", "ascend"]:
		return
	_tap_cooldown = 0.55
	PetState.interact_tap()


func clear_ascend() -> void:
	_anim = "idle"
	_anim_t = 0.0
	_pose_x = 0.0
	_pose_y = 0.0
	_wing_span = 0.0
	_fade = 1.0
	_head_dip = 0.0
	_body_squash = 1.0
	_ascend_done_emitted = false
	_speed = 0.0
	modulate = Color(1, 1, 1, 1)
	_sync_from_state()


func play_eat(food_kind: String = "berry") -> void:
	_eat_food = food_kind if food_kind != "" else "berry"
	play_anim("eat")


func _sync_from_state() -> void:
	var p: Dictionary = PetState.form_profile()
	stage = str(p.stage)
	young_form = str(p.young_form)
	teen_form = str(p.teen_form)
	adult_form = str(p.adult_form)
	genes = p.genes if typeof(p.genes) == TYPE_DICTIONARY else {}
	if PetState.ascending and _anim == "ascend":
		mood = "ascend"
	elif PetState.stubborn:
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
		"ascend":
			_anim_dur = 4.2
			_wing_span = 0.0
			_fade = 1.0
			_ascend_done_emitted = false
			_speed = 0.0
		"run":
			_anim_dur = randf_range(1.6, 2.8)
			_speed = randf_range(100.0, 155.0)
			_target_x = randf_range(-78.0, 78.0)
			_facing = signf(_target_x - _pose_x)
			if _facing == 0.0:
				_facing = 1.0
		"walk", "lope":
			_anim_dur = randf_range(2.2, 3.8)
			_speed = randf_range(40.0, 80.0) if kind == "walk" else randf_range(60.0, 105.0)
			_target_x = randf_range(-78.0, 78.0)
			_facing = signf(_target_x - _pose_x)
			if _facing == 0.0:
				_facing = [-1.0, 1.0][randi() % 2]
		"jump":
			_anim_dur = randf_range(0.55, 0.9)
			_jump_peak = randf_range(18.0, 36.0)
			_facing = [-1.0, 1.0][randi() % 2]
			_target_x = clampf(_pose_x + _facing * randf_range(20.0, 50.0), -70.0, 70.0)
		"pop":
			_anim_dur = 0.85
			_body_squash = 1.0
		"stretch":
			_anim_dur = 1.05
			_body_squash = 1.0
		"eat":
			_anim_dur = 1.15
			_eat_flash = 1.0
			_head_dip = 0.0
			if PetState and PetState.last_fed_food != "":
				_eat_food = PetState.last_fed_food
		"refuse":
			_anim_dur = 0.95
		"scold":
			_anim_dur = 0.9
		"stubborn", "sick":
			_anim_dur = 1.1
		"sniff":
			_anim_dur = 1.0
		"smile":
			_anim_dur = 0.95
			_smile = 1.0
		"sad":
			_anim_dur = 1.35
			_smile = 0.0
		"hop":
			_anim_dur = 0.7
			_jump_peak = randf_range(22.0, 34.0)
		"nuzzle":
			_anim_dur = 0.9
			_smile = 0.7
		"spin":
			_anim_dur = 0.85
		"rustle":
			_anim_dur = 0.7
		"happy":
			_anim_dur = 0.8
			_smile = 1.0
			_jump_peak = 16.0
		_:
			_anim_dur = randf_range(1.0, 2.0)
			_speed = 0.0


func _process(delta: float) -> void:
	_t += delta
	_anim_t += delta
	_tap_cooldown = maxf(0.0, _tap_cooldown - delta)
	_eat_flash = maxf(0.0, _eat_flash - delta * 0.85)
	if _anim not in ["smile", "nuzzle", "happy"]:
		_smile = maxf(0.0, _smile - delta * 1.8)

	if _anim == "ascend":
		var u := clampf(_anim_t / _anim_dur, 0.0, 1.0)
		_wing_span = smoothstep(0.0, 0.45, u)
		_pose_y = -u * 160.0 - sin(u * PI) * 12.0
		_pose_x = sin(_t * 1.6) * (8.0 * (1.0 - u * 0.5))
		_fade = 1.0 - smoothstep(0.55, 1.0, u)
		queue_redraw()
		if u >= 1.0 and not _ascend_done_emitted:
			_ascend_done_emitted = true
			ascend_finished.emit()
		return

	if stage == "bush":
		var bush_amp := 2.0
		if _anim == "rustle":
			bush_amp = 5.0 + sin(_anim_t * 28.0) * 2.0
			if _anim_t >= _anim_dur:
				_anim = "idle"
		_pose_x = sin(_t * 9.0) * bush_amp + sin(_t * 3.3) * (bush_amp * 0.7)
		_pose_y = sin(_t * 7.0) * (bush_amp * 0.7)
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
			_head_dip = sin(_walk_phase * 2.0) * 1.2
			_body_squash = 1.0
			if absf(_pose_x - _target_x) < 1.5 or _anim_t >= _anim_dur:
				if randf() < 0.55 and _anim_t < _anim_dur:
					_target_x = randf_range(-78.0, 78.0)
					_facing = signf(_target_x - _pose_x)
					if _facing == 0.0:
						_facing = 1.0
				else:
					_anim = "idle"
					_pose_y = 0.0
					_head_dip = 0.0
		"jump":
			var u := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_pose_y = -sin(u * PI) * _jump_peak
			_pose_x = lerpf(_pose_x, _target_x, delta * 3.5)
			_body_squash = 1.0 + sin(u * PI) * 0.08
			if u >= 1.0:
				_anim = "idle"
				_pose_y = 0.0
				_body_squash = 1.0
		"pop":
			var pu := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_pose_y = -ease(pu, 0.3) * 22.0
			_body_squash = 1.0 + (1.0 - pu) * 0.15
			if _anim_t >= _anim_dur:
				_anim = "idle"
				_pose_y = 0.0
				_body_squash = 1.0
		"stretch":
			var su := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_pose_y = -sin(su * PI) * 6.0
			_body_squash = 1.0 + sin(su * PI) * 0.22
			_head_dip = -sin(su * PI) * 4.0
			_walk_phase += delta * 4.0
			if _anim_t >= _anim_dur:
				_anim = "idle"
				_pose_y = 0.0
				_body_squash = 1.0
				_head_dip = 0.0
		"eat":
			var eu := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			# Reach → chew → settle
			if eu < 0.22:
				_head_dip = lerpf(0.0, 10.0, eu / 0.22)
				_pose_y = lerpf(0.0, 3.0, eu / 0.22)
			elif eu < 0.78:
				_head_dip = 8.0 + sin(_t * 22.0) * 2.5
				_pose_y = 2.0 + sin(_t * 18.0) * 1.5
				_walk_phase += delta * 10.0
			else:
				var settle := (eu - 0.78) / 0.22
				_head_dip = lerpf(8.0, 0.0, settle)
				_pose_y = lerpf(2.0, 0.0, settle)
			_eat_flash = 1.0 - eu * 0.85
			if _anim_t >= _anim_dur:
				_anim = "idle"
				_head_dip = 0.0
				_pose_y = 0.0
		"refuse":
			var ru := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_facing = -1.0 if int(_t * 8.0) % 2 == 0 else 1.0
			_pose_x += sin(_t * 20.0) * 1.1
			_head_dip = sin(ru * PI) * 4.0
			if _anim_t >= _anim_dur:
				_anim = "idle"
				_head_dip = 0.0
		"scold":
			var cu := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_pose_y = sin(cu * PI) * 2.0
			_head_dip = 3.0 + sin(_t * 14.0) * 2.0
			_body_squash = 0.94
			if _anim_t >= _anim_dur:
				_anim = "idle"
				_head_dip = 0.0
				_body_squash = 1.0
		"sniff":
			_head_dip = 6.0 + sin(_t * 10.0) * 2.0
			_pose_y = sin(_t * 3.0) * 1.0
			_facing = 1.0 if sin(_t * 1.4) > 0.0 else -1.0
			if _anim_t >= _anim_dur:
				_anim = "idle"
				_head_dip = 0.0
		"smile":
			var sm := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_smile = 1.0
			_pose_y = sin(sm * PI) * 3.0
			_head_dip = -sin(sm * PI) * 2.0
			_body_squash = 1.0 + sin(sm * PI) * 0.04
			if _anim_t >= _anim_dur:
				_anim = "idle"
				_head_dip = 0.0
		"sad":
			var sd := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_smile = 0.0
			_head_dip = 7.0 + sin(sd * PI) * 3.0
			_pose_y = sin(_t * 2.2) * 0.8
			_pose_x += sin(_t * 3.0) * 0.25
			if _anim_t >= _anim_dur:
				_anim = "idle"
				_head_dip = 0.0
		"hop", "happy":
			var hu := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_pose_y = -sin(hu * PI) * _jump_peak
			_smile = 0.85
			_body_squash = 1.0 + sin(hu * PI) * 0.1
			if hu >= 1.0:
				_anim = "idle"
				_pose_y = 0.0
				_body_squash = 1.0
		"nuzzle":
			var nu := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_pose_x += sin(_t * 10.0) * 0.8
			_head_dip = 4.0 + sin(nu * PI) * 5.0
			_facing = 1.0 if sin(_t * 6.0) > 0.0 else -1.0
			_smile = 0.8
			if _anim_t >= _anim_dur:
				_anim = "idle"
				_head_dip = 0.0
		"spin":
			var su2 := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_facing = 1.0 if int(su2 * 8.0) % 2 == 0 else -1.0
			_pose_y = -sin(su2 * PI) * 10.0
			_pose_x += sin(_t * 20.0) * 1.2
			_smile = 0.6
			if _anim_t >= _anim_dur:
				_anim = "idle"
				_pose_y = 0.0
		"stubborn", "sick":
			_pose_x += sin(_t * 16.0) * 0.55
			_head_dip = 2.0
			if _anim_t >= _anim_dur:
				_anim = "idle"
		_:
			# Livelier idle: bob, look around, tiny weight shifts
			_pose_y = sin(_t * 2.4) * 2.2 + sin(_t * 5.1) * 0.6
			var idle_target := sin(_t * 0.55) * 42.0 + sin(_t * 0.19) * 12.0
			var dir := signf(idle_target - _pose_x)
			if dir != 0.0 and absf(idle_target - _pose_x) > 2.0:
				_facing = dir
			_pose_x = move_toward(_pose_x, idle_target, 22.0 * delta)
			_head_dip = sin(_t * 1.7) * 1.4
			_body_squash = 1.0 + sin(_t * 2.4) * 0.02
			_walk_phase += delta * 1.2
			if int(_t * 2.0) % 9 == 0 and randf() < 0.04:
				_facing *= -1.0

	_pose_x = clampf(_pose_x, -78.0, 78.0)
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
	if stage == "young":
		match young_form:
			"puff":
				return Color(0.55 + g * 0.08, 0.5 + g * 0.05, 0.48)
			"looper":
				return Color(0.48 + g * 0.06, 0.44, 0.4)
			"shadow":
				return Color(0.22 + g * 0.04, 0.22, 0.26)
			"nub":
				return Color(0.42, 0.38 + g * 0.05, 0.34)
	elif stage == "teen":
		match teen_form:
			"dumpling":
				return Color(0.58, 0.52, 0.48)
			"bounder":
				return Color(0.46, 0.42, 0.4)
			"nightlane":
				return Color(0.2, 0.22, 0.3)
			"scruff":
				return Color(0.4, 0.34, 0.3)
	elif stage == "adult":
		match adult_form:
			"saint":
				return Color(0.4, 0.46, 0.4)
			"legend":
				return Color(0.45, 0.4, 0.36)
			"alley_ghost":
				return Color(0.55, 0.58, 0.64)
			"ballard_blip":
				return Color(0.48, 0.38, 0.3)
	return Color(0.42 + g * 0.08, 0.42 + g * 0.06, 0.46 + g * 0.05)


func _draw() -> void:
	_draw_clearing()
	var c := size * 0.5 + Vector2(_pose_x, _pose_y)
	if stage == "bush" and _anim != "ascend":
		_draw_bush(size * 0.5)
		return

	# Soft sky glow during ascent
	if _anim == "ascend":
		var glow_a := (1.0 - _fade) * 0.35 + _wing_span * 0.25
		_ellipse(c + Vector2(0, 10), Vector2(70, 40), Color(0.95, 0.88, 0.55, glow_a * 0.35))

	var face := _facing if _facing != 0.0 else 1.0
	var old_mod := modulate
	if _anim == "ascend":
		modulate = Color(1, 1, 1, _fade)

	if _anim == "ascend" and _wing_span > 0.05:
		_draw_wings(c, face, _wing_span)

	# Head dip nudges the silhouette down while chewing / sniffing.
	var draw_c := c + Vector2(0, _head_dip * 0.45)

	match stage:
		"baby":
			_draw_baby(draw_c, face)
		"young":
			_draw_young(draw_c, face)
		"teen":
			_draw_teen(draw_c, face)
		"adult":
			_draw_adult(draw_c, face)
		_:
			_draw_baby(draw_c, face)

	if _anim == "eat" and _eat_flash > 0.05:
		_draw_food_prop(c, face, clampf(_anim_t / _anim_dur, 0.0, 1.0))

	modulate = old_mod


func _draw_food_prop(c: Vector2, face: float, u: float) -> void:
	# Food arcs from paws up to muzzle, then fades while chewing.
	var reach := smoothstep(0.0, 0.28, u)
	var fade := 1.0 - smoothstep(0.55, 0.95, u)
	var paw := c + Vector2(14.0 * face, 18.0)
	var mouth := c + Vector2(2.0 * face, -2.0 + _head_dip)
	var p := paw.lerp(mouth, reach)
	p += Vector2(sin(u * PI) * -6.0 * face, -sin(reach * PI) * 10.0)
	var a := fade * 0.95
	match _eat_food:
		"pizza", "fries":
			_ellipse(p, Vector2(7, 4), Color(0.88, 0.63, 0.29, a))
			draw_line(p + Vector2(-5, -1), p + Vector2(5, -1), Color(0.77, 0.36, 0.29, a), 2.0)
		"fish":
			_ellipse(p, Vector2(8, 3.5), Color(0.66, 0.77, 0.83, a))
		"crickets":
			_ellipse(p, Vector2(5, 3), Color(0.42, 0.48, 0.28, a))
		_:
			_ellipse(p + Vector2(-3, 0), Vector2(4.5, 4.5), Color(0.42, 0.35, 0.63, a))
			_ellipse(p + Vector2(3, -1), Vector2(4.5, 4.5), Color(0.42, 0.35, 0.63, a))


func _draw_wings(c: Vector2, face: float, span: float) -> void:
	var spread := 28.0 + span * 46.0
	var flap := sin(_t * 7.0) * (6.0 + span * 10.0)
	var wing_col := Color(0.92, 0.9, 0.82, 0.55 + span * 0.35)
	var edge := Color(0.85, 0.78, 0.45, 0.4 + span * 0.4)
	# Left wing
	var l := PackedVector2Array([
		c + Vector2(-8, -4),
		c + Vector2(-spread * 0.55, -18 + flap),
		c + Vector2(-spread, -2 + flap * 0.4),
		c + Vector2(-spread * 0.6, 14),
		c + Vector2(-10, 6),
	])
	draw_colored_polygon(l, wing_col)
	draw_polyline(l, edge, 1.5, true)
	# Right wing
	var r := PackedVector2Array([
		c + Vector2(8, -4),
		c + Vector2(spread * 0.55, -18 - flap),
		c + Vector2(spread, -2 - flap * 0.4),
		c + Vector2(spread * 0.6, 14),
		c + Vector2(10, 6),
	])
	draw_colored_polygon(r, wing_col)
	draw_polyline(r, edge, 1.5, true)
	# Tiny sparkles
	for i in 4:
		var sx := sin(_t * 3.0 + i * 1.7) * spread * 0.7
		var sy := -20.0 - i * 8.0 - span * 20.0
		draw_circle(c + Vector2(sx, sy), 1.6, Color(1, 0.95, 0.7, 0.35 + span * 0.4))
	if face < 0.0:
		pass


func _draw_clearing() -> void:
	# Forest floor inside the pet screen
	var ground_y := size.y * 0.78
	_ellipse(Vector2(size.x * 0.5, ground_y), Vector2(size.x * 0.48, 18), Color(0.12, 0.18, 0.12, 0.55))
	_ellipse(Vector2(size.x * 0.35, ground_y + 2), Vector2(22, 7), Color(0.18, 0.14, 0.08, 0.25))
	_ellipse(Vector2(size.x * 0.65, ground_y + 1), Vector2(18, 6), Color(0.16, 0.22, 0.12, 0.3))
	# Leaf flecks
	for i in 5:
		var lx := size.x * (0.2 + float(i) * 0.14)
		draw_colored_polygon(PackedVector2Array([
			Vector2(lx, ground_y - 2),
			Vector2(lx + 5, ground_y),
			Vector2(lx + 1, ground_y + 3),
		]), Color(0.35, 0.22, 0.1, 0.45))


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


func _side_leg(hip: Vector2, foot: Vector2, width: float, phase: float, amp: float) -> void:
	# Side-view kick: swing along travel axis + slight lift.
	var kick := sin(phase) * amp
	var mid := (hip + foot) * 0.5 + Vector2(kick * 0.6, -absf(kick) * 0.35)
	var toe := foot + Vector2(kick * 0.4, absf(kick) * 0.15)
	draw_line(hip, mid, Color("4f4f58"), width)
	draw_line(mid, toe, Color("4f4f58"), width)
	_ellipse(toe, Vector2(6, 3.2), Color("3a3a44"))


func _ringed_tail(base: Vector2, length: float, face: float, rings: bool = true) -> void:
	var tip := base + Vector2(-length * face, -length * 0.25)
	draw_line(base, tip, Color("5a5a64"), 8.0)
	if rings:
		for i in 4:
			var t := 0.2 + float(i) * 0.18
			var p := base.lerp(tip, t)
			_ellipse(p, Vector2(4, 3), Color("c8c8d0").darkened(0.05))


func _side_eye(p: Vector2, r: float, gleam: Color = Color("faf6ec")) -> void:
	if _smile > 0.35:
		draw_line(p + Vector2(-r * 1.1, 0), p + Vector2(0, -r), gleam, 2.0)
		draw_line(p + Vector2(0, -r), p + Vector2(r * 1.1, 0), gleam, 2.0)
	else:
		draw_circle(p, r, gleam)
		draw_circle(p + Vector2(r * 0.25, 0), r * 0.45, Color("101014"))


func _side_ear(p: Vector2, rx: float = 5.5, ry: float = 9.0) -> void:
	_ellipse(p, Vector2(rx, ry), Color("4a4a54"))
	_ellipse(p, Vector2(rx * 0.5, ry * 0.55), Color("e2cdb2"))


func _draw_baby(c: Vector2, face: float) -> void:
	_ellipse(c + Vector2(0, 40), Vector2(22, 5), Color(0, 0, 0, 0.2))
	var fur := _fur()
	var wobble := sin(_walk_phase) * 1.5
	# Soft stub tail
	_ellipse(c + Vector2(-18 * face, 14 + wobble), Vector2(7, 5), fur)
	_side_leg(c + Vector2(-8 * face, 20), c + Vector2(-10 * face, 34), 3.6, _walk_phase, 2.0)
	_side_leg(c + Vector2(10 * face, 20), c + Vector2(12 * face, 34), 3.6, _walk_phase + 2.2, 2.0)
	_ellipse(c + Vector2(0, 14 + wobble), Vector2(20, 13), fur)
	_ellipse(c + Vector2(4 * face, 18), Vector2(10, 7), fur.lightened(0.18))
	_ellipse(c + Vector2(16 * face, 4), Vector2(12, 11), fur.lightened(0.04))
	_side_ear(c + Vector2(12 * face, -8))
	_ellipse(c + Vector2(24 * face, 6), Vector2(5, 3.2), Color("c9a292"))
	_ellipse(c + Vector2(16 * face, 6), Vector2(8, 5.5), Color("2a2a32"))
	_side_eye(c + Vector2(18 * face, 5), 2.3)


func _draw_young(c: Vector2, face: float) -> void:
	_ellipse(c + Vector2(0, 44), Vector2(28, 6), Color(0, 0, 0, 0.2))
	var fur := _fur()
	var body_rx := 24.0
	var body_ry := 14.0
	var body_y := 8.0
	var head_x := 22.0
	var head_r := 13.0
	var leg_h := 22.0
	var front_x := 14.0
	var back_x := -12.0

	match young_form:
		"puff":
			body_rx = 26.0
			body_ry = 18.0
			leg_h = 13.0
			_ellipse(c + Vector2(-24 * face, 12), Vector2(9, 7), fur.lightened(0.08))
			_ellipse(c + Vector2(-28 * face, 10), Vector2(5, 4), fur.lightened(0.16))
		"looper":
			body_rx = 22.0
			body_ry = 10.0
			body_y = 2.0
			leg_h = 34.0
			head_r = 11.0
			draw_line(c + Vector2(-8 * face, body_y - 8), c + Vector2(12 * face, body_y - 8), Color("e0a04a"), 2.0)
			_ringed_tail(c + Vector2(-20 * face, body_y + 2), 20.0, face, true)
		"shadow":
			body_rx = 26.0
			body_ry = 11.0
			body_y = 12.0
			leg_h = 20.0
			head_x = 24.0
			_ringed_tail(c + Vector2(-22 * face, body_y + 4), 26.0, face, true)
		"nub":
			body_rx = 18.0
			body_ry = 13.0
			head_r = 15.0
			leg_h = 15.0
			_ellipse(c + Vector2(-18 * face, 14), Vector2(5, 4), fur.darkened(0.05))
		_:
			_ringed_tail(c + Vector2(-20 * face, body_y + 2), 20.0, face, true)

	var phase := _walk_phase
	_side_leg(c + Vector2(back_x * face, body_y + 8), c + Vector2((back_x - 3) * face, body_y + 8 + leg_h), 4.4, phase, 3.2)
	_side_leg(c + Vector2(front_x * face, body_y + 8), c + Vector2((front_x + 4) * face, body_y + 8 + leg_h), 4.4, phase + 2.4, 3.2)
	_ellipse(c + Vector2(0, body_y), Vector2(body_rx, body_ry), fur)
	if young_form == "puff":
		_ellipse(c + Vector2(4 * face, body_y + 4), Vector2(12, 8), fur.lightened(0.2))
		_ellipse(c + Vector2(14 * face, body_y - 12), Vector2(5, 4), fur.lightened(0.14))
	elif young_form == "shadow":
		draw_line(c + Vector2(-16 * face, body_y - 4), c + Vector2(12 * face, body_y - 6), Color("1a1a22"), 5.0)
	elif young_form == "nub":
		var ear_a := PackedVector2Array([
			c + Vector2(10 * face, body_y - 10),
			c + Vector2(14 * face, body_y - 18),
			c + Vector2(18 * face, body_y - 10),
		])
		draw_colored_polygon(ear_a, Color("4a4a54"))
		_ellipse(c + Vector2(16 * face, body_y + 12), Vector2(5, 2.5), Color("3a3a44"))

	_ellipse(c + Vector2(head_x * face, body_y - 2), Vector2(head_r, head_r * 0.9), fur.lightened(0.05))
	if young_form != "nub":
		_side_ear(c + Vector2((head_x - 4) * face, body_y - head_r - 2))
	var snout_c := Color("1c1c22") if young_form == "shadow" else Color("c9a292")
	_ellipse(c + Vector2((head_x + 8) * face, body_y), Vector2(5.5, 3.5), snout_c)
	var mask_c := Color("121218") if young_form == "shadow" else Color("2a2a32")
	_ellipse(c + Vector2(head_x * face, body_y), Vector2(head_r * 0.72, head_r * 0.5), mask_c)
	var gleam := Color("d0d8e8") if young_form == "shadow" else Color("faf6ec")
	_side_eye(c + Vector2((head_x + 2) * face, body_y - 2), 2.8 if young_form != "shadow" else 3.1, gleam)


func _draw_teen(c: Vector2, face: float) -> void:
	_ellipse(c + Vector2(0, 48), Vector2(32, 6), Color(0, 0, 0, 0.22))
	var form := teen_form if teen_form != "" else "bounder"
	var fur := _fur()
	var body_rx := 28.0
	var body_ry := 15.0
	var body_y := 4.0
	var head_x := 24.0
	var head_r := 14.0
	var leg_h := 26.0
	var front_x := 16.0
	var back_x := -16.0

	match form:
		"dumpling":
			body_rx = 32.0
			body_ry = 22.0
			leg_h = 12.0
			_ellipse(c + Vector2(-24 * face, 10), Vector2(8, 6), fur.lightened(0.05))
		"bounder":
			body_rx = 24.0
			body_ry = 12.0
			body_y = -2.0
			leg_h = 38.0
			draw_line(c + Vector2(8 * face, body_y - 8), c + Vector2(16 * face, body_y - 16), Color("e0a04a"), 2.0)
			_ringed_tail(c + Vector2(-22 * face, body_y + 2), 24.0, face, true)
		"nightlane":
			body_rx = 32.0
			body_ry = 10.0
			body_y = 8.0
			head_x = 28.0
			leg_h = 24.0
			_ringed_tail(c + Vector2(-26 * face, body_y + 2), 32.0, face, true)
			_ellipse(c + Vector2(6 * face, body_y - 2), Vector2(18, 5), Color(0.06, 0.06, 0.1, 0.45))
		"scruff":
			body_rx = 26.0
			body_ry = 14.0
			_ringed_tail(c + Vector2(-22 * face, body_y + 2), 22.0, face, true)
			for i in 5:
				var sx := -10.0 + float(i) * 5.0
				draw_line(
					c + Vector2(sx * face, body_y - body_ry + 2),
					c + Vector2((sx + 2.0) * face, body_y - body_ry - 7.0),
					fur.darkened(0.12),
					2.6
				)
		_:
			_ringed_tail(c + Vector2(-22 * face, body_y + 2), 24.0, face, true)

	var phase := _walk_phase
	_side_leg(c + Vector2(back_x * face, body_y + 10), c + Vector2((back_x - 4) * face, body_y + 10 + leg_h), 5.0, phase, 3.8)
	_side_leg(c + Vector2(front_x * face, body_y + 10), c + Vector2((front_x + 5) * face, body_y + 10 + leg_h), 5.0, phase + 2.3, 3.8)
	_ellipse(c + Vector2(0, body_y), Vector2(body_rx, body_ry), fur)
	if form == "dumpling":
		_ellipse(c + Vector2(2 * face, body_y + 6), Vector2(16, 10), fur.lightened(0.18))
	elif form == "scruff":
		draw_line(c + Vector2(18 * face, body_y + 4), c + Vector2(26 * face, body_y + 6), Color("8a5a4a"), 2.0)

	_ellipse(c + Vector2(head_x * face, body_y - 1), Vector2(head_r, head_r * 0.9), fur.lightened(0.04))
	if form == "scruff":
		draw_line(c + Vector2((head_x - 2) * face, body_y - head_r), c + Vector2((head_x + 2) * face, body_y - head_r - 10), Color("4a4a54"), 3.0)
	else:
		_side_ear(c + Vector2((head_x - 3) * face, body_y - head_r - 2))
	var snout := Color("1a1a24") if form == "nightlane" else Color("c9a292")
	_ellipse(c + Vector2((head_x + 8) * face, body_y + 1), Vector2(6.5, 4), snout)
	_ellipse(c + Vector2(head_x * face, body_y + 1), Vector2(head_r * 0.7, head_r * 0.48), Color("0e1018") if form == "nightlane" else Color("2a2a32"))
	if form == "dumpling" and _smile < 0.35:
		draw_line(c + Vector2((head_x - 1) * face, body_y), c + Vector2((head_x + 5) * face, body_y - 2), Color("faf6ec"), 2.0)
	else:
		var gleam := Color("d8e4f8") if form == "nightlane" else Color("faf6ec")
		_side_eye(c + Vector2((head_x + 2) * face, body_y - 1), 3.0 if form != "nightlane" else 3.3, gleam)


func _draw_adult(c: Vector2, face: float) -> void:
	# Short-spine Jimothy in profile — long stilts, fused potato, form-forward flair.
	_ellipse(c + Vector2(0, 52), Vector2(36, 7), Color(0, 0, 0, 0.22))
	var fur := _fur()
	var body_rx := 32.0
	var body_ry := 26.0
	var body_y := -2.0
	var leg_h := 42.0
	var front_x := 14.0
	var back_x := -18.0
	var snout := Color("c9a292")
	var gleam := Color("faf6ec")
	var mask_c := Color("1c1c22")

	match adult_form:
		"saint":
			body_ry = 28.0
			_ellipse(c + Vector2(18 * face, -22), Vector2(8, 5), Color("6fbf84"))
			_ellipse(c + Vector2(12 * face, -24), Vector2(4, 3), Color("548a62"))
			draw_circle(c + Vector2(6 * face, -18), 1.5, Color(0.72, 0.88, 0.75, 0.7))
		"legend":
			leg_h = 46.0
			var blaze := PackedVector2Array([
				c + Vector2(8 * face, -12),
				c + Vector2(30 * face, -4),
				c + Vector2(10 * face, 4),
			])
			draw_colored_polygon(blaze, Color("e0a04a"))
			gleam = Color("fff3d0")
		"alley_ghost":
			body_rx = 34.0
			body_ry = 22.0
			leg_h = 44.0
			snout = Color("b8c4d4")
			gleam = Color("e8f0ff")
			mask_c = Color("3a4250")
			_ellipse(c + Vector2(-28 * face, 4), Vector2(10, 6), Color(0.78, 0.86, 0.94, 0.28))
			_ellipse(c + Vector2(30 * face, 6), Vector2(8, 5), Color(0.78, 0.86, 0.94, 0.22))
			draw_line(c + Vector2(-22 * face, 2), c + Vector2(-36 * face, -6), Color(0.66, 0.7, 0.77, 0.7), 7.0)
		"ballard_blip":
			leg_h = 40.0
			draw_line(c + Vector2(6 * face, 8), c + Vector2(28 * face, 8), Color("c45c4a"), 4.0)
			_ellipse(c + Vector2(0, 10), Vector2(11, 7), Color(0.88, 0.63, 0.29, 0.35))
			var notch := PackedVector2Array([
				c + Vector2(10 * face, -24),
				c + Vector2(16 * face, -10),
				c + Vector2(6 * face, -12),
			])
			draw_colored_polygon(notch, Color("4a4a54"))

	if adult_form != "alley_ghost":
		_ringed_tail(c + Vector2(-26 * face, body_y + 4), 26.0, face, true)

	var phase := _walk_phase
	var amp := 5.0 if _anim in ["run", "lope"] else 3.5
	_side_leg(c + Vector2(back_x * face, body_y + 14), c + Vector2((back_x - 5) * face, body_y + 14 + leg_h), 6.0, phase, amp)
	_side_leg(c + Vector2(front_x * face, body_y + 14), c + Vector2((front_x + 6) * face, body_y + 14 + leg_h), 6.0, phase + 2.5, amp)
	_ellipse(c + Vector2(0, body_y), Vector2(body_rx, body_ry), fur)
	if adult_form == "saint":
		_ellipse(c + Vector2(2 * face, body_y + 6), Vector2(12, 9), fur.lightened(0.16))
	elif adult_form == "alley_ghost":
		_ellipse(c + Vector2(10 * face, body_y), Vector2(14, 10), Color(0.9, 0.94, 1.0, 0.16))
	elif adult_form == "ballard_blip":
		_ellipse(c + Vector2(16 * face, body_y + 18), Vector2(6, 3.5), Color("3a3a44"))

	if adult_form != "ballard_blip":
		_side_ear(c + Vector2(12 * face, body_y - body_ry + 2), 6.0, 11.0)
	_ellipse(c + Vector2(24 * face, body_y + 2), Vector2(8, 5.5), snout)
	_ellipse(c + Vector2(14 * face, body_y), Vector2(16, 11), mask_c)
	_side_eye(c + Vector2(18 * face, body_y - 2), 4.0, gleam)
	draw_line(c + Vector2(26 * face, body_y), c + Vector2(36 * face, body_y), Color("d0d0d8"), 1.2)
	draw_line(c + Vector2(26 * face, body_y + 4), c + Vector2(34 * face, body_y + 4), Color("d0d0d8"), 1.2)
