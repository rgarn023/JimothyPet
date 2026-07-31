extends Control
## Animated Jimothy — bush rustle, walk/run/jump, form variance, adult short-spine look.

const VisualPolish = preload("res://scripts/visual_polish.gd")

signal ascend_finished

var stage: String = "bush"
var young_form: String = "puff"
var teen_form: String = "bounder"
var adult_form: String = "saint"
var genes: Dictionary = {}
var mood: String = "idle"

## Dive / mini-game avatar: side-form only, no clearing, no pet input.
var avatar_mode: bool = false
var avatar_face: float = 1.0
var avatar_walk: float = 0.0
var avatar_chew: float = 0.0
var avatar_scale: float = 0.62

## Forms gallery thumbnail: static front preview of a specific form.
var preview_mode: bool = false
var preview_scale: float = 0.42

var _t: float = 0.0
var _pose_x: float = 0.0
var _pose_y: float = 0.0
var _facing: float = 1.0
var _desired_facing: float = 1.0
var _face_cooldown: float = 0.0
var _anim: String = "idle"
var _anim_t: float = 0.0
var _anim_dur: float = 1.2
var _walk_phase: float = 0.0
var _jump_peak: float = 0.0
var _target_x: float = 0.0
var _speed: float = 0.0
var _eat_flash: float = 0.0
var _eat_food: String = "berry"
var _eat_crumbs: Array = []
var _head_dip: float = 0.0
var _body_squash: float = 1.0
var _smile: float = 0.0
var _wing_span: float = 0.0
var _fade: float = 1.0
var _ascend_done_emitted: bool = false
var _tap_cooldown: float = 0.0
var _paw_lift: float = 0.0

const SIDE_ANIMS := ["walk", "run", "lope", "jump", "hop", "sniff"]


func _ready() -> void:
	if preview_mode:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Gallery thumbs keep their staged form — do not sync from live PetState.
		return
	if avatar_mode:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if PetState:
			PetState.state_changed.connect(_sync_from_state)
			_sync_from_state()
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	if PetState:
		PetState.anim_impulse.connect(play_anim)
		PetState.state_changed.connect(_sync_from_state)
		_sync_from_state()
		# Only resume an in-progress ascension — never replay for a dead save.
		if PetState.ascending and not PetState.alive:
			play_anim("ascend")


func configure_as_avatar(scale: float = 0.62) -> void:
	avatar_mode = true
	preview_mode = false
	avatar_scale = scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 110)
	size = Vector2(120, 110)


func configure_as_form_preview(p_stage: String, form_id: String, thumb_scale: float = 0.38) -> void:
	## Round chibi thumbnail for the Forms gallery — front idle only.
	avatar_mode = false
	preview_mode = true
	preview_scale = thumb_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(168, 168)
	size = Vector2(168, 168)
	scale = Vector2(thumb_scale, thumb_scale)
	stage = p_stage
	young_form = "puff"
	teen_form = "bounder"
	adult_form = "saint"
	match p_stage:
		"baby":
			pass
		"young":
			young_form = form_id
		"teen":
			teen_form = form_id
		"adult":
			adult_form = form_id
	mood = "idle"
	_anim = "idle"
	_anim_t = 0.0
	_pose_x = 0.0
	_pose_y = 0.0
	_head_dip = 0.0
	_body_squash = 1.0
	_facing = 1.0
	_desired_facing = 1.0
	_smile = 0.35 if form_id in ["ballard_blip", "puff", "dumpling"] else 0.0
	set_process(true)
	queue_redraw()


func set_avatar_pose(face: float, walk: float, chew: float = 0.0) -> void:
	avatar_face = -1.0 if face < 0.0 else 1.0
	avatar_walk = walk
	avatar_chew = chew
	queue_redraw()


func _is_bouncy_form() -> bool:
	## Looper / Bounder get energy from bounce animation, never long legs.
	return (stage == "young" and young_form == "looper") or (stage == "teen" and teen_form == "bounder")


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
	_head_dip = 0.0
	_body_squash = 1.0
	_ascend_done_emitted = false
	_speed = 0.0
	_facing = 1.0
	_desired_facing = 1.0
	_face_cooldown = 0.0
	_sync_from_state()
	# Invisible only while waiting for a new session; sync reveals once alive.
	if PetState != null and not PetState.alive and not PetState.ascending:
		_fade = 0.0
		modulate = Color(1, 1, 1, 0)
		queue_redraw()


func reveal() -> void:
	_fade = 1.0
	_body_squash = 1.0
	modulate = Color(1, 1, 1, 1)
	visible = true
	queue_redraw()


func _view_front() -> bool:
	if stage == "bush":
		return true
	return not (_anim in SIDE_ANIMS)


func _request_facing(dir: float) -> void:
	if dir == 0.0:
		return
	_desired_facing = -1.0 if dir < 0.0 else 1.0


func _commit_facing(delta: float) -> void:
	_face_cooldown = maxf(0.0, _face_cooldown - delta)
	if _view_front():
		return
	if is_equal_approx(_desired_facing, _facing):
		return
	if _face_cooldown > 0.0:
		return
	_facing = _desired_facing
	_face_cooldown = 0.42


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
	elif PetState.is_sleeping():
		mood = "sleep"
		if _anim not in ["sleep", "fallAsleep", "ascend"]:
			_anim = "sleep"
			_anim_t = 0.0
			_anim_dur = 4.0
			_speed = 0.0
	elif PetState.sick:
		mood = "sick"
	elif PetState.stubborn:
		mood = "stubborn"
	else:
		mood = "idle"
	# Living kit after ascend/reset — never keep the post-fade invisible state.
	if PetState != null and PetState.alive and not PetState.ascending:
		if _anim in ["ascend", "gone"] or (_fade < 0.99 and _anim != "stageUp") or modulate.a < 0.99:
			if PetState.is_sleeping():
				_anim = "sleep"
				_anim_t = 0.0
				_anim_dur = 4.0
			elif _anim in ["ascend", "gone"]:
				_anim = "idle"
				_anim_t = 0.0
			_pose_x = 0.0
			_pose_y = 0.0
			_wing_span = 0.0
			reveal()
	queue_redraw()


func set_look(_stage: String, _variant: String = "", _mood: String = "idle") -> void:
	# Kept for main.gd compatibility; prefer PetState sync.
	mood = _mood
	_sync_from_state()


