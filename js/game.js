/**
 * Jimothy — real-time cryptid care (web port of godot/scripts/pet_state.gd).
 */
(() => {
  const STORAGE_KEY = "jimothy-pet-v2";
  const TICK_MS = 1000;

  const BUSH_SEC = 60;
  const BABY_SEC = 3600; // 1 hour
  const YOUNG_SEC = 86400; // 24 hours
  const TEEN_SEC_MIN = 86400; // 24 hours
  const TEEN_SEC_MAX = 259200; // 72 hours
  const ADULT_SEC_MIN = 864000; // 10 days
  const ADULT_SEC_MAX = 1728000; // 20 days
  const ADULT_SEC_FLOOR = 86400; // neglect can shorten, not below 1 adult day

  const FOOD = {
    berries: {
      name: "Wild Berries",
      type: "healthy",
      hunger: 18,
      happy: 3,
      health: 6,
      fitness: 0,
      satiety: 22,
      refuse: 0.22,
      blurb: "Tart forest berries — light, clean fuel.",
    },
    crickets: {
      name: "Night Crickets",
      type: "healthy",
      hunger: 16,
      happy: 2,
      health: 5,
      fitness: 1,
      satiety: 20,
      refuse: 0.28,
      blurb: "Crunchy protein. Kits need this to grow strong legs.",
    },
    fish: {
      name: "Stream Fish Bits",
      type: "healthy",
      hunger: 24,
      happy: 4,
      health: 8,
      fitness: 1,
      satiety: 30,
      refuse: 0.18,
      blurb: "Rich scraps from the creek — fills him up properly.",
    },
    pizza: {
      name: "Pizza Crust",
      type: "treat",
      hunger: 10,
      happy: 16,
      health: -3,
      fitness: -1,
      satiety: 14,
      refuse: 0.04,
      blurb: "Greasy alley treasure. Mood up, tummy pays later.",
    },
    fries: {
      name: "Dumpster Fries",
      type: "treat",
      hunger: 9,
      happy: 18,
      health: -4,
      fitness: -1,
      satiety: 12,
      refuse: 0.06,
      blurb: "Salty chaos. Fine sometimes — not a meal plan.",
    },
  };

  const state = {
    bornAt: 0,
    lastTick: 0,
    ageSec: 0,
    stage: "bush",
    youngForm: "puff",
    teenForm: "",
    adultForm: "",
    teenDuration: TEEN_SEC_MIN,
    adultDuration: ADULT_SEC_MIN,
    lifespanPenalty: 0,
    deathReason: "",
    genes: {},
    hunger: 70,
    happy: 70,
    health: 100,
    discipline: 50,
    fitness: 40,
    satiety: 0,
    weight: 0.8,
    careScore: 0,
    careMistakes: 0,
    stubborn: false,
    stubbornReason: "",
    hasMess: false,
    sick: false,
    alive: true,
    ascending: false,
    treatStreak: 0,
    healthyMeals: 0,
    playSessions: 0,
    energy: 80,
    formsUnlocked: { young: {}, teen: {}, adult: {} },
    devMode: false,
    soundMuted: false,
  };

  const YOUNG_FORMS = ["puff", "looper", "shadow", "nub"];
  const TEEN_FORMS = ["dumpling", "bounder", "nightlane", "scruff"];
  const ADULT_FORMS = ["saint", "legend", "alley_ghost", "ballard_blip"];

  let speechTimer = 0;
  let tickHandle = 0;
  let animCooldown = 0;
  let lastAnimPulse = performance.now();
  let tapCooldown = 0;
  let smileUntil = 0;

  const $ = (id) => document.getElementById(id);

  function clamp(n, min = 0, max = 100) {
    return Math.max(min, Math.min(max, n));
  }

  function randRange(min, max) {
    return min + Math.random() * (max - min);
  }

  function capitalize(s) {
    if (!s) return "";
    return s.charAt(0).toUpperCase() + s.slice(1);
  }

  function nowMs() {
    return Date.now();
  }

  function rollGenes() {
    return {
      roundness: Math.random(),
      legginess: Math.random(),
      fluff: Math.random(),
      mask: Math.random(),
      pep: Math.random(),
      gray: Math.random(),
      ear_flare: Math.random(),
    };
  }

  function pickYoungForm(g) {
    if (g.roundness > 0.62 && g.fluff > 0.45) return "puff";
    if (g.legginess > 0.6 && g.pep > 0.4) return "looper";
    if (g.mask > 0.65) return "shadow";
    return "nub";
  }

  function pickTeenForm(young, g) {
    switch (young) {
      case "puff":
        return g.fluff > 0.5 ? "dumpling" : "scruff";
      case "looper":
        return g.pep > 0.45 ? "bounder" : "nightlane";
      case "shadow":
        return g.mask > 0.5 ? "nightlane" : "scruff";
      default:
        return g.legginess > 0.5 ? "bounder" : "dumpling";
    }
  }

  function pickAdultForm(teen) {
    const good =
      state.careScore >= 10 &&
      state.careMistakes <= 8 &&
      state.healthyMeals >= 4 &&
      state.fitness >= 45;
    switch (teen) {
      case "dumpling":
        return good ? "saint" : "ballard_blip";
      case "bounder":
        return good ? "alley_ghost" : "legend";
      case "nightlane":
        return good ? "alley_ghost" : "legend";
      case "scruff":
        return good ? "saint" : "ballard_blip";
      default:
        return good ? "saint" : "legend";
    }
  }

  function adultFormTitle(form = state.adultForm) {
    switch (form) {
      case "saint":
        return "Saint";
      case "legend":
        return "Legend";
      case "alley_ghost":
        return "Alley Ghost";
      case "ballard_blip":
        return "Ballard Blip";
      default:
        return "Cryptid";
    }
  }

  function bushEnd() {
    return BUSH_SEC;
  }
  function babyEnd() {
    return BUSH_SEC + BABY_SEC;
  }
  function youngEnd() {
    return babyEnd() + YOUNG_SEC;
  }
  function teenEnd() {
    return youngEnd() + state.teenDuration;
  }
  function effectiveAdultSpan() {
    return Math.max(ADULT_SEC_FLOOR, state.adultDuration - (state.lifespanPenalty || 0));
  }

  function lifeEnd() {
    return teenEnd() + effectiveAdultSpan();
  }

  function applyNeglectPenalty(seconds) {
    if (state.stage === "bush" || !state.alive) return;
    let rate = 0;
    if (state.hunger < 25) rate += 2.2;
    if (state.happy < 20) rate += 1.4;
    if (state.health < 35) rate += 2.8;
    if (state.hasMess) rate += 0.8;
    if (state.sick) rate += 1.6;
    if (state.discipline < 25) rate += 0.4;
    state.lifespanPenalty = (state.lifespanPenalty || 0) + rate * seconds;
  }

  function endLife(reason) {
    if (state.ascending) return;
    state.alive = false;
    state.ascending = true;
    state.deathReason = reason;
    state.stubborn = false;
    if (reason === "lifespan") {
      say("His time is done. Wings catch the moonlight…");
    } else if (reason === "neglect") {
      say("Poor care wore him thin. Wings unfold anyway…");
    } else {
      say("Jimothy’s life is over. He rises into the sky…");
    }
    pulseAnim("ascend");
    sfx("ascend");
    render();
    save();
    // After the rise, clear the pet and show the rustling bush under the farewell.
    setTimeout(() => {
      startNextKitAfterAscension(reason);
    }, 4200);
  }

  function deathWhy(reason) {
    const r = reason || state.deathReason;
    if (r === "neglect") return "Poor care shortened his time.";
    if (r === "lifespan") return "He lived out his cryptid span.";
    return "His story has ended.";
  }

  function startNextKitAfterAscension(reason) {
    const why = deathWhy(reason);
    state.ascending = false;
    resetPet();
    showMessage(
      "Jimothy ascended",
      `${why} He grew wings and rose into the sky.\n\nA new bush is rustling…`
    );
    $("messageOk").textContent = "OK";
    $("messageOk").dataset.reset = "";
    render();
  }

  function stageLabel() {
    switch (state.stage) {
      case "bush":
        return "Bush";
      case "baby":
        return "Baby Kit";
      case "young":
        return "Young Kit";
      case "teen":
        return "Teen Kit";
      case "adult":
        return "Adult";
      default:
        return capitalize(state.stage);
    }
  }

  function stageName() {
    if (state.ascending) return "Ascending…";
    if (!state.alive) return "Gone to the night…";
    switch (state.stage) {
      case "bush":
        return "Rustling Bush";
      case "baby":
        return "Baby Kit Jimothy";
      case "young":
        return `${capitalize(state.youngForm)} Young Kit`;
      case "teen":
        return `${capitalize(state.teenForm || "Mystery")} Teen Kit`;
      case "adult":
        return `${adultFormTitle()} Jimothy`;
      default:
        return "Jimothy";
    }
  }

  function formProfile() {
    return {
      stage: state.stage,
      youngForm: state.youngForm,
      teenForm: state.teenForm,
      adultForm: state.adultForm,
      genes: state.genes,
      fitness: state.fitness,
      ageSec: state.ageSec,
      smiling: performance.now() < smileUntil,
    };
  }

  function interactTap() {
    if (state.ascending || !state.alive) return "";
    if (tapCooldown > 0) return "";
    tapCooldown = 0.55;

    if (state.stage === "bush") {
      say("The bush shivers under your hand…");
      pulseAnim("rustle");
      sfx("bush");
      render();
      return "rustle";
    }

    const roll = Math.random();
    let kind = "smile";
    if (state.stubborn) {
      kind = roll < 0.55 ? "refuse" : "sniff";
      say("He side-eyes you. Still sulking.");
    } else if (state.sick) {
      kind = "sniff";
      say("A weak little chitter.");
    } else if (state.stage === "baby") {
      kind = roll < 0.45 ? "hop" : roll < 0.8 ? "smile" : "nuzzle";
    } else if (state.energy < 25) {
      kind = roll < 0.6 ? "nuzzle" : "smile";
    } else if (state.happy > 70 && roll < 0.35) {
      kind = "hop";
    } else if (roll < 0.28) {
      kind = "hop";
    } else if (roll < 0.5) {
      kind = "nuzzle";
    } else if (roll < 0.62) {
      kind = "spin";
    } else {
      kind = "smile";
    }

    if (["smile", "hop", "nuzzle", "spin"].includes(kind)) {
      state.happy = clamp(state.happy + 4);
    } else {
      state.happy = clamp(state.happy + 1);
    }

    if (kind === "smile") {
      say(["He grins at you.", "Happy raccoon eyes!", "He leans into the pets."][Math.floor(Math.random() * 3)]);
      smileUntil = performance.now() + 950;
      bounceHappy();
      sfx("pet");
    } else if (kind === "hop") {
      say(["Boing!", "He hops for attention.", "Tiny cryptid bounce!"][Math.floor(Math.random() * 3)]);
      smileUntil = performance.now() + 700;
      sfx("pet");
    } else if (kind === "nuzzle") {
      say(["He nuzzles your finger.", "Soft headbonk.", "Purr-adjacent chitter."][Math.floor(Math.random() * 3)]);
      smileUntil = performance.now() + 900;
      sfx("pet");
    } else if (kind === "spin") {
      say(["Zoomies!", "A silly spin!", "He whirls in place."][Math.floor(Math.random() * 3)]);
      smileUntil = performance.now() + 850;
      sfx("pet");
    } else if (kind === "refuse") {
      sfx("refuse");
    }

    pulseAnim(kind);
    render();
    if (Math.random() < 0.35) save({ touchTick: false });
    setTimeout(() => render(), 1000);
    return kind;
  }

  function resetDefaults() {
    const t = nowMs();
    Object.assign(state, {
      bornAt: t,
      lastTick: t,
      ageSec: 0,
      stage: "bush",
      genes: rollGenes(),
      youngForm: "puff",
      teenForm: "",
      adultForm: "",
      teenDuration: randRange(TEEN_SEC_MIN, TEEN_SEC_MAX),
      adultDuration: randRange(ADULT_SEC_MIN, ADULT_SEC_MAX),
      lifespanPenalty: 0,
      deathReason: "",
      hunger: 70,
      happy: 70,
      health: 100,
      discipline: 50,
      fitness: 40,
      satiety: 0,
      weight: 0.8,
      careScore: 0,
      careMistakes: 0,
      stubborn: false,
      stubbornReason: "",
      hasMess: false,
      sick: false,
      alive: true,
      ascending: false,
      treatStreak: 0,
      healthyMeals: 0,
      playSessions: 0,
      energy: 80,
      formsUnlocked: state.formsUnlocked || { young: {}, teen: {}, adult: {} },
      devMode: !!state.devMode,
      soundMuted: !!state.soundMuted,
    });
    state.youngForm = pickYoungForm(state.genes);
    if ($("messageOk")) $("messageOk").textContent = "OK";
  }

  function sfx(kind) {
    if (window.JimothySound) JimothySound.cue(kind);
  }

  function refreshSoundButton() {
    const btn = $("btnSound");
    if (!btn) return;
    const on = window.JimothySound ? JimothySound.isEnabled() : !state.soundMuted;
    btn.textContent = on ? "Sound: On" : "Sound: Off";
    btn.setAttribute("aria-pressed", on ? "true" : "false");
  }

  function setSoundEnabled(on) {
    state.soundMuted = !on;
    if (window.JimothySound) JimothySound.setEnabled(on);
    refreshSoundButton();
    save({ touchTick: false });
  }

  function load() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return false;
      const saved = JSON.parse(raw);
      Object.assign(state, saved);
      // Migrate ancient egg saves if somehow present
      if (state.stage === "egg") state.stage = "bush";
      if (state.stage === "hatchling" || state.stage === "kit") state.stage = "baby";
      if (!state.genes || typeof state.genes !== "object") state.genes = rollGenes();
      if (!state.youngForm) state.youngForm = pickYoungForm(state.genes);
      if (state.adultForm === "noble" || state.adultVariant === "noble") state.adultForm = "saint";
      if (state.adultForm === "rascal" || state.adultVariant === "rascal") state.adultForm = "legend";
      if (!state.teenDuration) state.teenDuration = randRange(TEEN_SEC_MIN, TEEN_SEC_MAX);
      if (!state.adultDuration) state.adultDuration = randRange(ADULT_SEC_MIN, ADULT_SEC_MAX);
      if (state.energy == null) state.energy = 80;
      if (state.fitness == null) state.fitness = 40;
      if (state.satiety == null) state.satiety = 0;
      if (!state.formsUnlocked) state.formsUnlocked = { young: {}, teen: {}, adult: {} };
      if (state.devMode == null) state.devMode = false;
      if (state.soundMuted == null) state.soundMuted = false;
      unlockCurrentForm();
      syncRealtime({ announceDeath: false });
      return true;
    } catch {
      return false;
    }
  }

  function save({ touchTick = true } = {}) {
    if (touchTick) state.lastTick = nowMs();
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  }

  function syncRealtime({ announceDeath = true } = {}) {
    const now = nowMs();
    const last = state.lastTick || now;
    const elapsed = Math.max(0, Math.floor((now - last) / 1000));
    if (elapsed > 0 && state.alive) applyDecay(elapsed);
    state.lastTick = now;
    // Death path handled by endLife → ascension → raise-another-kit prompt
    void announceDeath;
    return elapsed;
  }

  function unlockForm(bucket, formId) {
    if (!formId) return;
    if (!state.formsUnlocked[bucket]) state.formsUnlocked[bucket] = {};
    if (!state.formsUnlocked[bucket][formId]) {
      state.formsUnlocked[bucket][formId] = true;
      say(`Form unlocked: ${capitalize(bucket)} ${prettyForm(formId)}`);
    }
  }

  function unlockCurrentForm() {
    if (state.stage === "young") unlockForm("young", state.youngForm);
    if (state.stage === "teen" && state.teenForm) unlockForm("teen", state.teenForm);
    if (state.stage === "adult" && state.adultForm) unlockForm("adult", state.adultForm);
  }

  function prettyForm(id) {
    return String(id || "")
      .replace(/_/g, " ")
      .replace(/\b\w/g, (c) => c.toUpperCase());
  }

  function isFormUnlocked(bucket, formId) {
    return !!(state.formsUnlocked[bucket] && state.formsUnlocked[bucket][formId]);
  }

  function resetPet() {
    const keepForms = JSON.parse(JSON.stringify(state.formsUnlocked || { young: {}, teen: {}, adult: {} }));
    const keepDev = !!state.devMode;
    const keepMute = !!state.soundMuted;
    resetDefaults();
    state.formsUnlocked = keepForms;
    state.devMode = keepDev;
    state.soundMuted = keepMute;
    save();
    if (window.RaccoonAnim) RaccoonAnim.reset();
    render();
    say("A roadside bush shivers… something’s in there.");
    sfx("bush");
  }

  function setDevMode(on) {
    state.devMode = !!on;
    render();
    save({ touchTick: false });
  }

  function devSkipTo(target) {
    if (!state.devMode) {
      say("Turn Dev Mode ON first.");
      return;
    }
    state.alive = true;
    state.ascending = false;
    state.deathReason = "";
    state.stubborn = false;
    state.hasMess = false;
    state.sick = false;
    state.hunger = 75;
    state.happy = 75;
    state.health = 95;
    state.energy = 80;
    state.satiety = 20;

    if (target === "bush") {
      state.stage = "bush";
      state.ageSec = 5;
    } else if (target === "baby") {
      state.stage = "baby";
      state.ageSec = bushEnd() + 2;
      state.weight = 1.2;
    } else if (target === "young") {
      state.stage = "young";
      state.ageSec = babyEnd() + 2;
      state.youngForm = pickYoungForm(state.genes);
      state.weight = 3.5;
      unlockCurrentForm();
    } else if (target === "teen") {
      state.stage = "teen";
      state.ageSec = youngEnd() + 2;
      if (!state.youngForm) state.youngForm = pickYoungForm(state.genes);
      unlockForm("young", state.youngForm);
      state.teenForm = pickTeenForm(state.youngForm, state.genes);
      state.teenDuration = randRange(TEEN_SEC_MIN, TEEN_SEC_MAX);
      state.weight = 7;
      unlockCurrentForm();
    } else if (target === "adult") {
      state.stage = "adult";
      if (!state.youngForm) state.youngForm = pickYoungForm(state.genes);
      unlockForm("young", state.youngForm);
      if (!state.teenForm) state.teenForm = pickTeenForm(state.youngForm, state.genes);
      unlockForm("teen", state.teenForm);
      state.adultForm = pickAdultForm(state.teenForm);
      state.adultDuration = randRange(ADULT_SEC_MIN, ADULT_SEC_MAX);
      state.ageSec = teenEnd() + 2;
      state.genes.legginess = clamp(state.genes.legginess * 0.5 + 0.55, 0, 1);
      state.genes.roundness = clamp(state.genes.roundness * 0.4 + 0.65, 0, 1);
      state.weight = 11;
      unlockCurrentForm();
    } else if (target === "ascend") {
      if (state.stage !== "adult") devSkipTo("adult");
      endLife("lifespan");
      return;
    } else {
      return;
    }

    state.lastTick = nowMs();
    say(`Dev: jumped to ${target}.`);
    pulseAnim(target === "baby" ? "pop" : "stretch");
    render();
    save();
  }

  function applyDecay(seconds) {
    if (!state.alive) return;

    const hungerRate = state.stage !== "bush" ? 0.0028 : 0;
    const happyRate = state.stage !== "bush" ? 0.0022 : 0;
    const energyRate = state.stage !== "bush" ? 0.0015 : 0;

    state.hunger = clamp(state.hunger - hungerRate * seconds);
    state.happy = clamp(state.happy - happyRate * seconds);
    state.energy = clamp(state.energy - energyRate * seconds);
    state.satiety = Math.max(0, state.satiety - 0.02 * seconds);
    state.ageSec += seconds;

    if (state.hasMess) {
      state.health = clamp(state.health - 0.0012 * seconds);
      state.happy = clamp(state.happy - 0.001 * seconds);
    }
    if (state.hunger < 20 && state.stage !== "bush") {
      state.health = clamp(state.health - 0.0025 * seconds);
      state.happy = clamp(state.happy - 0.0015 * seconds);
    }
    if (state.happy < 15 && state.stage !== "bush") {
      state.health = clamp(state.health - 0.001 * seconds);
    }
    if (state.treatStreak > 3) {
      state.health = clamp(state.health - 0.0008 * seconds);
      state.sick = true;
    }
    if (state.energy < 15) {
      state.happy = clamp(state.happy - 0.0005 * seconds);
    }

    applyNeglectPenalty(seconds);

    if (state.stage !== "bush" && !state.hasMess && Math.random() < seconds * 0.00025) {
      state.hasMess = true;
    }

    maybeTantrum(seconds);
    evolveIfNeeded();

    if (state.stage === "adult" && state.ageSec >= lifeEnd()) {
      const shortened = (state.lifespanPenalty || 0) > state.adultDuration * 0.15;
      endLife(shortened ? "neglect" : "lifespan");
    } else if (
      state.health <= 0 ||
      (state.hunger <= 0 && state.happy <= 0 && state.stage !== "bush")
    ) {
      state.health = 0;
      endLife("neglect");
    }
  }

  function maybeTantrum(seconds) {
    if (state.stage === "bush" || state.stage === "baby" || state.stubborn || !state.alive) {
      return;
    }
    let chance = (0.00015 + (100 - state.discipline) * 0.000002) * seconds;
    if (state.hunger < 30) chance *= 1.4;
    if (Math.random() < chance) {
      state.stubborn = true;
      state.stubbornReason =
        Math.random() < 0.5 ? "refuses a proper meal" : "refuses to exercise";
      state.careMistakes += 1;
      state.lifespanPenalty = (state.lifespanPenalty || 0) + 5400;
    }
  }

  function evolveIfNeeded() {
    if (!state.alive) return;
    const prev = state.stage;

    if (state.stage === "bush" && state.ageSec >= bushEnd()) {
      state.stage = "baby";
      state.weight = 1.2;
      state.happy = clamp(state.happy + 10);
      say("The bush explodes in leaves — baby kit Jimothy!");
      pulseAnim("pop");
      sfx("baby");
      showMessage(
        "Baby Kit!",
        "Jimothy burst from the bush. Keep him fed — young kit in ~1 hour."
      );
    } else if (state.stage === "baby" && state.ageSec >= babyEnd()) {
      state.stage = "young";
      state.youngForm = pickYoungForm(state.genes);
      state.weight = 3.5;
      say(`He’s a young kit now — form: ${capitalize(state.youngForm)}.`);
      pulseAnim("stretch");
      sfx("stage");
      unlockCurrentForm();
      showMessage(
        "Young Kit!",
        `Form: ${capitalize(state.youngForm)}. His teen/adult path is already leaning this way.`
      );
    } else if (state.stage === "young" && state.ageSec >= youngEnd()) {
      state.stage = "teen";
      state.teenForm = pickTeenForm(state.youngForm, state.genes);
      state.weight = 7;
      state.teenDuration = randRange(TEEN_SEC_MIN, TEEN_SEC_MAX);
      say(`Teen kit era. He’s turning into a ${state.teenForm}.`);
      pulseAnim("run");
      sfx("stage");
      unlockCurrentForm();
      showMessage(
        "Teen Kit!",
        `Form: ${capitalize(state.teenForm)}. Adult Jimothy arrives in 1–3 real days.`
      );
    } else if (state.stage === "teen" && state.ageSec >= teenEnd()) {
      state.stage = "adult";
      const teen = state.teenForm || pickTeenForm(state.youngForm, state.genes);
      state.adultForm = pickAdultForm(teen);
      const careQ = Math.max(
        0,
        Math.min(
          1,
          state.careScore * 0.04 +
            state.healthyMeals * 0.03 +
            state.fitness * 0.004 -
            state.careMistakes * 0.05
        )
      );
      state.adultDuration = ADULT_SEC_MIN + (ADULT_SEC_MAX - ADULT_SEC_MIN) * careQ;
      state.adultDuration = Math.max(
        ADULT_SEC_FLOOR,
        state.adultDuration - (state.lifespanPenalty || 0) * 0.35
      );
      state.weight = 11 + state.fitness * 0.03;
      state.genes.legginess = clamp(state.genes.legginess * 0.5 + 0.55, 0, 1);
      state.genes.roundness = clamp(state.genes.roundness * 0.4 + 0.65, 0, 1);
      say(`Fully grown — ${adultFormTitle()} Jimothy, midnight cryptid.`);
      pulseAnim("lope");
      sfx("stage");
      unlockCurrentForm();
      showMessage(
        "Adult Cryptid!",
        `${adultFormTitle()} Jimothy — care well and he may linger longer; neglect shortens his sky-bound days.`
      );
    }

    if (prev !== state.stage) save();
  }

  function alertText() {
    if (state.ascending) {
      return { text: "Jimothy grows wings and rises into the sky…", danger: false };
    }
    if (!state.alive) {
      return { text: "His life is over. You can raise another kit.", danger: true };
    }
    if (state.stage === "bush") {
      return { text: "The bush is rustling. Wait — something’s waking.", danger: false };
    }
    if (state.sick) {
      return { text: "Upset stomach from too much junk food.", danger: true };
    }
    if (state.stubborn) {
      return { text: `Acting up — ${state.stubbornReason}. Scold him.`, danger: true };
    }
    if (state.hasMess) {
      return { text: "He’s marked the nest. Clean it up.", danger: false };
    }
    if (state.energy < 20) {
      return { text: "Winded. Let him rest before more exercise.", danger: false };
    }
    if (state.satiety > 75) {
      return { text: "Full belly — forcing food won’t help.", danger: false };
    }
    if (state.hunger < 25) {
      return { text: "He’s hunting for a real meal.", danger: true };
    }
    if (state.happy < 25) {
      return { text: "Restless cryptid energy. Try a night run (Play).", danger: false };
    }
    if (state.health < 30) {
      return { text: "He’s run-down — skip treats, offer fish or berries.", danger: true };
    }
    return null;
  }

  function formatAge() {
    const s = Math.floor(state.ageSec);
    const days = Math.floor(s / 86400);
    const hours = Math.floor((s % 86400) / 3600);
    const mins = Math.floor((s % 3600) / 60);
    if (days > 0) return `Age ${days}d ${hours}h`;
    if (hours > 0) return `Age ${hours}h ${mins}m`;
    if (mins > 0) return `Age ${mins}m`;
    return `Age ${s}s`;
  }

  function clockNow() {
    const d = new Date();
    return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  }

  function say(text, ms = 2800) {
    const el = $("speech");
    el.hidden = false;
    el.textContent = text;
    clearTimeout(speechTimer);
    speechTimer = setTimeout(() => {
      el.hidden = true;
    }, ms);
  }

  function showMessage(title, body) {
    $("messageTitle").textContent = title;
    $("messageBody").textContent = body;
    $("messageModal").hidden = false;
  }

  function hideMessage() {
    $("messageModal").hidden = true;
  }

  function pulseAnim(kind, opts = {}) {
    if (window.RaccoonAnim) RaccoonAnim.play(kind, opts);
    animCooldown = randRange(1.2, 3.2);
  }

  function ambientAnim(dt) {
    tapCooldown = Math.max(0, tapCooldown - dt);
    if (!state.alive || state.ascending || state.stage === "bush") return;
    animCooldown -= dt;
    if (animCooldown > 0) return;

    if (state.stubborn || state.sick) {
      animCooldown = randRange(2.2, 3.6);
      pulseAnim(state.stubborn ? "stubborn" : "sick");
      return;
    }

    const peppy =
      ["looper", "nub"].includes(state.youngForm) ||
      state.teenForm === "bounder" ||
      state.fitness > 55;
    const sneaky =
      state.youngForm === "shadow" ||
      state.teenForm === "nightlane" ||
      state.adultForm === "alley_ghost";
    const roll = Math.random();
    let kind = "idle";
    if (state.energy > 55 && state.happy > 50 && roll < (peppy ? 0.42 : 0.32)) {
      kind = peppy && roll < 0.18 ? (state.fitness > 45 ? "run" : "jump") : "walk";
    } else if (roll < 0.5) {
      kind = "walk";
    } else if (roll < 0.66) {
      kind = peppy ? "jump" : "sniff";
    } else if (roll < 0.78) {
      kind = state.stage === "adult" ? "lope" : state.stage !== "baby" ? "stretch" : "sniff";
    } else if (roll < 0.9) {
      kind = sneaky || state.stage === "baby" ? "sniff" : "stretch";
    } else {
      kind = "idle";
    }
    pulseAnim(kind);
  }

  function render() {
    $("clock").textContent = clockNow();
    $("ageLabel").textContent = formatAge();
    $("stageChip").textContent = stageLabel();
    $("stageName").textContent = stageName();

    $("hungerFill").style.width = `${state.hunger}%`;
    $("happyFill").style.width = `${state.happy}%`;
    $("healthFill").style.width = `${state.health}%`;
    $("disciplineFill").style.width = `${state.discipline}%`;

    const wrap = $("raccoonWrap");
    wrap.classList.toggle("stubborn", state.stubborn && state.alive);
    wrap.classList.toggle("sick", state.sick && state.alive);
    wrap.classList.toggle("ascending", !!state.ascending);

    const raccoon = $("raccoon");
    const showBody = state.alive || state.ascending;
    raccoon.dataset.stage = showBody ? state.stage : "gone";
    raccoon.dataset.mood = state.ascending
      ? "ascend"
      : !state.alive
        ? "gone"
        : state.stubborn
          ? "stubborn"
          : state.sick
            ? "sick"
            : "idle";
    raccoon.dataset.form =
      state.stage === "adult"
        ? state.adultForm
        : state.stage === "teen"
          ? state.teenForm
          : state.stage === "young"
            ? state.youngForm
            : "";

    raccoon.innerHTML = showBody
      ? RaccoonArt.render(formProfile())
      : RaccoonArt.render({ stage: "bush", ageSec: 0, genes: {} });

    if (window.RaccoonAnim) {
      RaccoonAnim.sync({
        stage: showBody ? state.stage : "bush",
        ageSec: state.ageSec,
        alive: showBody,
        ascending: !!state.ascending,
      });
    }

    $("mess").hidden = !(state.hasMess && state.alive);

    const alert = alertText();
    const banner = $("alertBanner");
    if (alert) {
      banner.hidden = false;
      banner.textContent = alert.text;
      banner.classList.toggle("danger", alert.danger);
    } else {
      banner.hidden = true;
    }

    const canCare = state.alive && state.stage !== "bush" && !state.ascending;
    $("btnDiscipline").disabled = !(state.alive && state.stubborn);
    $("btnClean").disabled = !(state.alive && state.hasMess);
    $("btnFeed").disabled = !canCare;
    $("btnPlay").disabled =
      !state.alive || state.ascending || state.stage === "bush" || state.stage === "baby";

    $("btnDiscipline").classList.toggle("needs-attention", state.stubborn && state.alive);
    $("btnClean").classList.toggle("needs-attention", state.hasMess && state.alive);

    const btnDev = $("btnDev");
    if (btnDev) btnDev.textContent = state.devMode ? "Dev mode ✓" : "Dev mode";

    if (state.ascending) {
      $("hint").textContent = "Watch… Jimothy grows wings and rises into the sky.";
    } else if (state.stage === "bush") {
      $("hint").textContent =
        "Tap the bush to rustle it. A baby kit may pop out soon.";
    } else if (!state.alive) {
      $("hint").textContent =
        "His cryptid life is complete. You can raise another kit.";
    } else if (state.stage === "baby") {
      $("hint").textContent =
        "Tap Jimothy for smiles and hops. Too tiny for a full night run yet.";
    } else {
      $("hint").textContent =
        "Tap Jimothy to pet him. Good care lengthens his days — check Form paths.";
    }
  }

  function formPathsHtml() {
    // Young → teen forks → adult (good care / neglect)
    const paths = [
      ["puff", ["dumpling", "scruff"]],
      ["looper", ["bounder", "nightlane"]],
      ["shadow", ["nightlane", "scruff"]],
      ["nub", ["bounder", "dumpling"]],
    ];
    const teenAdult = {
      dumpling: ["saint", "ballard_blip"],
      bounder: ["alley_ghost", "legend"],
      nightlane: ["alley_ghost", "legend"],
      scruff: ["saint", "ballard_blip"],
    };
    const mark = (bucket, id) => {
      const unlocked = isFormUnlocked(bucket, id);
      const current =
        (bucket === "young" && state.stage !== "bush" && state.stage !== "baby" && state.youngForm === id) ||
        (bucket === "teen" && state.teenForm === id) ||
        (bucket === "adult" && state.adultForm === id);
      return `<span class="path-node ${unlocked ? "unlocked" : "locked"} ${
        current ? "current" : ""
      }" title="${unlocked ? "Unlocked" : "Not unlocked yet"}">${prettyForm(id)}</span>`;
    };
    return paths
      .map(([young, teens]) => {
        const teenBlocks = teens
          .map((teen) => {
            const [good, neglect] = teenAdult[teen];
            return `<div class="path-branch">
              ${mark("teen", teen)}
              <span class="path-arrow">→</span>
              <span class="path-adults">
                <span class="path-care">care ${mark("adult", good)}</span>
                <span class="path-neglect">neglect ${mark("adult", neglect)}</span>
              </span>
            </div>`;
          })
          .join("");
        return `<div class="path-card">
          <div class="path-young">${mark("young", young)}</div>
          <div class="path-forks">${teenBlocks}</div>
        </div>`;
      })
      .join("");
  }

  function refreshFormsList() {
    const root = $("formsList");
    if (!root) return;
    const unlockedBits = [
      ["Young", "young", YOUNG_FORMS],
      ["Teen", "teen", TEEN_FORMS],
      ["Adult", "adult", ADULT_FORMS],
    ]
      .map(([label, bucket, forms]) => {
        const got = forms.filter((f) => isFormUnlocked(bucket, f)).length;
        return `${label} ${got}/${forms.length}`;
      })
      .join(" · ");
    root.innerHTML = `
      <div class="forms-section">Evolution paths</div>
      <p class="path-legend">Young kit forks into teen shapes, then adult flair depends on care vs neglect. Adults always keep the short-spine Jimothy look.</p>
      <div class="path-tree">${formPathsHtml()}</div>
      <div class="forms-section">Unlocked · ${unlockedBits}</div>
      <p class="path-legend">Bright nodes are unlocked. Amber outline marks this kit’s path.</p>
    `;
  }

  function refreshDevStatus() {
    const el = $("devStatus");
    if (!el) return;
    el.textContent = `Dev Mode: ${state.devMode ? "ON" : "OFF"} · Stage: ${stageLabel()} · ${formatAge()}`;
  }

  function openFeed() {
    if (!state.alive || state.stage === "bush") return;
    $("feedModal").hidden = false;
  }

  function closeFeed() {
    $("feedModal").hidden = true;
  }

  function feed(foodKey) {
    const food = FOOD[foodKey];
    if (!food || !state.alive || state.stage === "bush") return;

    if (state.satiety >= 85) {
      say("He turns his nose away — still digesting.");
      pulseAnim("refuse");
      sfx("refuse");
      closeFeed();
      render();
      return;
    }

    if (state.stubborn && food.type === "healthy") {
      say(`Nope. He buries the ${food.name.toLowerCase()} under a leaf.`);
      pulseAnim("refuse");
      sfx("refuse");
      closeFeed();
      render();
      return;
    }

    const disciplineFactor = (100 - state.discipline) / 100;
    if (
      food.type === "healthy" &&
      Math.random() < food.refuse * (0.4 + disciplineFactor)
    ) {
      state.stubborn = true;
      state.stubbornReason = "refuses a proper meal";
      state.careMistakes += 1;
      state.lifespanPenalty = (state.lifespanPenalty || 0) + 3600;
      say(`Jimothy bats the ${food.name.toLowerCase()} away!`);
      pulseAnim("refuse");
      sfx("refuse");
      closeFeed();
      render();
      save();
      return;
    }

    state.hunger = clamp(state.hunger + food.hunger);
    state.happy = clamp(state.happy + food.happy);
    state.health = clamp(state.health + food.health);
    state.fitness = clamp(state.fitness + food.fitness);
    state.satiety = clamp(state.satiety + food.satiety);
    state.weight += food.type === "treat" ? 0.35 : 0.15;
    state.energy = clamp(state.energy + (food.type === "healthy" ? 4 : 1));

    if (food.type === "treat") {
      state.treatStreak += 1;
      if (state.treatStreak >= 4) {
        state.sick = true;
        state.health = clamp(state.health - 8);
        say("Too much alley grease… he flops, queasy.");
        pulseAnim("sick");
      } else {
        say(`He stash-eats the ${food.name}.`);
        pulseAnim("eat", { food: foodKey });
        sfx("eat");
        bounceHappy();
      }
    } else {
      state.treatStreak = 0;
      state.healthyMeals += 1;
      state.careScore += 1;
      if (state.health > 40) state.sick = false;
      state.discipline = clamp(state.discipline + 1.5);
      say(`He forages the ${food.name} carefully.`);
      pulseAnim("eat", { food: foodKey });
      sfx("eat");
      bounceHappy();
    }

    closeFeed();
    render();
    save();
  }

  function bounceHappy() {
    const wrap = $("raccoonWrap");
    wrap.classList.remove("happy");
    void wrap.offsetWidth;
    wrap.classList.add("happy");
    setTimeout(() => wrap.classList.remove("happy"), 600);
  }

  function discipline() {
    if (!state.alive || !state.stubborn) return;
    state.stubborn = false;
    state.stubbornReason = "";
    state.discipline = clamp(state.discipline + 10);
    state.happy = clamp(state.happy - 5);
    state.careScore += 1;
    say("A firm chitter. He listens… for now.");
    pulseAnim("scold");
    sfx("scold");
    render();
    save();
  }

  function clean() {
    if (!state.alive || !state.hasMess) return;
    state.hasMess = false;
    state.happy = clamp(state.happy + 3);
    state.health = clamp(state.health + 2);
    state.careScore += 1;
    say("Nest cleared. He sniffs approval.");
    sfx("clean");
    render();
    save();
  }

  function canStartPlay() {
    if (!state.alive || state.stage === "bush" || state.stage === "baby") {
      if (state.stage === "baby") {
        say("Too tiny for a full dumpster run — let him wobble first.");
      }
      render();
      return "blocked";
    }
    if (state.energy < 18) {
      say("He’s wiped. Rest a bit, then try again.");
      render();
      return "tired";
    }
    if (state.stubborn && state.stubbornReason.includes("exercise")) {
      say("He plants his paws. No night run until you scold him.");
      render();
      return "stubborn";
    }
    if (!state.stubborn && state.discipline < 35 && Math.random() < 0.3) {
      state.stubborn = true;
      state.stubbornReason = "refuses to exercise";
      state.careMistakes += 1;
      say("He flops dramatically. Absolutely not chasing trash.");
      render();
      save();
      return "stubborn";
    }
    return "ok";
  }

  function openGame() {
    if (canStartPlay() !== "ok") return;
    sfx("play");
    $("gameModal").hidden = false;
    DumpsterDive.start(onGameDone);
  }

  function closeGame() {
    DumpsterDive.stop(false);
    $("gameModal").hidden = true;
  }

  function onGameDone(result) {
    $("gameModal").hidden = true;
    if (!state.alive) return;

    if (!result.completed && result.score === 0) {
      say("He peeks from the alley and bails.");
      return;
    }

    state.playSessions += 1;
    const burn = 8 + result.stars * 3;
    state.happy = clamp(state.happy + 8 + result.stars * 5);
    state.hunger = clamp(state.hunger - burn * 0.7);
    state.energy = clamp(state.energy - (20 + result.stars * 4));
    state.health = clamp(state.health + 2 + result.stars);
    state.fitness = clamp(state.fitness + 3 + result.stars * 2);
    state.discipline = clamp(state.discipline + 2);
    state.careScore += result.stars > 0 ? 2 : 1;
    state.weight = Math.max(1, state.weight - 0.12 * result.stars);
    state.genes.legginess = clamp(state.genes.legginess + result.stars * 0.01, 0, 1);

    bounceHappy();
    if (result.stars >= 3) {
      say("A legendary night lope — treasure secured.");
      pulseAnim("run");
    } else if (result.stars >= 1) {
      say(`Solid forage run. Score ${result.score}.`);
      pulseAnim("walk");
    } else {
      say(`A sleepy shuffle. Score ${result.score}.`);
    }
    render();
    save();
  }

  function onTick() {
    if (!state.alive) {
      render();
      return;
    }
    applyDecay(1);
    render();
    save();
  }

  function wireIcons() {
    $("btnFeed").querySelector(".ctrl-icon").innerHTML = RaccoonArt.icons.feed;
    $("btnPlay").querySelector(".ctrl-icon").innerHTML = RaccoonArt.icons.play;
    $("btnDiscipline").querySelector(".ctrl-icon").innerHTML = RaccoonArt.icons.scold;
    $("btnClean").querySelector(".ctrl-icon").innerHTML = RaccoonArt.icons.clean;

    document.querySelectorAll(".food-btn").forEach((btn) => {
      const key = btn.dataset.food;
      const art = btn.querySelector(".food-art");
      if (art && RaccoonArt.icons[key]) art.innerHTML = RaccoonArt.icons[key];
    });
  }

  function bind() {
    $("btnFeed").addEventListener("click", openFeed);
    $("btnPlay").addEventListener("click", openGame);
    $("btnDiscipline").addEventListener("click", discipline);
    $("btnClean").addEventListener("click", clean);
    const wrap = $("raccoonWrap");
    if (wrap) {
      wrap.style.cursor = "pointer";
      wrap.setAttribute("role", "button");
      wrap.setAttribute("aria-label", "Pet Jimothy");
      wrap.tabIndex = 0;
      wrap.addEventListener("pointerdown", (e) => {
        // Avoid stealing clicks from mess clean overlay if present
        if (e.target.closest && e.target.closest("#mess")) return;
        interactTap();
      });
      wrap.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          interactTap();
        }
      });
    }
    if ($("btnSound")) {
      $("btnSound").addEventListener("click", () => {
        const next = window.JimothySound ? !JimothySound.isEnabled() : state.soundMuted;
        setSoundEnabled(next);
      });
    }
    $("feedClose").addEventListener("click", closeFeed);
    $("gameClose").addEventListener("click", closeGame);
    $("messageOk").addEventListener("click", () => {
      const shouldReset = $("messageOk").dataset.reset === "1";
      hideMessage();
      $("messageOk").textContent = "OK";
      $("messageOk").dataset.reset = "";
      // Legacy: only reset if a dialog still asked to raise another kit.
      if (shouldReset && !state.alive) {
        resetPet();
      }
    });

    document.querySelectorAll(".food-btn").forEach((btn) => {
      if (btn.dataset.food) btn.addEventListener("click", () => feed(btn.dataset.food));
    });

    $("feedModal").addEventListener("click", (e) => {
      if (e.target === $("feedModal")) closeFeed();
    });

    const btnForms = $("btnForms");
    const btnDev = $("btnDev");
    if (btnForms) {
      btnForms.addEventListener("click", () => {
        refreshFormsList();
        $("formsModal").hidden = false;
      });
    }
    if ($("formsClose")) {
      $("formsClose").addEventListener("click", () => {
        $("formsModal").hidden = true;
      });
    }
    if (btnDev) {
      btnDev.addEventListener("click", () => {
        refreshDevStatus();
        $("devModal").hidden = false;
      });
    }
    if ($("devClose")) {
      $("devClose").addEventListener("click", () => {
        $("devModal").hidden = true;
      });
    }
    if ($("devToggle")) {
      $("devToggle").addEventListener("click", () => {
        setDevMode(!state.devMode);
        refreshDevStatus();
      });
    }
    document.querySelectorAll("[data-dev-skip]").forEach((btn) => {
      btn.addEventListener("click", () => {
        devSkipTo(btn.dataset.devSkip);
        $("devModal").hidden = true;
      });
    });
  }

  function animLoop(now) {
    const dt = Math.min(0.05, (now - lastAnimPulse) / 1000);
    lastAnimPulse = now;
    ambientAnim(dt);
    if (window.RaccoonAnim) RaccoonAnim.tick(dt);
    requestAnimationFrame(animLoop);
  }

  function init() {
    wireIcons();
    bind();
    const hadSave = load();
    if (!hadSave) {
      resetDefaults();
      say("A roadside bush shivers… something’s in there.");
    }
    if (window.JimothySound) {
      JimothySound.setOnChange((on) => {
        state.soundMuted = !on;
        refreshSoundButton();
      });
      JimothySound.setEnabled(!state.soundMuted, { announce: false });
    }
    refreshSoundButton();
    save({ touchTick: false });
    if (window.RaccoonAnim) RaccoonAnim.init($("raccoonWrap"), $("raccoon"));
    render();
    // Dead / leftover saves: land on a fresh rustling bush (no re-ascent).
    if (!state.alive) {
      startNextKitAfterAscension(state.deathReason);
    }
    tickHandle = setInterval(onTick, TICK_MS);
    lastAnimPulse = performance.now();
    requestAnimationFrame(animLoop);

    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "hidden") {
        save();
        return;
      }
      syncRealtime({ announceDeath: true });
      render();
      save();
    });
    window.addEventListener("focus", () => {
      syncRealtime({ announceDeath: true });
      render();
      save();
    });
    window.addEventListener("beforeunload", save);

    if ("serviceWorker" in navigator) {
      navigator.serviceWorker.register("./sw.js").catch(() => {
        /* optional offline shell */
      });
    }
  }

  init();

  window.JimothyDebug = {
    getState: () => ({ ...state }),
    setState: (partial) => {
      Object.assign(state, partial);
      render();
      save({ touchTick: false });
    },
    syncRealtime: () => {
      const elapsed = syncRealtime({ announceDeath: true });
      render();
      save();
      return elapsed;
    },
    reset: resetPet,
    endLife,
    setDevMode,
    devSkipTo,
    FOOD,
  };
})();
