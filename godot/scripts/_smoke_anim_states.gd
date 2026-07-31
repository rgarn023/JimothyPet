extends SceneTree
## Smoke: Baby Kit animation state machine (no artwork changes).

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	var Raccoon = load("res://scripts/raccoon_view.gd")
	var r = Raccoon.new()
	root.add_child(r)
	await process_frame
	r.custom_minimum_size = Vector2(240, 240)
	r.size = Vector2(240, 240)
	r.stage = "baby"
	r.play_anim("idle_front")
	if r._anim != "idle_front":
		failures.append("idle_front not set")
	# Side ambient must not stick on baby
	r.play_anim("walk")
	if r._anim != "idle_front":
		failures.append("baby walk should remap to idle_front, got " + r._anim)
	if not r._view_front():
		failures.append("baby must stay front-facing")
	# Food-specific feeds
	for pair in [
		["fries", "feed_dumpster_fries"],
		["berries", "feed_wild_berries"],
		["crickets", "feed_night_crickets"],
		["fish", "feed_stream_fish"],
		["pizza", "feed_pizza_crust"],
	]:
		r._action_locked = false
		r.play_eat(str(pair[0]))
		if r._anim != str(pair[1]):
			failures.append("expected %s got %s" % [pair[1], r._anim])
		if r._anim_dur < 0.8 or r._anim_dur > 1.4:
			failures.append("feed dur out of range for " + str(pair[1]))
		# Ambient cannot interrupt feed
		r.play_anim("walk")
		if r._anim != str(pair[1]):
			failures.append("ambient interrupted feed " + str(pair[1]))
		# Finish → idle_front
		r._anim_t = r._anim_dur + 0.01
		r._process(0.016)
		if r._anim != "idle_front":
			failures.append("feed did not return idle_front from " + str(pair[1]))
	# Bounce timing
	r._action_locked = false
	r.play_anim("happy_bounce")
	if r._anim != "happy_bounce":
		failures.append("happy_bounce missing")
	if r._anim_dur < 0.5 or r._anim_dur > 0.9:
		failures.append("bounce dur out of range")
	r._anim_t = r._anim_dur + 0.01
	r._process(0.016)
	if r._anim != "idle_front":
		failures.append("bounce did not return idle_front")
	# Hatch
	r._action_locked = false
	r.play_anim("hatch_reveal")
	if r._anim != "hatch_reveal":
		failures.append("hatch_reveal missing")
	if r._anim_dur < 1.0 or r._anim_dur > 1.5:
		failures.append("hatch dur out of range")
	if not r._hatch_show_bush:
		failures.append("hatch should show bush for baby")
	r._anim_t = r._anim_dur + 0.01
	r._process(0.016)
	if r._anim != "idle_front":
		failures.append("hatch did not return idle_front")
	# Foot pivot helper exists and is stable
	if absf(r._foot_pivot_y() - 54.0) > 0.01:
		failures.append("baby foot pivot should be 54")
	# Foot-anchored squash transform math: pivot y constant
	var piv: float = r._foot_pivot_y()
	r._body_squash = 0.85
	var xy: Vector2 = r._mascot_squash_xy(r._body_squash)
	if xy.x < 0.78 or xy.y > 1.18:
		failures.append("squash out of mascot bounds")
	r.queue_free()
	await process_frame
	if failures.size() > 0:
		for f in failures:
			push_error("ANIM_SMOKE FAIL: " + f)
		quit(1)
	else:
		print("ANIM_SMOKE OK")
		quit(0)
