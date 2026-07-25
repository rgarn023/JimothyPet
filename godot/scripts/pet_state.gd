extends Node
## Jimothy — real-time cryptid care, bush start, form variance → adult Jimothy look.

signal state_changed
signal speech(text: String)
signal stage_changed(stage: String)
signal anim_impulse(kind: String)
signal pet_died(reason: String)
signal needs_reset

const SAVE_PATH := "user://jimothy_save_v2.json"

# Real-time stage lengths (seconds).
const BUSH_SEC := 60.0
const BABY_SEC := 3600.0          # 1 hour
const YOUNG_SEC := 86400.0        # 24 hours
const TEEN_SEC_MIN := 86400.0     # 24 hours
const TEEN_SEC_MAX := 259200.0    # 72 hours
const ADULT_SEC_MIN := 864000.0   # 10 days
const ADULT_SEC_MAX := 1728000.0  # 20 days
const ADULT_SEC_FLOOR := 86400.0  # neglect can shorten life, but not below 1 day as adult

const FOOD := {
	"berries": {
		"name": "Wild Berries",
		"type": "healthy",
		"hunger": 18, "happy": 3, "health": 6, "fitness": 0,
		"satiety": 22, "refuse": 0.22,
		"blurb": "Tart forest berries — light, clean fuel.",
	},
	"crickets": {
		"name": "Night Crickets",
		"type": "healthy",
		"hunger": 16, "happy": 2, "health": 5, "fitness": 1,
		"satiety": 20, "refuse": 0.28,
		"blurb": "Crunchy protein. Kits need this to grow strong legs.",
	},
	"fish": {
		"name": "Stream Fish Bits",
		"type": "healthy",
		"hunger": 24, "happy": 4, "health": 8, "fitness": 1,
		"satiety": 30, "refuse": 0.18,
		"blurb": "Rich scraps from the creek — fills him up properly.",
	},
	"pizza": {
		"name": "Pizza Crust",
		"type": "treat",
		"hunger": 10, "happy": 16, "health": -3, "fitness": -1,
		"satiety": 14, "refuse": 0.04,
		"blurb": "Greasy alley treasure. Mood up, tummy pays later.",
	},
	"fries": {
		"name": "Dumpster Fries",
		"type": "treat",
		"hunger": 9, "happy": 18, "health": -4, "fitness": -1,
		"satiety": 12, "refuse": 0.06,
		"blurb": "Salty chaos. Fine sometimes — not a meal plan.",
	},
}

var born_at: int = 0
var last_tick: int = 0
var age_sec: float = 0.0
var stage: String = "bush"
var young_form: String = "puff"
var teen_form: String = "bounder"
var adult_form: String = "saint"
var teen_duration: float = TEEN_SEC_MIN
var adult_duration: float = ADULT_SEC_MIN
var lifespan_penalty: float = 0.0
var genes: Dictionary = {}
var death_reason: String = ""

var hunger: float = 70.0
var happy: float = 70.0
var health: float = 100.0
var discipline: float = 50.0
var fitness: float = 40.0
var satiety: float = 0.0
var weight: float = 1.0
var care_score: int = 0
var care_mistakes: int = 0
var stubborn: bool = false
var stubborn_reason: String = ""
var has_mess: bool = false
var sick: bool = false
var alive: bool = true
var ascending: bool = false
var treat_streak: int = 0
var healthy_meals: int = 0
var play_sessions: int = 0
var energy: float = 80.0
## Lifetime unlocks across kits (persists through reset).
var forms_unlocked: Dictionary = {
	"young": {},
	"teen": {},
	"adult": {},
}
var dev_mode: bool = false
## Secret gesture unlocks the Dev button (persists).
var dev_unlocked: bool = false
## When true, night ambience + raccoon SFX are muted (persists).
var sound_muted: bool = false
## When true, care notifications (hungry / play / acting up / waste) are allowed.
var alerts_enabled: bool = false
## Last successful food key — used by eat animation prop.
var last_fed_food: String = "berries"

