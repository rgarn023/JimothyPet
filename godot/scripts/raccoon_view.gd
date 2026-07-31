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
var _anim: String = "idle_front"
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
var _mouth_open: float = 0.0
var _chew_puff: float = 0.0
var _bite_progress: float = 0.0

const SIDE_ANIMS := ["walk", "run", "lope", "jump", "sniff"]
## Explicit Baby Kit / care animation states (procedural poses — not auto-scanned textures).
## idle_front: front-facing breathing only (no side / roll / feed poses)
## hatch_reveal: bush → leaf FX → front kit bounce → idle_front
## happy_bounce: short front bounce one-shot
## feed_*: anticipation → food to mouth → bite → chew → swallow → recovery → idle_front
## blink: optional one-shot eyelid close during idle_front
const FEED_ANIMS := [
	"feed_dumpster_fries",
	"feed_wild_berries",
	"feed_night_crickets",
	"feed_stream_fish",
	"feed_pizza_crust",
]
const ONE_SHOT_ANIMS := [
	"hatch_reveal",
	"happy_bounce",
	"blink",
	"ascend",
	"fallAsleep",
	"feed_dumpster_fries",
	"feed_wild_berries",
	"feed_night_crickets",
	"feed_stream_fish",
	"feed_pizza_crust",
	# legacy aliases still treated as locked one-shots while playing
	"eat",
	"stageUp",
	"hop",
	"happy",
]
## Temporary debug for state transitions — disabled after validation.
const ANIM_DEBUG := false

var _blink_amt: float = 0.0
var _hatch_show_bush: bool = false
var _action_locked: bool = false

const CREAM := Color("f2e6d2")
const CREAM_SOFT := Color("e8d8c2")
const MASK_DARK := Color("2a2a32")
const OUTLINE := Color("26262e")
const PAW_DARK := Color("3a3a44")


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


func configure_as_avatar(scale: float = 0.48) -> void:
	avatar_mode = true
	preview_mode = false
	avatar_scale = scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(150, 140)
	size = Vector2(150, 140)


func configure_as_form_preview(p_stage: String, form_id: String, thumb_scale: float = 0.22) -> void:
	## Round chibi thumbnail for the Forms gallery — front idle only.
	avatar_mode = false
	preview_mode = true
	preview_scale = thumb_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(220, 220)
	size = Vector2(220, 220)
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
	_anim = "idle_front"
	_anim_t = 0.0
	_pose_x = 0.0
	_pose_y = 0.0
	_head_dip = 0.0
	_body_squash = 1.0
	_facing = 1.0
	_desired_facing = 1.0
	_action_locked = false
	_blink_amt = 0.0
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
	# Don't interrupt one-shot care / feed / ascend mid-motion
	if _action_locked or _is_one_shot_anim(_anim):
		return
	_tap_cooldown = 0.55
	PetState.interact_tap()


func clear_ascend() -> void:
	_anim = "idle_front"
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
	_action_locked = false
	_blink_amt = 0.0
	_hatch_show_bush = false
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
	# Baby Kit never uses side/roll poses for care or idle — front only.
	if stage == "baby":
		return true
	if _is_feeding() or _anim in ["idle_front", "idle", "hatch_reveal", "happy_bounce", "blink", "stageUp"]:
		return true
	return not (_anim in SIDE_ANIMS)


func _is_feeding() -> bool:
	return _anim in FEED_ANIMS or _anim == "eat"


func _is_one_shot_anim(name: String) -> bool:
	return name in ONE_SHOT_ANIMS or name in FEED_ANIMS


func _is_idle_front() -> bool:
	return _anim in ["idle_front", "idle"]


func _foot_pivot_y() -> float:
	## Bottom-center body anchor so squash/stretch does not float the feet.
	match stage:
		"baby":
			return 54.0
		"young":
			return 58.0
		"teen":
			return 66.0
		"adult":
			return 74.0
		_:
			return 54.0


func _anim_debug(name: String) -> void:
	if ANIM_DEBUG:
		print("Jimothy animation: ", name)


func _return_to_idle_front() -> void:
	_anim = "idle_front"
	_anim_t = 0.0
	_anim_dur = 4.0
	_action_locked = false
	_hatch_show_bush = false
	_pose_y = 0.0
	_head_dip = 0.0
	_body_squash = 1.0
	_paw_lift = 0.0
	_mouth_open = 0.0
	_chew_puff = 0.0
	_bite_progress = 0.0
	_blink_amt = 0.0
	_speed = 0.0
	_anim_debug("idle_front")


func _feed_anim_for_food(food_key: String) -> String:
	## Explicit food → feed state mapping (never alphabetical directory order).
	match food_key:
		"fries":
			return "feed_dumpster_fries"
		"berries", "berry":
			return "feed_wild_berries"
		"crickets":
			return "feed_night_crickets"
		"fish":
			return "feed_stream_fish"
		"pizza":
			return "feed_pizza_crust"
		_:
			return "feed_wild_berries"


func _food_for_feed_anim(anim_name: String) -> String:
	match anim_name:
		"feed_dumpster_fries":
			return "fries"
		"feed_wild_berries":
			return "berries"
		"feed_night_crickets":
			return "crickets"
		"feed_stream_fish":
			return "fish"
		"feed_pizza_crust":
			return "pizza"
		_:
			return _eat_food if _eat_food != "" else "berries"


func _normalize_anim_name(kind: String) -> String:
	## Map legacy impulses onto the explicit state machine names.
	match kind:
		"idle":
			return "idle_front"
		"hop", "happy":
			return "happy_bounce"
		"stageUp":
			return "hatch_reveal"
		"eat":
			var food := _eat_food
			if PetState and PetState.last_fed_food != "":
				food = PetState.last_fed_food
			return _feed_anim_for_food(food)
		_:
			if kind in FEED_ANIMS:
				return kind
			return kind


