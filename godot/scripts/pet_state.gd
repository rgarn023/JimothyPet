extends Node
## Jimothy pet brain — save/load, real-time decay, growth, care actions.

signal state_changed
signal speech(text: String)
signal stage_changed(stage: String)
signal pet_died
signal needs_reset

const SAVE_PATH := "user://jimothy_save.json"

const STAGE_AGE := {
	"egg": 45,
	"hatchling": 90,
	"kit": 150,
	"teen": 210,
}

const FOOD := {
	"berries": {"name": "Berry Bundle", "type": "healthy", "hunger": 28, "happy": 4, "health": 8, "refuse": 0.35},
	"acorns": {"name": "Crunchy Acorns", "type": "healthy", "hunger": 24, "happy": 6, "health": 6, "refuse": 0.3},
	"pizza": {"name": "Pizza Crust", "type": "treat", "hunger": 12, "happy": 22, "health": -2, "refuse": 0.05},
	"fries": {"name": "Dumpster Fries", "type": "treat", "hunger": 10, "happy": 26, "health": -4, "refuse": 0.08},
}

var born_at: int = 0
var last_tick: int = 0
var age_sec: float = 0.0
var stage: String = "egg"
var adult_variant: String = "noble"
var hunger: float = 80.0
var happy: float = 80.0
var health: float = 100.0
var discipline: float = 55.0
var weight: float = 1.0
var care_score: int = 0
var care_mistakes: int = 0
var stubborn: bool = false
var stubborn_reason: String = ""
var has_mess: bool = false
var sick: bool = false
var alive: bool = true
var treat_streak: int = 0
var healthy_meals: int = 0
var play_sessions: int = 0

var _tick_accum: float = 0.0
var _save_accum: float = 0.0


func _ready() -> void:
	_reset_defaults()
	load_game()
	sync_realtime(false)
	state_changed.emit()


func _process(delta: float) -> void:
	if alive:
		_tick_accum += delta
		while _tick_accum >= 1.0:
			_tick_accum -= 1.0
			apply_decay(1.0)
			if not alive:
				pet_died.emit()
				needs_reset.emit()
				break
	_save_accum += delta
	if _save_accum >= 5.0:
		_save_accum = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		sync_realtime(true)
		state_changed.emit()
		save_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _reset_defaults() -> void:
	var now := _now()
	born_at = now
	last_tick = now
	age_sec = 0.0
	stage = "egg"
	adult_variant = "noble"
	hunger = 80.0
	happy = 80.0
	health = 100.0
	discipline = 55.0
	weight = 1.0
	care_score = 0
	care_mistakes = 0
	stubborn = false
	stubborn_reason = ""
	has_mess = false
	sick = false
	alive = true
	treat_streak = 0
	healthy_meals = 0
	play_sessions = 0


func reset_pet() -> void:
	_reset_defaults()
	save_game()
	speech.emit("A warm egg. Something wiggles inside…")
	stage_changed.emit(stage)
	state_changed.emit()


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func clamp01(n: float) -> float:
	return clampf(n, 0.0, 100.0)


func sync_realtime(announce_death: bool = true) -> int:
	var now := _now()
	var elapsed := maxi(0, now - last_tick)
	var was_alive := alive
	if elapsed > 0 and alive:
		apply_decay(float(elapsed))
	last_tick = now
	if announce_death and was_alive and not alive:
		pet_died.emit()
		needs_reset.emit()
	return elapsed


func apply_decay(seconds: float) -> void:
	hunger = clamp01(hunger - 0.045 * seconds)
	happy = clamp01(happy - 0.035 * seconds)
	age_sec += seconds

	if has_mess:
		health = clamp01(health - 0.02 * seconds)
		happy = clamp01(happy - 0.015 * seconds)
	if hunger < 20.0:
		health = clamp01(health - 0.04 * seconds)
		happy = clamp01(happy - 0.02 * seconds)
	if happy < 15.0:
		health = clamp01(health - 0.02 * seconds)
	if treat_streak > 3:
		health = clamp01(health - 0.01 * seconds)

	if not has_mess and stage != "egg" and randf() < seconds * 0.004:
		has_mess = true

	_maybe_tantrum(seconds)

	if health <= 0.0 or (hunger <= 0.0 and happy <= 0.0):
		alive = false
		health = 0.0

	_evolve_if_needed()
	state_changed.emit()