var _tick_accum: float = 0.0
var _save_accum: float = 0.0
var _anim_cooldown: float = 0.0


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
				break
		_anim_cooldown -= delta
		if _anim_cooldown <= 0.0 and alive and not ascending:
			if stage == "bush":
				_anim_cooldown = randf_range(1.6, 3.2)
				anim_impulse.emit("rustle")
				if JimothyAudio and randf() < 0.4:
					JimothyAudio.play("rustle", -10.0)
			else:
				_pulse_ambient_anim()
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
	stage = "bush"
	genes = _roll_genes()
	young_form = _pick_young_form(genes)
	teen_form = ""
	adult_form = ""
	teen_duration = randf_range(TEEN_SEC_MIN, TEEN_SEC_MAX)
	adult_duration = randf_range(ADULT_SEC_MIN, ADULT_SEC_MAX)
	lifespan_penalty = 0.0
	death_reason = ""
	hunger = 70.0
	happy = 70.0
	health = 100.0
	discipline = 50.0
	fitness = 40.0
	satiety = 0.0
	weight = 0.8
	care_score = 0
	care_mistakes = 0
	stubborn = false
	stubborn_reason = ""
	has_mess = false
	sick = false
	alive = true
	ascending = false
	treat_streak = 0
	healthy_meals = 0
	play_sessions = 0
	energy = 80.0


func reset_pet() -> void:
	var keep_forms := forms_unlocked.duplicate(true)
	var keep_dev := dev_mode
	var keep_dev_unlocked := dev_unlocked
	var keep_mute := sound_muted
	var keep_alerts := alerts_enabled
	_reset_defaults()
	forms_unlocked = keep_forms
	dev_mode = keep_dev
	dev_unlocked = keep_dev_unlocked or keep_dev
	sound_muted = keep_mute
	alerts_enabled = keep_alerts
	save_game()
	speech.emit("A roadside bush shivers… something’s in there.")
	stage_changed.emit(stage)
	state_changed.emit()


func unlock_current_form() -> void:
	match stage:
		"young":
			_unlock_form("young", young_form)
		"teen":
			if teen_form != "":
				_unlock_form("teen", teen_form)
		"adult":
			if adult_form != "":
				_unlock_form("adult", adult_form)


func _unlock_form(bucket: String, form_id: String) -> void:
	if form_id == "":
		return
	if not forms_unlocked.has(bucket):
		forms_unlocked[bucket] = {}
	var bag: Dictionary = forms_unlocked[bucket]
	if not bag.has(form_id):
		bag[form_id] = true
		forms_unlocked[bucket] = bag
		speech.emit("Form unlocked: %s %s" % [bucket.capitalize(), form_id.capitalize()])


func unlocked_list(bucket: String) -> Array:
	if not forms_unlocked.has(bucket):
		return []
	return (forms_unlocked[bucket] as Dictionary).keys()


func is_form_unlocked(bucket: String, form_id: String) -> bool:
	if not forms_unlocked.has(bucket):
		return false
	return bool((forms_unlocked[bucket] as Dictionary).get(form_id, false))


func unlock_dev_access() -> void:
	dev_unlocked = true
	save_game()
	state_changed.emit()


func set_dev_mode(on: bool) -> void:
	if on:
		dev_unlocked = true
	dev_mode = on
	state_changed.emit()
	save_game()