func _request_facing(dir: float) -> void:
	if dir == 0.0:
		return
	# Baby Kit stays front-facing — ignore side facing requests.
	if stage == "baby":
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
	play_anim(_feed_anim_for_food(_eat_food))


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
		if _anim not in ["sleep", "fallAsleep", "ascend"] and not _action_locked:
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
		if _anim in ["ascend", "gone"] or (_fade < 0.99 and _anim not in ["stageUp", "hatch_reveal"]) or modulate.a < 0.99:
			if PetState.is_sleeping():
				_anim = "sleep"
				_anim_t = 0.0
				_anim_dur = 4.0
			elif _anim in ["ascend", "gone"]:
				_anim = "idle_front"
				_anim_t = 0.0
				_action_locked = false
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
	var raw := kind
	var normalized := _normalize_anim_name(kind)

	# Baby Kit: ambient side locomotion is never allowed (no roll/side idle).
	if stage == "baby" and normalized in SIDE_ANIMS:
		if _action_locked:
			return
		normalized = "idle_front"

	# Sleep may interrupt hatch when he emerges during sleep hours.
	var allow_sleep_interrupt := raw in ["fallAsleep", "sleep"] and _anim in ["hatch_reveal", "stageUp"]
	if not allow_sleep_interrupt:
		if _action_locked or _is_one_shot_anim(_anim):
			# Ambient / idle noise cannot cut a one-shot.
			if normalized in ["walk", "run", "lope", "jump", "sniff", "stretch", "idle", "idle_front", "stubborn", "sick", "sleep", "blink"]:
				return
			# Another major one-shot also waits (except sleep interrupt handled above).
			if _is_one_shot_anim(normalized) and _anim in ["ascend", "hatch_reveal", "stageUp"] and normalized not in ["fallAsleep"]:
				return

	_anim = normalized
	_anim_t = 0.0
	_action_locked = _is_one_shot_anim(normalized) and normalized not in ["sleep"]
	_anim_debug(normalized)

	match normalized:
		"ascend":
			_anim_dur = 4.2
			_wing_span = 0.0
			_fade = 1.0
			_ascend_done_emitted = false
			_speed = 0.0
			_hatch_show_bush = false
		"hatch_reveal", "stageUp":
			# ~1.0–1.5s bush/leaf reveal + controlled bounce, then idle_front.
			_anim_dur = 1.35
			_jump_peak = 18.0
			_speed = 0.0
			_smile = 1.0
			_fade = 1.0
			_pose_x = 0.0
			_pose_y = 0.0
			_body_squash = 1.0
			_hatch_show_bush = (stage == "baby")
		"fallAsleep":
			_anim_dur = 1.5
			_speed = 0.0
		"sleep":
			_anim_dur = 4.0
			_speed = 0.0
			_action_locked = false
		"run":
			_anim_dur = randf_range(1.6, 2.8)
			_speed = randf_range(100.0, 155.0)
			_target_x = randf_range(-78.0, 78.0)
			_request_facing(signf(_target_x - _pose_x) if _target_x != _pose_x else 1.0)
			_facing = _desired_facing
			_face_cooldown = 0.0
			_action_locked = false
		"walk", "lope":
			_anim_dur = randf_range(2.2, 3.8)
			_speed = randf_range(40.0, 80.0) if normalized == "walk" else randf_range(60.0, 105.0)
			_target_x = randf_range(-78.0, 78.0)
			var wdir := signf(_target_x - _pose_x)
			if wdir == 0.0:
				wdir = [-1.0, 1.0][randi() % 2]
			_request_facing(wdir)
			_facing = _desired_facing
			_face_cooldown = 0.0
			_action_locked = false
		"jump":
			_anim_dur = randf_range(0.55, 0.9)
			_jump_peak = randf_range(18.0, 36.0)
			_request_facing([-1.0, 1.0][randi() % 2])
			_facing = _desired_facing
			_face_cooldown = 0.0
			_target_x = clampf(_pose_x + _facing * randf_range(20.0, 50.0), -70.0, 70.0)
			_action_locked = false
		"pop":
			_anim_dur = 0.85
			_body_squash = 1.0
		"stretch":
			_anim_dur = 1.05
			_body_squash = 1.0
		"feed_dumpster_fries", "feed_wild_berries", "feed_night_crickets", "feed_stream_fish", "feed_pizza_crust", "eat":
			# Coherent eat sequence ~0.8–1.4s (not slow static image swaps).
			_anim_dur = 1.15
			_eat_flash = 1.0
			_head_dip = 0.0
			_paw_lift = 0.0
			_mouth_open = 0.0
			_chew_puff = 0.0
			_bite_progress = 0.0
			_eat_crumbs.clear()
			_pose_x = 0.0
			_pose_y = 0.0
			_body_squash = 1.0
			if normalized in FEED_ANIMS:
				_eat_food = _food_for_feed_anim(normalized)
			elif PetState and PetState.last_fed_food != "":
				_eat_food = PetState.last_fed_food
		"refuse":
			_anim_dur = 0.95
		"scold":
			_anim_dur = 0.9
		"stubborn", "sick":
			_anim_dur = 1.1
			_action_locked = false
		"sniff":
			_anim_dur = 1.0
			_action_locked = false
		"smile":
			_anim_dur = 0.95
			_smile = 1.0
		"sad":
			_anim_dur = 1.35
			_smile = 0.0
		"happy_bounce", "hop", "happy":
			# Short front-facing bounce ~0.5–0.9s.
			_anim_dur = 0.7
			_jump_peak = 20.0
			_smile = 1.0
			_pose_x = 0.0
			_body_squash = 1.0
		"blink":
			_anim_dur = 0.28
			_blink_amt = 0.0
			_speed = 0.0
		"idle_front", "idle":
			_anim = "idle_front"
			_anim_dur = 4.0
			_speed = 0.0
			_action_locked = false
			_blink_amt = 0.0
		"nuzzle", "heal":
			_anim_dur = 1.05
			_smile = 0.85
			_head_dip = 2.0
		"spin":
			_anim_dur = 0.85
		"rustle":
			_anim_dur = 1.15
		_:
			_anim_dur = randf_range(1.0, 2.0)
			_speed = 0.0