func _maybe_tantrum(seconds: float) -> void:
	if stage == "egg" or stubborn or not alive:
		return
	var chance := (0.002 + (100.0 - discipline) * 0.00004 + (0.002 if hunger < 35.0 else 0.0)) * seconds
	if randf() < chance:
		stubborn = true
		stubborn_reason = "refuses healthy food" if randf() < 0.5 else "refuses to exercise"
		care_mistakes += 1


func _evolve_if_needed() -> void:
	if not alive:
		return
	var prev := stage
	var egg_end := float(STAGE_AGE.egg)
	var hatch_end := egg_end + float(STAGE_AGE.hatchling)
	var kit_end := hatch_end + float(STAGE_AGE.kit)
	var teen_end := kit_end + float(STAGE_AGE.teen)

	if stage == "egg" and age_sec >= egg_end:
		stage = "hatchling"
		weight = 2.0
		speech.emit("Crack! Peep Jimothy hatched!")
	elif stage == "hatchling" and age_sec >= hatch_end:
		stage = "kit"
		weight = 5.0
		speech.emit("Jimothy grew into a kit!")
	elif stage == "kit" and age_sec >= kit_end:
		stage = "teen"
		weight = 9.0
		speech.emit("Teen Jimothy! Attitude unlocked.")
	elif stage == "teen" and age_sec >= teen_end:
		stage = "adult"
		weight = 14.0
		var good_care := care_score >= 8 and care_mistakes <= 6 and healthy_meals >= 3 and discipline >= 45.0
		adult_variant = "noble" if good_care else "rascal"
		if good_care:
			speech.emit("Behold — Saint Jimothy, short-spine legend!")
		else:
			speech.emit("Behold — Legend Jimothy, Ballard’s dumpster cryptid!")

	if prev != stage:
		stage_changed.emit(stage)
		save_game()


func stage_label() -> String:
	match stage:
		"egg": return "Egg"
		"hatchling": return "Hatchling"
		"kit": return "Kit"
		"teen": return "Teen"
		"adult": return "Adult"
		_: return stage.capitalize()


func stage_name() -> String:
	if not alive:
		return "Gone to the woods…"
	match stage:
		"egg": return "Mystery Egg"
		"hatchling": return "Peep Jimothy"
		"kit": return "Kit Jimothy"
		"teen": return "Teen Jimothy"
		"adult":
			return "Saint Jimothy" if adult_variant == "noble" else "Legend Jimothy"
		_: return "Jimothy"


func alert_text() -> Dictionary:
	if not alive:
		return {"text": "Jimothy needs a new life…", "danger": true}
	if sick:
		return {"text": "Jimothy feels queasy from too many treats.", "danger": true}
	if stubborn:
		return {"text": "Acting up — %s. Use Scold." % stubborn_reason, "danger": true}
	if has_mess:
		return {"text": "There's a mess. Clean it up!", "danger": false}
	if hunger < 25.0:
		return {"text": "Jimothy is starving for snacks.", "danger": true}
	if happy < 25.0:
		return {"text": "Jimothy is bored. Try Dumpster Dive.", "danger": false}
	if health < 30.0:
		return {"text": "Health is low — feed healthy meals.", "danger": true}
	return {}


func try_feed(food_key: String) -> String:
	if not alive or stage == "egg":
		return ""
	if not FOOD.has(food_key):
		return ""
	var food: Dictionary = FOOD[food_key]

	if stubborn and food.type == "healthy":
		speech.emit("Nope! Paws crossed. He refuses the healthy meal.")
		state_changed.emit()
		return "refused"

	var discipline_factor := (100.0 - discipline) / 100.0
	if food.type == "healthy" and randf() < float(food.refuse) * (0.45 + discipline_factor):
		stubborn = true
		stubborn_reason = "refuses healthy food"
		care_mistakes += 1
		speech.emit("Jimothy pushes away the %s!" % str(food.name).to_lower())
		state_changed.emit()
		save_game()
		return "refused"

	hunger = clamp01(hunger + float(food.hunger))
	happy = clamp01(happy + float(food.happy))
	health = clamp01(health + float(food.health))
	weight += 0.4 if food.type == "treat" else 0.2

	if food.type == "treat":
		treat_streak += 1
		if treat_streak >= 4:
			sick = true
			health = clamp01(health - 10.0)
			speech.emit("Too many treats… Jimothy looks green around the mask.")
		else:
			speech.emit("Nom nom — %s!" % food.name)
	else:
		treat_streak = 0
		healthy_meals += 1
		care_score += 1
		sick = false
		discipline = clamp01(discipline + 2.0)
		speech.emit("Crunch — %s. Good choice." % food.name)

	state_changed.emit()
	save_game()
	return "ok"