## Developer fast-forward — jumps wall-clock age to the start of a stage.
func dev_skip_to(target: String) -> void:
	if not dev_mode:
		return
	alive = true
	ascending = false
	death_reason = ""
	stubborn = false
	has_mess = false
	sick = false
	hunger = 75.0
	happy = 75.0
	health = 95.0
	energy = 80.0
	satiety = 20.0

	match target:
		"bush":
			stage = "bush"
			age_sec = 5.0
		"baby":
			stage = "baby"
			age_sec = bush_end() + 2.0
			weight = 1.2
		"young":
			stage = "young"
			age_sec = baby_end() + 2.0
			young_form = _pick_young_form(genes)
			weight = 3.5
			unlock_current_form()
		"teen":
			stage = "teen"
			age_sec = young_end() + 2.0
			if young_form == "":
				young_form = _pick_young_form(genes)
			_unlock_form("young", young_form)
			teen_form = _pick_teen_form(young_form, genes)
			teen_duration = randf_range(TEEN_SEC_MIN, TEEN_SEC_MAX)
			weight = 7.0
			unlock_current_form()
		"adult":
			stage = "adult"
			if young_form == "":
				young_form = _pick_young_form(genes)
			_unlock_form("young", young_form)
			if teen_form == "":
				teen_form = _pick_teen_form(young_form, genes)
			_unlock_form("teen", teen_form)
			adult_form = _pick_adult_form(teen_form)
			var care_q := clampf(
				(float(care_score) * 0.04 + float(healthy_meals) * 0.03 + fitness * 0.004)
				- float(care_mistakes) * 0.05,
				0.0,
				1.0
			)
			adult_duration = lerpf(ADULT_SEC_MIN, ADULT_SEC_MAX, care_q)
			age_sec = teen_end() + 2.0
			genes.legginess = clampf(float(genes.legginess) * 0.5 + 0.55, 0.0, 1.0)
			genes.roundness = clampf(float(genes.roundness) * 0.4 + 0.65, 0.0, 1.0)
			weight = 11.0
			unlock_current_form()
		"ascend":
			if stage != "adult":
				dev_skip_to("adult")
			end_life("lifespan")
			return
		_:
			return

	last_tick = _now()
	speech.emit("Dev: jumped to %s." % target)
	stage_changed.emit(stage)
	anim_impulse.emit("pop" if target == "baby" else "stretch")
	state_changed.emit()
	save_game()


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func clamp01(n: float) -> float:
	return clampf(n, 0.0, 100.0)


func _roll_genes() -> Dictionary:
	return {
		"roundness": randf(),
		"legginess": randf(),
		"fluff": randf(),
		"mask": randf(),
		"pep": randf(),
		"gray": randf(),
		"ear_flare": randf(),
	}


func _pick_young_form(g: Dictionary) -> String:
	# Early silhouette variance that steers later teen/adult flair.
	if float(g.roundness) > 0.62 and float(g.fluff) > 0.45:
		return "puff"
	if float(g.legginess) > 0.6 and float(g.pep) > 0.4:
		return "looper"
	if float(g.mask) > 0.65:
		return "shadow"
	return "nub"


func _pick_teen_form(young: String, g: Dictionary) -> String:
	match young:
		"puff":
			return "dumpling" if float(g.fluff) > 0.5 else "scruff"
		"looper":
			return "bounder" if float(g.pep) > 0.45 else "nightlane"
		"shadow":
			return "nightlane" if float(g.mask) > 0.5 else "scruff"
		_:
			return "bounder" if float(g.legginess) > 0.5 else "dumpling"


func _pick_adult_form(teen: String) -> String:
	var good := care_score >= 10 and care_mistakes <= 8 and healthy_meals >= 4 and fitness >= 45.0
	# Always short-spine Jimothy; flair differs.
	match teen:
		"dumpling":
			return "saint" if good else "ballard_blip"
		"bounder":
			return "legend" if not good else "alley_ghost"
		"nightlane":
			return "alley_ghost" if good else "legend"
		"scruff":
			return "ballard_blip" if not good else "saint"
		_:
			return "saint" if good else "legend"


func bush_end() -> float:
	return BUSH_SEC


func baby_end() -> float:
	return BUSH_SEC + BABY_SEC


func young_end() -> float:
	return baby_end() + YOUNG_SEC


func teen_end() -> float:
	return young_end() + teen_duration


func effective_adult_span() -> float:
	# Neglect / poor care shortens the adult chapter.
	var span := adult_duration - lifespan_penalty
	return maxf(ADULT_SEC_FLOOR, span)


func life_end() -> float:
	return teen_end() + effective_adult_span()


func remaining_life_sec() -> float:
	if stage != "adult" or not alive:
		return 0.0
	return maxf(0.0, life_end() - age_sec)


func _apply_neglect_penalty(seconds: float) -> void:
	if stage == "bush" or not alive:
		return
	var rate := 0.0
	if hunger < 25.0:
		rate += 2.2
	if happy < 20.0:
		rate += 1.4
	if health < 35.0:
		rate += 2.8
	if has_mess:
		rate += 0.8
	if sick:
		rate += 1.6
	if discipline < 25.0:
		rate += 0.4
	# Mistakes carve larger chunks off the eventual / current lifespan.
	lifespan_penalty += rate * seconds