func _process(delta: float) -> void:
	_t += delta
	_anim_t += delta
	_tap_cooldown = maxf(0.0, _tap_cooldown - delta)
	_eat_flash = maxf(0.0, _eat_flash - delta * 0.85)
	if _anim not in ["smile", "nuzzle", "happy", "happy_bounce"]:
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
			_return_to_idle_front()
			reveal()
		else:
			queue_redraw()
			return

	if _anim in ["hatch_reveal", "stageUp"]:
		var u := clampf(_anim_t / _anim_dur, 0.0, 1.0)
		_smile = 1.0
		_pose_x = 0.0
		# Bush hold → leaf reveal → front kit pop with small squash/stretch → idle_front.
		if u < 0.28:
			var p := u / 0.28
			_pose_y = 0.0
			_head_dip = 0.0
			_body_squash = 1.0
			_fade = 0.0 if _hatch_show_bush else lerpf(0.35, 0.0, p)
		elif u < 0.48:
			var p2 := (u - 0.28) / 0.20
			_pose_y = 0.0
			_head_dip = 0.0
			_body_squash = lerpf(1.0, 0.88, p2)
			_fade = lerpf(0.0, 0.55, p2)
		elif u < 0.72:
			var p3 := (u - 0.48) / 0.24
			# Small controlled bounce — feet stay via foot-pivot squash.
			_pose_y = -sin(p3 * PI) * 10.0
			_head_dip = -sin(p3 * PI) * 1.5
			_body_squash = lerpf(0.88, 1.10, sin(p3 * PI))
			_fade = smoothstep(0.0, 0.35, p3)
		elif u < 0.88:
			var p4 := (u - 0.72) / 0.16
			_pose_y = -absf(sin(p4 * PI)) * 4.0
			_head_dip = 0.0
			_body_squash = lerpf(1.08, 0.94, p4)
			_fade = 1.0
		else:
			var p5 := (u - 0.88) / 0.12
			_pose_y = 0.0
			_head_dip = 0.0
			_body_squash = lerpf(0.94, 1.0, p5)
			_fade = 1.0
		if _anim_t >= _anim_dur:
			_fade = 1.0
			_return_to_idle_front()
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
				_anim = "idle_front"
				_action_locked = false
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
					_return_to_idle_front()
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
				_return_to_idle_front()
		"pop":
			var pu := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_pose_y = -ease(pu, 0.3) * 22.0
			_body_squash = 1.0 + (1.0 - pu) * 0.15
			if _anim_t >= _anim_dur:
				_return_to_idle_front()
		"stretch":
			var su := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_pose_y = -sin(su * PI) * 6.0
			# Stretch widens a round body — never elongates into a tall torso.
			_body_squash = 1.0 + sin(su * PI) * 0.14
			_head_dip = -sin(su * PI) * 4.0
			_walk_phase += delta * 4.0
			if _anim_t >= _anim_dur:
				_return_to_idle_front()
		"feed_dumpster_fries", "feed_wild_berries", "feed_night_crickets", "feed_stream_fish", "feed_pizza_crust", "eat":
			var eu := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			# anticipation → food in paws → to mouth → bite → 2–3 chews → swallow → recovery
			_pose_x = 0.0
			if eu < 0.12:
				var sn := eu / 0.12
				_head_dip = lerpf(0.0, 3.0, sn)
				_pose_y = 0.0
				_paw_lift = lerpf(0.0, 0.35, sn)
				_mouth_open = lerpf(0.0, 0.12, sn)
				_chew_puff = 0.0
				_bite_progress = 0.0
				_body_squash = lerpf(1.0, 0.96, sn)
			elif eu < 0.28:
				var lift := (eu - 0.12) / 0.16
				_head_dip = lerpf(3.0, 6.5, lift)
				_pose_y = 0.0
				_paw_lift = lerpf(0.35, 1.0, lift)
				_mouth_open = lerpf(0.12, 0.55, lift)
				_chew_puff = 0.0
				_bite_progress = lerpf(0.0, 0.12, lift)
				_body_squash = 0.96
			elif eu < 0.40:
				# Bite
				var bite_u := (eu - 0.28) / 0.12
				_head_dip = 7.0 + sin(bite_u * PI) * 1.5
				_pose_y = 0.0
				_paw_lift = 1.0
				_mouth_open = lerpf(0.55, 0.85, sin(bite_u * PI))
				_chew_puff = bite_u * 0.4
				_bite_progress = lerpf(0.12, 0.45, bite_u)
				_body_squash = lerpf(0.96, 1.04, bite_u)
			elif eu < 0.72:
				# Two–three quick chew pulses (~10 FPS holds via sin)
				var chew_u := (eu - 0.40) / 0.32
				var chew_wave := sin(chew_u * PI * 3.0)
				_head_dip = 6.5 + chew_wave * 1.8
				_pose_y = 0.0
				_paw_lift = 0.92
				_mouth_open = 0.22 + absf(chew_wave) * 0.55
				_chew_puff = absf(chew_wave) * 0.85
				_bite_progress = lerpf(0.45, 0.92, chew_u)
				_body_squash = 1.0 + absf(chew_wave) * 0.03
				if chew_wave > 0.85 and _eat_crumbs.size() < 10:
					_eat_crumbs.append({
						"x": randf_range(-4.0, 6.0),
						"y": randf_range(-18.0, -8.0),
						"vx": randf_range(-28.0, 28.0),
						"vy": randf_range(-42.0, -12.0),
						"t": 0.0,
						"life": randf_range(0.25, 0.45),
					})
			elif eu < 0.84:
				var sw := (eu - 0.72) / 0.12
				_head_dip = lerpf(6.5, 2.0, sw)
				_pose_y = 0.0
				_paw_lift = lerpf(0.92, 0.1, sw)
				_mouth_open = lerpf(0.35, 0.0, sw)
				_chew_puff = lerpf(0.4, 0.0, sw)
				_bite_progress = lerpf(0.92, 1.0, sw)
				_body_squash = lerpf(1.0, 1.06, sin(sw * PI))
			else:
				var please := (eu - 0.84) / 0.16
				_head_dip = lerpf(2.0, 0.0, please)
				_pose_y = 0.0
				_paw_lift = 0.0
				_mouth_open = 0.0
				_chew_puff = 0.0
				_bite_progress = 1.0
				_smile = 1.0
				_body_squash = lerpf(1.06, 1.0, please)
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
				_eat_crumbs.clear()
				_return_to_idle_front()
		"refuse":
			var ru := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			# Head-shake without rapid facing flips (avoids visual glitch).
			_pose_x += sin(_t * 14.0) * 0.9
			_head_dip = sin(ru * PI) * 4.0
			if _anim_t >= _anim_dur:
				_return_to_idle_front()
		"scold":
			var cu := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_pose_y = sin(cu * PI) * 2.0
			_head_dip = 3.0 + sin(_t * 14.0) * 2.0
			_body_squash = 0.94
			if _anim_t >= _anim_dur:
				_return_to_idle_front()
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
				_return_to_idle_front()
		"smile":
			var sm := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_smile = 1.0
			_pose_y = sin(sm * PI) * 3.0
			_head_dip = -sin(sm * PI) * 2.0
			_body_squash = 1.0 + sin(sm * PI) * 0.04
			if _anim_t >= _anim_dur:
				_return_to_idle_front()
		"sad":
			var sd := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_smile = 0.0
			_head_dip = 7.0 + sin(sd * PI) * 3.0
			_pose_y = sin(_t * 2.2) * 0.8
			_pose_x += sin(_t * 3.0) * 0.25
			if _anim_t >= _anim_dur:
				_return_to_idle_front()
		"happy_bounce", "hop", "happy":
			var hu := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			var hop_peak := _jump_peak * (1.15 if _is_bouncy_form() else 1.0)
			_pose_x = 0.0
			# Rise → land compress → recover to idle_front (front-facing only).
			if hu < 0.18:
				_body_squash = lerpf(1.0, 0.82, hu / 0.18)
				_pose_y = 0.0
			elif hu < 0.72:
				var ju := (hu - 0.18) / 0.54
				_pose_y = -sin(ju * PI) * hop_peak
				_body_squash = lerpf(0.9, 1.10, sin(ju * PI))
			else:
				var lu := (hu - 0.72) / 0.28
				_pose_y = 0.0
				_body_squash = lerpf(0.78, 1.0, ease(lu, 0.45))
			_smile = 0.9
			if hu >= 1.0:
				_return_to_idle_front()
		"blink":
			var bu := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_pose_x = move_toward(_pose_x, 0.0, 40.0 * delta)
			_pose_y = 0.0
			_body_squash = 1.0 + sin(_t * 1.7) * 0.02
			if bu < 0.45:
				_blink_amt = lerpf(0.0, 1.0, bu / 0.45)
			else:
				_blink_amt = lerpf(1.0, 0.0, (bu - 0.45) / 0.55)
			if bu >= 1.0:
				_return_to_idle_front()
		"nuzzle":
			var nu := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			_pose_x += sin(_t * 6.0) * 0.45
			_head_dip = 4.0 + sin(nu * PI) * 5.0
			_smile = 0.8
			if _anim_t >= _anim_dur:
				_return_to_idle_front()
		"spin":
			var su2 := clampf(_anim_t / _anim_dur, 0.0, 1.0)
			if su2 > 0.45 and su2 < 0.55:
				_request_facing(-_facing if _facing != 0.0 else 1.0)
			_pose_y = -sin(su2 * PI) * 10.0
			_pose_x += sin(_t * 10.0) * 0.6
			_smile = 0.6
			if _anim_t >= _anim_dur:
				_return_to_idle_front()
		"stubborn", "sick":
			_pose_x += sin(_t * 10.0) * 0.35
			_head_dip = 2.0
			if _anim_t >= _anim_dur:
				_return_to_idle_front()
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
				# idle_front: calm front-facing breath. Feet stay planted (pose_y=0);
				# subtle squash uses the bottom-center foot pivot in _draw.
				var breath_i := sin(_t * 1.7)
				_pose_y = 0.0
				_pose_x = move_toward(_pose_x, 0.0, 36.0 * delta)
				_head_dip = sin(_t * 1.4) * (0.7 if stage == "baby" else 1.1)
				_body_squash = 1.0 + breath_i * (0.025 if stage == "baby" else 0.035)
				_blink_amt = 0.0
				# Occasional blink one-shot only from approved idle — never side poses.
				if stage == "baby" and not _action_locked and randf() < 0.0025:
					play_anim("blink")
				elif _is_bouncy_form() and stage != "baby" and randf() < 0.004:
					_body_squash = 0.96
			_walk_phase += delta * 1.2

	_pose_x = clampf(_pose_x, -56.0, 56.0)
	_commit_facing(delta)
	queue_redraw()


func _ellipse(center: Vector2, radii: Vector2, color: Color, points: int = 28) -> void:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * float(i) / float(points)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func _ellipse_outlined(center: Vector2, radii: Vector2, fill: Color, outline: Color = OUTLINE, width: float = 2.6, points: int = 28) -> void:
	## Clean dark outer outline behind a filled ellipse (reference mascot look).
	_ellipse(center, radii + Vector2(width * 0.55, width * 0.55), outline, points)
	_ellipse(center, radii, fill, points)


func _mascot_squash_xy(squash: float) -> Vector2:
	## Anticipation squash helper — neither axis goes outside mascot-safe bounds.
	var squash_x := clampf(squash, 0.78, 1.20)
	var squash_y := clampf(2.0 - squash_x, 0.82, 1.18)
	return Vector2(squash_x, squash_y)


func _cream() -> Color:
	return CREAM


func _form_ids() -> Dictionary:
	return {
		"young": young_form,
		"teen": teen_form,
		"adult": adult_form,
	}


func _g(key: String, fallback: float = 0.5) -> float:
	return float(genes.get(key, fallback))


func _is_sick() -> bool:
	return mood == "sick" or (PetState != null and PetState.sick and PetState.alive and not PetState.ascending)


func _is_stubborn() -> bool:
	if _is_sick():
		return false
	return mood == "stubborn" or (PetState != null and PetState.stubborn and PetState.alive and not PetState.ascending)


