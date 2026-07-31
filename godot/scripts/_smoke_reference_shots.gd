extends Node
## Capture Jimothy poses for visual comparison against the raccoon reference.


func _ready() -> void:
	# Avoid depending on autoload process loops for static shots.
	call_deferred("_run")


func _capture(vp: SubViewport) -> Image:
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	await get_tree().process_frame
	return vp.get_texture().get_image()


func _run() -> void:
	var out_dir := "/opt/cursor/artifacts/jimothy-visual-check"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var Raccoon = load("res://scripts/raccoon_view.gd")

	var probe = Raccoon.new()
	for s in [0.08, 0.12, 0.55, 0.84, 1.0, 1.15, 2.0]:
		var xy: Vector2 = probe._mascot_squash_xy(s)
		if xy.x < 0.72 or xy.x > 1.22 or xy.y < 0.72 or xy.y > 1.22:
			print("SQUASH FAIL for ", s, " -> ", xy)
			get_tree().quit(1)
			return
	probe.free()

	var cases := [
		["baby_front_idle", "baby", "", "idle", false],
		["baby_front_smile", "baby", "", "idle", false],
		["baby_side_walk", "baby", "", "walk", true],
		["baby_eat_fries", "baby", "", "eat", false],
		["baby_sleep", "baby", "", "sleep", false],
		["young_puff_front", "young", "puff", "idle", false],
		["teen_bounder_side", "teen", "bounder", "walk", true],
		["adult_legend_front", "adult", "legend", "idle", false],
		["stage_up_mid", "young", "looper", "stageUp", false],
	]

	for case in cases:
		var host := Node2D.new()
		add_child(host)
		var vp := SubViewport.new()
		vp.size = Vector2i(420, 420)
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		host.add_child(vp)
		var bg := ColorRect.new()
		bg.color = Color("1f3d2e")
		bg.size = Vector2(420, 420)
		vp.add_child(bg)
		var r = Raccoon.new()
		vp.add_child(r)
		r.set_process(false)
		r.preview_mode = true
		r.avatar_mode = false
		r.position = Vector2.ZERO
		r.size = Vector2(420, 420)
		r.custom_minimum_size = Vector2(420, 420)
		r.stage = str(case[1])
		r.young_form = "puff"
		r.teen_form = "bounder"
		r.adult_form = "saint"
		match str(case[1]):
			"young":
				r.young_form = str(case[2]) if str(case[2]) != "" else "puff"
			"teen":
				r.teen_form = str(case[2]) if str(case[2]) != "" else "bounder"
			"adult":
				r.adult_form = str(case[2]) if str(case[2]) != "" else "saint"
		r.mood = "idle"
		r._anim = "idle"
		r._pose_x = 0.0
		r._pose_y = 0.0
		r._head_dip = 0.0
		r._body_squash = 1.0
		r._fade = 1.0
		r.modulate = Color(1, 1, 1, 1)
		r.scale = Vector2.ONE
		if bool(case[4]):
			r._anim = "walk"
			r._facing = 1.0
			r._walk_phase = 1.2
		if str(case[0]).find("smile") >= 0:
			r._smile = 1.0
			r._anim = "idle"
		if str(case[3]) == "eat":
			r._eat_food = "fries"
			r._paw_lift = 0.95
			r._mouth_open = 0.75
			r._bite_progress = 0.45
			r._chew_puff = 0.7
			r._anim = "eat"
			r._anim_t = 1.8
			r._anim_dur = 3.2
		if str(case[3]) == "sleep":
			r.mood = "sleep"
			r._anim = "sleep"
		if str(case[3]) == "stageUp":
			r._anim = "stageUp"
			r._anim_dur = 2.8
			r._anim_t = 0.95
			r._body_squash = 0.84
			r._fade = 0.55
			r.modulate = Color(1, 1, 1, 0.55)
		r.queue_redraw()
		var img: Image = await _capture(vp)
		var path := "%s/%s.png" % [out_dir, str(case[0])]
		img.save_png(path)
		print("SHOT: ", path, " ", img.get_width(), "x", img.get_height())
		host.queue_free()
		await get_tree().process_frame

	print("SHOTS OK: reference comparison frames written")
	get_tree().quit(0)
