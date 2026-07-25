extends Control
## Alley rummage mini-game — scraps fling out of the dumpster.

signal finished(score: int, stars: int, completed: bool)

const GOOD := [
	{"kind": "pizza", "points": 2, "color": Color("e0a04a")},
	{"kind": "can", "points": 3, "color": Color("a8c4d4")},
	{"kind": "berry", "points": 2, "color": Color("6b5aa0")},
	{"kind": "fries", "points": 1, "color": Color("f0c57a")},
	{"kind": "fish", "points": 3, "color": Color("8eb4c4")},
]
const BAD := {"kind": "rotten", "points": -2, "color": Color("5a6b3a")}

var running := false
var score := 0
var time_left := 22.0
var player_x := 180.0
var player_facing := 1.0
var walk_phase := 0.0
var items: Array = []
var fx: Array = []
var spawn_timer := 0.0
var dig_hold := 0.0
var lid_open := 0.0
var chew_t := 0.0
var _pointer_down := false
var dumpster := Rect2(60, 70, 240, 78)

@onready var score_label: Label = %ScoreLabel
@onready var time_label: Label = %TimeLabel
@onready var playfield: Control = %Playfield


func _ready() -> void:
	visible = false
	set_process(false)


func start_game() -> void:
	score = 0
	time_left = 22.0
	items.clear()
	fx.clear()
	spawn_timer = 0.2
	dig_hold = 0.0
	lid_open = 0.0
	chew_t = 0.0
	walk_phase = 0.0
	player_facing = 1.0
	player_x = playfield.size.x * 0.5 if playfield.size.x > 0 else 180.0
	_layout_dumpster()
	running = true
	visible = true
	set_process(true)
	_update_hud()
	playfield.queue_redraw()


func bail_out() -> void:
	_end(false)


func _layout_dumpster() -> void:
	var w := playfield.size.x if playfield.size.x > 0 else 360.0
	dumpster = Rect2(w * 0.18, 70.0, w * 0.64, 78.0)


func _end(completed: bool) -> void:
	if not running:
		return
	running = false
	set_process(false)
	visible = false
	var stars := 0
	if score >= 18:
		stars = 3
	elif score >= 10:
		stars = 2
	elif score >= 4:
		stars = 1
	finished.emit(score, stars, completed)


func _under_dumpster() -> bool:
	return absf(player_x - dumpster.get_center().x) < dumpster.size.x * 0.28


func _spawn_item(forced_good: bool = false) -> void:
	var proto: Dictionary = BAD if (not forced_good and randf() < 0.26) else GOOD[randi() % GOOD.size()]
	var mouth_x := dumpster.position.x + dumpster.size.x * randf_range(0.28, 0.72)
	var mouth_y := dumpster.position.y + 18.0
	var outward := -1.0 if mouth_x < playfield.size.x * 0.5 else 1.0
	var vx := randf_range(40.0, 110.0) * (-outward if randf() < 0.5 else outward * 0.35)
	items.append({
		"kind": proto.kind,
		"points": proto.points,
		"color": proto.color,
		"x": mouth_x,
		"y": mouth_y,
		"r": 13.0 + randf() * 4.0,
		"vx": vx,
		"vy": -(160.0 + randf() * 90.0),
		"rot": randf() * TAU,
		"spin": randf_range(-6.0, 6.0),
	})
	lid_open = 1.0
	if JimothyAudio:
		JimothyAudio.play("rustle", -8.0)


func _add_fx(kind: String, x: float, y: float, text: String = "") -> void:
	fx.append({"kind": kind, "x": x, "y": y, "text": text, "t": 0.0, "life": 0.7})