func play_anim(kind: String) -> void:
	# Don't let ambient walks cut off a slow eat / ascent / stage-up / falling asleep.
	# Sleep may interrupt stage-up when he hatches during sleep hours.
	if kind in ["fallAsleep", "sleep"] and _anim == "stageUp":
		pass  # allow interrupt below
	elif _anim in ["eat", "ascend", "fallAsleep", "stageUp"] and kind in ["walk", "run", "lope", "jump", "sniff", "stretch", "idle", "stubborn", "sick", "sleep"]:
		return
	_anim = kind
	_anim_t = 0.0
	match kind:
		"ascend":
			_anim_dur = 4.2
			_wing_span = 0.0
			_fade = 1.0
			_ascend_done_emitted = false
			_speed = 0.0
		"stageUp":
			_anim_dur = 10.0
			_jump_peak = 26.0
			_speed = 0.0
			_smile = 1.0
			_fade = 1.0
		"fallAsleep":
			_anim_dur = 1.5
			_speed = 0.0
		"sleep":
			_anim_dur = 4.0
			_speed = 0.0
		"run":
			_anim_dur = randf_range(1.6, 2.8)
			_speed = randf_range(100.0, 155.0)
			_target_x = randf_range(-78.0, 78.0)
			_request_facing(signf(_target_x - _pose_x) if _target_x != _pose_x else 1.0)
			_facing = _desired_facing
			_face_cooldown = 0.0
		"walk", "lope":
			_anim_dur = randf_range(2.2, 3.8)
			_speed = randf_range(40.0, 80.0) if kind == "walk" else randf_range(60.0, 105.0)
			_target_x = randf_range(-78.0, 78.0)
			var wdir := signf(_target_x - _pose_x)
			if wdir == 0.0:
				wdir = [-1.0, 1.0][randi() % 2]
			_request_facing(wdir)
			_facing = _desired_facing
			_face_cooldown = 0.0
		"jump":
			_anim_dur = randf_range(0.55, 0.9)
			_jump_peak = randf_range(18.0, 36.0)
			_request_facing([-1.0, 1.0][randi() % 2])
			_facing = _desired_facing
			_face_cooldown = 0.0
			_target_x = clampf(_pose_x + _facing * randf_range(20.0, 50.0), -70.0, 70.0)
		"pop":
			_anim_dur = 0.85
			_body_squash = 1.0
		"stretch":
			_anim_dur = 1.05
			_body_squash = 1.0
		"eat":
			_anim_dur = 3.2
			_eat_flash = 1.0
			_head_dip = 0.0
			_paw_lift = 0.0
			_eat_crumbs.clear()
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
		"nuzzle", "heal":
			_anim_dur = 1.05
			_smile = 0.85
			_head_dip = 2.0
		"spin":
			_anim_dur = 0.85
		"rustle":
			_anim_dur = 1.15
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
		modulate = Color(1, 1, 1, _fade)
		queue_redraw()
		if u >= 1.0 and not _ascend_done_emitted:
			_ascend_done_emitted = true
			# Leave ascend so later frames don't keep applying fade=0.
			_anim = "gone"
			_anim_t = 0.0
			_pose_x = 0.0
			_pose_y = 0.0
			_wing_span = 0.0
			_fade = 0.0
			modulate = Color(1, 1, 1, 0)
			ascend_finished.emit()
		return

	if _anim == "gone":
		_fade = 0.0
		modulate = Color(1, 1, 1, 0)
		# New session may have revived the kit while we were still "gone".
		if PetState != null and PetState.alive and not PetState.ascending:
			_anim = "idle"
			_anim_t = 0.0
			reveal()
		else:
			queue_redraw()
			return

	if _anim == "stageUp":
		var u := clampf(_anim_t / _anim_dur, 0.0, 1.0)
		_smile = 1.0
		# Coil → vanish → bloom → settle (matches web morph timing).
		if u < 0.22:
			var p := u / 0.22
			_pose_y = sin(p * PI) * 6.0
			_pose_x = sin(_t * 14.0) * (4.0 + p * 10.0)
			_head_dip = p * 8.0
			_body_squash = lerpf(1.0, 0.55, p)
			_fade = lerpf(1.0, 0.65, p)
			_walk_phase += delta * 10.0
		elif u < 0.38:
			var p2 := (u - 0.22) / 0.16
			_pose_y = -p2 * 8.0
			_pose_x = sin(_t * 18.0) * (14.0 * (1.0 - p2))
			_head_dip = 8.0 * (1.0 - p2)
			_body_squash = lerpf(0.55, 0.12, p2)
			_fade = lerpf(0.65, 0.05, p2)
		elif u < 0.45:
			_pose_y = -4.0
			_pose_x = 0.0
			_head_dip = 0.0
			_body_squash = 0.08
			_fade = 0.0
		elif u < 0.7:
			var p3 := (u - 0.45) / 0.25
			_pose_y = -sin(p3 * PI) * 26.0
			_pose_x = sin(_t * 9.0) * 12.0 * (1.0 - p3 * 0.5)
			_head_dip = -sin(p3 * PI) * 4.0
			_body_squash = lerpf(0.2, 1.15, smoothstep(0.0, 1.0, p3))
			_fade = smoothstep(0.0, 0.35, p3)
			_walk_phase += delta * 7.0
			if p3 > 0.35 and p3 < 0.55:
				_request_facing(-_facing if _facing != 0.0 else 1.0)
		elif u < 0.88:
			var p4 := (u - 0.7) / 0.18
			_pose_y = -absf(sin(p4 * PI * 2.0)) * 12.0
			_pose_x = sin(_t * 8.0) * 8.0 * (1.0 - p4)
			_head_dip = sin(_t * 10.0) * 2.0
			_body_squash = lerpf(1.15, 1.0, p4)
			_fade = 1.0
		else:
			var p5 := (u - 0.88) / 0.12
			_pose_y = -sin(p5 * PI) * 5.0 * (1.0 - p5)
			_pose_x = lerpf(_pose_x, 0.0, minf(1.0, delta * 3.5))
			_head_dip = 2.0 * (1.0 - p5)
			_body_squash = 1.0
			_fade = 1.0
		if _anim_t >= _anim_dur:
			_anim = "idle"
			_pose_y = 0.0
			_pose_x = 0.0
			_head_dip = 0.0
			_body_squash = 1.0
			_fade = 1.0
		queue_redraw()
		return

	# After ascend finishes, stay invisible until a new kit starts.
	if PetState != null and not PetState.alive and not PetState.ascending:
		_fade = 0.0
		modulate = Color(1, 1, 1, 0)
		queue_redraw()
		return

	# New kit / bush — make sure ascend fade never sticks.
	if PetState != null and PetState.alive and modulate.a < 0.99:
		reveal()

	if stage == "bush":
		var bush_amp := 4.2
		if _anim == "rustle":
			bush_amp = 9.0 + sin(_anim_t * 34.0) * 3.5
			if _anim_t >= _anim_dur:
				_anim = "idle"
		_pose_x = sin(_t * 11.0) * bush_amp + sin(_t * 4.1) * (bush_amp * 0.85) + sin(_t * 17.0) * (bush_amp * 0.22)
		_pose_y = sin(_t * 8.2) * (bush_amp * 0.8) + cos(_t * 13.0) * (bush_amp * 0.25)
		modulate = Color(1, 1, 1, 1)
		_fade = 1.0
		queue_redraw()
		return

	match _anim:
		"walk", "run", "lope":
			var dir := signf(_target_x - _pose_x)
			if dir == 0.0:
				dir = _facing
			_request_facing(dir)
			var move_spd := _speed * (1.2 if _is_bouncy_form() else 1.0)
			_pose_x = move_toward(_pose_x, _target_x, move_spd * delta)
			var phase_mul := 0.18 if _is_bouncy_form() else 0.12
			if _anim == "run" or _anim == "lope":
				phase_mul *= 1.35
			_walk_phase += delta * (move_spd * phase_mul)
			var hop_amp := 3.0 if _anim == "walk" else 5.5
			if _is_bouncy_form():
				hop_amp = 7.5 if _anim == "walk" else 11.0
			_pose_y = absf(sin(_walk_phase)) * hop_amp
			_head_dip = sin(_walk_phase * 2.0) * (1.6 if _is_bouncy_form() else 1.2)
			# Gentle squash on landing steps — torso stays round.
			_body_squash = 1.0 + absf(cos(_walk_phase)) * (0.06 if _is_bouncy_form() else 0.03)
			if absf(_pose_x - _target_x) < 1.5 or _anim_t >= _anim_dur:
				if randf() < 0.55 and _anim_t < _anim_dur:
					_target_x = randf_range(-78.0, 78.0)
					var ndir := signf(_target_x - _pose_x)
					if ndir == 0.0:
						ndir = 1.0
					_request_facing(ndir)
				else:
					_anim = "idle"
					_pose_y = 0.0
					_head_dip = 0.0
					_body_squash = 1.0
		"jump":
			var u := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			var peak := _jump_peak * (1.25 if _is_bouncy_form() else 1.0)
			if u < 0.16:
				# Anticipation squash before takeoff.
				var a := u / 0.16
				_body_squash = lerpf(1.0, 0.72, a)
				_pose_y = lerpf(0.0, 4.0, a)
			elif u < 0.82:
				var ju := (u - 0.16) / 0.66
				_pose_y = -sin(ju * PI) * peak
				_body_squash = lerpf(0.88, 1.14, sin(ju * PI))
				_pose_x = lerpf(_pose_x, _target_x, delta * 3.5)
			else:
				# Landing squash — keep round silhouette.
				var lu := (u - 0.82) / 0.18
				_pose_y = lerpf(2.5, 0.0, lu)
				_body_squash = lerpf(0.7, 1.0, ease(lu, 0.4))
				_pose_x = lerpf(_pose_x, _target_x, delta * 2.5)
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
			# Stretch widens a round body — never elongates into a tall torso.
			_body_squash = 1.0 + sin(su * PI) * 0.14
			_head_dip = -sin(su * PI) * 4.0
			_walk_phase += delta * 4.0
			if _anim_t >= _anim_dur:
				_anim = "idle"
				_pose_y = 0.0
				_body_squash = 1.0
				_head_dip = 0.0
		"eat":
			var eu := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			# Inspect/sniff → paw lift → bites/chew → swallow → pleased.
			if eu < 0.14:
				var sn := eu / 0.14
				_head_dip = lerpf(0.0, 5.0, sn) + sin(_t * 12.0) * 1.2
				_pose_y = sin(_t * 6.0) * 1.0
				_paw_lift = lerpf(0.0, 0.35, sn)
			elif eu < 0.28:
				var lift := (eu - 0.14) / 0.14
				_head_dip = lerpf(5.0, 9.0, lift)
				_pose_y = lerpf(0.0, 2.5, lift)
				_paw_lift = lerpf(0.35, 1.0, lift)
			elif eu < 0.72:
				_head_dip = 8.0 + sin(_t * 11.0) * 2.4
				_pose_y = 2.0 + sin(_t * 9.0) * 1.3
				_paw_lift = 0.92 + sin(_t * 10.0) * 0.06
				_walk_phase += delta * 5.0
				# Spawn crumbs on bite peaks
				if sin(_t * 11.0) > 0.92 and _eat_crumbs.size() < 10:
					_eat_crumbs.append({
						"x": randf_range(-8.0, 10.0),
						"y": randf_range(-2.0, 6.0),
						"vx": randf_range(-18.0, 22.0),
						"vy": randf_range(-30.0, -8.0),
						"t": 0.0,
						"life": randf_range(0.35, 0.65),
					})
			elif eu < 0.84:
				var sw := (eu - 0.72) / 0.12
				_head_dip = lerpf(8.0, 4.0, sw)
				_pose_y = lerpf(2.0, 1.0, sw)
				_paw_lift = lerpf(0.9, 0.2, sw)
				_body_squash = lerpf(1.0, 1.08, sin(sw * PI))
			else:
				var please := (eu - 0.84) / 0.16
				_head_dip = lerpf(4.0, -1.5, please)
				_pose_y = -sin(please * PI) * 4.0
				_paw_lift = lerpf(0.2, 0.0, please)
				_smile = 1.0
				_body_squash = 1.0
			# Update crumbs
			var keep_c: Array = []
			for crumb in _eat_crumbs:
				crumb.t = float(crumb.t) + delta
				crumb.x = float(crumb.x) + float(crumb.vx) * delta
				crumb.y = float(crumb.y) + float(crumb.vy) * delta
				crumb.vy = float(crumb.vy) + 90.0 * delta
				if float(crumb.t) < float(crumb.life):
					keep_c.append(crumb)
			_eat_crumbs = keep_c
			_eat_flash = 1.0 - smoothstep(0.55, 0.95, eu)
			if _anim_t >= _anim_dur:
				_anim = "idle"
				_head_dip = 0.0
				_pose_y = 0.0
				_paw_lift = 0.0
				_eat_crumbs.clear()
		"refuse":
			var ru := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			# Head-shake without rapid facing flips (avoids visual glitch).
			_pose_x += sin(_t * 14.0) * 0.9
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
			var sniff_target := sin(_t * 0.7) * 28.0
			var sniff_dir := signf(sniff_target - _pose_x)
			if sniff_dir == 0.0:
				sniff_dir = _facing
			_request_facing(sniff_dir)
			_pose_x = move_toward(_pose_x, sniff_target, 18.0 * delta)
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
			var hop_peak := _jump_peak * (1.2 if _is_bouncy_form() else 1.0)
			if hu < 0.15:
				_body_squash = lerpf(1.0, 0.75, hu / 0.15)
				_pose_y = lerpf(0.0, 3.0, hu / 0.15)
			elif hu < 0.8:
				var ju := (hu - 0.15) / 0.65
				_pose_y = -sin(ju * PI) * hop_peak
				_body_squash = lerpf(0.9, 1.12, sin(ju * PI))
			else:
				var lu := (hu - 0.8) / 0.2
				_pose_y = lerpf(2.0, 0.0, lu)
				_body_squash = lerpf(0.72, 1.0, lu)
			_smile = 0.85
			if hu >= 1.0:
				_anim = "idle"
				_pose_y = 0.0
				_body_squash = 1.0
		"nuzzle":
			var nu := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_pose_x += sin(_t * 6.0) * 0.45
			_head_dip = 4.0 + sin(nu * PI) * 5.0
			_smile = 0.8
			if _anim_t >= _anim_dur:
				_anim = "idle"
				_head_dip = 0.0
		"spin":
			var su2 := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			if su2 > 0.45 and su2 < 0.55:
				_request_facing(-_facing if _facing != 0.0 else 1.0)
			_pose_y = -sin(su2 * PI) * 10.0
			_pose_x += sin(_t * 10.0) * 0.6
			_smile = 0.6
			if _anim_t >= _anim_dur:
				_anim = "idle"
				_pose_y = 0.0
		"stubborn", "sick":
			_pose_x += sin(_t * 10.0) * 0.35
			_head_dip = 2.0
			if _anim_t >= _anim_dur:
				_anim = "idle"
		"fallAsleep":
			var fu := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_head_dip = 4.0 + fu * 6.0
			_pose_y = fu * 4.0
			_body_squash = 1.0 + fu * 0.08
			if _anim_t >= _anim_dur:
				_anim = "sleep"
				_anim_t = 0.0
				_anim_dur = 4.0
		"sleep":
			# Slow breathing motion — visual only.
			var breath := sin(_t * 1.15)
			_pose_y = 4.0 + breath * 1.1
			_head_dip = 9.0 + breath * 0.7
			_pose_x = move_toward(_pose_x, 0.0, 30.0 * delta)
			_body_squash = 1.05 + breath * 0.035
			_smile = 0.0
		_:
			# Idle: face the screen, gentle bob, settle toward center.
			if mood == "sleep" or (PetState != null and PetState.is_sleeping()):
				var breath2 := sin(_t * 1.15)
				_pose_y = 4.0 + breath2 * 1.1
				_head_dip = 9.0 + breath2 * 0.7
				_pose_x = move_toward(_pose_x, 0.0, 30.0 * delta)
				_body_squash = 1.05 + breath2 * 0.035
				_smile = 0.0
			elif _is_sick():
				_pose_y = sin(_t * 1.35) * 1.0
				_pose_x = move_toward(_pose_x, 0.0, 22.0 * delta)
				_head_dip = 5.5 + sin(_t * 1.1) * 1.6
				_smile = 0.0
				_body_squash = 1.0
			elif _is_stubborn():
				_pose_y = sin(_t * 3.2) * 1.4
				var sulk_x := -18.0 if _facing < 0.0 else 18.0
				_pose_x = move_toward(_pose_x, sulk_x, 28.0 * delta)
				_head_dip = -1.5 + sin(_t * 4.0) * 0.8
				_smile = 0.0
				_body_squash = 1.0
			else:
				# Subtle breathing on every idle form — keeps the plush orb alive.
				var breath_i := sin(_t * 1.7)
				_pose_y = breath_i * 1.6 + sin(_t * 4.2) * 0.35
				_pose_x = move_toward(_pose_x, 0.0, 36.0 * delta)
				_head_dip = sin(_t * 1.4) * 1.1
				_body_squash = 1.0 + breath_i * 0.035
				if _is_bouncy_form() and randf() < 0.004:
					# Tiny idle micro-hop personality without changing proportions.
					_pose_y -= 2.5
			_walk_phase += delta * 1.2

	_pose_x = clampf(_pose_x, -78.0, 78.0)
	_commit_facing(delta)
	queue_redraw()