func end_life(reason: String) -> void:
	if not alive and ascending:
		return
	alive = false
	ascending = true
	death_reason = reason
	stubborn = false
	anim_impulse.emit("ascend")
	match reason:
		"lifespan":
			speech.emit("His time is done. Wings catch the moonlight…")
		"neglect":
			speech.emit("Poor care wore him thin. Wings unfold anyway…")
		_:
			speech.emit("Jimothy’s life is over. He rises into the sky…")
	pet_died.emit(reason)
	state_changed.emit()
	save_game()


func sync_realtime(announce_death: bool = true) -> int:
	var now := _now()
	var elapsed := maxi(0, now - last_tick)
	var was_alive := alive
	if elapsed > 0 and alive:
		apply_decay(float(elapsed))
	last_tick = now
	if announce_death and was_alive and not alive and not ascending:
		# Offline death still triggers ascension path via end_life inside apply_decay.
		pass
	return elapsed


func apply_decay(seconds: float) -> void:
	if not alive:
		state_changed.emit()
		return

	# Slower, more pet-like drain over real hours/days.
	var hunger_rate := 0.0028 if stage != "bush" else 0.0
	var happy_rate := 0.0022 if stage != "bush" else 0.0
	var energy_rate := 0.0015 if stage != "bush" else 0.0

	hunger = clamp01(hunger - hunger_rate * seconds)
	happy = clamp01(happy - happy_rate * seconds)
	energy = clamp01(energy - energy_rate * seconds)
	satiety = maxf(0.0, satiety - 0.02 * seconds)
	age_sec += seconds

	if has_mess:
		health = clamp01(health - 0.0012 * seconds)
		happy = clamp01(happy - 0.001 * seconds)
	if hunger < 20.0 and stage != "bush":
		health = clamp01(health - 0.0025 * seconds)
		happy = clamp01(happy - 0.0015 * seconds)
	if happy < 15.0 and stage != "bush":
		health = clamp01(health - 0.001 * seconds)
	if treat_streak > 3:
		health = clamp01(health - 0.0008 * seconds)
		sick = true
	if energy < 15.0:
		happy = clamp01(happy - 0.0005 * seconds)

	_apply_neglect_penalty(seconds)

	if stage != "bush" and not has_mess and randf() < seconds * 0.00025:
		has_mess = true

	_maybe_tantrum(seconds)
	_evolve_if_needed()

	# Natural / care-shortened lifespan end after adult window.
	if stage == "adult" and age_sec >= life_end():
		var shortened := lifespan_penalty > adult_duration * 0.15
		end_life("neglect" if shortened else "lifespan")
	elif health <= 0.0 or (hunger <= 0.0 and happy <= 0.0 and stage != "bush"):
		health = 0.0
		end_life("neglect")

	state_changed.emit()


func _maybe_tantrum(seconds: float) -> void:
	if stage in ["bush", "baby"] or stubborn or not alive:
		return
	var chance := (0.00015 + (100.0 - discipline) * 0.000002) * seconds
	if hunger < 30.0:
		chance *= 1.4
	if randf() < chance:
		stubborn = true
		stubborn_reason = "refuses a proper meal" if randf() < 0.5 else "refuses to exercise"
		care_mistakes += 1
		lifespan_penalty += 5400.0  # ~1.5 hours shaved per unresolved chaos streak