func _process(delta: float) -> void:
	if not running:
		return
	_layout_dumpster()
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_update_hud()
		_end(true)
		return

	lid_open = maxf(0.0, lid_open - delta * 1.6)
	chew_t = maxf(0.0, chew_t - delta)

	spawn_timer += delta
	var interval := maxf(0.38, 0.85 - mini(score, 20) * 0.015)
	if spawn_timer >= interval:
		spawn_timer = 0.0
		_spawn_item(false)

	var move := Input.get_axis("ui_left", "ui_right")
	if absf(move) > 0.01:
		player_x += move * 240.0 * delta
		player_facing = signf(move)
		walk_phase += delta * 12.0
		dig_hold = 0.0
	elif _under_dumpster():
		dig_hold += delta
		walk_phase += delta * 4.0
		if dig_hold >= 0.55:
			dig_hold = 0.0
			_spawn_item(true)
			_add_fx("label", player_x, playfield.size.y - 90.0, "DIG!")
			if JimothyAudio:
				JimothyAudio.play("chitter", -6.0)
	else:
		dig_hold = maxf(0.0, dig_hold - delta)
		walk_phase += delta * 2.0

	player_x = clampf(player_x, 26.0, maxf(26.0, playfield.size.x - 26.0))

	var gravity := 420.0
	var ground := playfield.size.y - 54.0
	var keep: Array = []
	for item in items:
		item.vy = float(item.vy) + gravity * delta
		item.x = float(item.x) + float(item.vx) * delta
		item.y = float(item.y) + float(item.vy) * delta
		item.rot = float(item.rot) + float(item.spin) * delta
		if float(item.x) < 16.0 or float(item.x) > playfield.size.x - 16.0:
			item.vx = float(item.vx) * -0.55
			item.x = clampf(float(item.x), 16.0, playfield.size.x - 16.0)

		var near_x: bool = absf(float(item.x) - player_x) < 28.0
		var near_y: bool = float(item.y) > ground - 34.0 and float(item.y) < ground + 12.0
		if near_x and near_y:
			score = maxi(0, score + int(item.points))
			chew_t = 0.35
			if int(item.points) < 0:
				_add_fx("splat", float(item.x), float(item.y))
				_add_fx("label", float(item.x), float(item.y) - 12.0, str(item.points))
				if JimothyAudio:
					JimothyAudio.play("grumble", -4.0)
			else:
				_add_fx("crumb", float(item.x), float(item.y))
				_add_fx("label", float(item.x), float(item.y) - 14.0, "+%d" % int(item.points))
				if JimothyAudio:
					JimothyAudio.play("crunch", -5.0)
			_update_hud()
		elif float(item.y) >= ground + 6.0 and float(item.vy) > 0.0:
			if str(item.kind) == "rotten":
				_add_fx("splat", float(item.x), ground)
			else:
				_add_fx("litter", float(item.x), ground)
		elif float(item.y) <= playfield.size.y + 40.0:
			keep.append(item)
	items = keep

	var keep_fx: Array = []
	for f in fx:
		f.t = float(f.t) + delta
		f.y = float(f.y) - 18.0 * delta
		if float(f.t) < float(f.life):
			keep_fx.append(f)
	fx = keep_fx

	_update_hud()
	playfield.queue_redraw()


func _update_hud() -> void:
	score_label.text = "Score %d" % score
	time_label.text = "Time %ds" % int(ceil(time_left))


func _on_playfield_gui_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		_pointer_down = event.pressed
		if event.pressed:
			var prev := player_x
			player_x = clampf(event.position.x, 26.0, playfield.size.x - 26.0)
			if absf(player_x - prev) > 0.5:
				player_facing = signf(player_x - prev)
	elif event is InputEventScreenDrag:
		var prev2 := player_x
		player_x = clampf(event.position.x, 26.0, playfield.size.x - 26.0)
		player_facing = signf(player_x - prev2) if absf(player_x - prev2) > 0.2 else player_facing
	elif event is InputEventMouseButton:
		_pointer_down = event.pressed
		if event.pressed:
			player_x = clampf(event.position.x, 26.0, playfield.size.x - 26.0)
	elif event is InputEventMouseMotion and _pointer_down:
		var prev3 := player_x
		player_x = clampf(event.position.x, 26.0, playfield.size.x - 26.0)
		if absf(player_x - prev3) > 0.2:
			player_facing = signf(player_x - prev3)


func _on_playfield_draw() -> void:
	var pf := playfield
	var w := pf.size.x
	var h := pf.size.y
	pf.draw_rect(Rect2(Vector2.ZERO, pf.size), Color("101a14"))
	# Brick hints
	for y in range(100, int(h - 70), 26):
		pf.draw_line(Vector2(0, y), Vector2(w, y), Color(0.6, 0.67, 0.61, 0.1), 1.0)
	# Ground
	pf.draw_rect(Rect2(0, h - 48, w, 48), Color("1a281e"))
	pf.draw_rect(Rect2(0, h - 48, w, 3), Color(0.88, 0.63, 0.29, 0.12))
	for i in 8:
		_draw_ellipse(pf, Vector2(30 + i * 42, h - 38 + (i % 3)), Vector2(10, 4), Color(0.24, 0.19, 0.12, 0.35))

	_draw_dumpster(pf)

	if _under_dumpster() and dig_hold > 0.0:
		pf.draw_rect(Rect2(dumpster.position.x + 20, dumpster.position.y - 4, (dumpster.size.x - 40) * minf(1.0, dig_hold / 0.55), 3), Color(0.44, 0.75, 0.51, 0.5))
		pf.draw_rect(Rect2(dumpster.get_center().x - 18, dumpster.position.y - 14, 36, 8), Color(0.94, 0.77, 0.48, 0.35))

	for item in items:
		_draw_item(pf, item)
	for f in fx:
		_draw_fx(pf, f)

	_draw_player(pf, Vector2(player_x, h - 58))