func _ellipse(center: Vector2, radii: Vector2, color: Color, points: int = 26) -> void:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * float(i) / float(points)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func _g(key: String, fallback: float = 0.5) -> float:
	return float(genes.get(key, fallback))


func _is_sick() -> bool:
	return mood == "sick" or (PetState != null and PetState.sick and PetState.alive and not PetState.ascending)


func _is_stubborn() -> bool:
	if _is_sick():
		return false
	return mood == "stubborn" or (PetState != null and PetState.stubborn and PetState.alive and not PetState.ascending)


func _fur() -> Color:
	var g := _g("gray", 0.5)
	var c := Color(0.42 + g * 0.08, 0.42 + g * 0.06, 0.46 + g * 0.05)
	if stage == "young":
		match young_form:
			"puff":
				c = Color(0.55 + g * 0.08, 0.5 + g * 0.05, 0.48)
			"looper":
				c = Color(0.48 + g * 0.06, 0.44, 0.4)
			"shadow":
				c = Color(0.22 + g * 0.04, 0.22, 0.26)
			"nub":
				c = Color(0.42, 0.38 + g * 0.05, 0.34)
	elif stage == "teen":
		match teen_form:
			"dumpling":
				c = Color(0.58, 0.52, 0.48)
			"bounder":
				c = Color(0.46, 0.42, 0.4)
			"nightlane":
				c = Color(0.2, 0.22, 0.3)
			"scruff":
				c = Color(0.4, 0.34, 0.3)
	elif stage == "adult":
		match adult_form:
			"saint":
				c = Color(0.4, 0.46, 0.4)
			"legend":
				c = Color(0.45, 0.4, 0.36)
			"alley_ghost":
				c = Color(0.55, 0.58, 0.64)
			"ballard_blip":
				c = Color(0.48, 0.38, 0.3)
	if _is_sick():
		c = c.lerp(Color(0.47, 0.66, 0.43), 0.32).lightened(0.06)
	elif _is_stubborn():
		c = c.lerp(Color(0.62, 0.38, 0.34), 0.22)
	return c


func _draw() -> void:
	if avatar_mode:
		_draw_avatar()
		return
	if not preview_mode:
		_draw_clearing()
	# Empty nest after ascend until the player starts a new session.
	if not preview_mode and PetState != null and not PetState.alive and not PetState.ascending and _anim not in ["ascend"]:
		return
	var c := size * 0.5 + Vector2(_pose_x, _pose_y)
	if stage == "bush" and _anim not in ["ascend", "gone"]:
		_draw_bush(size * 0.5)
		return

	# Soft sky glow during ascent / stage-up
	if _anim == "ascend":
		var glow_a := (1.0 - _fade) * 0.35 + _wing_span * 0.25
		_ellipse(c + Vector2(0, 10), Vector2(70, 40), Color(0.95, 0.88, 0.55, glow_a * 0.35))
	elif _anim == "stageUp":
		_draw_stage_up_fx(c)

	var face := _facing if _facing != 0.0 else 1.0
	var old_mod := modulate
	if _anim == "ascend":
		modulate = Color(1, 1, 1, _fade)
	elif _anim == "stageUp":
		modulate = Color(1, 1, 1, _fade)

	if _anim == "ascend" and _wing_span > 0.05:
		_draw_wings(c, face, _wing_span)

	# Head dip nudges the silhouette down while chewing / sniffing.
	var draw_c := c + Vector2(0, _head_dip * 0.45)
	# Gentle squash-and-stretch for breathing, hops, and stage-up — keeps the orb round.
	var using_squash := absf(_body_squash - 1.0) > 0.004 and not _is_sleeping()
	if using_squash:
		var sy := 1.0 / maxf(0.55, _body_squash)
		draw_set_transform(draw_c, 0.0, Vector2(_body_squash, sy))
		draw_c = Vector2.ZERO

	if _is_sleeping() and _anim != "ascend":
		if not preview_mode:
			_draw_nest_bed(c + Vector2(0, 18))
		_draw_sleeping(draw_c + Vector2(0, 6))
	elif (_view_front() or preview_mode) and _anim != "ascend":
		_draw_front(draw_c)
	else:
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

	if using_squash:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _anim == "eat":
		var eat_u := clampf(_anim_t / maxf(0.001, _anim_dur), 0.0, 1.0)
		_draw_food_prop(c, face, eat_u)
		_draw_eat_crumbs(c)
		_draw_eating_details(c + Vector2(0, _head_dip * 0.45), face, eat_u)
		if _eat_flash > 0.05:
			var flash_col := VisualPolish.food_flash_color(_eat_food)
			flash_col.a = 0.22 * _eat_flash
			_ellipse(c + Vector2(0, 4), Vector2(48, 36), flash_col)

	modulate = old_mod


func _draw_avatar() -> void:
	# Side silhouette of the live form for Dumpster Dive (and similar).
	var c := size * 0.5
	var face := avatar_face if avatar_face != 0.0 else 1.0
	var old_walk := _walk_phase
	var old_anim := _anim
	_walk_phase = avatar_walk
	_anim = "walk"
	draw_set_transform(c, 0.0, Vector2(avatar_scale, avatar_scale))
	match stage:
		"baby":
			_draw_baby(Vector2.ZERO, face)
		"young":
			_draw_young(Vector2.ZERO, face)
		"teen":
			_draw_teen(Vector2.ZERO, face)
		"adult":
			_draw_adult(Vector2.ZERO, face)
		_:
			_draw_young(Vector2.ZERO, face)
	if avatar_chew > 0.0:
		draw_circle(Vector2(16.0 * face, 2.0), 3.2, Color(0.88, 0.63, 0.29, 0.78))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_walk_phase = old_walk
	_anim = old_anim