func _evolve_if_needed() -> void:
	if not alive:
		return
	var prev := stage

	if stage == "bush" and age_sec >= bush_end():
		stage = "baby"
		weight = 1.2
		happy = clamp01(happy + 10.0)
		speech.emit("The bush explodes in leaves — baby kit Jimothy!")
		anim_impulse.emit("pop")
	elif stage == "baby" and age_sec >= baby_end():
		stage = "young"
		young_form = _pick_young_form(genes)
		weight = 3.5
		speech.emit("He’s a young kit now — form: %s." % young_form.capitalize())
		anim_impulse.emit("stretch")
		unlock_current_form()
	elif stage == "young" and age_sec >= young_end():
		stage = "teen"
		teen_form = _pick_teen_form(young_form, genes)
		weight = 7.0
		# Teen duration already rolled; may re-roll lightly for variance
		teen_duration = randf_range(TEEN_SEC_MIN, TEEN_SEC_MAX)
		speech.emit("Teen kit era. He’s turning into a %s." % teen_form)
		anim_impulse.emit("run")
		unlock_current_form()
	elif stage == "teen" and age_sec >= teen_end():
		stage = "adult"
		adult_form = _pick_adult_form(teen_form if teen_form != "" else _pick_teen_form(young_form, genes))
		# Better care → longer adult life; neglect already in lifespan_penalty.
		var care_q := clampf(
			(float(care_score) * 0.04 + float(healthy_meals) * 0.03 + fitness * 0.004)
			- float(care_mistakes) * 0.05,
			0.0,
			1.0
		)
		adult_duration = lerpf(ADULT_SEC_MIN, ADULT_SEC_MAX, care_q)
		adult_duration = maxf(ADULT_SEC_FLOOR, adult_duration - lifespan_penalty * 0.35)
		weight = 11.0 + fitness * 0.03
		# Nudge genes toward short-spine Jimothy silhouette
		genes.legginess = clampf(float(genes.legginess) * 0.5 + 0.55, 0.0, 1.0)
		genes.roundness = clampf(float(genes.roundness) * 0.4 + 0.65, 0.0, 1.0)
		speech.emit("Fully grown — %s Jimothy, midnight cryptid." % adult_form_title())
		anim_impulse.emit("lope")
		unlock_current_form()

	if prev != stage:
		stage_changed.emit(stage)
		save_game()


func stage_label() -> String:
	match stage:
		"bush": return "Bush"
		"baby": return "Baby Kit"
		"young": return "Young Kit"
		"teen": return "Teen Kit"
		"adult": return "Adult"
		_: return stage.capitalize()


func stage_name() -> String:
	if ascending:
		return "Ascending…"
	if not alive:
		return "Gone to the night…"
	match stage:
		"bush": return "Rustling Bush"
		"baby": return "Baby Kit Jimothy"
		"young": return "%s Young Kit" % young_form.capitalize()
		"teen": return "%s Teen Kit" % (teen_form.capitalize() if teen_form != "" else "Mystery")
		"adult": return "%s Jimothy" % adult_form_title()
		_: return "Jimothy"


func adult_form_title() -> String:
	match adult_form:
		"saint": return "Saint"
		"legend": return "Legend"
		"alley_ghost": return "Alley Ghost"
		"ballard_blip": return "Ballard Blip"
		_: return "Cryptid"


func form_profile() -> Dictionary:
	return {
		"stage": stage,
		"young_form": young_form,
		"teen_form": teen_form,
		"adult_form": adult_form,
		"genes": genes.duplicate(),
		"fitness": fitness,
	}


func alert_text() -> Dictionary:
	if ascending:
		return {"text": "Jimothy grows wings and rises into the sky…", "danger": false}
	if not alive:
		return {"text": "His life is over. You can raise another kit.", "danger": true}
	if stage == "bush":
		return {"text": "The bush is rustling. Wait — something’s waking.", "danger": false}
	if sick:
		return {"text": "Upset stomach from too much junk food.", "danger": true}
	if stubborn:
		return {"text": "Acting up — %s. Scold him." % stubborn_reason, "danger": true}
	if has_mess:
		return {"text": "He’s marked the nest. Clean it up.", "danger": false}
	if energy < 20.0:
		return {"text": "Winded. Let him rest before more exercise.", "danger": false}
	if satiety > 75.0:
		return {"text": "Full belly — forcing food won’t help.", "danger": false}
	if hunger < 25.0:
		return {"text": "He’s hunting for a real meal.", "danger": true}
	if happy < 25.0:
		return {"text": "Restless cryptid energy. Try a night run (Play).", "danger": false}
	if health < 30.0:
		return {"text": "He’s run-down — skip treats, offer fish or berries.", "danger": true}
	return {}


