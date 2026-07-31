extends Node
## Headless smoke checks for visual-detail polish. Exits non-zero on failure.


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	await _check_scripts(failures)
	await _check_food_effects(failures)
	await _check_dice(failures)
	_check_dumpster(failures)
	await _check_raccoon(failures)
	await _check_forest(failures)
	_check_main_feed_helpers(failures)
	await _check_feed_full_and_accept(failures)
	await _check_minigame_open_close(failures)
	if failures.size() > 0:
		for f in failures:
			push_error("SMOKE FAIL: " + f)
			print("SMOKE FAIL: ", f)
		get_tree().quit(1)
	else:
		print("SMOKE OK: all visual-detail checks passed")
		get_tree().quit(0)


func _check_scripts(failures: PackedStringArray) -> void:
	var paths := [
		"res://scripts/dumpster_dive.gd",
		"res://scripts/dice_high_low.gd",
		"res://scripts/raccoon_view.gd",
		"res://scripts/main.gd",
		"res://scripts/visual_polish.gd",
		"res://scripts/forest_bg.gd",
	]
	for p in paths:
		var scr = load(p)
		if scr == null:
			failures.append("failed to load " + p)
	await get_tree().process_frame


func _check_food_effects(failures: PackedStringArray) -> void:
	var expected := {
		"berries": {"hunger": 18, "happy": 3, "health": 6, "fitness": 0},
		"crickets": {"hunger": 16, "happy": 2, "health": 5, "fitness": 1},
		"fish": {"hunger": 24, "happy": 4, "health": 8, "fitness": 1},
		"pizza": {"hunger": 10, "happy": 16, "health": -3, "fitness": -1},
		"fries": {"hunger": 9, "happy": 18, "health": -4, "fitness": -1},
	}
	for k in expected.keys():
		if not PetState.FOOD.has(k):
			failures.append("missing food key " + str(k))
			continue
		var f: Dictionary = PetState.FOOD[k]
		var e: Dictionary = expected[k]
		for field in e.keys():
			if int(f[field]) != int(e[field]):
				failures.append("food effect changed for %s.%s: got %s want %s" % [str(k), str(field), str(f[field]), str(e[field])])
		var line: String = _effect_line(str(k))
		if line.length() < 8 or not line.contains("H"):
			failures.append("food_effect_line bad for " + str(k) + ": " + line)
	await get_tree().process_frame


func _effect_line(food_key: String) -> String:
	const VP = preload("res://scripts/visual_polish.gd")
	return VP.food_effect_line(food_key)


func _check_dice(failures: PackedStringArray) -> void:
	var Dice = load("res://scripts/dice_high_low.gd")
	var d = Dice.new()
	add_child(d)
	await get_tree().process_frame
	d.start_game()
	if d._call_label == null:
		failures.append("dice missing _call_label")
	elif d._call_label.text != "Awaiting your call":
		failures.append("dice call label reset text wrong: " + d._call_label.text)
	if d._result_chip == null:
		failures.append("dice missing _result_chip")
	# Open/close
	if not d.visible:
		failures.append("dice start_game did not show UI")
	d._pick("low")
	d._result = 4
	var face_i: int = d.FACE_NUMS.find(d._result)
	d._target_rot = d._rotation_for_face(face_i if face_i >= 0 else 0)
	d._finish()
	if not d._correct:
		failures.append("dice correct low call not marked correct")
	if not d._result_chip.visible or not str(d._result_chip.text).begins_with("CORRECT"):
		failures.append("dice result chip not showing CORRECT: " + str(d._result_chip.text))
	if not str(d._call_label.text).contains("LOW"):
		failures.append("dice call label missing LOW: " + d._call_label.text)
	d._on_again()
	d._pick("high")
	d._result = 3
	face_i = d.FACE_NUMS.find(d._result)
	d._target_rot = d._rotation_for_face(face_i if face_i >= 0 else 0)
	d._finish()
	if d._correct:
		failures.append("dice incorrect high call marked correct")
	if not str(d._result_chip.text).begins_with("MISSED"):
		failures.append("dice result chip not showing MISSED: " + str(d._result_chip.text))
	d._on_done()
	if d.visible:
		failures.append("dice Done did not close UI")
	d.queue_free()
	await get_tree().process_frame


func _check_dumpster(failures: PackedStringArray) -> void:
	var src := FileAccess.get_file_as_string("res://scripts/dumpster_dive.gd")
	for must in ["_draw_alley", "_draw_dumpster", "VisualPolish.draw_vignette", "catch_streak", "_steam", "DIG!", "YUCK", "NICE", "Drainpipe", "Warning label"]:
		if src.find(must) < 0:
			failures.append("dumpster missing feature marker: " + must)
	if src.find("score >= 18") < 0 or src.find("score >= 10") < 0 or src.find("score >= 4") < 0:
		failures.append("dumpster star thresholds changed")
	if src.find("time_left = 22.0") < 0:
		failures.append("dumpster timer changed")


func _check_raccoon(failures: PackedStringArray) -> void:
	var src := FileAccess.get_file_as_string("res://scripts/raccoon_view.gd")
	for must in ["_draw_chibi_eye", "_draw_eating_details", "_draw_nest_bed", "_draw_sleeping", "_paw_lift", "VisualPolish.draw_food", "fireflies", "breath"]:
		if src.find(must) < 0:
			failures.append("raccoon missing: " + must)
	var Raccoon = load("res://scripts/raccoon_view.gd")
	var r = Raccoon.new()
	add_child(r)
	await get_tree().process_frame
	r.custom_minimum_size = Vector2(200, 200)
	r.size = Vector2(200, 200)
	r.play_anim("eat")
	if r._anim != "eat":
		failures.append("eat anim did not start")
	# Exercise all five food keys visually
	for food_key in ["berries", "crickets", "fish", "pizza", "fries"]:
		r.play_anim("eat")
		r._eat_food = food_key
		r.queue_redraw()
		await get_tree().process_frame
	r.mood = "sleep"
	r.play_anim("sleep")
	r.queue_redraw()
	await get_tree().process_frame
	r.queue_free()
	await get_tree().process_frame