func _draw_front(c: Vector2) -> void:
	## Round short-spine chibi — head overlaps body; tiny tucked feet.
	var fur := _fur()
	var belly := fur.lightened(0.22)
	var body_rx := 30.0
	var body_ry := 28.0
	var body_y := 10.0
	var head_r := 22.0
	var head_y := -2.0
	var leg_h := 10.0
	var leg_spread := 12.0
	var stroke_w := 4.2
	var ear_y := -20.0
	var ear_rx := 6.5
	var ear_ry := 9.0
	var snout := Color("c9a292")
	var mask := Color("1c1c22")
	var gleam := Color("faf6ec")
	var wing_kind := ""
	var crown_kind := ""
	var tuft := false

	match stage:
		"baby":
			body_rx = 22.0
			body_ry = 21.0
			body_y = 14.0
			head_r = 18.0
			head_y = 2.0
			leg_h = 6.0
			leg_spread = 9.0
			stroke_w = 3.4
			ear_y = -12.0
			ear_rx = 5.0
			ear_ry = 7.0
		"young":
			body_rx = 28.0
			body_ry = 26.0
			body_y = 12.0
			head_r = 20.0
			head_y = 0.0
			leg_h = 8.0
			leg_spread = 11.0
			ear_y = -16.0
			if young_form == "puff":
				body_rx = 32.0
				body_ry = 30.0
				leg_h = 6.0
			elif young_form == "nub":
				leg_h = 7.0
				crown_kind = "bottlecap"
				tuft = true
			elif young_form == "shadow":
				mask = Color("0e1018")
				gleam = Color("e8f0ff")
				wing_kind = "bat"
			elif young_form == "looper":
				# Energy from bounce animation — keep short tucked feet.
				leg_h = 8.0
		"teen":
			body_rx = 30.0
			body_ry = 28.0
			body_y = 10.0
			head_r = 21.0
			head_y = -2.0
			leg_h = 9.0
			if teen_form == "bounder":
				leg_h = 10.0
			if teen_form == "dumpling":
				body_rx = 36.0
				body_ry = 34.0
				leg_h = 6.0
			if teen_form == "nightlane":
				mask = Color("0e1018")
				snout = Color("1a1a24")
				gleam = Color("e8f0ff")
				wing_kind = "moth"
			if teen_form == "scruff":
				crown_kind = "tincan"
				tuft = true
		_:
			body_rx = 34.0
			body_ry = 32.0
			body_y = 8.0
			head_r = 23.0
			head_y = -4.0
			leg_h = 11.0
			leg_spread = 13.0
			stroke_w = 5.0
			ear_y = -24.0
			ear_rx = 7.0
			ear_ry = 10.0
			if adult_form == "alley_ghost":
				snout = Color("b8c4d4")
				mask = Color("3a4250")
				gleam = Color("e8f0ff")
				wing_kind = "ghost"
			elif adult_form == "legend":
				gleam = Color("fff3d0")
				crown_kind = "gold"
			elif adult_form == "saint":
				wing_kind = "leaf"
			elif adult_form == "ballard_blip":
				crown_kind = "pizza"

	# Shadow sits under tiny feet — never floats far below the orb.
	var foot_y := body_y + body_ry * 0.55 + leg_h
	_ellipse(c + Vector2(0, foot_y + 4.0), Vector2(body_rx * 0.72, 5.0), Color(0, 0, 0, 0.2))
	# Tail peek / stub
	if stage == "baby":
		_ellipse(c + Vector2(-22, body_y + 4), Vector2(6, 5), fur.lightened(0.05))
	else:
		draw_line(c + Vector2(-body_rx * 0.85, body_y), c + Vector2(-body_rx * 1.15, body_y + 4), Color("5a5a64"), 6.5)
		_ellipse(c + Vector2(-body_rx * 1.05, body_y - 2), Vector2(3.4, 2.8), Color("c8c8d0").darkened(0.05))
		_ellipse(c + Vector2(-body_rx * 0.95, body_y + 2), Vector2(3.2, 2.6), Color("c8c8d0").darkened(0.12))

	if wing_kind != "":
		_form_wings(wing_kind, c, 1.0, body_y - 2.0)

	# Tiny tucked feet (drawn under the round body)
	var lx := c.x - leg_spread
	var rx := c.x + leg_spread
	var hip_y := c.y + body_y + body_ry * 0.35
	draw_line(Vector2(lx, hip_y), Vector2(lx - 1.5, hip_y + leg_h), Color("4f4f58"), stroke_w * 0.85)
	draw_line(Vector2(rx, hip_y), Vector2(rx + 1.5, hip_y + leg_h), Color("4f4f58"), stroke_w * 0.85)
	_ellipse(Vector2(lx - 1.5, hip_y + leg_h), Vector2(5.5, 3.0), Color("3a3a44"))
	_ellipse(Vector2(rx + 1.5, hip_y + leg_h), Vector2(5.5, 3.0), Color("3a3a44"))

	# Round plush body
	_ellipse(c + Vector2(0, body_y), Vector2(body_rx, body_ry), fur)
	_ellipse(c + Vector2(0, body_y + 4), Vector2(body_rx * 0.58, body_ry * 0.48), Color(belly.r, belly.g, belly.b, 0.5))
	if tuft:
		for i in 4:
			var tx := -10.0 + float(i) * 6.5
			draw_line(c + Vector2(tx, body_y - body_ry + 2), c + Vector2(tx + 1.5, body_y - body_ry - 6), fur.darkened(0.1), 2.2)

	if stage == "adult" and adult_form == "saint":
		_ellipse(c + Vector2(0, body_y + 6), Vector2(14, 10), Color(belly.r, belly.g, belly.b, 0.35))
	elif stage == "adult" and adult_form == "legend":
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-8, -4), c + Vector2(10, 2), c + Vector2(-6, 8)
		]), Color("e0a04a"))
	elif stage == "adult" and adult_form == "ballard_blip":
		draw_line(c + Vector2(-12, 18), c + Vector2(12, 18), Color("c45c4a"), 3.5)
	elif stage == "young" and young_form == "puff":
		_ellipse(c + Vector2(0, body_y + 6), Vector2(14, 10), Color(belly.r, belly.g, belly.b, 0.5))

	_ellipse(c + Vector2(0, head_y), Vector2(head_r, head_r * 0.95), fur.lightened(0.04))
	_ellipse(c + Vector2(-10, ear_y), Vector2(ear_rx, ear_ry), Color("4a4a54"))
	_ellipse(c + Vector2(-10, ear_y), Vector2(ear_rx * 0.45, ear_ry * 0.55), Color("e2cdb2"))
	_ellipse(c + Vector2(10, ear_y), Vector2(ear_rx, ear_ry), Color("4a4a54"))
	_ellipse(c + Vector2(10, ear_y), Vector2(ear_rx * 0.45, ear_ry * 0.55), Color("e2cdb2"))
	if crown_kind != "":
		_trash_crown(crown_kind, c + Vector2(0, head_y - head_r + 2), 1.0)
	_ellipse(c + Vector2(0, head_y + 2), Vector2(head_r * 0.72, head_r * 0.42), Color(mask.r, mask.g, mask.b, 0.9))

	# Rounded chibi eyes — larger, outlined, glossy highlights.
	var eye_r := 3.4 if stage == "baby" else (4.6 if stage == "adult" else 4.0)
	var gap := eye_r * 2.05
	var eye_y := head_y + 1.0
	var eye_state := "sleep" if _is_sleeping() else ("sick" if _is_sick() else ("stubborn" if _is_stubborn() else ("happy" if _smile > 0.35 else "idle")))
	_draw_chibi_eye(c + Vector2(-gap, eye_y), eye_r, gleam, eye_state, -1.0)
	_draw_chibi_eye(c + Vector2(gap, eye_y), eye_r, gleam, eye_state, 1.0)

	_ellipse(c + Vector2(0, head_y + head_r * 0.42), Vector2(head_r * 0.28, head_r * 0.18), snout)
	draw_circle(c + Vector2(0, head_y + head_r * 0.32), 1.8, Color("2a2a32"))
	draw_circle(c + Vector2(-0.5, head_y + head_r * 0.28), 0.55, Color(1, 1, 1, 0.45))
	_draw_sick_marks(c + Vector2(0, head_y), false)
	_draw_stubborn_marks(c + Vector2(0, head_y), false)


func _draw_food_prop(c: Vector2, face: float, u: float) -> void:
	# Food stays in paws: inspect → lift to muzzle → shrink on bites → gone after swallow.
	var fade := 1.0 - smoothstep(0.78, 0.93, u)
	if fade <= 0.02:
		return
	var paw_base := c + Vector2(16.0 * face, 20.0 - _paw_lift * 14.0)
	var mouth := c + Vector2(4.0 * face, -2.0 + _head_dip * 0.35)
	var hold := smoothstep(0.12, 0.30, u)
	var p := paw_base.lerp(mouth + Vector2(6.0 * face, 8.0), hold * 0.72)
	# Drawn paws gripping the food (under then over so food is held, not floating).
	_ellipse(paw_base + Vector2(-3.0 * face, 4.0), Vector2(6.5, 3.8), Color("3a3a44"))
	_ellipse(paw_base + Vector2(4.0 * face, 5.0), Vector2(5.8, 3.4), Color("3a3a44"))
	var bite_shrink := 1.0 - smoothstep(0.30, 0.78, u) * 0.55
	var a := fade * 0.98
	VisualPolish.draw_food(self, _eat_food, p, a, 0.92 * bite_shrink)
	# Forepaw digits over the treat
	if hold > 0.2:
		_ellipse(p + Vector2(-4.0 * face, 5.0), Vector2(4.2, 2.6), Color("3a3a44"))
		_ellipse(p + Vector2(3.0 * face, 5.5), Vector2(3.8, 2.4), Color("32323a"))


func _draw_eat_crumbs(c: Vector2) -> void:
	var flash := VisualPolish.food_flash_color(_eat_food)
	for crumb in _eat_crumbs:
		var aa := 1.0 - float(crumb.t) / float(crumb.life)
		var p := c + Vector2(float(crumb.x), float(crumb.y) - 4.0)
		_ellipse(p, Vector2(2.2, 1.8), Color(flash.r, flash.g, flash.b, 0.75 * aa))


func _draw_chibi_eye(center: Vector2, radius: float, gleam: Color, state: String, brow_flip: float = 1.0) -> void:
	var outline := Color("202328")
	if state == "sleep":
		draw_arc(center + Vector2(0, 1), radius * 0.78, 0.12, PI - 0.12, 14, outline, 2.0, true)
		return
	if state == "happy":
		draw_line(center + Vector2(-radius * 1.05, 0), center + Vector2(0, -radius * 0.95), gleam, 2.1)
		draw_line(center + Vector2(0, -radius * 0.95), center + Vector2(radius * 1.05, 0), gleam, 2.1)
		return

	var eye_fill := Color("fff8ea")
	var eye_radii := Vector2(radius * 0.95, radius * 1.08)
	if state == "sick":
		eye_radii.y *= 0.72
	_ellipse(center, eye_radii, outline)
	_ellipse(center, eye_radii * 0.86, eye_fill)
	_ellipse(center + Vector2(radius * 0.1, radius * 0.12), Vector2(radius * 0.55, radius * 0.68), Color("171619"))
	draw_circle(center + Vector2(-radius * 0.22, -radius * 0.28), radius * 0.2, gleam)
	draw_circle(center + Vector2(radius * 0.2, radius * 0.18), radius * 0.08, Color(1, 1, 1, 0.65))

	if state == "sick":
		draw_line(center + Vector2(-radius, -radius * 0.63), center + Vector2(radius, -radius * 0.25), outline, 1.7)
	elif state == "stubborn":
		draw_line(
			center + Vector2(-radius * 0.95, -radius * (0.95 + 0.12 * brow_flip)),
			center + Vector2(radius * 0.78, -radius * (0.62 - 0.12 * brow_flip)),
			outline,
			2.0
		)


func _draw_eating_details(c: Vector2, face: float, u: float) -> void:
	# Visual-only chew feedback: puffy cheeks + chew line. Does not alter PetState.
	if u > 0.35 and u < 0.82:
		var chew := (u - 0.35) / 0.47
		var pulse := absf(sin(chew * PI * 6.0))
		_ellipse(c + Vector2(-11.0 * face, 1.0 + _head_dip * 0.5), Vector2(4.5 + pulse * 1.5, 3.5), Color(0.94, 0.72, 0.62, 0.24 * pulse))
		_ellipse(c + Vector2(11.0 * face, 1.0 + _head_dip * 0.5), Vector2(4.5 + pulse * 1.5, 3.5), Color(0.94, 0.72, 0.62, 0.24 * pulse))
		draw_line(c + Vector2(-3, 8 + pulse), c + Vector2(3, 8 - pulse), Color("2a2a32"), 1.4)


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


func _draw_oval_leaf(c: Vector2, rx: float, ry: float, color: Color, rot_deg: float) -> void:
	var rad := deg_to_rad(rot_deg)
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		var local := Vector2(cos(a) * rx, sin(a) * ry).rotated(rad)
		pts.append(c + local)
	draw_colored_polygon(pts, color)


func _draw_tip_leaf(c: Vector2, len: float, wid: float, color: Color, rot_deg: float) -> void:
	var rad := deg_to_rad(rot_deg)
	var tip := Vector2(0, -len * 0.55).rotated(rad)
	var base := Vector2(0, len * 0.45).rotated(rad)
	var left := Vector2(-wid, 0).rotated(rad)
	var right := Vector2(wid, 0).rotated(rad)
	draw_colored_polygon(PackedVector2Array([c + tip, c + right, c + base, c + left]), color)