func try_feed(food_key: String) -> String:
	if not alive or stage == "bush":
		return ""
	if not FOOD.has(food_key):
		return ""
	var food: Dictionary = FOOD[food_key]

	if satiety >= 85.0:
		speech.emit("He turns his nose away — still digesting.")
		anim_impulse.emit("refuse")
		state_changed.emit()
		return "full"

	if stubborn and food.type == "healthy":
		speech.emit("Nope. He buries the %s under a leaf." % str(food.name).to_lower())
		anim_impulse.emit("refuse")
		state_changed.emit()
		return "refused"

	var discipline_factor := (100.0 - discipline) / 100.0
	if food.type == "healthy" and randf() < float(food.refuse) * (0.4 + discipline_factor):
		stubborn = true
		stubborn_reason = "refuses a proper meal"
		care_mistakes += 1
		lifespan_penalty += 3600.0
		speech.emit("Jimothy bats the %s away!" % str(food.name).to_lower())
		anim_impulse.emit("refuse")
		state_changed.emit()
		save_game()
		return "refused"

	hunger = clamp01(hunger + float(food.hunger))
	happy = clamp01(happy + float(food.happy))
	health = clamp01(health + float(food.health))
	fitness = clamp01(fitness + float(food.fitness))
	satiety = clamp01(satiety + float(food.satiety))
	weight += 0.35 if food.type == "treat" else 0.15
	energy = clamp01(energy + (4.0 if food.type == "healthy" else 1.0))

	last_fed_food = food_key
	if food.type == "treat":
		treat_streak += 1
		if treat_streak >= 4:
			sick = true
			health = clamp01(health - 8.0)
			speech.emit("Too much alley grease… he flops, queasy.")
			anim_impulse.emit("sick")
		else:
			speech.emit("He stash-eats the %s." % food.name)
			anim_impulse.emit("eat")
			_anim_cooldown = 3.2
	else:
		treat_streak = 0
		healthy_meals += 1
		care_score += 1
		sick = false if health > 40.0 else sick
		discipline = clamp01(discipline + 1.5)
		speech.emit("He forages the %s carefully." % food.name)
		anim_impulse.emit("eat")
		_anim_cooldown = 3.2

	state_changed.emit()
	save_game()
	return "ok"


func discipline_pet() -> void:
	if not alive or not stubborn:
		return
	stubborn = false
	stubborn_reason = ""
	discipline = clamp01(discipline + 10.0)
	happy = clamp01(happy - 5.0)
	care_score += 1
	speech.emit("A firm chitter. He listens… for now.")
	anim_impulse.emit("scold")
	state_changed.emit()
	save_game()


## Tap / pet Jimothy — smile, hop, nuzzle, etc.
func interact_tap() -> String:
	if ascending:
		return ""
	if not alive:
		return ""
	if stage == "bush":
		speech.emit("The bush shivers under your hand…")
		anim_impulse.emit("rustle")
		state_changed.emit()
		return "rustle"

	var kind := "smile"
	var roll := randf()
	if stubborn:
		kind = "refuse" if roll < 0.55 else "sniff"
		speech.emit("He side-eyes you. Still sulking.")
	elif sick:
		kind = "sniff"
		speech.emit("A weak little chitter.")
	elif stage == "baby":
		kind = "hop" if roll < 0.45 else ("smile" if roll < 0.8 else "nuzzle")
	elif energy < 25.0:
		kind = "nuzzle" if roll < 0.6 else "smile"
	elif happy > 70.0 and roll < 0.35:
		kind = "hop"
	elif roll < 0.28:
		kind = "hop"
	elif roll < 0.5:
		kind = "nuzzle"
	elif roll < 0.62:
		kind = "spin"
	else:
		kind = "smile"

	happy = clamp01(happy + (4.0 if kind in ["smile", "hop", "nuzzle", "spin"] else 1.0))
	if kind == "smile":
		speech.emit(["He grins at you.", "Happy raccoon eyes!", "He leans into the pets."][randi() % 3])
	elif kind == "hop":
		speech.emit(["Boing!", "He hops for attention.", "Tiny cryptid bounce!"][randi() % 3])
	elif kind == "nuzzle":
		speech.emit(["He nuzzles your finger.", "Soft headbonk.", "Purr-adjacent chitter."][randi() % 3])
	elif kind == "spin":
		speech.emit(["Zoomies!", "A silly spin!", "He whirls in place."][randi() % 3])

	anim_impulse.emit(kind)
	state_changed.emit()
	# Soft save — tapping is frequent
	if randf() < 0.35:
		save_game()
	return kind