func _fur() -> Color:
	# Medium gray base matching the supplied raccoon reference (not charcoal potato).
	var g := _g("gray", 0.5)
	var c := Color(0.58 + g * 0.08, 0.58 + g * 0.06, 0.62 + g * 0.05)
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

	# Hatch from bush: keep bush visible first, then leaf FX, then reveal kit.
	if _anim in ["hatch_reveal", "stageUp"] and _hatch_show_bush:
		var hu := clampf(_anim_t / maxf(0.001, _anim_dur), 0.0, 1.0)
		if hu < 0.34:
			_draw_bush(size * 0.5)
			_draw_stage_up_fx(c)
			return
		if hu < 0.48:
			_draw_bush(size * 0.5)
			_draw_stage_up_fx(c)
			# Baby peeks under leaves at low fade.

	# Soft sky glow during ascent / hatch
	if _anim == "ascend":
		var glow_a := (1.0 - _fade) * 0.35 + _wing_span * 0.25
		_ellipse(c + Vector2(0, 10), Vector2(70, 40), Color(0.95, 0.88, 0.55, glow_a * 0.35))
	elif _anim in ["hatch_reveal", "stageUp"]:
		_draw_stage_up_fx(c)

	var face := _facing if _facing != 0.0 else 1.0
	var old_mod := modulate
	if _anim == "ascend":
		modulate = Color(1, 1, 1, _fade)
	elif _anim in ["hatch_reveal", "stageUp"]:
		modulate = Color(1, 1, 1, _fade)

	if _anim == "ascend" and _wing_span > 0.05:
		_draw_wings(c, face, _wing_span)

	# Head dip nudges the silhouette down while chewing / sniffing.
	var draw_c := c + Vector2(0, _head_dip * 0.45)
	# Foot-anchored squash: scale around body base so feet/Y do not jump.
	var using_squash := absf(_body_squash - 1.0) > 0.004 and not _is_sleeping()
	var squash_xy := _mascot_squash_xy(_body_squash)
	if using_squash:
		var pivot_y := _foot_pivot_y()
		var pivot := draw_c + Vector2(0.0, pivot_y)
		draw_set_transform(pivot, 0.0, squash_xy)
		draw_c = Vector2(0.0, -pivot_y)

	if _is_sleeping() and _anim != "ascend":
		if not preview_mode:
			_draw_nest_bed(c + Vector2(0, 28))
		_draw_sleeping(draw_c + Vector2(0, 8))
	elif _view_front() and _anim != "ascend":
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

	if _is_feeding():
		var eat_u := clampf(_anim_t / maxf(0.001, _anim_dur), 0.0, 1.0)
		_draw_food_prop(c, face, eat_u)
		_draw_eat_crumbs(c)
		if _eat_flash > 0.05:
			var flash_col := VisualPolish.food_flash_color(_eat_food)
			flash_col.a = 0.18 * _eat_flash
			_ellipse(c + Vector2(0, 8), Vector2(70, 52), flash_col)

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
	## reference-matched plush raccoon: large overlapping head + round body, glossy eyes, cream muzzle.
	var fur := _fur()
	var belly := _cream()
	var snout := _cream()
	var mask := MASK_DARK
	var gleam := Color("faf6ec")
	var wing_kind := ""
	var crown_kind := ""
	var tuft := false
	var stroke_w := 3.2

	# Proportional guidance from the supplied round raccoon reference.
	var head_rx := 57.0
	var head_ry := 53.0
	var head_y := -8.0
	var body_rx := 55.0
	var body_ry := 47.0
	var body_y := 20.0
	var eye_r := 8.0
	var ear_rx := 13.0
	var ear_ry := 15.0
	var ear_y := -48.0
	var foot_spread := 14.0
	var foot_y := 52.0
	var paw_show := true

	match stage:
		"baby":
			head_rx = 57.0
			head_ry = 53.0
			head_y = -6.0
			body_rx = 54.0
			body_ry = 46.0
			body_y = 22.0
			eye_r = 8.2
			ear_rx = 13.0
			ear_ry = 15.0
			ear_y = -46.0
			foot_spread = 13.0
			foot_y = 54.0
			stroke_w = 3.0
		"young":
			head_rx = 62.0
			head_ry = 57.0
			head_y = -8.0
			body_rx = 62.0
			body_ry = 54.0
			body_y = 22.0
			eye_r = 8.6
			ear_rx = 14.0
			ear_ry = 16.0
			ear_y = -50.0
			foot_spread = 15.0
			foot_y = 58.0
			if young_form == "puff":
				body_rx = 70.0
				body_ry = 60.0
				foot_y = 60.0
			elif young_form == "nub":
				crown_kind = "bottlecap"
				tuft = true
			elif young_form == "shadow":
				mask = Color("121218")
				gleam = Color("e8f0ff")
				wing_kind = "bat"
			elif young_form == "looper":
				pass
		"teen":
			head_rx = 68.0
			head_ry = 62.0
			head_y = -10.0
			body_rx = 72.0
			body_ry = 64.0
			body_y = 24.0
			eye_r = 9.0
			ear_rx = 15.0
			ear_ry = 17.0
			ear_y = -55.0
			foot_spread = 17.0
			foot_y = 66.0
			stroke_w = 3.4
			if teen_form == "dumpling":
				body_rx = 84.0
				body_ry = 74.0
				foot_y = 70.0
			elif teen_form == "bounder":
				pass
			elif teen_form == "nightlane":
				mask = Color("0e1018")
				gleam = Color("e8f0ff")
				wing_kind = "moth"
			elif teen_form == "scruff":
				crown_kind = "tincan"
				tuft = true
		_:
			head_rx = 74.0
			head_ry = 68.0
			head_y = -12.0
			body_rx = 82.0
			body_ry = 72.0
			body_y = 26.0
			eye_r = 9.6
			ear_rx = 16.0
			ear_ry = 18.5
			ear_y = -62.0
			foot_spread = 19.0
			foot_y = 74.0
			stroke_w = 3.8
			if adult_form == "alley_ghost":
				snout = Color("d8e2ee")
				belly = Color("d8e2ee")
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

	# Contact shadow immediately under tucked feet.
	_ellipse(c + Vector2(0, foot_y + 6.0), Vector2(body_rx * 0.78, 8.0), Color(0, 0, 0, 0.22))

	# Ringed raccoon tail peek (left side).
	if stage == "baby":
		_ellipse_outlined(c + Vector2(-body_rx * 0.78, body_y + 6), Vector2(14, 11), fur.lightened(0.04), OUTLINE, stroke_w * 0.7)
		_ellipse(c + Vector2(-body_rx * 0.78, body_y + 6), Vector2(7, 5), CREAM_SOFT.darkened(0.08))
	else:
		var tail_base := c + Vector2(-body_rx * 0.72, body_y + 2)
		draw_line(tail_base, tail_base + Vector2(-28, 6), Color("5a5a64"), 9.0)
		for i in 4:
			var tp := tail_base + Vector2(-8.0 - float(i) * 7.0, 2.0 + float(i) * 1.5)
			_ellipse(tp, Vector2(5.5, 4.2), Color("d0d0d8").darkened(0.06 if i % 2 == 0 else 0.16))

	if wing_kind != "":
		_form_wings(wing_kind, c, 1.0, body_y - 6.0)

	# Tiny dark tucked feet (under the round body).
	var lx := c.x - foot_spread
	var rx := c.x + foot_spread
	_ellipse_outlined(Vector2(lx, c.y + foot_y), Vector2(11, 6.5), PAW_DARK, OUTLINE, 1.8)
	_ellipse_outlined(Vector2(rx, c.y + foot_y), Vector2(11, 6.5), PAW_DARK, OUTLINE, 1.8)
	# Toe ticks
	for toe_x in [-3.5, 0.0, 3.5]:
		draw_line(Vector2(lx + toe_x, c.y + foot_y - 1), Vector2(lx + toe_x, c.y + foot_y + 3), Color("222228"), 1.3)
		draw_line(Vector2(rx + toe_x, c.y + foot_y - 1), Vector2(rx + toe_x, c.y + foot_y + 3), Color("222228"), 1.3)

	# Round plush body — overlaps heavily with the head for one circular silhouette.
	_ellipse_outlined(c + Vector2(0, body_y), Vector2(body_rx, body_ry), fur, OUTLINE, stroke_w)
	_ellipse(c + Vector2(0, body_y + body_ry * 0.12), Vector2(body_rx * 0.62, body_ry * 0.55), Color(belly.r, belly.g, belly.b, 0.92))
	# Soft volume shade
	_ellipse(c + Vector2(-body_rx * 0.22, body_y - body_ry * 0.15), Vector2(body_rx * 0.35, body_ry * 0.28), Color(1, 1, 1, 0.07))

	if tuft:
		for i in 5:
			var tx := -16.0 + float(i) * 8.0
			draw_line(c + Vector2(tx, body_y - body_ry + 4), c + Vector2(tx + 1.5, body_y - body_ry - 10), fur.darkened(0.12), 2.6)

	# Large rounded head overlapping the body.
	_ellipse_outlined(c + Vector2(0, head_y), Vector2(head_rx, head_ry), fur.lightened(0.03), OUTLINE, stroke_w)
	# Cheek/head fur tufts
	draw_line(c + Vector2(-head_rx * 0.92, head_y - 2), c + Vector2(-head_rx * 1.05, head_y - 8), fur.darkened(0.08), 2.4)
	draw_line(c + Vector2(head_rx * 0.92, head_y - 2), c + Vector2(head_rx * 1.05, head_y - 8), fur.darkened(0.08), 2.4)
	for i in 3:
		var hx := -8.0 + float(i) * 8.0
		draw_line(c + Vector2(hx, head_y - head_ry + 2), c + Vector2(hx + 1.0, head_y - head_ry - 7), fur.darkened(0.1), 2.2)

	# Broad rounded ears with cream inners + tick marks.
	_draw_front_ear(c + Vector2(-head_rx * 0.42, ear_y), ear_rx, ear_ry, fur)
	_draw_front_ear(c + Vector2(head_rx * 0.42, ear_y), ear_rx, ear_ry, fur)

	if crown_kind != "":
		_trash_crown(crown_kind, c + Vector2(0, head_y - head_ry + 4), 1.0)

	# Cream eyebrow markings above the mask.
	_ellipse(c + Vector2(-eye_r * 2.05, head_y - eye_r * 1.55), Vector2(eye_r * 0.95, eye_r * 0.55), CREAM)
	_ellipse(c + Vector2(eye_r * 2.05, head_y - eye_r * 1.55), Vector2(eye_r * 0.95, eye_r * 0.55), CREAM)

	# Strong dark raccoon mask around both eyes.
	_ellipse(c + Vector2(-eye_r * 2.05, head_y + eye_r * 0.05), Vector2(eye_r * 2.15, eye_r * 1.55), Color(mask.r, mask.g, mask.b, 0.96))
	_ellipse(c + Vector2(eye_r * 2.05, head_y + eye_r * 0.05), Vector2(eye_r * 2.15, eye_r * 1.55), Color(mask.r, mask.g, mask.b, 0.96))
	_ellipse(c + Vector2(0, head_y + eye_r * 0.15), Vector2(eye_r * 1.1, eye_r * 0.85), Color(mask.r, mask.g, mask.b, 0.55))

	# Large cream muzzle and cheek area.
	var muzzle_y := head_y + head_ry * 0.28
	_ellipse(c + Vector2(0, muzzle_y), Vector2(head_rx * 0.72, head_ry * 0.52), snout)
	# Cheek puff while chewing.
	if _chew_puff > 0.05:
		var puff := _chew_puff
		_ellipse(c + Vector2(-head_rx * 0.48, muzzle_y + 2), Vector2(10 + puff * 4, 8 + puff * 2), Color(snout.r, snout.g, snout.b, 0.95))
		_ellipse(c + Vector2(head_rx * 0.48, muzzle_y + 2), Vector2(10 + puff * 4, 8 + puff * 2), Color(snout.r, snout.g, snout.b, 0.95))

	# Large glossy eyes with multiple highlights.
	var eye_state := "sleep" if _is_sleeping() else ("sick" if _is_sick() else ("stubborn" if _is_stubborn() else ("happy" if _smile > 0.35 and not _is_feeding() else "idle")))
	if _blink_amt > 0.55 or _anim == "blink":
		eye_state = "sleep"
	var eye_y := head_y + eye_r * 0.05
	_draw_chibi_eye(c + Vector2(-eye_r * 2.05, eye_y), eye_r, gleam, eye_state, -1.0)
	_draw_chibi_eye(c + Vector2(eye_r * 2.05, eye_y), eye_r, gleam, eye_state, 1.0)

	# Small black rounded nose + smiling / chewing mouth.
	var nose_p := c + Vector2(0, muzzle_y - head_ry * 0.06)
	_ellipse(nose_p, Vector2(4.2, 3.2), Color("1a1a20"))
	draw_circle(nose_p + Vector2(-1.2, -0.8), 1.1, Color(1, 1, 1, 0.45))
	var mouth_y := muzzle_y + head_ry * 0.18
	if _is_feeding() and _mouth_open > 0.08:
		var open_h := 2.0 + _mouth_open * 7.0
		_ellipse(c + Vector2(0, mouth_y), Vector2(7.5, open_h), Color("4a2030"))
		_ellipse(c + Vector2(0, mouth_y + open_h * 0.25), Vector2(4.5, open_h * 0.45), Color("c45c6a"))
	elif _smile > 0.2 or eye_state == "happy":
		draw_arc(c + Vector2(0, mouth_y - 1), 7.0, 0.25, PI - 0.25, 12, Color("2a2a32"), 2.0, true)
		_ellipse(c + Vector2(0, mouth_y + 2.5), Vector2(3.2, 2.0), Color("c45c6a"))
	else:
		draw_arc(c + Vector2(0, mouth_y), 5.5, 0.35, PI - 0.35, 10, Color("2a2a32"), 1.7, true)

	# Small rounded paws when eating (hold food in front of belly).
	if _is_feeding() and paw_show:
		var hold := clampf(_paw_lift, 0.0, 1.0)
		var paw_y := body_y + lerpf(18.0, -2.0, hold)
		_ellipse_outlined(c + Vector2(-18, paw_y), Vector2(10, 7), PAW_DARK, OUTLINE, 1.6)
		_ellipse_outlined(c + Vector2(18, paw_y), Vector2(10, 7), PAW_DARK, OUTLINE, 1.6)

	# Adult form accent markings (do not change silhouette).
	if stage == "adult" and adult_form == "legend":
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-10, head_y + 8), c + Vector2(14, head_y + 14), c + Vector2(-8, head_y + 22)
		]), Color("e0a04a"))
	elif stage == "adult" and adult_form == "ballard_blip":
		draw_line(c + Vector2(-16, body_y + 18), c + Vector2(16, body_y + 18), Color("c45c4a"), 3.5)

	_draw_sick_marks(c + Vector2(0, head_y), false)
	_draw_stubborn_marks(c + Vector2(0, head_y), false)