func _draw_bush(c: Vector2) -> void:
	var shake := 1.0 if _anim != "rustle" else 2.35
	var rustle := sin(_t * 14.0) * 4.2 * shake
	var rustle2 := cos(_t * 11.0) * 3.6 * shake
	var rustle3 := sin(_t * 19.0 + 1.2) * 2.8 * shake
	# Wide shrub shadow
	_ellipse(c + Vector2(rustle * 0.15, 52), Vector2(54, 7), Color(0, 0, 0, 0.2))
	# Tiny soil-line twigs only
	draw_line(c + Vector2(-12, 46), c + Vector2(-8 + rustle * 0.2, 40), Color("4a3424"), 1.8)
	draw_line(c + Vector2(12, 46), c + Vector2(8 + rustle2 * 0.2, 40), Color("3d2c1e"), 1.6)
	# Dense body pads — wider than tall
	var deep: Array = [Color("1e3f2a"), Color("244a32"), Color("2a5236"), Color("2f5a3c")]
	var mid: Array = [Color("355f44"), Color("3d6b4f"), Color("3a6648"), Color("2d5740")]
	var lite: Array = [Color("4a8a5e"), Color("548a62"), Color("5aa870"), Color("6fbf84")]
	var pads: Array = [
		[-40, 34, 14, 10], [-24, 30, 16, 11], [-6, 28, 18, 12], [12, 30, 16, 11], [30, 34, 14, 10],
		[-32, 20, 13, 10], [-14, 16, 15, 11], [4, 16, 15, 11], [22, 20, 13, 10],
		[-22, 38, 14, 9], [-2, 40, 16, 9], [18, 38, 14, 9],
		[-20, 8, 12, 9], [-2, 6, 14, 10], [16, 8, 12, 9],
		[-10, 24, 12, 9], [8, 24, 12, 9],
	]
	for i in pads.size():
		var L: Array = pads[i]
		var p := Vector2(float(L[0]), float(L[1]))
		var side := -1.0 if p.x < 0.0 else 1.0
		p.x += (rustle if side < 0.0 else rustle2) * 0.55 + rustle3 * 0.2 * side
		p.y += sin(_t * 12.0 + float(i) * 0.7) * 1.8 * shake
		var wobble_rot := float((i * 13) % 40) - 20.0 + (rustle if side < 0.0 else rustle2) * 1.8
		_draw_oval_leaf(c + p, float(L[2]), float(L[3]), mid[i % mid.size()], wobble_rot)
	for i in 5:
		var under_pts: Array[Vector2] = [
			Vector2(-36, 36), Vector2(-8, 42), Vector2(20, 36), Vector2(-26, 14), Vector2(14, 12)
		]
		var under: Vector2 = under_pts[i]
		under.x += sin(_t * 10.0 + float(i)) * 2.2 * shake
		under.y += cos(_t * 9.0 + float(i) * 1.3) * 1.4 * shake
		_draw_oval_leaf(c + under, 12.0, 8.0, deep[i % deep.size()], float(i * 9) + rustle * 0.8)
	# Tip leaves for ragged bushy edge
	var tips: Array = [
		[-46, 28, 11, 5, -70], [-42, 16, 10, 4.5, -50], [-36, 6, 10, 4.5, -35],
		[-26, 0, 10, 4.5, -20], [-14, -4, 11, 5, -8], [-2, -6, 11, 5, 4],
		[10, -4, 11, 5, 16], [22, 0, 10, 4.5, 30], [32, 8, 10, 4.5, 45],
		[40, 18, 10, 4.5, 60], [46, 30, 10, 4.5, 75],
		[-48, 38, 9, 4, -85], [48, 38, 9, 4, 85],
		[-30, 4, 9, 4, -28], [-10, -2, 9, 4, 0], [14, 2, 9, 4, 28],
		[-38, 24, 8, 3.5, -55], [-20, 10, 8, 3.5, -15], [2, 8, 8, 3.5, 12],
		[24, 14, 8, 3.5, 40], [-18, 34, 8, 3.5, -40], [18, 32, 8, 3.5, 40],
	]
	for i in tips.size():
		var T: Array = tips[i]
		var p := Vector2(float(T[0]), float(T[1]))
		var side2 := -1.0 if p.x < 0.0 else 1.0
		p.x += (rustle if side2 < 0.0 else rustle2) * 0.85 + sin(_t * 16.0 + float(i)) * 1.6 * shake
		p.y += cos(_t * 14.0 + float(i) * 0.9) * 2.2 * shake
		var tip_rot := float(T[4]) + (rustle if side2 < 0.0 else rustle2) * 2.8 + sin(_t * 18.0 + float(i)) * 6.0 * shake
		_draw_tip_leaf(c + p, float(T[2]), float(T[3]), lite[i % lite.size()], tip_rot)
	if age_hint() > 0.7:
		draw_circle(c + Vector2(-8 + rustle, 22 + rustle3 * 0.3), 2.0, Color(0.98, 0.96, 0.9, 0.55))
		draw_circle(c + Vector2(10 + rustle2, 24 - rustle * 0.2), 1.8, Color(0.98, 0.96, 0.9, 0.42))


func age_hint() -> float:
	# 0..1 through bush stage for tease glints
	if stage != "bush":
		return 1.0
	return clampf(PetState.age_sec / 60.0, 0.0, 1.0)


func _side_leg(hip: Vector2, foot: Vector2, width: float, phase: float, amp: float) -> void:
	# Short tucked kick — feet stay visually connected to the round body.
	var kick := sin(phase) * amp
	var mid := (hip + foot) * 0.5 + Vector2(kick * 0.45, -absf(kick) * 0.25)
	var toe := foot + Vector2(kick * 0.3, absf(kick) * 0.1)
	draw_line(hip, mid, Color("4f4f58"), width)
	draw_line(mid, toe, Color("4f4f58"), width)
	_ellipse(toe, Vector2(5.0, 2.8), Color("3a3a44"))


func _ringed_tail(base: Vector2, length: float, face: float, rings: bool = true) -> void:
	var tip := base + Vector2(-length * face, -length * 0.22)
	draw_line(base, tip, Color("5a5a64"), 7.0)
	if rings:
		for i in 4:
			var t := 0.2 + float(i) * 0.18
			var p := base.lerp(tip, t)
			_ellipse(p, Vector2(3.6, 2.8), Color("c8c8d0").darkened(0.05))