func _draw_dumpster(pf: Control) -> void:
	var r := dumpster
	_draw_ellipse(pf, Vector2(r.get_center().x, r.end.y + 8), Vector2(r.size.x * 0.45, 10), Color(0, 0, 0, 0.25))
	pf.draw_rect(Rect2(r.position + Vector2(0, 16), Vector2(r.size.x, r.size.y - 10)), Color("3d6b4f"), true, -1.0, true)
	pf.draw_rect(Rect2(r.position + Vector2(8, 28), Vector2(r.size.x - 16, r.size.y - 30)), Color("2a4a38"), true, -1.0, true)
	pf.draw_rect(Rect2(r.position + Vector2(14, 22), Vector2(r.size.x - 30, 28)), Color("142019"), true, -1.0, true)
	# Lid (tilted when open)
	var lid_y := r.position.y + 4.0 - lid_open * 18.0
	pf.draw_rect(Rect2(r.position.x + 10, lid_y, r.size.x - 20, 18), Color("2f5540"), true, -1.0, true)
	pf.draw_circle(Vector2(r.position.x + 22, r.end.y + 2), 7, Color("1c1c22"))
	pf.draw_circle(Vector2(r.end.x - 22, r.end.y + 2), 7, Color("1c1c22"))


func _draw_item(pf: Control, item: Dictionary) -> void:
	var p := Vector2(item.x, item.y)
	var col: Color = item.color
	match str(item.kind):
		"rotten":
			_draw_ellipse(pf, p, Vector2(item.r, item.r * 0.75), col)
		"can":
			pf.draw_rect(Rect2(p.x - 10, p.y - 12, 20, 24), col, true, -1.0, true)
		"berry":
			_draw_ellipse(pf, p + Vector2(-4, 0), Vector2(7, 7), col)
			_draw_ellipse(pf, p + Vector2(5, -2), Vector2(7, 7), col)
		"fries":
			pf.draw_rect(Rect2(p.x - 10, p.y, 20, 14), Color("c45c4a"), true, -1.0, true)
			pf.draw_rect(Rect2(p.x - 7, p.y - 10, 3, 14), col)
			pf.draw_rect(Rect2(p.x - 1, p.y - 12, 3, 16), col)
		"fish":
			_draw_ellipse(pf, p, Vector2(12, 5), col)
			var fin := PackedVector2Array([p + Vector2(10, 0), p + Vector2(16, -5), p + Vector2(16, 5)])
			pf.draw_colored_polygon(fin, col)
		_:
			var tri := PackedVector2Array([p + Vector2(0, -12), p + Vector2(12, 10), p + Vector2(-12, 10)])
			pf.draw_colored_polygon(tri, col)


func _draw_fx(pf: Control, f: Dictionary) -> void:
	var a := 1.0 - float(f.t) / float(f.life)
	var p := Vector2(f.x, f.y)
	match str(f.kind):
		"label":
			# Tiny score pip (no font dependency)
			_draw_ellipse(pf, p, Vector2(8, 5), Color(0.94, 0.77, 0.48, a))
		"splat":
			_draw_ellipse(pf, p, Vector2(14 * (1.0 + float(f.t)), 6), Color(0.35, 0.42, 0.23, 0.55 * a))
		_:
			_draw_ellipse(pf, p + Vector2(-3, 0), Vector2(2.5, 2.5), Color(0.88, 0.63, 0.29, 0.45 * a))
			_draw_ellipse(pf, p + Vector2(3, 1), Vector2(2, 2), Color(0.88, 0.63, 0.29, 0.45 * a))


func _draw_player(pf: Control, pos: Vector2) -> void:
	var kick := sin(walk_phase) * (1.0 if chew_t > 0.0 else 3.5)
	var bob := sin(walk_phase) * 2.0 if chew_t <= 0.0 else sin(Time.get_ticks_msec() * 0.04) * 2.0
	var face := player_facing if player_facing != 0.0 else 1.0
	var p := pos + Vector2(0, bob)
	# Legs with walk kick (mirrored by facing via x scale of offsets)
	pf.draw_line(p + Vector2(-12 * face, 0), p + Vector2(-18 * face, 16 + kick), Color("4f4f58"), 5.0)
	pf.draw_line(p + Vector2(-4 * face, 2), p + Vector2(-6 * face, 18 - kick), Color("4f4f58"), 5.0)
	pf.draw_line(p + Vector2(4 * face, 2), p + Vector2(6 * face, 18 + kick * 0.8), Color("4f4f58"), 5.0)
	pf.draw_line(p + Vector2(12 * face, 0), p + Vector2(18 * face, 16 - kick * 0.8), Color("4f4f58"), 5.0)
	var body_y := -4.0 + (2.0 if chew_t > 0.0 else 0.0)
	_draw_ellipse(pf, p + Vector2(0, body_y), Vector2(20, 17), Color("6a6a74"))
	_draw_ellipse(pf, p + Vector2(0, -6), Vector2(14, 8), Color("1c1c22"))
	pf.draw_circle(p + Vector2(-5, -7), 2.6, Color("f7f3e8"))
	pf.draw_circle(p + Vector2(5, -7), 2.6, Color("f7f3e8"))
	pf.draw_circle(p + Vector2(-4.5, -6.5), 1.2, Color("121214"))
	pf.draw_circle(p + Vector2(5.5, -6.5), 1.2, Color("121214"))
	if chew_t > 0.0:
		pf.draw_circle(p + Vector2(8 * face, 2), 3.0, Color(0.88, 0.63, 0.29, 0.75))


func _draw_ellipse(pf: Control, center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	pf.draw_colored_polygon(pts, color)