func clean_mess() -> void:
	if not alive or not has_mess:
		return
	has_mess = false
	happy = clamp01(happy + 3.0)
	health = clamp01(health + 2.0)
	care_score += 1
	speech.emit("Nest cleared. He sniffs approval.")
	state_changed.emit()
	save_game()


func can_start_play(roll_stubborn: bool = false) -> String:
	if not alive or stage in ["bush", "baby"]:
		if stage == "baby":
			speech.emit("Too tiny for games — let him wobble a bit first.")
		state_changed.emit()
		return "blocked"
	if energy < 18.0:
		speech.emit("He’s wiped. Rest a bit, then try again.")
		state_changed.emit()
		return "tired"
	if stubborn and stubborn_reason.contains("exercise"):
		speech.emit("He plants his paws. No night run until you scold him.")
		state_changed.emit()
		return "stubborn"
	# Only roll stubborn when opening the picker — not again when launching a game.
	if roll_stubborn and not stubborn and discipline < 35.0 and randf() < 0.3:
		stubborn = true
		stubborn_reason = "refuses to exercise"
		care_mistakes += 1
		speech.emit("He flops dramatically. Absolutely not chasing trash.")
		state_changed.emit()
		save_game()
		return "stubborn"
	return "ok"


func apply_play_result(score: int, stars: int, completed: bool) -> void:
	if not alive:
		return
	if not completed and score == 0:
		speech.emit("He peeks from the alley and bails.")
		return
	play_sessions += 1
	var burn := 8.0 + stars * 3.0
	happy = clamp01(happy + 8.0 + stars * 5.0)
	hunger = clamp01(hunger - burn * 0.7)
	energy = clamp01(energy - (20.0 + stars * 4.0))
	health = clamp01(health + 2.0 + stars)
	fitness = clamp01(fitness + 3.0 + stars * 2.0)
	discipline = clamp01(discipline + 2.0)
	care_score += 2 if stars > 0 else 1
	weight = maxf(1.0, weight - 0.12 * stars)
	# Fitness nudges leg gene for later adult silhouette
	genes.legginess = clampf(float(genes.legginess) + stars * 0.01, 0.0, 1.0)
	if stars >= 3:
		speech.emit("A legendary night lope — treasure secured.")
		anim_impulse.emit("run")
	elif stars >= 1:
		speech.emit("Solid forage run. Score %d." % score)
		anim_impulse.emit("walk")
	else:
		speech.emit("A sleepy shuffle. Score %d." % score)
	state_changed.emit()
	save_game()


func apply_dice_result(correct: bool, roll: int) -> void:
	if not alive:
		return
	play_sessions += 1
	energy = clamp01(energy - 10.0)
	hunger = clamp01(hunger - 3.0)
	discipline = clamp01(discipline + 1.0)
	if correct:
		happy = clamp01(happy + 14.0)
		fitness = clamp01(fitness + 2.0)
		health = clamp01(health + 1.0)
		care_score += 2
		speech.emit("d20 shows %d — you called it! He chirps with joy." % roll)
		anim_impulse.emit("happy")
	else:
		happy = clamp01(happy - 6.0)
		speech.emit("d20 shows %d — wrong call. He droops and sighs." % roll)
		anim_impulse.emit("sad")
	state_changed.emit()
	save_game()


func _pulse_ambient_anim() -> void:
	# Skip while a care animation (especially slow eat) should stay visible.
	# Cooldown is also stretched when eat is emitted.
	if stubborn or sick:
		_anim_cooldown = randf_range(2.2, 3.6)
		anim_impulse.emit("stubborn" if stubborn else "sick")
		return
	var roll := randf()
	var kind := "idle"
	var peppy := young_form in ["looper", "nub"] or teen_form in ["bounder"] or fitness > 55.0
	var sneaky := young_form == "shadow" or teen_form == "nightlane" or adult_form == "alley_ghost"
	if energy > 55.0 and happy > 50.0 and roll < (0.42 if peppy else 0.32):
		if peppy and roll < 0.18:
			kind = "run" if fitness > 45.0 else "jump"
		else:
			kind = "walk"
	elif roll < 0.5:
		kind = "walk"
	elif roll < 0.66:
		kind = "jump" if peppy else "sniff"
	elif roll < 0.78:
		kind = "lope" if stage == "adult" else ("stretch" if stage != "baby" else "sniff")
	elif roll < 0.9:
		kind = "sniff" if sneaky or stage == "baby" else "stretch"
	else:
		kind = "idle"
	_anim_cooldown = randf_range(1.2, 3.2)
	anim_impulse.emit(kind)