func _draw_stage_up_fx(c: Vector2) -> void:
	var u := clampf(_anim_t / maxf(0.01, _anim_dur), 0.0, 1.0)
	var aura := 0.2 + 0.55 * absf(sin(_t * 3.2))
	if u > 0.3 and u < 0.55:
		aura = 0.85
	_ellipse(c + Vector2(0, 8), Vector2(58, 40), Color(0.95, 0.8, 0.4, aura * 0.32))
	# Expanding ring near morph flash
	if u > 0.34 and u < 0.62:
		var ring_t := (u - 0.34) / 0.28
		var rr := lerpf(16.0, 72.0, ring_t)
		draw_arc(c, rr, 0.0, TAU, 36, Color(0.94, 0.77, 0.48, 0.7 * (1.0 - ring_t)), 2.2, true)
	# Swirling leaves
	for i in 10:
		var ang := _t * 2.4 + float(i) * TAU / 10.0
		var rad := lerpf(18.0, 62.0, clampf(u * 1.2, 0.0, 1.0))
		var lp := c + Vector2(cos(ang), sin(ang) * 0.72) * rad
		var leaf_a := 0.85 if u < 0.85 else (1.0 - u) / 0.15
		var col := Color("6fbf84") if i % 2 == 0 else Color("3d6b4f")
		col.a = leaf_a * 0.9
		draw_set_transform(lp, ang + 0.8, Vector2.ONE)
		_ellipse(Vector2.ZERO, Vector2(7, 3.5), col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Sparks on bloom
	if u > 0.4:
		for i in 8:
			var a2 := float(i) * TAU / 8.0 + _t
			var push := lerpf(10.0, 48.0, clampf((u - 0.4) / 0.35, 0.0, 1.0))
			var sp := c + Vector2(cos(a2), sin(a2)) * push
			var sa := 0.9 * (1.0 - clampf((u - 0.55) / 0.4, 0.0, 1.0))
			draw_circle(sp, 2.2, Color(0.96, 0.8, 0.4, sa))


func _is_sleeping() -> bool:
	return mood == "sleep" or _anim in ["sleep", "fallAsleep"] or (PetState != null and PetState.is_sleeping())


func _draw_nest_bed(c: Vector2) -> void:
	# Layered nest: outer twigs → moss cushion → leaf pillow → leaf blanket edge
	_ellipse(c + Vector2(0, 10), Vector2(52, 16), Color(0.16, 0.11, 0.06, 0.45))
	_ellipse(c + Vector2(0, 8), Vector2(48, 14), Color(0.23, 0.16, 0.09, 0.6))
	var sticks := [
		[Vector2(-40, 2), Vector2(-4, -2), Vector2(36, 4)],
		[Vector2(-34, 12), Vector2(-2, 16), Vector2(32, 10)],
		[Vector2(-24, -6), Vector2(4, -10), Vector2(38, 0)],
		[Vector2(-38, 8), Vector2(-10, 14), Vector2(22, 6)],
		[Vector2(-14, 16), Vector2(12, 20), Vector2(42, 6)],
		[Vector2(-44, 6), Vector2(-28, 0), Vector2(-10, 8)],
		[Vector2(18, -2), Vector2(34, 4), Vector2(46, 10)],
	]
	var stick_cols := [
		Color("6b4a2a"), Color("5a3c22"), Color("7a5530"), Color("4a3018"),
		Color("6a4828"), Color("5c3e20"), Color("734f2c"),
	]
	for i in sticks.size():
		var pts: Array = sticks[i]
		draw_polyline(PackedVector2Array([c + pts[0], c + pts[1], c + pts[2]]), stick_cols[i], 2.8, true)
	# Soft cushion
	_ellipse(c + Vector2(0, 6), Vector2(36, 10), Color(0.32, 0.24, 0.14, 0.85))
	_ellipse(c + Vector2(-2, 4), Vector2(28, 7), Color(0.4, 0.32, 0.2, 0.55))
	# Leaf pillow
	draw_set_transform(c + Vector2(18, -2), deg_to_rad(-18.0), Vector2.ONE)
	_ellipse(Vector2.ZERO, Vector2(14, 7), Color(0.33, 0.54, 0.38, 0.92))
	_ellipse(Vector2(-3, -1), Vector2(6, 3), Color(0.45, 0.68, 0.48, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Leaf blanket draped over near side
	draw_set_transform(c + Vector2(-6, 12), deg_to_rad(8.0), Vector2.ONE)
	_ellipse(Vector2.ZERO, Vector2(22, 8), Color(0.3, 0.48, 0.34, 0.8))
	_ellipse(Vector2(8, 1), Vector2(12, 5), Color(0.42, 0.62, 0.4, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var leaves := [
		[Vector2(-32, 4), Vector2(7, 3.5), Color("4a7a48"), -28.0],
		[Vector2(-20, 12), Vector2(8, 3.8), Color("3d6b4f"), 18.0],
		[Vector2(12, 13), Vector2(9, 4.0), Color("548a62"), -12.0],
		[Vector2(28, 6), Vector2(7.5, 3.4), Color("6fbf84"), 22.0],
		[Vector2(-4, 16), Vector2(8, 3.2), Color("3d6b4f"), 8.0],
		[Vector2(4, -2), Vector2(6, 2.8), Color("5a8a58"), -35.0],
		[Vector2(-12, 0), Vector2(5.5, 2.6), Color("6fbf84"), 40.0],
		[Vector2(22, 14), Vector2(6.5, 3.0), Color("4a7a48"), -20.0],
	]
	for L in leaves:
		var p: Vector2 = c + L[0]
		var r: Vector2 = L[1]
		var col: Color = L[2]
		var rot: float = deg_to_rad(float(L[3]))
		draw_set_transform(p, rot, Vector2.ONE)
		_ellipse(Vector2.ZERO, r, Color(col.r, col.g, col.b, 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_sleeping(c: Vector2) -> void:
	## Curled round sleep ball — still the same plush short-spine orb.
	var fur := _fur()
	var belly := fur.lightened(0.22)
	var body_rx := 28.0
	var body_ry := 25.0
	var body_y := 10.0
	var head_r := 16.0
	var head := Vector2(16, -2)
	var stroke_w := 4.0
	match stage:
		"baby":
			body_rx = 20.0
			body_ry = 18.0
			body_y = 14.0
			head_r = 13.0
			head = Vector2(12, 0)
			stroke_w = 3.2
		"young":
			body_rx = 24.0
			body_ry = 22.0
			body_y = 12.0
			head_r = 14.5
			head = Vector2(14, -1)
		"teen":
			body_rx = 27.0
			body_ry = 24.0
			body_y = 11.0
			head_r = 15.5
			head = Vector2(15, -2)
		"adult":
			body_rx = 32.0
			body_ry = 29.0
			body_y = 8.0
			head_r = 17.5
			head = Vector2(17, -3)
			stroke_w = 5.0
	var breath := sin(_t * 1.15)
	var body := c + Vector2(0, body_y)
	# Breathing arc (subtle)
	draw_arc(body + Vector2(2, -2), body_rx * 0.85 + breath * 1.5, -2.5, -0.6, 16, Color(0.85, 0.9, 0.95, 0.12 + breath * 0.04), 1.6, true)
	# Curled ringed tail tucked against the orb
	var tail_pts := PackedVector2Array([
		body + Vector2(-body_rx * 0.55, 2),
		body + Vector2(-body_rx * 0.85, -4),
		body + Vector2(-body_rx * 0.7, -12),
		body + Vector2(-body_rx * 0.35, -14),
		body + Vector2(-body_rx * 0.15, -8),
	])
	draw_polyline(tail_pts, Color("5a5a64"), stroke_w, true)
	for i in 5:
		var tt := 0.15 + float(i) * 0.18
		var tp := tail_pts[0].lerp(tail_pts[mini(4, i + 1)], tt)
		_ellipse(tp, Vector2(4.0, 3.0), Color("c8c8d0").darkened(0.08 if i % 2 == 0 else 0.18))
	# Tucked paws against the round belly
	_ellipse(body + Vector2(-10, body_ry * 0.55), Vector2(7, 4.0), Color("3a3a44"))
	_ellipse(body + Vector2(4, body_ry * 0.6), Vector2(6.5, 3.6), Color("3a3a44"))
	_ellipse(body + Vector2(-2, body_ry * 0.65), Vector2(5.5, 3.0), Color("32323a"))
	# Soft breathing squash on round body
	draw_set_transform(body, 0.0, Vector2(1.0 + breath * 0.02, 1.0 - breath * 0.02))
	_ellipse(Vector2.ZERO, Vector2(body_rx, body_ry), fur)
	_ellipse(Vector2(2, 2), Vector2(body_rx * 0.55, body_ry * 0.55), Color(belly.r, belly.g, belly.b, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Head overlapping the body (same round silhouette)
	var hp := body + head
	_ellipse(hp, Vector2(head_r, head_r * 0.95), fur.lightened(0.04))
	draw_set_transform(hp + Vector2(-4, -head_r * 0.55), deg_to_rad(-18.0), Vector2.ONE)
	_ellipse(Vector2.ZERO, Vector2(head_r * 0.38, head_r * 0.55), Color("4a4a54"))
	_ellipse(Vector2.ZERO, Vector2(head_r * 0.17, head_r * 0.3), Color("e2cdb2"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(hp + Vector2(6, -head_r * 0.5), deg_to_rad(12.0), Vector2.ONE)
	_ellipse(Vector2.ZERO, Vector2(head_r * 0.34, head_r * 0.5), Color("4a4a54"))
	_ellipse(Vector2.ZERO, Vector2(head_r * 0.15, head_r * 0.28), Color("e2cdb2"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_ellipse(hp + Vector2(1, 1), Vector2(head_r * 0.7, head_r * 0.4), Color(0.11, 0.11, 0.13, 0.9))
	# Closed eyes
	draw_polyline(
		PackedVector2Array([hp + Vector2(-6, 1), hp + Vector2(-2, 4), hp + Vector2(2, 1)]),
		Color("2a2a32"),
		1.8,
		true
	)
	draw_polyline(
		PackedVector2Array([hp + Vector2(4, 0), hp + Vector2(8, 3.2), hp + Vector2(12, 0)]),
		Color("2a2a32"),
		1.7,
		true
	)
	_ellipse(hp + Vector2(4, head_r * 0.38), Vector2(head_r * 0.26, head_r * 0.16), Color("c9a292"))
	draw_circle(hp + Vector2(4, head_r * 0.28), 1.4, Color("2a2a32"))
	# Drifting Z symbols
	for i in 3:
		var zt := fposmod(_t * 0.35 + float(i) * 0.33, 1.0)
		var zp := hp + Vector2(14.0 + float(i) * 6.0 + zt * 8.0, -10.0 - zt * 22.0 - float(i) * 4.0)
		var za := (1.0 - zt) * 0.75
		var zs := 10 + i * 2
		draw_string(ThemeDB.fallback_font, zp, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, zs, Color(0.85, 0.9, 0.95, za))
	# Quiet fireflies near nest
	for i in 4:
		var fx := c.x - 36.0 + fposmod(float(i) * 29.0 + _t * 12.0, 72.0)
		var fy := c.y - 28.0 + sin(_t * 1.4 + float(i) * 1.7) * 10.0 + float(i) * 3.0
		var pulse := 0.25 + 0.55 * absf(sin(_t * 2.2 + float(i)))
		draw_circle(Vector2(fx, fy), 1.7, Color(0.95, 0.82, 0.4, pulse * 0.65))


func _side_eye(p: Vector2, r: float, gleam: Color = Color("faf6ec")) -> void:
	var state := "sleep" if _is_sleeping() else ("sick" if _is_sick() else ("stubborn" if _is_stubborn() else ("happy" if _smile > 0.35 else "idle")))
	_draw_chibi_eye(p, r * 1.15, gleam, state, 1.0)


func _draw_sick_marks(head: Vector2, side: bool = false) -> void:
	if not _is_sick():
		return
	var drop := Color(0.55, 0.77, 0.63, 0.9)
	if side:
		draw_circle(head + Vector2(-6, -10), 1.7, drop)
		draw_circle(head + Vector2(-3, -4), 1.2, Color(drop.r, drop.g, drop.b, 0.75))
		draw_line(head + Vector2(-1, 8), head + Vector2(3, 12), Color("5a4038"), 1.7)
		draw_line(head + Vector2(3, 12), head + Vector2(7, 8), Color("5a4038"), 1.7)
	else:
		draw_circle(head + Vector2(-14, -10), 1.8, drop)
		draw_circle(head + Vector2(-11, -3), 1.25, Color(drop.r, drop.g, drop.b, 0.75))
		draw_circle(head + Vector2(14, -9), 1.5, Color(drop.r, drop.g, drop.b, 0.8))
		draw_line(head + Vector2(-5, 12), head + Vector2(0, 16), Color("5a4038"), 1.8)
		draw_line(head + Vector2(0, 16), head + Vector2(5, 12), Color("5a4038"), 1.8)
		_ellipse(head + Vector2(-11, 6), Vector2(3.2, 2.2), Color(0.42, 0.6, 0.47, 0.35))
		_ellipse(head + Vector2(11, 6), Vector2(3.2, 2.2), Color(0.42, 0.6, 0.47, 0.35))


func _draw_stubborn_marks(head: Vector2, side: bool = false) -> void:
	if not _is_stubborn():
		return
	if side:
		draw_line(head + Vector2(-7, -8), head + Vector2(2, -4), Color("2a2a32"), 1.9)
		draw_line(head + Vector2(-2, 8), head + Vector2(6, 8), Color("5a4038"), 1.8)
	else:
		draw_line(head + Vector2(-16, -8), head + Vector2(-6, -4), Color("2a2a32"), 2.0)
		draw_line(head + Vector2(16, -8), head + Vector2(6, -4), Color("2a2a32"), 2.0)
		draw_line(head + Vector2(-5, 12), head + Vector2(5, 12), Color("5a4038"), 2.0)


func _side_ear(p: Vector2, rx: float = 5.5, ry: float = 9.0) -> void:
	_ellipse(p, Vector2(rx, ry), Color("4a4a54"))
	_ellipse(p, Vector2(rx * 0.5, ry * 0.55), Color("e2cdb2"))


func _extra_mid_leg(c: Vector2, face: float, hip_y: float, mid_x: float, leg_h: float, width: float, phase: float) -> void:
	_side_leg(c + Vector2(mid_x * face, hip_y), c + Vector2((mid_x - 3.0) * face, hip_y + leg_h * 0.92), width * 0.85, phase + 1.1, 2.8)
	_ellipse(c + Vector2((mid_x - 3.0) * face, hip_y + leg_h * 0.92), Vector2(4.2, 2.4), Color("3a3a44"))


func _form_wings(kind: String, c: Vector2, face: float, cy: float) -> void:
	match kind:
		"bat":
			var l := PackedVector2Array([
				c + Vector2(-6 * face, cy),
				c + Vector2(-28 * face, cy - 16),
				c + Vector2(-34 * face, cy + 2),
				c + Vector2(-10 * face, cy + 4),
			])
			draw_colored_polygon(l, Color(0.1, 0.1, 0.13, 0.88))
			var r := PackedVector2Array([
				c + Vector2(4 * face, cy - 2),
				c + Vector2(22 * face, cy - 14),
				c + Vector2(28 * face, cy),
				c + Vector2(6 * face, cy + 2),
			])
			draw_colored_polygon(r, Color(0.1, 0.1, 0.13, 0.7))
		"moth":
			_ellipse(c + Vector2(-16 * face, cy - 2), Vector2(15, 9), Color(0.16, 0.19, 0.28, 0.8))
			_ellipse(c + Vector2(12 * face, cy - 4), Vector2(11, 7), Color(0.16, 0.19, 0.28, 0.65))
			_ellipse(c + Vector2(-14 * face, cy - 2), Vector2(7, 3.5), Color(0.78, 0.85, 0.94, 0.22))
		"leaf":
			_ellipse(c + Vector2(-18 * face, cy), Vector2(13, 7.5), Color("6fbf84"))
			_ellipse(c + Vector2(14 * face, cy - 2), Vector2(11, 6.5), Color(0.33, 0.54, 0.38, 0.85))
		"ghost":
			var gl := PackedVector2Array([
				c + Vector2(-4 * face, cy),
				c + Vector2(-28 * face, cy - 18),
				c + Vector2(-34 * face, cy + 3),
				c + Vector2(-8 * face, cy + 3),
			])
			draw_colored_polygon(gl, Color(0.78, 0.86, 0.94, 0.45))
			var gr := PackedVector2Array([
				c + Vector2(2 * face, cy - 2),
				c + Vector2(24 * face, cy - 16),
				c + Vector2(32 * face, cy + 2),
				c + Vector2(4 * face, cy + 2),
			])
			draw_colored_polygon(gr, Color(0.78, 0.86, 0.94, 0.35))


func _trash_crown(kind: String, tip: Vector2, face: float = 1.0) -> void:
	match kind:
		"bottlecap":
			_ellipse(tip + Vector2(0, -2), Vector2(8.5, 3.0), Color("8a9aaa"))
			_ellipse(tip + Vector2(0, -4), Vector2(7.0, 2.2), Color("b8c4d0"))
			draw_line(tip + Vector2(-6.5, -3), tip + Vector2(-7.5, -7), Color("6a7888"), 1.5)
			draw_line(tip + Vector2(-1.5, -4), tip + Vector2(-1.0, -8), Color("6a7888"), 1.5)
			draw_line(tip + Vector2(3.0, -4), tip + Vector2(3.5, -8), Color("6a7888"), 1.5)
			draw_line(tip + Vector2(6.5, -3), tip + Vector2(7.5, -7), Color("6a7888"), 1.5)
		"tincan":
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-9, 0), tip + Vector2(-7, -9), tip + Vector2(7, -9), tip + Vector2(9, 0)
			]), Color("9a7a4a"))
			draw_rect(Rect2(tip + Vector2(-6.5, -8), Vector2(13, 2.5)), Color(0.77, 0.63, 0.42, 0.85))
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-5, -9), tip + Vector2(-3, -14), tip + Vector2(-1, -9)
			]), Color("b8925a"))
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(1, -9), tip + Vector2(3, -13), tip + Vector2(5, -9)
			]), Color("b8925a"))
		"gold":
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-11, 0), tip + Vector2(-9, -7), tip + Vector2(-3, -3),
				tip + Vector2(0, -13), tip + Vector2(3, -3), tip + Vector2(9, -7), tip + Vector2(11, 0)
			]), Color("e0a04a"))
			draw_circle(tip + Vector2(0, -5), 2.0, Color("fff3d0"))
			_ellipse(tip, Vector2(11, 2.2), Color(0.77, 0.52, 0.16, 0.55))
		"pizza":
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-10, 1), tip + Vector2(-7, -8), tip + Vector2(0, -4),
				tip + Vector2(7, -9), tip + Vector2(10, 1)
			]), Color("8a4a28"))
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-8, 0), tip + Vector2(-6, -6), tip + Vector2(0, -3),
				tip + Vector2(6, -7), tip + Vector2(8, 0)
			]), Color("e0a04a"))
			draw_circle(tip + Vector2(-2.5 * face, -2.5), 1.3, Color("8a2f2f"))
			draw_circle(tip + Vector2(2.5 * face, -3.5), 1.1, Color("8a2f2f"))


