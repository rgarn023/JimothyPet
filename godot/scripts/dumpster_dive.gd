extends Control
## Raccoon-themed catch mini-game.

signal finished(score: int, stars: int, completed: bool)

const GOOD := [
	{"kind": "pizza", "points": 2, "color": Color("e0a04a")},
	{"kind": "can", "points": 3, "color": Color("a8c4d4")},
	{"kind": "berry", "points": 2, "color": Color("6b5aa0")},
	{"kind": "fries", "points": 1, "color": Color("f0c57a")},
]
const BAD := {"kind": "rotten", "points": -2, "color": Color("5a6b3a")}

var running := false
var score := 0
var time_left := 20.0
var player_x := 180.0
var items: Array = []
var spawn_timer := 0.0
var _pointer_down := false

@onready var score_label: Label = %ScoreLabel
@onready var time_label: Label = %TimeLabel
@onready var playfield: Control = %Playfield


func _ready() -> void:
	visible = false
	set_process(false)


func start_game() -> void:
	score = 0
	time_left = 20.0
	items.clear()
	spawn_timer = 0.0
	player_x = playfield.size.x * 0.5 if playfield.size.x > 0 else 180.0
	running = true
	visible = true
	set_process(true)
	_update_hud()
	playfield.queue_redraw()


func bail_out() -> void:
	_end(false)


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


func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_update_hud()
		_end(true)
		return

	var move := Input.get_axis("ui_left", "ui_right")
	player_x += move * 260.0 * delta
	player_x = clampf(player_x, 26.0, maxf(26.0, playfield.size.x - 26.0))

	spawn_timer += delta
	var interval := maxf(0.3, 0.55 - mini(score, 20) * 0.008)
	if spawn_timer >= interval:
		spawn_timer = 0.0
		_spawn_item()

	var ground := playfield.size.y - 54.0
	var keep: Array = []
	for item in items:
		var iy := float(item.y) + float(item.vy) * delta
		item.y = iy
		var near_x: bool = absf(float(item.x) - player_x) < 28.0
		var near_y: bool = iy > ground - 28.0 and iy < ground + 10.0
		if near_x and near_y:
			score = maxi(0, score + int(item.points))
			_update_hud()
		elif iy <= playfield.size.y + 30.0:
			keep.append(item)
	items = keep
	_update_hud()
	playfield.queue_redraw()


func _spawn_item() -> void:
	var proto: Dictionary = BAD if randf() < 0.28 else GOOD[randi() % GOOD.size()]
	items.append({
		"kind": proto.kind,
		"points": proto.points,
		"color": proto.color,
		"x": 24.0 + randf() * maxf(1.0, playfield.size.x - 48.0),
		"y": -20.0,
		"r": 14.0 + randf() * 4.0,
		"vy": 140.0 + randf() * 90.0 + mini(score * 2, 80),
	})


func _update_hud() -> void:
	score_label.text = "Score %d" % score
	time_label.text = "Time %ds" % int(ceil(time_left))


func _on_playfield_gui_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		_pointer_down = event.pressed
		if event.pressed:
			player_x = clampf(event.position.x, 26.0, playfield.size.x - 26.0)
	elif event is InputEventScreenDrag:
		player_x = clampf(event.position.x, 26.0, playfield.size.x - 26.0)
	elif event is InputEventMouseButton:
		_pointer_down = event.pressed
		if event.pressed:
			player_x = clampf(event.position.x, 26.0, playfield.size.x - 26.0)
	elif event is InputEventMouseMotion and _pointer_down:
		player_x = clampf(event.position.x, 26.0, playfield.size.x - 26.0)


func _on_playfield_draw() -> void:
	var pf := playfield
	var w := pf.size.x
	var h := pf.size.y
	pf.draw_rect(Rect2(Vector2.ZERO, pf.size), Color("0c1410"))
	# dumpster
	pf.draw_rect(Rect2(40, 36, w - 80, 54), Color("3d6b4f"), true, -1.0, true)
	pf.draw_rect(Rect2(48, 24, w - 96, 20), Color("2f5540"), true, -1.0, true)
	pf.draw_rect(Rect2(0, h - 48, w, 48), Color("1a281e"))
	pf.draw_rect(Rect2(0, h - 48, w, 3), Color(0.88, 0.63, 0.29, 0.15))

	for item in items:
		_draw_item(pf, item)

	_draw_player(pf, Vector2(player_x, h - 58))


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
		_:
			var tri := PackedVector2Array([p + Vector2(0, -12), p + Vector2(12, 10), p + Vector2(-12, 10)])
			pf.draw_colored_polygon(tri, col)


func _draw_player(pf: Control, pos: Vector2) -> void:
	# Short-spine Jimothy
	pf.draw_line(pos + Vector2(-12, 0), pos + Vector2(-18, 16), Color("4f4f58"), 5.0)
	pf.draw_line(pos + Vector2(-4, 2), pos + Vector2(-6, 18), Color("4f4f58"), 5.0)
	pf.draw_line(pos + Vector2(4, 2), pos + Vector2(6, 18), Color("4f4f58"), 5.0)
	pf.draw_line(pos + Vector2(12, 0), pos + Vector2(18, 16), Color("4f4f58"), 5.0)
	_draw_ellipse(pf, pos + Vector2(0, -4), Vector2(20, 17), Color("6a6a74"))
	_draw_ellipse(pf, pos + Vector2(0, -6), Vector2(14, 8), Color("1c1c22"))
	pf.draw_circle(pos + Vector2(-5, -7), 2.6, Color("f7f3e8"))
	pf.draw_circle(pos + Vector2(5, -7), 2.6, Color("f7f3e8"))
	pf.draw_circle(pos + Vector2(-4.5, -6.5), 1.2, Color("121214"))
	pf.draw_circle(pos + Vector2(5.5, -6.5), 1.2, Color("121214"))


func _draw_ellipse(pf: Control, center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	pf.draw_colored_polygon(pts, color)