func _draw_front_ear(center: Vector2, rx: float, ry: float, fur: Color) -> void:
	_ellipse_outlined(center, Vector2(rx, ry), fur.darkened(0.05), OUTLINE, 2.2)
	_ellipse(center + Vector2(0, 1), Vector2(rx * 0.55, ry * 0.55), CREAM)
	# Inner-ear tick marks
	for i in 3:
		var ox := -3.0 + float(i) * 3.0
		draw_line(center + Vector2(ox, -ry * 0.15), center + Vector2(ox * 0.6, ry * 0.2), Color("6a6a74"), 1.2)


func _draw_food_prop(c: Vector2, face: float, u: float) -> void:
	# Both paws hold food; food moves to mouth, shrinks/bites, never floats over the body.
	var fade := 1.0 - smoothstep(0.82, 0.95, u)
	if fade <= 0.02 or _bite_progress >= 0.99:
		return
	var hold := smoothstep(0.10, 0.28, u)
	var paw_y := lerpf(28.0, 6.0, _paw_lift)
	var mouth := c + Vector2(0.0, -6.0 + _head_dip * 0.25)
	var paw_center := c + Vector2(0.0, paw_y)
	var p := paw_center.lerp(mouth + Vector2(0.0, 14.0), hold * 0.85)
	# Rear paw pads under the food.
	_ellipse_outlined(p + Vector2(-12.0, 8.0), Vector2(11, 7), PAW_DARK, OUTLINE, 1.5)
	_ellipse_outlined(p + Vector2(12.0, 8.0), Vector2(11, 7), PAW_DARK, OUTLINE, 1.5)
	var food_scale := lerpf(1.15, 0.72, clampf(_bite_progress, 0.0, 1.0))
	VisualPolish.draw_food(self, _eat_food, p + Vector2(0, -2), fade * 0.98, food_scale, _bite_progress)
	# Forepaw digits over the treat so it is clearly held.
	if hold > 0.15:
		_ellipse(p + Vector2(-10.0, 4.0), Vector2(7, 4.5), PAW_DARK)
		_ellipse(p + Vector2(10.0, 4.5), Vector2(7, 4.5), Color("32323a"))
		for dx in [-2.5, 0.0, 2.5]:
			draw_line(p + Vector2(-10.0 + dx, 2.0), p + Vector2(-10.0 + dx, 6.0), Color("222228"), 1.1)
			draw_line(p + Vector2(10.0 + dx, 2.5), p + Vector2(10.0 + dx, 6.5), Color("222228"), 1.1)


func _draw_eat_crumbs(c: Vector2) -> void:
	var flash := VisualPolish.food_flash_color(_eat_food)
	for crumb in _eat_crumbs:
		var aa := 1.0 - float(crumb.t) / float(crumb.life)
		var p := c + Vector2(float(crumb.x), float(crumb.y))
		_ellipse(p, Vector2(2.6, 2.1), Color(flash.r, flash.g, flash.b, 0.8 * aa))