func _check_forest(failures: PackedStringArray) -> void:
	var Forest = load("res://scripts/forest_bg.gd")
	var f = Forest.new()
	add_child(f)
	f.size = Vector2(420, 860)
	await get_tree().process_frame
	f.queue_redraw()
	await get_tree().process_frame
	if not f.has_method("_draw_sky") or not f.has_method("_draw_tree_layers"):
		failures.append("forest missing layered draw helpers")
	f.queue_free()
	await get_tree().process_frame


func _check_main_feed_helpers(failures: PackedStringArray) -> void:
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	if src.find("food_effect_line") < 0:
		failures.append("main missing food_effect_line wiring")
	if src.find("_refresh_feed_menu_effects") < 0:
		failures.append("main missing feed menu effect refresh")


func _check_feed_full_and_accept(failures: PackedStringArray) -> void:
	PetState.alive = true
	PetState.stage = "young"
	PetState.hunger = 40.0
	PetState.satiety = 0.0
	PetState.happy = 50.0
	PetState.health = 70.0
	PetState.fitness = 40.0
	PetState.stubborn = false
	var fed := str(PetState.try_feed("fish"))
	if fed == "full":
		failures.append("unexpected full when satiety 0")
	elif fed == "refused":
		print("SMOKE NOTE: fish refused once (RNG/stubborn); trying berries")
		PetState.stubborn = false
		fed = str(PetState.try_feed("berries"))
	print("SMOKE NOTE: accepted feed result=", fed)
	if fed == "refused" or fed == "full" or fed == "":
		# Force a treat accept path (low refuse chance) for coverage
		PetState.satiety = 0.0
		PetState.stubborn = false
		fed = str(PetState.try_feed("pizza"))
		print("SMOKE NOTE: pizza feed result=", fed)
	PetState.satiety = 100.0
	PetState.hunger = 100.0
	var full_res := str(PetState.try_feed("fries"))
	if full_res != "full" and full_res != "refused":
		failures.append("stuffed pet did not full/refuse, got: " + full_res)
	else:
		print("SMOKE NOTE: stuffed response=", full_res)
	await get_tree().process_frame


func _check_minigame_open_close(failures: PackedStringArray) -> void:
	# DumpsterDive needs scene tree labels; load main scene lightly if available.
	var main_packed := load("res://scenes/main.tscn")
	if main_packed == null:
		failures.append("main.tscn missing")
		return
	var main = main_packed.instantiate()
	add_child(main)
	await get_tree().process_frame
	# Feed / Play panels
	if main.has_method("_on_feed_pressed"):
		main._on_feed_pressed()
		await get_tree().process_frame
		if main.feed_panel and not main.feed_panel.visible:
			failures.append("Feed panel did not open")
		if main.has_method("_on_feed_close"):
			main._on_feed_close()
			await get_tree().process_frame
			if main.feed_panel and main.feed_panel.visible:
				failures.append("Feed panel did not close")
	if main.has_method("_on_play_pressed"):
		# Play is disabled on bush/baby — temporarily unlock for UI smoke only.
		var old_stage := str(PetState.stage)
		var old_energy := float(PetState.energy)
		var old_stubborn := bool(PetState.stubborn)
		PetState.stage = "young"
		PetState.young_form = "puff"
		PetState.energy = maxf(PetState.energy, 40.0)
		PetState.stubborn = false
		PetState.discipline = maxf(PetState.discipline, 80.0)
		if main.btn_play:
			main.btn_play.disabled = false
		main._on_play_pressed()
		await get_tree().process_frame
		if main._play_pick_panel and not main._play_pick_panel.visible:
			failures.append("Play pick panel did not open")
		if main._play_pick_panel:
			main._play_pick_panel.visible = false
		PetState.stage = old_stage
		PetState.energy = old_energy
		PetState.stubborn = old_stubborn
	# Dumpster + High/Low if present on main
	var dive = main.dumpster if "dumpster" in main else null
	if dive == null:
		dive = main.find_child("DumpsterDive", true, false)
	if dive and dive.has_method("start_game"):
		dive.start_game()
		await get_tree().process_frame
		if not dive.visible:
			failures.append("Dumpster Dive did not open")
		# Simulate good catch + spoiled catch scoring path without changing thresholds
		var before := int(dive.score)
		dive.score = before + 2
		dive.catch_streak = 2
		dive._add_fx("catch", 100.0, 100.0, "NICE")
		dive._add_fx("bad", 120.0, 100.0, "YUCK")
		dive._add_fx("streak", 110.0, 80.0, "x2")
		dive.playfield.queue_redraw()
		await get_tree().process_frame
		if dive.has_method("bail_out"):
			dive.bail_out()
		await get_tree().process_frame
		if dive.visible:
			failures.append("Dumpster Dive did not close")
	var dice = main.find_child("DiceHighLow", true, false)
	if dice == null:
		# May be constructed dynamically
		for c in main.get_children():
			if c.has_method("start_game") and c.has_method("_on_low"):
				dice = c
				break
	if dice:
		dice.start_game()
		await get_tree().process_frame
		if not dice.visible:
			failures.append("High/Low did not open")
		dice._on_done()
		await get_tree().process_frame
		if dice.visible:
			failures.append("High/Low did not close")
	main.queue_free()
	await get_tree().process_frame