func _draw_baby(c: Vector2, face: float) -> void:
	## Smallest round orb — oversized head, tiny tucked feet, stub tail.
	var fur := _fur()
	var wobble := sin(_walk_phase) * 1.2
	var body_y := 14.0 + wobble
	_ellipse(c + Vector2(0, body_y + 16), Vector2(16, 4), Color(0, 0, 0, 0.2))
	_ellipse(c + Vector2(-16 * face, body_y + 4), Vector2(6, 4.5), fur)
	_side_leg(c + Vector2(-7 * face, body_y + 8), c + Vector2(-8 * face, body_y + 14), 3.2, _walk_phase, 1.4)
	_side_leg(c + Vector2(8 * face, body_y + 8), c + Vector2(9 * face, body_y + 14), 3.2, _walk_phase + 2.2, 1.4)
	_ellipse(c + Vector2(0, body_y), Vector2(20, 18), fur)
	_ellipse(c + Vector2(3 * face, body_y + 4), Vector2(10, 8), fur.lightened(0.2))
	_ellipse(c + Vector2(10 * face, body_y - 6), Vector2(14, 13), fur.lightened(0.04))
	_side_ear(c + Vector2(8 * face, body_y - 16), 4.5, 7.0)
	_ellipse(c + Vector2(18 * face, body_y - 4), Vector2(5, 3.2), Color("c9a292"))
	_ellipse(c + Vector2(11 * face, body_y - 4), Vector2(9, 5.5), Color("2a2a32"))
	_side_eye(c + Vector2(13 * face, body_y - 5), 2.6)
	_draw_sick_marks(c + Vector2(13 * face, body_y - 5), true)
	_draw_stubborn_marks(c + Vector2(13 * face, body_y - 5), true)


func _draw_young(c: Vector2, face: float) -> void:
	## Round short-spine young forms — accessories/colors differ, not body length.
	var fur := _fur()
	var body_rx := 26.0
	var body_ry := 24.0
	var body_y := 8.0
	var head_x := 14.0
	var head_r := 15.0
	var leg_h := 8.0
	var front_x := 10.0
	var back_x := -10.0
	var crown_kind := ""
	var leg_amp := 2.2

	match young_form:
		"puff":
			body_rx = 30.0
			body_ry = 28.0
			leg_h = 6.0
			_ellipse(c + Vector2(-22 * face, body_y + 2), Vector2(8, 7), fur.lightened(0.08))
			_ellipse(c + Vector2(-26 * face, body_y), Vector2(5, 4), fur.lightened(0.16))
		"looper":
			body_rx = 26.0
			body_ry = 24.0
			leg_h = 8.0
			leg_amp = 4.5
			# Looping ringed tail motion sells the energy.
			var loop_wag := sin(_walk_phase * 1.6) * 6.0
			_ringed_tail(c + Vector2(-18 * face, body_y + 2 + loop_wag * 0.15), 18.0 + absf(loop_wag) * 0.2, face, true)
			draw_line(c + Vector2(-6 * face, body_y - 8), c + Vector2(10 * face, body_y - 8), Color("e0a04a"), 2.0)
		"shadow":
			body_rx = 26.0
			body_ry = 24.0
			leg_h = 7.0
			_form_wings("bat", c, face, body_y - 4.0)
			_ringed_tail(c + Vector2(-18 * face, body_y + 2), 18.0, face, true)
		"nub":
			body_rx = 24.0
			body_ry = 22.0
			head_r = 16.0
			leg_h = 7.0
			crown_kind = "bottlecap"
			_ellipse(c + Vector2(-16 * face, body_y + 4), Vector2(5, 4), fur.darkened(0.05))
		_:
			_ringed_tail(c + Vector2(-18 * face, body_y + 2), 16.0, face, true)

	_ellipse(c + Vector2(0, body_y + body_ry * 0.7 + leg_h), Vector2(body_rx * 0.65, 4.5), Color(0, 0, 0, 0.2))
	var phase := _walk_phase
	_side_leg(c + Vector2(back_x * face, body_y + body_ry * 0.35), c + Vector2((back_x - 2) * face, body_y + body_ry * 0.35 + leg_h), 3.8, phase, leg_amp)
	_side_leg(c + Vector2(front_x * face, body_y + body_ry * 0.35), c + Vector2((front_x + 2) * face, body_y + body_ry * 0.35 + leg_h), 3.8, phase + 2.4, leg_amp)
	_ellipse(c + Vector2(0, body_y), Vector2(body_rx, body_ry), fur)
	if young_form == "puff":
		_ellipse(c + Vector2(3 * face, body_y + 4), Vector2(14, 11), fur.lightened(0.22))
		_ellipse(c + Vector2(10 * face, body_y - 10), Vector2(5, 4), fur.lightened(0.14))
	elif young_form == "shadow":
		draw_line(c + Vector2(-12 * face, body_y - 4), c + Vector2(10 * face, body_y - 5), Color("1a1a22"), 4.5)
	elif young_form == "nub":
		for i in 3:
			var sx := -6.0 + float(i) * 5.0
			draw_line(c + Vector2(sx * face, body_y - body_ry + 2), c + Vector2((sx + 1.5) * face, body_y - body_ry - 5), fur.darkened(0.1), 2.0)

	_ellipse(c + Vector2(head_x * face, body_y - 4), Vector2(head_r, head_r * 0.95), fur.lightened(0.05))
	if young_form != "nub":
		_side_ear(c + Vector2((head_x - 3) * face, body_y - head_r - 4), 5.0, 8.0)
	else:
		_side_ear(c + Vector2((head_x - 2) * face, body_y - head_r - 3), 4.5, 7.0)
	if crown_kind != "":
		_trash_crown(crown_kind, c + Vector2(head_x * face, body_y - head_r - 4), face)
	var snout_c := Color("1c1c22") if young_form == "shadow" else Color("c9a292")
	_ellipse(c + Vector2((head_x + 7) * face, body_y - 2), Vector2(5.5, 3.5), snout_c)
	var mask_c := Color("121218") if young_form == "shadow" else Color("2a2a32")
	_ellipse(c + Vector2(head_x * face, body_y - 2), Vector2(head_r * 0.72, head_r * 0.5), mask_c)
	var gleam := Color("d0d8e8") if young_form == "shadow" else Color("faf6ec")
	var young_eye := c + Vector2((head_x + 2) * face, body_y - 4)
	_side_eye(young_eye, 3.0 if young_form != "shadow" else 3.2, gleam)
	_draw_sick_marks(young_eye, true)
	_draw_stubborn_marks(young_eye, true)