func _draw_chibi_eye(center: Vector2, radius: float, gleam: Color, state: String, brow_flip: float = 1.0) -> void:
	var outline := OUTLINE
	if state == "sleep":
		draw_arc(center + Vector2(0, 1), radius * 0.85, 0.12, PI - 0.12, 16, outline, 2.4, true)
		return
	if state == "happy":
		# Happy crescent eyes stay large and readable.
		draw_arc(center, radius * 0.95, PI + 0.35, TAU - 0.35, 14, gleam, 2.6, true)
		draw_arc(center, radius * 0.95, PI + 0.35, TAU - 0.35, 14, outline, 1.6, true)
		return

	# Large glossy dark eyes with multiple specular highlights (reference look).
	_ellipse(center, Vector2(radius * 1.05, radius * 1.12), outline)
	_ellipse(center, Vector2(radius * 0.92, radius * 0.98), Color("1a1a20"))
	if state == "sick":
		_ellipse(center, Vector2(radius * 0.92, radius * 0.72), Color("1a1a20"))
	draw_circle(center + Vector2(-radius * 0.28, -radius * 0.32), radius * 0.28, gleam)
	draw_circle(center + Vector2(radius * 0.22, radius * 0.18), radius * 0.12, Color(1, 1, 1, 0.75))
	draw_circle(center + Vector2(radius * 0.05, -radius * 0.05), radius * 0.08, Color(1, 1, 1, 0.35))

	if state == "sick":
		draw_line(center + Vector2(-radius, -radius * 0.7), center + Vector2(radius, -radius * 0.3), outline, 2.0)
	elif state == "stubborn":
		draw_line(
			center + Vector2(-radius * 0.95, -radius * (1.05 + 0.12 * brow_flip)),
			center + Vector2(radius * 0.78, -radius * (0.7 - 0.12 * brow_flip)),
			outline,
			2.2
		)


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
	_ellipse_outlined(toe, Vector2(7.5, 4.2), PAW_DARK, OUTLINE, 1.4)


func _ringed_tail(base: Vector2, length: float, face: float, rings: bool = true) -> void:
	var tip := base + Vector2(-length * face, -length * 0.22)
	draw_line(base, tip, Color("5a5a64"), 10.0)
	if rings:
		for i in 4:
			var t := 0.18 + float(i) * 0.18
			var p := base.lerp(tip, t)
			_ellipse(p, Vector2(5.2, 4.0), Color("d0d0d8").darkened(0.05 if i % 2 == 0 else 0.16))


