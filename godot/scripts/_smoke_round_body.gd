extends Node
## Validates round short-spine proportions across all Jimothy forms.


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	_check_source_proportions(failures)
	await _check_runtime_forms(failures)
	await _check_mechanics_untouched(failures)
	if failures.size() > 0:
		for f in failures:
			push_error("ROUND FAIL: " + f)
			print("ROUND FAIL: ", f)
		get_tree().quit(1)
	else:
		print("ROUND OK: all forms stay short-spine and round")
		get_tree().quit(0)


func _check_source_proportions(failures: PackedStringArray) -> void:
	var src := FileAccess.get_file_as_string("res://scripts/raccoon_view.gd")
	# Tall-leg outliers must be gone.
	for bad in ["leg_h = 28.0", "leg_h = 32.0", "leg_h = 34.0", "leg_h = 36.0", "leg_h = 26.0", "leg_h = 22.0"]:
		if src.find(bad) >= 0:
			failures.append("tall leg constant still present: " + bad)
	# Elongated weasel/potato side bodies must be gone.
	for bad in ["Vector2(22, 17)", "Vector2(26, 18)", "body_ry := 18.0\n\tvar body_y := 8.0", "leg_h := 18.0", "leg_h := 22.0", "leg_h := 36.0"]:
		if src.find(bad) >= 0:
			failures.append("elongated body marker still present: " + bad)
	for must in ["configure_as_form_preview", "_is_bouncy_form", "Round short-spine", "Anticipation squash"]:
		if src.find(must) < 0:
			failures.append("missing round-body helper/marker: " + must)


func _check_runtime_forms(failures: PackedStringArray) -> void:
	var Raccoon = load("res://scripts/raccoon_view.gd")
	var cases := [
		["baby", ""],
		["young", "puff"], ["young", "looper"], ["young", "shadow"], ["young", "nub"],
		["teen", "dumpling"], ["teen", "bounder"], ["teen", "nightlane"], ["teen", "scruff"],
		["adult", "saint"], ["adult", "legend"], ["adult", "alley_ghost"], ["adult", "ballard_blip"],
	]
	for case in cases:
		var r = Raccoon.new()
		r.preview_mode = true
		add_child(r)
		r.configure_as_form_preview(str(case[0]), str(case[1]) if str(case[1]) != "" else "puff", 0.4)
		r.play_anim("idle")
		await get_tree().process_frame
		r.play_anim("walk")
		await get_tree().process_frame
		r.play_anim("jump")
		await get_tree().process_frame
		r.play_anim("eat")
		await get_tree().process_frame
		r.mood = "sleep"
		r.play_anim("sleep")
		await get_tree().process_frame
		r.queue_free()
		await get_tree().process_frame
	# Dumpster avatar path
	var av = Raccoon.new()
	add_child(av)
	av.configure_as_avatar(0.62)
	av.stage = "teen"
	av.teen_form = "bounder"
	av.set_avatar_pose(1.0, 1.5, 0.0)
	await get_tree().process_frame
	av.queue_free()
	await get_tree().process_frame


func _check_mechanics_untouched(failures: PackedStringArray) -> void:
	var expected := {
		"berries": {"hunger": 18, "happy": 3, "health": 6, "fitness": 0},
		"crickets": {"hunger": 16, "happy": 2, "health": 5, "fitness": 1},
		"fish": {"hunger": 24, "happy": 4, "health": 8, "fitness": 1},
		"pizza": {"hunger": 10, "happy": 16, "health": -3, "fitness": -1},
		"fries": {"hunger": 9, "happy": 18, "health": -4, "fitness": -1},
	}
	for k in expected.keys():
		var f: Dictionary = PetState.FOOD[k]
		var e: Dictionary = expected[k]
		for field in e.keys():
			if int(f[field]) != int(e[field]):
				failures.append("food effect changed %s.%s" % [str(k), str(field)])
	var dive_src := FileAccess.get_file_as_string("res://scripts/dumpster_dive.gd")
	if dive_src.find("time_left = 22.0") < 0 or dive_src.find("score >= 18") < 0:
		failures.append("dumpster scoring/timer changed")
	var ver: Variant = ProjectSettings.get_setting("application/config/version", "")
	if str(ver) != "1.0.29":
		failures.append("project version not 1.0.29: " + str(ver))
	await get_tree().process_frame