func _draw_teen(c: Vector2, face: float) -> void:
	## Round teen orb — Bounder hops hard; Dumpling is widest; no tall legs.
	var form := teen_form if teen_form != "" else "bounder"
	var fur := _fur()
	var body_rx := 28.0
	var body_ry := 26.0
	var body_y := 6.0
	var head_x := 15.0
	var head_r := 16.0
	var leg_h := 9.0
	var front_x := 11.0
	var back_x := -12.0
	var crown_kind := ""
	var leg_amp := 2.6

	match form:
		"dumpling":
			body_rx = 34.0
			body_ry = 32.0
			leg_h = 6.0
			_ellipse(c + Vector2(-20 * face, body_y + 4), Vector2(8, 6), fur.lightened(0.05))
		"bounder":
			body_rx = 28.0
			body_ry = 26.0
			leg_h = 10.0
			leg_amp = 5.0
			draw_line(c + Vector2(6 * face, body_y - 8), c + Vector2(12 * face, body_y - 14), Color("e0a04a"), 2.0)
			_ringed_tail(c + Vector2(-18 * face, body_y + 2), 18.0, face, true)
		"nightlane":
			body_rx = 28.0
			body_ry = 26.0
			leg_h = 8.0
			_form_wings("moth", c, face, body_y - 4.0)
			_ringed_tail(c + Vector2(-20 * face, body_y + 2), 20.0, face, true)
			_ellipse(c + Vector2(4 * face, body_y - 2), Vector2(14, 6), Color(0.06, 0.06, 0.1, 0.4))
		"scruff":
			body_rx = 28.0
			body_ry = 26.0
			crown_kind = "tincan"
			_ringed_tail(c + Vector2(-18 * face, body_y + 2), 16.0, face, true)
			for i in 5:
				var sx := -10.0 + float(i) * 5.0
				draw_line(
					c + Vector2(sx * face, body_y - body_ry + 2),
					c + Vector2((sx + 2.0) * face, body_y - body_ry - 6.0),
					fur.darkened(0.12),
					2.4
				)
		_:
			_ringed_tail(c + Vector2(-18 * face, body_y + 2), 16.0, face, true)

	_ellipse(c + Vector2(0, body_y + body_ry * 0.7 + leg_h), Vector2(body_rx * 0.65, 4.5), Color(0, 0, 0, 0.22))
	var phase := _walk_phase
	_side_leg(c + Vector2(back_x * face, body_y + body_ry * 0.35), c + Vector2((back_x - 2) * face, body_y + body_ry * 0.35 + leg_h), 4.2, phase, leg_amp)
	_side_leg(c + Vector2(front_x * face, body_y + body_ry * 0.35), c + Vector2((front_x + 2) * face, body_y + body_ry * 0.35 + leg_h), 4.2, phase + 2.3, leg_amp)
	_ellipse(c + Vector2(0, body_y), Vector2(body_rx, body_ry), fur)
	if form == "dumpling":
		_ellipse(c + Vector2(2 * face, body_y + 6), Vector2(18, 13), fur.lightened(0.2))
	elif form == "scruff":
		draw_line(c + Vector2(14 * face, body_y + 4), c + Vector2(20 * face, body_y + 5), Color("8a5a4a"), 2.0)
		_ellipse(c + Vector2(-4 * face, body_y + 6), Vector2(3.5, 2.5), Color(0.42, 0.47, 0.53, 0.55))

	_ellipse(c + Vector2(head_x * face, body_y - 4), Vector2(head_r, head_r * 0.95), fur.lightened(0.04))
	if form == "scruff":
		draw_line(c + Vector2((head_x - 2) * face, body_y - head_r - 2), c + Vector2((head_x + 1) * face, body_y - head_r - 9), Color("4a4a54"), 2.8)
		_side_ear(c + Vector2((head_x - 2) * face, body_y - head_r - 3), 5.0, 8.0)
	else:
		_side_ear(c + Vector2((head_x - 3) * face, body_y - head_r - 3), 5.2, 8.5)
	if crown_kind != "":
		_trash_crown(crown_kind, c + Vector2((head_x - 1) * face, body_y - head_r - 3), face)
	var snout := Color("1a1a24") if form == "nightlane" else Color("c9a292")
	_ellipse(c + Vector2((head_x + 7) * face, body_y - 1), Vector2(6.0, 3.8), snout)
	_ellipse(c + Vector2(head_x * face, body_y - 1), Vector2(head_r * 0.7, head_r * 0.48), Color("0e1018") if form == "nightlane" else Color("2a2a32"))
	var teen_eye := c + Vector2((head_x + 2) * face, body_y - 3)
	var gleam := Color("d8e4f8") if form == "nightlane" else Color("faf6ec")
	if form == "dumpling" and _smile < 0.35 and not _is_sick() and not _is_stubborn():
		draw_line(c + Vector2((head_x - 1) * face, body_y - 2), c + Vector2((head_x + 5) * face, body_y - 4), Color("faf6ec"), 2.0)
	else:
		_side_eye(teen_eye, 3.2 if form != "nightlane" else 3.4, gleam)
	_draw_sick_marks(teen_eye, true)
	_draw_stubborn_marks(teen_eye, true)


func _draw_adult(c: Vector2, face: float) -> void:
	## Large round adult orb — form flair via wings/crowns/palette only.
	var fur := _fur()
	var body_rx := 32.0
	var body_ry := 30.0
	var body_y := 2.0
	var head_x := 14.0
	var head_r := 17.0
	var leg_h := 10.0
	var front_x := 11.0
	var back_x := -13.0
	var snout := Color("c9a292")
	var gleam := Color("faf6ec")
	var mask_c := Color("1c1c22")
	var crown_kind := ""

	match adult_form:
		"saint":
			body_rx = 34.0
			body_ry = 32.0
			_form_wings("leaf", c, face, body_y - 2.0)
			_ellipse(c + Vector2(14 * face, body_y - 20), Vector2(7, 4.5), Color("6fbf84"))
			_ellipse(c + Vector2(10 * face, body_y - 22), Vector2(3.5, 2.8), Color("548a62"))
			draw_circle(c + Vector2(5 * face, body_y - 16), 1.4, Color(0.72, 0.88, 0.75, 0.7))
		"legend":
			body_rx = 32.0
			body_ry = 30.0
			crown_kind = "gold"
			var blaze := PackedVector2Array([
				c + Vector2(6 * face, body_y - 10),
				c + Vector2(22 * face, body_y - 2),
				c + Vector2(8 * face, body_y + 4),
			])
			draw_colored_polygon(blaze, Color("e0a04a"))
			gleam = Color("fff3d0")
		"alley_ghost":
			body_rx = 34.0
			body_ry = 32.0
			snout = Color("b8c4d4")
			gleam = Color("e8f0ff")
			mask_c = Color("3a4250")
			_form_wings("ghost", c, face, body_y)
			_ellipse(c + Vector2(-24 * face, body_y + 2), Vector2(9, 5.5), Color(0.78, 0.86, 0.94, 0.28))
			_ellipse(c + Vector2(24 * face, body_y + 4), Vector2(7, 4.5), Color(0.78, 0.86, 0.94, 0.22))
		"ballard_blip":
			body_rx = 32.0
			body_ry = 30.0
			crown_kind = "pizza"
			draw_line(c + Vector2(4 * face, body_y + 8), c + Vector2(22 * face, body_y + 8), Color("c45c4a"), 3.5)
			_ellipse(c + Vector2(0, body_y + 8), Vector2(12, 8), Color(0.88, 0.63, 0.29, 0.32))

	if adult_form != "alley_ghost":
		_ringed_tail(c + Vector2(-22 * face, body_y + 2), 18.0, face, true)
	else:
		draw_line(c + Vector2(-18 * face, body_y + 2), c + Vector2(-28 * face, body_y - 4), Color(0.66, 0.7, 0.77, 0.7), 6.0)

	_ellipse(c + Vector2(0, body_y + body_ry * 0.7 + leg_h), Vector2(body_rx * 0.65, 5.0), Color(0, 0, 0, 0.22))
	var phase := _walk_phase
	var amp := 3.8 if _anim in ["run", "lope"] else 2.6
	_side_leg(c + Vector2(back_x * face, body_y + body_ry * 0.35), c + Vector2((back_x - 2) * face, body_y + body_ry * 0.35 + leg_h), 4.6, phase, amp)
	_side_leg(c + Vector2(front_x * face, body_y + body_ry * 0.35), c + Vector2((front_x + 2) * face, body_y + body_ry * 0.35 + leg_h), 4.6, phase + 2.5, amp)
	_ellipse(c + Vector2(0, body_y), Vector2(body_rx, body_ry), fur)
	if adult_form == "saint":
		_ellipse(c + Vector2(2 * face, body_y + 6), Vector2(14, 11), fur.lightened(0.16))
	elif adult_form == "alley_ghost":
		_ellipse(c + Vector2(8 * face, body_y), Vector2(13, 10), Color(0.9, 0.94, 1.0, 0.16))
	elif adult_form == "ballard_blip":
		_ellipse(c + Vector2(12 * face, body_y + 14), Vector2(5.5, 3.2), Color("3a3a44"))

	# Overlapping round head
	_ellipse(c + Vector2(head_x * face, body_y - 4), Vector2(head_r, head_r * 0.95), fur.lightened(0.04))
	if adult_form != "ballard_blip":
		_side_ear(c + Vector2((head_x - 3) * face, body_y - head_r - 3), 5.5, 9.0)
	if crown_kind != "":
		_trash_crown(crown_kind, c + Vector2(head_x * face, body_y - head_r - 2), face)
	_ellipse(c + Vector2((head_x + 8) * face, body_y - 1), Vector2(7, 4.8), snout)
	_ellipse(c + Vector2(head_x * face, body_y - 1), Vector2(head_r * 0.72, head_r * 0.48), mask_c)
	var adult_eye := c + Vector2((head_x + 2) * face, body_y - 3)
	_side_eye(adult_eye, 3.8, gleam)
	_draw_sick_marks(adult_eye, true)
	_draw_stubborn_marks(adult_eye, true)
	if adult_form == "ballard_blip":
		# Goofy smile accent
		draw_arc(c + Vector2((head_x + 6) * face, body_y + 2), 4.0, 0.2, PI - 0.2, 8, Color("2a2a32"), 1.4, true)
	elif adult_form == "legend":
		draw_line(c + Vector2((head_x + 6) * face, body_y + 1), c + Vector2((head_x + 12) * face, body_y + 1), Color("d0d0d8"), 1.1)