func to_dict() -> Dictionary:
	return {
		"born_at": born_at,
		"last_tick": last_tick,
		"age_sec": age_sec,
		"stage": stage,
		"young_form": young_form,
		"teen_form": teen_form,
		"adult_form": adult_form,
		"teen_duration": teen_duration,
		"adult_duration": adult_duration,
		"lifespan_penalty": lifespan_penalty,
		"death_reason": death_reason,
		"ascending": ascending,
		"genes": genes,
		"hunger": hunger,
		"happy": happy,
		"health": health,
		"discipline": discipline,
		"fitness": fitness,
		"satiety": satiety,
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
		"energy": energy,
		"forms_unlocked": forms_unlocked,
		"dev_mode": dev_mode,
		"dev_unlocked": dev_unlocked,
		"sound_muted": sound_muted,
		"alerts_enabled": alerts_enabled,
	}


func from_dict(d: Dictionary) -> void:
	born_at = int(d.get("born_at", _now()))
	last_tick = int(d.get("last_tick", _now()))
	age_sec = float(d.get("age_sec", 0.0))
	stage = str(d.get("stage", "bush"))
	# Migrate ancient egg saves
	if stage in ["egg", "hatchling", "kit"]:
		stage = "bush" if stage == "egg" else "baby"
	young_form = str(d.get("young_form", "puff"))
	teen_form = str(d.get("teen_form", ""))
	adult_form = str(d.get("adult_form", str(d.get("adult_variant", ""))))
	if adult_form in ["noble", ""]:
		adult_form = "saint"
	elif adult_form == "rascal":
		adult_form = "legend"
	teen_duration = float(d.get("teen_duration", randf_range(TEEN_SEC_MIN, TEEN_SEC_MAX)))
	adult_duration = float(d.get("adult_duration", randf_range(ADULT_SEC_MIN, ADULT_SEC_MAX)))
	lifespan_penalty = float(d.get("lifespan_penalty", 0.0))
	death_reason = str(d.get("death_reason", ""))
	var g = d.get("genes", {})
	genes = g if typeof(g) == TYPE_DICTIONARY else _roll_genes()
	hunger = float(d.get("hunger", 70.0))
	happy = float(d.get("happy", 70.0))
	health = float(d.get("health", 100.0))
	discipline = float(d.get("discipline", 50.0))
	fitness = float(d.get("fitness", 40.0))
	satiety = float(d.get("satiety", 0.0))
	weight = float(d.get("weight", 1.0))
	care_score = int(d.get("care_score", 0))
	care_mistakes = int(d.get("care_mistakes", 0))
	stubborn = bool(d.get("stubborn", false))
	stubborn_reason = str(d.get("stubborn_reason", ""))
	has_mess = bool(d.get("has_mess", false))
	sick = bool(d.get("sick", false))
	alive = bool(d.get("alive", true))
	ascending = bool(d.get("ascending", false))
	treat_streak = int(d.get("treat_streak", 0))
	healthy_meals = int(d.get("healthy_meals", 0))
	play_sessions = int(d.get("play_sessions", 0))
	energy = float(d.get("energy", 80.0))
	var fu = d.get("forms_unlocked", {})
	if typeof(fu) == TYPE_DICTIONARY:
		forms_unlocked = fu
	dev_mode = bool(d.get("dev_mode", false))
	dev_unlocked = bool(d.get("dev_unlocked", false)) or dev_mode
	sound_muted = bool(d.get("sound_muted", false))
	alerts_enabled = bool(d.get("alerts_enabled", false))
	# Dead / mid-ascension saves resume as a finished life — main starts a new bush.
	if not alive:
		ascending = false
	# Seed unlocks from current kit if migrating old saves
	unlock_current_form()


func save_game() -> void:
	last_tick = _now()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(to_dict()))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		speech.emit("A roadside bush shivers… something’s in there.")
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	from_dict(data)