func _draw_stage_up_fx(c: Vector2) -> void:
	var u := clampf(_anim_t / maxf(0.01, _anim_dur), 0.0, 1.0)
	var aura := 0.2 + 0.55 * absf(sin(_t * 3.2))
	if u > 0.3 and u < 0.55:
		aura = 0.85
	_ellipse(c + Vector2(0, 10), Vector2(90, 62), Color(0.95, 0.8, 0.4, aura * 0.32))
	# Expanding ring near morph flash — leaves/sparkles cover the brief hide.
	if u > 0.30 and u < 0.62:
		var ring_t := (u - 0.30) / 0.32
		var rr := lerpf(24.0, 110.0, ring_t)
		draw_arc(c, rr, 0.0, TAU, 40, Color(0.94, 0.77, 0.48, 0.75 * (1.0 - ring_t)), 2.6, true)
	for i in 14:
		var ang := _t * 2.4 + float(i) * TAU / 14.0
		var rad := lerpf(28.0, 96.0, clampf(u * 1.15, 0.0, 1.0))
		var lp := c + Vector2(cos(ang), sin(ang) * 0.72) * rad
		var leaf_a := 0.9 if u < 0.85 else (1.0 - u) / 0.15
		var col := Color("6fbf84") if i % 2 == 0 else Color("3d6b4f")
		col.a = leaf_a * 0.95
		draw_set_transform(lp, ang + 0.8, Vector2.ONE)
		_ellipse(Vector2.ZERO, Vector2(10, 5), col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if u > 0.38:
		for i in 12:
			var a2 := float(i) * TAU / 12.0 + _t
			var push := lerpf(16.0, 78.0, clampf((u - 0.38) / 0.35, 0.0, 1.0))
			var sp := c + Vector2(cos(a2), sin(a2)) * push
			var sa := 0.9 * (1.0 - clampf((u - 0.55) / 0.4, 0.0, 1.0))
			draw_circle(sp, 2.8, Color(0.96, 0.8, 0.4, sa))


func _is_sleeping() -> bool:
	return mood == "sleep" or _anim in ["sleep", "fallAsleep"] or (PetState != null and PetState.is_sleeping())


func _draw_nest_bed(c: Vector2) -> void:
	# Layered nest: outer twigs → moss cushion → leaf pillow → leaf blanket edge
	_ellipse(c + Vector2(0, 12), Vector2(78, 22), Color(0.16, 0.11, 0.06, 0.45))
	_ellipse(c + Vector2(0, 10), Vector2(70, 18), Color(0.23, 0.16, 0.09, 0.6))
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
	## Curled round sleep ball — same plush short-spine orb as the reference.
	var fur := _fur()
	var belly := _cream()
	var body_rx := 58.0
	var body_ry := 52.0
	var body_y := 16.0
	var head_r := 36.0
	var head := Vector2(28, -6)
	var stroke_w := 3.4
	match stage:
		"baby":
			body_rx = 48.0
			body_ry = 44.0
			body_y = 18.0
			head_r = 32.0
			head = Vector2(24, -2)
			stroke_w = 3.0
		"young":
			body_rx = 54.0
			body_ry = 48.0
			body_y = 16.0
			head_r = 34.0
			head = Vector2(26, -4)
		"teen":
			body_rx = 62.0
			body_ry = 56.0
			body_y = 14.0
			head_r = 38.0
			head = Vector2(30, -6)
		"adult":
			body_rx = 72.0
			body_ry = 64.0
			body_y = 12.0
			head_r = 42.0
			head = Vector2(34, -8)
			stroke_w = 3.8
	var breath := sin(_t * 1.15)
	var body := c + Vector2(0, body_y)
	draw_arc(body + Vector2(2, -2), body_rx * 0.85 + breath * 1.5, -2.5, -0.6, 16, Color(0.85, 0.9, 0.95, 0.12 + breath * 0.04), 1.8, true)
	# Curled ringed tail
	var tail_pts := PackedVector2Array([
		body + Vector2(-body_rx * 0.55, 2),
		body + Vector2(-body_rx * 0.9, -6),
		body + Vector2(-body_rx * 0.72, -18),
		body + Vector2(-body_rx * 0.35, -20),
		body + Vector2(-body_rx * 0.12, -10),
	])
	draw_polyline(tail_pts, Color("5a5a64"), stroke_w + 2.0, true)
	for i in 5:
		var tt := 0.15 + float(i) * 0.18
		var tp := tail_pts[0].lerp(tail_pts[mini(4, i + 1)], tt)
		_ellipse(tp, Vector2(5.5, 4.2), Color("c8c8d0").darkened(0.08 if i % 2 == 0 else 0.18))
	_ellipse(body + Vector2(-14, body_ry * 0.55), Vector2(12, 7), PAW_DARK)
	_ellipse(body + Vector2(6, body_ry * 0.6), Vector2(11, 6.5), PAW_DARK)
	draw_set_transform(body, 0.0, Vector2(1.0 + breath * 0.02, 1.0 - breath * 0.02))
	_ellipse_outlined(Vector2.ZERO, Vector2(body_rx, body_ry), fur, OUTLINE, stroke_w)
	_ellipse(Vector2(2, 4), Vector2(body_rx * 0.55, body_ry * 0.52), Color(belly.r, belly.g, belly.b, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var hp := body + head
	_ellipse_outlined(hp, Vector2(head_r, head_r * 0.95), fur.lightened(0.03), OUTLINE, stroke_w)
	_draw_front_ear(hp + Vector2(-head_r * 0.35, -head_r * 0.7), head_r * 0.28, head_r * 0.34, fur)
	_draw_front_ear(hp + Vector2(head_r * 0.4, -head_r * 0.65), head_r * 0.26, head_r * 0.32, fur)
	_ellipse(hp + Vector2(2, 2), Vector2(head_r * 0.72, head_r * 0.42), Color(MASK_DARK.r, MASK_DARK.g, MASK_DARK.b, 0.9))
	draw_arc(hp + Vector2(-8, 2), 6.0, 0.2, PI - 0.2, 10, OUTLINE, 2.0, true)
	draw_arc(hp + Vector2(10, 1), 5.5, 0.2, PI - 0.2, 10, OUTLINE, 2.0, true)
	_ellipse(hp + Vector2(6, head_r * 0.35), Vector2(head_r * 0.42, head_r * 0.28), CREAM)
	draw_circle(hp + Vector2(6, head_r * 0.22), 2.2, Color("1a1a20"))
	for i in 3:
		var zt := fposmod(_t * 0.35 + float(i) * 0.33, 1.0)
		var zp := hp + Vector2(18.0 + float(i) * 7.0 + zt * 8.0, -14.0 - zt * 24.0 - float(i) * 4.0)
		var za := (1.0 - zt) * 0.75
		draw_string(ThemeDB.fallback_font, zp, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 11 + i * 2, Color(0.85, 0.9, 0.95, za))
	# Quiet fireflies near nest
	for i in 4:
		var fx := c.x - 42.0 + fposmod(float(i) * 29.0 + _t * 12.0, 84.0)
		var fy := c.y - 34.0 + sin(_t * 1.4 + float(i) * 1.7) * 12.0 + float(i) * 3.0
		var pulse := 0.25 + 0.55 * absf(sin(_t * 2.2 + float(i)))
		draw_circle(Vector2(fx, fy), 1.8, Color(0.95, 0.82, 0.4, pulse * 0.65))


func _draw_eating_details(c: Vector2, face: float, u: float) -> void:
	# Chew feedback is primarily drawn in _draw_front / _draw_food_prop; keep helper for smoke/API.
	if u > 0.35 and u < 0.82 and _chew_puff > 0.05:
		var pulse := _chew_puff
		_ellipse(c + Vector2(-18.0 * face, 4.0), Vector2(8 + pulse * 2, 6), Color(0.94, 0.78, 0.68, 0.22 * pulse))
		_ellipse(c + Vector2(18.0 * face, 4.0), Vector2(8 + pulse * 2, 6), Color(0.94, 0.78, 0.68, 0.22 * pulse))


func _side_eye(p: Vector2, r: float, gleam: Color = Color("faf6ec")) -> void:
	var state := "sleep" if _is_sleeping() else ("sick" if _is_sick() else ("stubborn" if _is_stubborn() else ("happy" if _smile > 0.35 else "idle")))
	_draw_chibi_eye(p, r, gleam, state, 1.0)


func _draw_sick_marks(head: Vector2, side: bool = false) -> void:
	if not _is_sick():
		return
	var drop := Color(0.55, 0.77, 0.63, 0.9)
	if side:
		draw_circle(head + Vector2(-8, -14), 2.2, drop)
		draw_circle(head + Vector2(-4, -6), 1.5, Color(drop.r, drop.g, drop.b, 0.75))
		draw_line(head + Vector2(-1, 12), head + Vector2(4, 18), Color("5a4038"), 2.0)
		draw_line(head + Vector2(4, 18), head + Vector2(9, 12), Color("5a4038"), 2.0)
	else:
		draw_circle(head + Vector2(-22, -16), 2.4, drop)
		draw_circle(head + Vector2(-17, -6), 1.6, Color(drop.r, drop.g, drop.b, 0.75))
		draw_circle(head + Vector2(22, -14), 2.0, Color(drop.r, drop.g, drop.b, 0.8))
		draw_line(head + Vector2(-7, 18), head + Vector2(0, 24), Color("5a4038"), 2.2)
		draw_line(head + Vector2(0, 24), head + Vector2(7, 18), Color("5a4038"), 2.2)


func _draw_stubborn_marks(head: Vector2, side: bool = false) -> void:
	if not _is_stubborn():
		return
	if side:
		draw_line(head + Vector2(-10, -12), head + Vector2(4, -6), Color("2a2a32"), 2.2)
		draw_line(head + Vector2(-2, 12), head + Vector2(8, 12), Color("5a4038"), 2.0)
	else:
		draw_line(head + Vector2(-24, -14), head + Vector2(-10, -8), Color("2a2a32"), 2.4)
		draw_line(head + Vector2(24, -14), head + Vector2(10, -8), Color("2a2a32"), 2.4)
		draw_line(head + Vector2(-8, 18), head + Vector2(8, 18), Color("5a4038"), 2.2)


func _side_ear(p: Vector2, rx: float = 9.0, ry: float = 12.0) -> void:
	_ellipse_outlined(p, Vector2(rx, ry), Color("6a6a74"), OUTLINE, 2.0)
	_ellipse(p + Vector2(0, 1), Vector2(rx * 0.52, ry * 0.55), CREAM)
	for i in 3:
		var ox := -2.5 + float(i) * 2.5
		draw_line(p + Vector2(ox, -ry * 0.1), p + Vector2(ox * 0.5, ry * 0.18), Color("6a6a74"), 1.1)


func _extra_mid_leg(c: Vector2, face: float, hip_y: float, mid_x: float, leg_h: float, width: float, phase: float) -> void:
	_side_leg(c + Vector2(mid_x * face, hip_y), c + Vector2((mid_x - 3.0) * face, hip_y + leg_h * 0.92), width * 0.85, phase + 1.1, 2.8)
	_ellipse(c + Vector2((mid_x - 3.0) * face, hip_y + leg_h * 0.92), Vector2(6.0, 3.4), PAW_DARK)


func _form_wings(kind: String, c: Vector2, face: float, cy: float) -> void:
	match kind:
		"bat":
			var l := PackedVector2Array([
				c + Vector2(-10 * face, cy),
				c + Vector2(-44 * face, cy - 24),
				c + Vector2(-52 * face, cy + 4),
				c + Vector2(-14 * face, cy + 6),
			])
			draw_colored_polygon(l, Color(0.1, 0.1, 0.13, 0.88))
			var r := PackedVector2Array([
				c + Vector2(6 * face, cy - 2),
				c + Vector2(34 * face, cy - 22),
				c + Vector2(44 * face, cy),
				c + Vector2(10 * face, cy + 4),
			])
			draw_colored_polygon(r, Color(0.1, 0.1, 0.13, 0.7))
		"moth":
			_ellipse(c + Vector2(-26 * face, cy - 2), Vector2(24, 14), Color(0.16, 0.19, 0.28, 0.8))
			_ellipse(c + Vector2(20 * face, cy - 6), Vector2(18, 11), Color(0.16, 0.19, 0.28, 0.65))
			_ellipse(c + Vector2(-22 * face, cy - 2), Vector2(11, 5.5), Color(0.78, 0.85, 0.94, 0.22))
		"leaf":
			_ellipse(c + Vector2(-28 * face, cy), Vector2(20, 12), Color("6fbf84"))
			_ellipse(c + Vector2(22 * face, cy - 2), Vector2(17, 10), Color(0.33, 0.54, 0.38, 0.85))
		"ghost":
			var gl := PackedVector2Array([
				c + Vector2(-6 * face, cy),
				c + Vector2(-44 * face, cy - 28),
				c + Vector2(-52 * face, cy + 4),
				c + Vector2(-12 * face, cy + 4),
			])
			draw_colored_polygon(gl, Color(0.78, 0.86, 0.94, 0.45))
			var gr := PackedVector2Array([
				c + Vector2(4 * face, cy - 2),
				c + Vector2(38 * face, cy - 24),
				c + Vector2(50 * face, cy + 2),
				c + Vector2(8 * face, cy + 2),
			])
			draw_colored_polygon(gr, Color(0.78, 0.86, 0.94, 0.35))


func _trash_crown(kind: String, tip: Vector2, face: float = 1.0) -> void:
	match kind:
		"bottlecap":
			_ellipse(tip + Vector2(0, -2), Vector2(13, 4.5), Color("8a9aaa"))
			_ellipse(tip + Vector2(0, -6), Vector2(11, 3.4), Color("b8c4d0"))
			for ox in [-10.0, -3.0, 4.0, 10.0]:
				draw_line(tip + Vector2(ox, -5), tip + Vector2(ox * 1.1, -12), Color("6a7888"), 1.8)
		"tincan":
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-14, 0), tip + Vector2(-11, -14), tip + Vector2(11, -14), tip + Vector2(14, 0)
			]), Color("9a7a4a"))
			draw_rect(Rect2(tip + Vector2(-10, -12), Vector2(20, 3.5)), Color(0.77, 0.63, 0.42, 0.85))
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-8, -14), tip + Vector2(-5, -20), tip + Vector2(-2, -14)
			]), Color("b8925a"))
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(2, -14), tip + Vector2(5, -19), tip + Vector2(8, -14)
			]), Color("b8925a"))
		"gold":
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-16, 0), tip + Vector2(-13, -10), tip + Vector2(-5, -5),
				tip + Vector2(0, -18), tip + Vector2(5, -5), tip + Vector2(13, -10), tip + Vector2(16, 0)
			]), Color("e0a04a"))
			draw_circle(tip + Vector2(0, -7), 3.0, Color("fff3d0"))
			_ellipse(tip, Vector2(16, 3.2), Color(0.77, 0.52, 0.16, 0.55))
		"pizza":
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-15, 1), tip + Vector2(-11, -12), tip + Vector2(0, -6),
				tip + Vector2(11, -13), tip + Vector2(15, 1)
			]), Color("8a4a28"))
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-12, 0), tip + Vector2(-9, -9), tip + Vector2(0, -5),
				tip + Vector2(9, -10), tip + Vector2(12, 0)
			]), Color("e0a04a"))
			draw_circle(tip + Vector2(-4 * face, -4), 2.0, Color("8a2f2f"))
			draw_circle(tip + Vector2(4 * face, -5), 1.6, Color("8a2f2f"))


