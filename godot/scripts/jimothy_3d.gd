extends Node3D
## Procedural 3D Jimothy mesh for Realistic graphic mode.

var stage: String = "baby"
var young_form: String = "puff"
var teen_form: String = ""
var adult_form: String = ""
var genes: Dictionary = {}
var mood: String = "idle"
var anim: String = "idle"
var anim_t: float = 0.0
var facing: float = 1.0
var pose_y: float = 0.0
var head_dip: float = 0.0
var body_squash: float = 1.0
var smile: float = 0.5
var walk_phase: float = 0.0
var wing_span: float = 0.0
var fade: float = 1.0
var sleeping: bool = false
var eat_food: String = ""

var _root: Node3D
var _body: MeshInstance3D
var _belly: MeshInstance3D
var _head: MeshInstance3D
var _mask: MeshInstance3D
var _snout: MeshInstance3D
var _ear_l: MeshInstance3D
var _ear_r: MeshInstance3D
var _eye_l: MeshInstance3D
var _eye_r: MeshInstance3D
var _pupil_l: MeshInstance3D
var _pupil_r: MeshInstance3D
var _nose: MeshInstance3D
var _leg_fl: MeshInstance3D
var _leg_fr: MeshInstance3D
var _leg_bl: MeshInstance3D
var _leg_br: MeshInstance3D
var _tail: Node3D
var _tail_segs: Array[MeshInstance3D] = []
var _food: MeshInstance3D
var _shadow: MeshInstance3D
var _blink_t: float = 0.0
var _built: bool = false


func _ready() -> void:
	_build()


func configure(data: Dictionary) -> void:
	stage = str(data.get("stage", stage))
	young_form = str(data.get("young_form", young_form))
	teen_form = str(data.get("teen_form", teen_form))
	adult_form = str(data.get("adult_form", adult_form))
	genes = data.get("genes", genes)
	mood = str(data.get("mood", mood))
	anim = str(data.get("anim", anim))
	anim_t = float(data.get("anim_t", anim_t))
	facing = float(data.get("facing", facing))
	pose_y = float(data.get("pose_y", pose_y))
	head_dip = float(data.get("head_dip", head_dip))
	body_squash = float(data.get("body_squash", body_squash))
	smile = float(data.get("smile", smile))
	walk_phase = float(data.get("walk_phase", walk_phase))
	wing_span = float(data.get("wing_span", wing_span))
	fade = float(data.get("fade", fade))
	sleeping = bool(data.get("sleeping", sleeping))
	eat_food = str(data.get("eat_food", eat_food))
	if _built:
		_apply_materials()
		_update_pose(0.0)


func _process(delta: float) -> void:
	if not _built:
		return
	_blink_t += delta
	_update_pose(delta)