func discipline_pet() -> void:
	if not alive or not stubborn:
		return
	stubborn = false
	stubborn_reason = ""
	discipline = clamp01(discipline + 12.0)
	happy = clamp01(happy - 6.0)
	care_score += 1
	speech.emit("Hey! Listen up, bandit. …okay, okay.")
	state_changed.emit()
	save_game()


func clean_mess() -> void:
	if not alive or not has_mess:
		return
	has_mess = false
	happy = clamp01(happy + 4.0)
	health = clamp01(health + 3.0)
	care_score += 1
	speech.emit("All tidy. Whiskers gleam.")
	state_changed.emit()
	save_game()


func can_start_play() -> String:
	if not alive or stage == "egg":
		return "blocked"
	if stubborn and stubborn_reason.contains("exercise"):
		speech.emit("He plants his paws. No dumpster diving until you scold him.")
		state_changed.emit()
		return "stubborn"
	if not stubborn and discipline < 40.0 and randf() < 0.35:
		stubborn = true
		stubborn_reason = "refuses to exercise"
		care_mistakes += 1
		speech.emit("Jimothy flops over. Absolutely not playing.")
		state_changed.emit()
		save_game()
		return "stubborn"
	return "ok"


func apply_play_result(score: int, stars: int, completed: bool) -> void:
	if not alive:
		return
	if not completed and score == 0:
		speech.emit("Maybe later, alley cat.")
		return
	play_sessions += 1
	happy = clamp01(happy + 10.0 + stars * 6.0)
	hunger = clamp01(hunger - 6.0)
	health = clamp01(health + 4.0 + stars)
	discipline = clamp01(discipline + 3.0)
	care_score += 2 if stars > 0 else 1
	weight = maxf(1.0, weight - 0.15 * stars)
	if stars >= 3:
		speech.emit("Legendary dive! Shiny treasures secured.")
	elif stars >= 1:
		speech.emit("Nice dive — score %d." % score)
	else:
		speech.emit("A sleepy dive. Score %d." % score)
	state_changed.emit()
	save_game()


func to_dict() -> Dictionary:
	return {
		"born_at": born_at,
		"last_tick": last_tick,
		"age_sec": age_sec,
		"stage": stage,
		"adult_variant": adult_variant,
		"hunger": hunger,
		"happy": happy,
		"health": health,
		"discipline": discipline,
		"weight": weight,
		"care_score": care_score,
		"care_mistakes": care_mistakes,
		"stubborn": stubborn,
		"stubborn_reason": stubborn_reason,
		"has_mess": has_mess,
		"sick": sick,
		"alive": alive,
		"treat_streak": treat_streak,
		"healthy_meals": healthy_meals,
		"play_sessions": play_sessions,
	}


func from_dict(d: Dictionary) -> void:
	born_at = int(d.get("born_at", _now()))
	last_tick = int(d.get("last_tick", _now()))
	age_sec = float(d.get("age_sec", 0.0))
	stage = str(d.get("stage", "egg"))
	adult_variant = str(d.get("adult_variant", "noble"))
	hunger = float(d.get("hunger", 80.0))
	happy = float(d.get("happy", 80.0))
	health = float(d.get("health", 100.0))
	discipline = float(d.get("discipline", 55.0))
	weight = float(d.get("weight", 1.0))
	care_score = int(d.get("care_score", 0))
	care_mistakes = int(d.get("care_mistakes", 0))
	stubborn = bool(d.get("stubborn", false))
	stubborn_reason = str(d.get("stubborn_reason", ""))
	has_mess = bool(d.get("has_mess", false))
	sick = bool(d.get("sick", false))
	alive = bool(d.get("alive", true))
	treat_streak = int(d.get("treat_streak", 0))
	healthy_meals = int(d.get("healthy_meals", 0))
	play_sessions = int(d.get("play_sessions", 0))


func save_game() -> void:
	last_tick = _now()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(to_dict()))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		speech.emit("A warm egg. Something wiggles inside…")
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	from_dict(data)