func _draw_side_raccoon(c: Vector2, face: float, body_rx: float, body_ry: float, body_y: float, head_x: float, head_r: float, leg_h: float, front_x: float, back_x: float, eye_r: float, gleam: Color, snout: Color, mask_c: Color, wing_kind: String = "", crown_kind: String = "", tuft: bool = false, leg_amp: float = 3.0, belly_boost: float = 0.0) -> void:
	## Shared round side silhouette — head overlaps body front; short tucked legs.
	var fur := _fur()
	var stroke_w := 3.2
	if wing_kind != "":
		_form_wings(wing_kind, c, face, body_y - 4.0)
	# Shadow under feet
	_ellipse(c + Vector2(0, body_y + body_ry * 0.72 + leg_h), Vector2(body_rx * 0.7, 6.0), Color(0, 0, 0, 0.22))
	# Ringed tail behind
	_ringed_tail(c + Vector2(-body_rx * 0.7 * face, body_y + 4), body_rx * 0.7, face, true)
	var phase := _walk_phase
	var hip := body_y + body_ry * 0.28
	_side_leg(c + Vector2(back_x * face, hip), c + Vector2((back_x - 2) * face, hip + leg_h), 5.2, phase, leg_amp)
	_side_leg(c + Vector2(front_x * face, hip), c + Vector2((front_x + 2) * face, hip + leg_h), 5.2, phase + 2.4, leg_amp)
	# Round body
	_ellipse_outlined(c + Vector2(0, body_y), Vector2(body_rx, body_ry), fur, OUTLINE, stroke_w)
	_ellipse(c + Vector2(4 * face, body_y + 6), Vector2(body_rx * (0.5 + belly_boost), body_ry * 0.48), Color(CREAM.r, CREAM.g, CREAM.b, 0.88))
	if tuft:
		for i in 4:
			var sx := -10.0 + float(i) * 7.0
			draw_line(c + Vector2(sx * face, body_y - body_ry + 2), c + Vector2((sx + 1.5) * face, body_y - body_ry - 9), fur.darkened(0.12), 2.4)
	# Overlapping round head on the front edge
	var hx := head_x * face
	var hy := body_y - body_ry * 0.15
	_ellipse_outlined(c + Vector2(hx, hy), Vector2(head_r, head_r * 0.95), fur.lightened(0.03), OUTLINE, stroke_w)
	_side_ear(c + Vector2((head_x - 4) * face, hy - head_r * 0.75), head_r * 0.32, head_r * 0.4)
	if crown_kind != "":
		_trash_crown(crown_kind, c + Vector2(hx, hy - head_r + 2), face)
	# Cream brow + dark mask + cream muzzle
	_ellipse(c + Vector2((head_x + 1) * face, hy - eye_r * 1.4), Vector2(eye_r * 0.9, eye_r * 0.45), CREAM)
	_ellipse(c + Vector2(hx, hy + 1), Vector2(head_r * 0.72, head_r * 0.48), mask_c)
	_ellipse(c + Vector2((head_x + head_r * 0.42) * face, hy + head_r * 0.2), Vector2(head_r * 0.42, head_r * 0.32), snout)
	var eye_p := c + Vector2((head_x + 3) * face, hy - 1)
	_side_eye(eye_p, eye_r, gleam)
	draw_circle(c + Vector2((head_x + head_r * 0.5) * face, hy + head_r * 0.12), 2.4, Color("1a1a20"))
	draw_circle(c + Vector2((head_x + head_r * 0.5) * face - 0.8 * face, hy + head_r * 0.08), 0.8, Color(1, 1, 1, 0.45))
	if _smile > 0.35:
		draw_arc(c + Vector2((head_x + head_r * 0.45) * face, hy + head_r * 0.35), 5.0, 0.3, PI - 0.3, 8, OUTLINE, 1.6, true)
	_draw_sick_marks(eye_p, true)
	_draw_stubborn_marks(eye_p, true)


func _draw_baby(c: Vector2, face: float) -> void:
	## Smallest round orb — oversized head, tiny tucked feet, stub tail.
	# Round short-spine baby side view.
	_draw_side_raccoon(
		c, face,
		42.0, 38.0, 16.0,
		18.0, 30.0,
		9.0, 12.0, -12.0,
		6.5, Color("faf6ec"), CREAM, MASK_DARK,
		"", "", false, 2.2, 0.08
	)


func _draw_young(c: Vector2, face: float) -> void:
	## Round short-spine young forms — accessories/colors differ, not body length.
	var body_rx := 50.0
	var body_ry := 46.0
	var leg_h := 10.0
	var leg_amp := 3.2
	var wing_kind := ""
	var crown_kind := ""
	var tuft := false
	var gleam := Color("faf6ec")
	var mask_c := MASK_DARK
	var snout := CREAM
	var belly := 0.05
	match young_form:
		"puff":
			body_rx = 58.0
			body_ry = 52.0
			leg_h = 8.0
			belly = 0.16
		"looper":
			leg_amp = 5.5
		"shadow":
			wing_kind = "bat"
			gleam = Color("e8f0ff")
			mask_c = Color("121218")
		"nub":
			body_rx = 48.0
			body_ry = 44.0
			crown_kind = "bottlecap"
			tuft = true
	_draw_side_raccoon(
		c, face,
		body_rx, body_ry, 12.0,
		20.0, 32.0,
		leg_h, 14.0, -14.0,
		7.0, gleam, snout, mask_c,
		wing_kind, crown_kind, tuft, leg_amp, belly
	)
	if young_form == "looper":
		draw_line(c + Vector2(-8 * face, 4), c + Vector2(14 * face, 2), Color("e0a04a"), 2.4)


func _draw_teen(c: Vector2, face: float) -> void:
	## Round teen orb — Bounder hops hard; Dumpling is widest; no tall legs.
	var form := teen_form if teen_form != "" else "bounder"
	var body_rx := 56.0
	var body_ry := 50.0
	var leg_h := 11.0
	var leg_amp := 3.4
	var wing_kind := ""
	var crown_kind := ""
	var tuft := false
	var gleam := Color("faf6ec")
	var mask_c := MASK_DARK
	var snout := CREAM
	var belly := 0.06
	match form:
		"dumpling":
			body_rx = 68.0
			body_ry = 62.0
			leg_h = 8.0
			belly = 0.18
		"bounder":
			leg_h = 12.0
			leg_amp = 6.0
		"nightlane":
			wing_kind = "moth"
			gleam = Color("d8e4f8")
			mask_c = Color("0e1018")
			snout = Color("d0d6e0")
		"scruff":
			crown_kind = "tincan"
			tuft = true
	_draw_side_raccoon(
		c, face,
		body_rx, body_ry, 10.0,
		22.0, 34.0,
		leg_h, 15.0, -16.0,
		7.4, gleam, snout, mask_c,
		wing_kind, crown_kind, tuft, leg_amp, belly
	)
	if form == "bounder":
		draw_line(c + Vector2(8 * face, -4), c + Vector2(16 * face, -12), Color("e0a04a"), 2.4)


func _draw_adult(c: Vector2, face: float) -> void:
	## Large round adult orb — form flair via wings/crowns/palette only.
	var body_rx := 66.0
	var body_ry := 60.0
	var leg_h := 12.0
	var leg_amp := 3.6
	var wing_kind := ""
	var crown_kind := ""
	var gleam := Color("faf6ec")
	var mask_c := MASK_DARK
	var snout := CREAM
	var belly := 0.08
	match adult_form:
		"saint":
			body_rx = 70.0
			body_ry = 64.0
			wing_kind = "leaf"
			belly = 0.12
		"legend":
			crown_kind = "gold"
			gleam = Color("fff3d0")
		"alley_ghost":
			body_rx = 70.0
			body_ry = 64.0
			wing_kind = "ghost"
			snout = Color("d8e2ee")
			gleam = Color("e8f0ff")
			mask_c = Color("3a4250")
		"ballard_blip":
			crown_kind = "pizza"
	_draw_side_raccoon(
		c, face,
		body_rx, body_ry, 6.0,
		24.0, 38.0,
		leg_h, 16.0, -18.0,
		8.0, gleam, snout, mask_c,
		wing_kind, crown_kind, false, leg_amp, belly
	)
	if adult_form == "legend":
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(8 * face, -8), c + Vector2(28 * face, 2), c + Vector2(10 * face, 8)
		]), Color("e0a04a"))
	elif adult_form == "ballard_blip":
		draw_line(c + Vector2(4 * face, 16), c + Vector2(26 * face, 16), Color("c45c4a"), 3.5)
		draw_arc(c + Vector2(28 * face, 8), 6.0, 0.2, PI - 0.2, 8, OUTLINE, 1.6, true)