func _build() -> void:
	_root = Node3D.new()
	_root.name = "JimothyRoot"
	add_child(_root)

	_shadow = _make_mesh(SphereMesh.new(), _mat(Color(0.02, 0.03, 0.02, 0.35), 1.0, 0.0))
	(_shadow.mesh as SphereMesh).radius = 0.42
	(_shadow.mesh as SphereMesh).height = 0.08
	_shadow.position = Vector3(0, 0.02, 0)
	_root.add_child(_shadow)

	_body = _make_mesh(_capsule(0.28, 0.55), null)
	_body.position = Vector3(0, 0.55, 0)
	_root.add_child(_body)

	_belly = _make_mesh(_sphere(0.22), null)
	_belly.position = Vector3(0, 0.48, 0.16)
	_belly.scale = Vector3(0.9, 0.85, 0.7)
	_root.add_child(_belly)

	_head = _make_mesh(_sphere(0.26), null)
	_head.position = Vector3(0, 0.98, 0.06)
	_root.add_child(_head)

	_mask = _make_mesh(_sphere(0.2), null)
	_mask.position = Vector3(0, 0.96, 0.14)
	_mask.scale = Vector3(1.05, 0.55, 0.55)
	_root.add_child(_mask)

	_snout = _make_mesh(_sphere(0.11), null)
	_snout.position = Vector3(0, 0.9, 0.28)
	_snout.scale = Vector3(0.85, 0.7, 1.0)
	_root.add_child(_snout)

	_nose = _make_mesh(_sphere(0.035), _mat(Color(0.12, 0.1, 0.12), 0.45, 0.15))
	_nose.position = Vector3(0, 0.92, 0.38)
	_root.add_child(_nose)

	_ear_l = _make_mesh(_sphere(0.09), null)
	_ear_l.position = Vector3(-0.16, 1.18, 0.0)
	_ear_l.scale = Vector3(0.7, 1.15, 0.55)
	_root.add_child(_ear_l)
	_ear_r = _make_mesh(_sphere(0.09), null)
	_ear_r.position = Vector3(0.16, 1.18, 0.0)
	_ear_r.scale = Vector3(0.7, 1.15, 0.55)
	_root.add_child(_ear_r)

	_eye_l = _make_mesh(_sphere(0.055), _mat(Color(0.95, 0.92, 0.75), 0.2, 0.4))
	_eye_l.position = Vector3(-0.09, 1.0, 0.26)
	_root.add_child(_eye_l)
	_eye_r = _make_mesh(_sphere(0.055), _mat(Color(0.95, 0.92, 0.75), 0.2, 0.4))
	_eye_r.position = Vector3(0.09, 1.0, 0.26)
	_root.add_child(_eye_r)

	_pupil_l = _make_mesh(_sphere(0.028), _mat(Color(0.05, 0.05, 0.07), 0.35, 0.2))
	_pupil_l.position = Vector3(-0.09, 1.0, 0.3)
	_root.add_child(_pupil_l)
	_pupil_r = _make_mesh(_sphere(0.028), _mat(Color(0.05, 0.05, 0.07), 0.35, 0.2))
	_pupil_r.position = Vector3(0.09, 1.0, 0.3)
	_root.add_child(_pupil_r)

	_leg_fl = _make_mesh(_capsule(0.055, 0.22), null)
	_leg_fr = _make_mesh(_capsule(0.055, 0.22), null)
	_leg_bl = _make_mesh(_capsule(0.055, 0.22), null)
	_leg_br = _make_mesh(_capsule(0.055, 0.22), null)
	for leg in [_leg_fl, _leg_fr, _leg_bl, _leg_br]:
		_root.add_child(leg)

	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.55, -0.22)
	_root.add_child(_tail)
	_tail_segs.clear()
	for i in 5:
		var seg := _make_mesh(_sphere(0.09 - i * 0.01), null)
		seg.position = Vector3(0, 0.02, -0.12 - i * 0.11)
		_tail.add_child(seg)
		_tail_segs.append(seg)

	_food = _make_mesh(_sphere(0.08), _mat(Color(0.55, 0.2, 0.35), 0.55, 0.1))
	_food.visible = false
	_root.add_child(_food)

	_built = true
	_apply_materials()
	_update_pose(0.0)


func _fur_color() -> Color:
	var g := float(genes.get("gray", 0.5))
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
	if mood == "sick":
		c = c.lerp(Color(0.47, 0.66, 0.43), 0.32)
	elif mood == "stubborn":
		c = c.lerp(Color(0.62, 0.38, 0.34), 0.22)
	return c


func _apply_materials() -> void:
	var fur := _fur_color()
	var belly := fur.lightened(0.28).lerp(Color(0.86, 0.8, 0.72), 0.35)
	var mask := Color(0.1, 0.1, 0.12)
	var paw := Color(0.22, 0.22, 0.26)
	_set_mesh_mat(_body, _mat(fur, 0.82, 0.08))
	_set_mesh_mat(_belly, _mat(belly, 0.78, 0.06))
	_set_mesh_mat(_head, _mat(fur.lightened(0.04), 0.8, 0.08))
	_set_mesh_mat(_mask, _mat(mask, 0.7, 0.05))
	_set_mesh_mat(_snout, _mat(belly, 0.75, 0.05))
	_set_mesh_mat(_ear_l, _mat(fur.darkened(0.08), 0.85, 0.05))
	_set_mesh_mat(_ear_r, _mat(fur.darkened(0.08), 0.85, 0.05))
	for leg in [_leg_fl, _leg_fr, _leg_bl, _leg_br]:
		_set_mesh_mat(leg, _mat(paw, 0.7, 0.08))
	for i in _tail_segs.size():
		var stripe := fur.darkened(0.35) if i % 2 == 1 else fur.lightened(0.05)
		_set_mesh_mat(_tail_segs[i], _mat(stripe, 0.8, 0.06))


func _update_pose(_delta: float) -> void:
	var scale_mul := 1.0
	match stage:
		"bush":
			visible = false
			return
		"baby":
			scale_mul = 0.72
		"young":
			scale_mul = 0.88
		"teen":
			scale_mul = 1.0
		_:
			scale_mul = 1.12
	visible = true
	_root.scale = Vector3(scale_mul * body_squash, scale_mul / maxf(0.55, body_squash), scale_mul)
	_root.position.y = pose_y * 0.012
	_root.rotation.y = 0.35 if facing >= 0.0 else -0.35
	if absf(facing) < 0.2:
		_root.rotation.y = 0.0

	var bob := sin(walk_phase) * 0.03
	_body.position = Vector3(0, 0.55 + bob, 0)
	_belly.position = Vector3(0, 0.48 + bob, 0.16)
	_head.position = Vector3(0, 0.98 + bob - head_dip * 0.01, 0.06)
	_mask.position = Vector3(0, 0.96 + bob - head_dip * 0.01, 0.14)
	_snout.position = Vector3(0, 0.9 + bob - head_dip * 0.01, 0.28)
	_nose.position = Vector3(0, 0.92 + bob - head_dip * 0.01, 0.38)
	_ear_l.position = Vector3(-0.16, 1.18 + bob - head_dip * 0.01, 0.0)
	_ear_r.position = Vector3(0.16, 1.18 + bob - head_dip * 0.01, 0.0)

	var step := sin(walk_phase) * 0.12
	_leg_fl.position = Vector3(-0.12, 0.22, 0.12 + step)
	_leg_fr.position = Vector3(0.12, 0.22, 0.12 - step)
	_leg_bl.position = Vector3(-0.12, 0.22, -0.1 - step)
	_leg_br.position = Vector3(0.12, 0.22, -0.1 + step)
	for leg in [_leg_fl, _leg_fr, _leg_bl, _leg_br]:
		leg.rotation.x = step * 0.8

	_tail.rotation.y = sin(walk_phase * 0.7) * 0.35
	_tail.rotation.x = -0.4 + sin(Time.get_ticks_msec() * 0.002) * 0.1

	var blink := 1.0
	if sleeping or anim in ["sleep", "doze"]:
		blink = 0.08
	elif fmod(_blink_t, 3.6) > 3.35:
		blink = 0.12
	_eye_l.scale = Vector3(1.0, blink, 1.0)
	_eye_r.scale = Vector3(1.0, blink, 1.0)
	_pupil_l.scale = Vector3(1.0, blink, 1.0)
	_pupil_r.scale = Vector3(1.0, blink, 1.0)
	_eye_l.position = Vector3(-0.09, 1.0 + bob - head_dip * 0.01, 0.26)
	_eye_r.position = Vector3(0.09, 1.0 + bob - head_dip * 0.01, 0.26)
	_pupil_l.position = Vector3(-0.09, 1.0 + bob - head_dip * 0.01, 0.3)
	_pupil_r.position = Vector3(0.09, 1.0 + bob - head_dip * 0.01, 0.3)

	var show_food := anim == "eat" and anim_t < 0.65
	_food.visible = show_food
	if show_food:
		_food.position = Vector3(0.18 * facing, 0.72 + bob, 0.32)
		match eat_food:
			"fish":
				_set_mesh_mat(_food, _mat(Color(0.55, 0.72, 0.8), 0.35, 0.25))
			"can":
				_set_mesh_mat(_food, _mat(Color(0.7, 0.75, 0.8), 0.25, 0.55))
			"pizza", "fries":
				_set_mesh_mat(_food, _mat(Color(0.88, 0.63, 0.29), 0.55, 0.1))
			_:
				_set_mesh_mat(_food, _mat(Color(0.55, 0.25, 0.55), 0.6, 0.08))

	modulate_fade(fade)


func modulate_fade(a: float) -> void:
	# MeshInstance3D has no modulate — fade via material albedo alpha when ascending.
	for child in _root.get_children():
		_fade_node(child, a)


func _fade_node(n: Node, a: float) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mat := mi.get_active_material(0)
		if mat is StandardMaterial3D:
			var sm := mat as StandardMaterial3D
			sm.albedo_color.a = a * (0.35 if mi == _shadow else 1.0)
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if a < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
	for c in n.get_children():
		_fade_node(c, a)


func _make_mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	return mi


func _set_mesh_mat(mi: MeshInstance3D, mat: Material) -> void:
	if mi:
		mi.material_override = mat


func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.4
	return m


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c
