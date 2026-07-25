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
    messCount: 0,
    sick: false,
    alive: true,
    ascending: false,
    treatStreak: 0,
    healthyMeals: 0,
    playSessions: 0,
    energy: 80,
    /** Timestamps (ms) of illness onsets in the rolling 24h window. Max 2. */
    illnessEvents: [],
    /** Timestamps (ms) of acting-out onsets in the rolling 24h window. Max 3. */
    tantrumEvents: [],
    formsUnlocked: { young: {}, teen: {}, adult: {} },
    devMode: false,
    soundMuted: false,
    ambienceMuted: false,
    sfxMuted: false,
    alertsEnabled: false,
  };

  const DAY_MS = 86400000;
  const MAX_ILLNESS_PER_DAY = 2;
  const MAX_TANTRUM_PER_DAY = 3;
  const MAX_MESS = 6;
  const MESS_PILE_SVG = `<svg viewBox="0 0 48 36" aria-hidden="true">
    <ellipse cx="24" cy="30" rx="16" ry="5" fill="rgba(20,16,10,0.35)" />
    <ellipse cx="18" cy="20" rx="11" ry="8" fill="#52361c" />
    <ellipse cx="28" cy="18" rx="10" ry="7" fill="#463016" />
    <ellipse cx="23" cy="14" rx="8" ry="6" fill="#5c3c20" />
    <ellipse cx="31" cy="22" rx="6" ry="5" fill="#3f2914" />
    <ellipse cx="20" cy="16" rx="3" ry="2" fill="rgba(90,60,30,0.55)" />
  </svg>`;
  const MESS_SLOTS = [
    { left: "62%", bottom: "78px" },
    { left: "48%", bottom: "72px" },
    { left: "74%", bottom: "70px" },
    { left: "36%", bottom: "76px" },
    { left: "22%", bottom: "68px" },
    { left: "55%", bottom: "64px" },
  ];

  const YOUNG_FORMS = ["puff", "looper", "shadow", "nub"];
  const TEEN_FORMS = ["dumpling", "bounder", "nightlane", "scruff"];
  const ADULT_FORMS = ["saint", "legend", "alley_ghost", "ballard_blip"];

  let speechTimer = 0;
  let tickHandle = 0;
  let animCooldown = 0;
  let lastAnimPulse = performance.now();
  let tapCooldown = 0;
  let smileUntil = 0;
  // Session-only — never ship a visible Dev control; secret unlock each visit.
  let devUnlocked = false;
  let brandTapTimes = [];

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
    if (state.messCount > 0) rate += 0.35 + state.messCount * 0.2;
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
      smiling:
        performance.now() < smileUntil &&
        !(state.sick && state.alive) &&
        !(state.stubborn && state.alive),
      sick: !!(state.sick && state.alive && !state.ascending),
      stubborn: !!(state.stubborn && state.alive && !state.ascending && !state.sick),
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
      messCount: 0,
      sick: false,
      alive: true,
      ascending: false,
      treatStreak: 0,
      healthyMeals: 0,
      playSessions: 0,
      energy: 80,
      illnessEvents: [],
      tantrumEvents: [],
      formsUnlocked: state.formsUnlocked || { young: {}, teen: {}, adult: {} },
      devMode: false,
      soundMuted: !!state.soundMuted,
      ambienceMuted: !!state.ambienceMuted,
      sfxMuted: !!state.sfxMuted,
      alertsEnabled: !!state.alertsEnabled,
    });
    state.youngForm = pickYoungForm(state.genes);
    if ($("messageOk")) $("messageOk").textContent = "OK";
  }

  function sfx(kind) {
    if (window.JimothySound) JimothySound.cue(kind);
  }

  function refreshSoundButtons() {
    const bgOn = window.JimothySound
      ? JimothySound.isAmbienceEnabled()
      : !state.ambienceMuted;
    const sfxOn = window.JimothySound ? JimothySound.isSfxEnabled() : !state.sfxMuted;
    const btnBg = $("btnAmbience");
    const btnSfx = $("btnSfx");
    if (btnBg) {
      btnBg.textContent = bgOn ? "BG: On" : "BG: Off";
      btnBg.setAttribute("aria-pressed", bgOn ? "true" : "false");
    }
    if (btnSfx) {
      btnSfx.textContent = sfxOn ? "Jimothy: On" : "Jimothy: Off";
      btnSfx.setAttribute("aria-pressed", sfxOn ? "true" : "false");
    }
    state.ambienceMuted = !bgOn;
    state.sfxMuted = !sfxOn;
    state.soundMuted = !bgOn && !sfxOn;
  }

  function setAmbienceEnabled(on) {
    if (window.JimothySound) JimothySound.setAmbienceEnabled(on);
    refreshSoundButtons();
    save({ touchTick: false });
  }

  function setSfxEnabled(on) {
    if (window.JimothySound) JimothySound.setSfxEnabled(on);
    refreshSoundButtons();
    save({ touchTick: false });
  }

  function refreshAlertsButton() {
    const btn = $("btnAlerts");
    if (!btn) return;
    if (!window.JimothyNotify || !JimothyNotify.supported()) {
      btn.textContent = "Alerts: N/A";
      btn.disabled = true;
      btn.title = "Notifications are not supported in this browser";
      btn.setAttribute("aria-pressed", "false");
      return;
    }
    btn.disabled = false;
    const on = !!state.alertsEnabled && JimothyNotify.isEnabled();
    btn.textContent = on ? "Alerts: On" : "Alerts: Off";
    btn.setAttribute("aria-pressed", on ? "true" : "false");
    btn.title = on
      ? "Care alerts on — hunger, play, acting up, waste, new forms"
      : "Turn on notifications when Jimothy needs care";
  }

  async function toggleAlerts() {
    if (!window.JimothyNotify || !JimothyNotify.supported()) {
      say("Alerts aren’t supported in this browser.");
      return;
    }
    const want = !state.alertsEnabled;
    if (want) {
      const ok = await JimothyNotify.setEnabled(true);
      state.alertsEnabled = ok;
      refreshAlertsButton();
      save({ touchTick: false });
      if (ok) {
        say("Alerts on — care needs, nest waste, and new forms.");
        JimothyNotify.check(state);
      } else if (JimothyNotify.permission() === "denied") {
        say("Notifications are blocked. Enable them in browser settings for this site.");
      } else {
        say("Couldn’t enable alerts.");
      }
    } else {
      state.alertsEnabled = false;
      await JimothyNotify.setEnabled(false);
      refreshAlertsButton();
      save({ touchTick: false });
      say("Care alerts off.");
    }
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
      // Dev is session-only — never restore a published Dev button from saves.
      state.devMode = false;
      if (state.soundMuted == null) state.soundMuted = false;
      if (state.ambienceMuted == null) state.ambienceMuted = !!state.soundMuted;
      if (state.sfxMuted == null) state.sfxMuted = !!state.soundMuted;
      if (state.alertsEnabled == null) state.alertsEnabled = false;
      state.illnessEvents = pruneDayEvents(
        Array.isArray(state.illnessEvents) ? state.illnessEvents : []
      );
      state.tantrumEvents = pruneDayEvents(
        Array.isArray(state.tantrumEvents) ? state.tantrumEvents : []
      );
      if (state.messCount == null) {
        state.messCount = state.hasMess ? 1 : 0;
      }
      state.messCount = Math.max(0, Math.min(MAX_MESS, state.messCount | 0));
      delete state.hasMess;
      unlockCurrentForm();
      syncRealtime({ announceDeath: false });
      return true;
    } catch {
      return false;
    }
  }

  function save({ touchTick = true } = {}) {
    if (touchTick) state.lastTick = nowMs();
    const payload = {
      ...state,
      devMode: false,
      soundMuted: !!(state.ambienceMuted && state.sfxMuted),
    };
    localStorage.setItem(STORAGE_KEY, JSON.stringify(payload));
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
    const keepMute = !!state.soundMuted;
    const keepAmb = !!state.ambienceMuted;
    const keepSfx = !!state.sfxMuted;
    const keepAlerts = !!state.alertsEnabled;
    const keepSessionDev = devUnlocked;
    resetDefaults();
    state.formsUnlocked = keepForms;
    state.devMode = keepSessionDev;
    state.soundMuted = keepMute;
    state.ambienceMuted = keepAmb;
    state.sfxMuted = keepSfx;
    state.alertsEnabled = keepAlerts;
    save();
    if (window.RaccoonAnim) RaccoonAnim.reset();
    render();
    say("A roadside bush shivers… something’s in there.");
    sfx("bush");
  }

  function setDevMode(on) {
    state.devMode = !!on;
    // Don't persist Dev Mode into public saves.
    render();
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
    state.messCount = 0;
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

  function pruneDayEvents(arr, now = nowMs()) {
    return (arr || []).filter((t) => typeof t === "number" && now - t < DAY_MS);
  }

  function illnessDailyRate() {
    const h = clamp(state.health, 0, 100);
    // Rare baseline even when well cared for; health is the main driver.
    let rate = 0.035 + Math.pow((100 - h) / 100, 1.35) * 1.5;
    if (state.messCount > 0) rate *= 1.15 + Math.min(state.messCount, MAX_MESS) * 0.08;
    if (state.hunger < 25) rate *= 1.35;
    if (state.treatStreak >= 2) rate *= 1.15 + state.treatStreak * 0.12;
    return Math.min(rate, 2.1);
  }

  function tantrumDailyRate() {
    const d = clamp(state.discipline, 0, 100);
    return Math.min(0.05 + Math.pow((100 - d) / 100, 1.25) * 2.4, 3.1);
  }

  /** Returns true if illness started. Respects max 2 / 24h. */
  function tryBecomeSick({ announce = true } = {}) {
    if (!state.alive || state.ascending || state.sick || state.stage === "bush") {
      return false;
    }
    const now = nowMs();
    state.illnessEvents = pruneDayEvents(state.illnessEvents, now);
    if (state.illnessEvents.length >= MAX_ILLNESS_PER_DAY) return false;
    state.sick = true;
    state.illnessEvents.push(now);
    if (announce) {
      say("He’s feeling queasy…");
      pulseAnim("sick");
      sfx("sick");
    }
    return true;
  }

  /** Returns true if a new acting-out started. Respects max 3 / 24h. */
  function tryBecomeStubborn(reason, { announce = true, penalty = 5400 } = {}) {
    if (!state.alive || state.ascending || state.stubborn) return false;
    if (state.stage === "bush" || state.stage === "baby") return false;
    const now = nowMs();
    state.tantrumEvents = pruneDayEvents(state.tantrumEvents, now);
    if (state.tantrumEvents.length >= MAX_TANTRUM_PER_DAY) return false;
    state.stubborn = true;
    state.stubbornReason = reason || "acting up";
    state.tantrumEvents.push(now);
    state.careMistakes += 1;
    state.lifespanPenalty = (state.lifespanPenalty || 0) + penalty;
    if (announce) {
      say(`He’s ${state.stubbornReason}. Scold him.`);
      pulseAnim("stubborn");
      sfx("stubborn");
    }
    return true;
  }

  function applyDecay(seconds) {
    if (!state.alive) return;

    const hungerRate = state.stage !== "bush" ? 0.0028 : 0;
    const happyRate = state.stage !== "bush" ? 0.0022 : 0;
    const energyRate = state.stage !== "bush" ? 0.0015 : 0;
    // Slow discipline fade — acting-out odds rise as it falls.
    const disciplineRate = state.stage !== "bush" && state.stage !== "baby" ? 0.00016 : 0;

    state.hunger = clamp(state.hunger - hungerRate * seconds);
    state.happy = clamp(state.happy - happyRate * seconds);
    state.energy = clamp(state.energy - energyRate * seconds);
    state.discipline = clamp(state.discipline - disciplineRate * seconds);
    state.satiety = Math.max(0, state.satiety - 0.02 * seconds);
    state.ageSec += seconds;

    // Health drains mainly from waste, hunger, and junk streak — kept slow.
    if (state.messCount > 0) {
      const piles = Math.min(state.messCount, MAX_MESS);
      state.health = clamp(state.health - 0.00035 * piles * seconds);
      state.happy = clamp(state.happy - 0.0004 * piles * seconds);
    }
    if (state.hunger < 20 && state.stage !== "bush") {
      state.health = clamp(state.health - 0.00095 * seconds);
      state.happy = clamp(state.happy - 0.001 * seconds);
    }
    if (state.treatStreak > 3) {
      state.health = clamp(state.health - 0.0004 * seconds);
    }
    if (state.sick) {
      state.health = clamp(state.health - 0.00025 * seconds);
    }
    if (state.energy < 15) {
      state.happy = clamp(state.happy - 0.0005 * seconds);
    }

    applyNeglectPenalty(seconds);

    if (
      state.stage !== "bush" &&
      state.messCount < MAX_MESS &&
      Math.random() < seconds * 0.00022
    ) {
      state.messCount += 1;
    }

    maybeIllness(seconds);
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

  function maybeIllness(seconds) {
    if (state.stage === "bush" || state.stage === "baby" || state.sick || !state.alive) {
      return false;
    }
    const now = nowMs();
    state.illnessEvents = pruneDayEvents(state.illnessEvents, now);
    if (state.illnessEvents.length >= MAX_ILLNESS_PER_DAY) return false;
    const chance = (illnessDailyRate() / 86400) * seconds;
    if (Math.random() >= Math.min(0.35, chance)) return false;
    return tryBecomeSick({ announce: true });
  }

  function maybeTantrum(seconds) {
    if (state.stage === "bush" || state.stage === "baby" || state.stubborn || !state.alive) {
      return false;
    }
    const now = nowMs();
    state.tantrumEvents = pruneDayEvents(state.tantrumEvents, now);
    if (state.tantrumEvents.length >= MAX_TANTRUM_PER_DAY) return false;
    const chance = (tantrumDailyRate() / 86400) * seconds;
    if (Math.random() >= Math.min(0.4, chance)) return false;
    const reasons = ["acting up", "needs a firm word", "pushing boundaries"];
    return tryBecomeStubborn(reasons[Math.floor(Math.random() * reasons.length)], {
      announce: true,
      penalty: 5400,
    });
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
        "Jimothy burst from the bush. Keep him fed and cozy."
      );
      if (state.alertsEnabled && window.JimothyNotify) {
        JimothyNotify.notifyForm("baby", "Baby Kit");
      }
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
      if (state.alertsEnabled && window.JimothyNotify) {
        JimothyNotify.notifyForm("young", prettyForm(state.youngForm));
      }
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
        `Form: ${capitalize(state.teenForm)}. Keep caring — he keeps growing.`
      );
      if (state.alertsEnabled && window.JimothyNotify) {
        JimothyNotify.notifyForm("teen", prettyForm(state.teenForm));
      }
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
      if (state.alertsEnabled && window.JimothyNotify) {
        JimothyNotify.notifyForm("adult", adultFormTitle());
      }
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
    if (state.messCount > 0) {
      const n = state.messCount;
      return {
        text:
          n === 1
            ? "He’s marked the nest. Clean it up."
            : `${n} waste piles in the nest. Clean them up.`,
        danger: n >= 4,
      };
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

  function say(text, ms = 5200) {
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
    // Keep ambient from cutting off a slow eat / key reaction.
    if (kind === "eat") animCooldown = 3.2;
    else if (kind === "ascend") animCooldown = 5;
    else animCooldown = randRange(1.2, 3.2);
  }

  function ambientAnim(dt) {
    tapCooldown = Math.max(0, tapCooldown - dt);
    if (!state.alive || state.ascending) return;
    if (window.RaccoonAnim && typeof RaccoonAnim.isBusy === "function" && RaccoonAnim.isBusy()) {
      return;
    }
    animCooldown -= dt;
    if (animCooldown > 0) return;

    // Bush stage: gusty ambient rustles so foliage stays lively.
    if (state.stage === "bush") {
      animCooldown = randRange(1.6, 3.2);
      pulseAnim("rustle");
      if (Math.random() < 0.4 && window.JimothySound) JimothySound.play("rustle", 0.28);
      return;
    }

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
    if (state.energy > 55 && state.happy > 50 && roll < (peppy ? 0.48 : 0.38)) {
      kind = peppy && roll < 0.2 ? (state.fitness > 45 ? "run" : "jump") : "walk";
    } else if (roll < 0.62) {
      kind = "walk";
    } else if (roll < 0.74) {
      kind = peppy ? "jump" : "sniff";
    } else if (roll < 0.84) {
      kind = state.stage === "adult" ? "lope" : state.stage !== "baby" ? "stretch" : "sniff";
    } else if (roll < 0.93) {
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
        : state.sick
          ? "sick"
          : state.stubborn
            ? "stubborn"
            : "idle";
    raccoon.dataset.form =
      state.stage === "adult"
        ? state.adultForm
        : state.stage === "teen"
          ? state.teenForm
          : state.stage === "young"
            ? state.youngForm
            : "";

    refreshArt(true);

    if (window.RaccoonAnim) {
      RaccoonAnim.sync({
        stage: showBody ? state.stage : "bush",
        ageSec: state.ageSec,
        alive: showBody,
        ascending: !!state.ascending,
      });
    }

    renderMessPiles();

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
    const canScold = !!(state.alive && state.stubborn);
    const canHeal = !!(state.alive && state.sick && state.stage !== "bush" && !state.ascending);
    const canClean = !!(state.alive && state.messCount > 0);
    if ($("btnDiscipline")) {
      $("btnDiscipline").disabled = !canScold;
      $("btnDiscipline").classList.toggle("needs-attention", canScold);
    }
    if ($("btnClean")) {
      $("btnClean").disabled = !canClean;
      $("btnClean").classList.toggle("needs-attention", canClean);
      const cleanLabel = $("btnClean").querySelector("span:last-child");
      if (cleanLabel) {
        cleanLabel.textContent =
          state.messCount > 1 ? `Clean (${state.messCount})` : "Clean";
      }
    }
    if ($("btnHeal")) {
      $("btnHeal").disabled = !canHeal;
      $("btnHeal").classList.toggle("needs-attention", canHeal);
    }
    if ($("btnFeed")) $("btnFeed").disabled = !canCare;
    if ($("btnPlay")) {
      $("btnPlay").disabled =
        !state.alive || state.ascending || state.stage === "bush" || state.stage === "baby";
    }
    if ($("btnAction")) {
      $("btnAction").classList.toggle("needs-attention", canScold || canHeal || canClean);
    }

    refreshDevButton();

    if (state.ascending) {
      $("hint").textContent = "Watch… Jimothy grows wings and rises into the sky.";
    } else if (state.stage === "bush") {
      $("hint").textContent = "Tap the bush to rustle it. Something’s waking…";
    } else if (!state.alive) {
      $("hint").textContent =
        "His cryptid life is complete. You can raise another kit.";
    } else if (state.sick) {
      $("hint").textContent = "He’s under the weather — open Action → Heal.";
    } else if (state.stubborn) {
      $("hint").textContent = "He’s acting up — open Action → Scold.";
    } else if (state.messCount > 0) {
      $("hint").textContent = "Waste in the nest — open Action → Clean.";
    } else if (state.stage === "baby") {
      $("hint").textContent =
        "Tap Jimothy for smiles and hops. Too tiny for a full night run yet.";
    } else {
      $("hint").textContent = "Tap Jimothy to pet him. Good care lengthens his days.";
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

  const FORM_BLURBS = {
    young: {
      puff: "Cotton-ball fluff + stubby legs — leans dumpling or scruff.",
      looper: "Stilt legs + pep stripe — leans bounder or nightlane.",
      shadow: "Charcoal crouch + ringed tail — leans nightlane or scruff.",
      nub: "Big head, nub ears, chin tuft — leans bounder or dumpling.",
    },
    teen: {
      dumpling: "Loaf body, sleepy eye → Saint (care) or Ballard Blip (neglect).",
      bounder: "Athletic stilts + spring mark → Alley Ghost / Legend.",
      nightlane: "Sleek navy prowler + pale gleam → Alley Ghost / Legend.",
      scruff: "Jagged back fur + notch ear → Saint / Ballard Blip.",
    },
    adult: {
      saint: "Moss ear leaf + soft green undertone.",
      legend: "Amber face blaze + proud stilts.",
      alley_ghost: "Pale mist coat + hollow gleam.",
      ballard_blip: "Scrap scarf + notched ear, warm alley fur.",
    },
  };

  function formGalleryHtml() {
    const genes = state.genes || {};
    const sections = [
      ["Young kits", "young", YOUNG_FORMS, (id) => ({ stage: "young", youngForm: id, genes })],
      ["Teen kits", "teen", TEEN_FORMS, (id) => ({ stage: "teen", teenForm: id, genes })],
      ["Adult Jimothy", "adult", ADULT_FORMS, (id) => ({ stage: "adult", adultForm: id, genes })],
    ];
    return sections
      .map(([title, bucket, forms, profileFor]) => {
        const cards = forms
          .map((id) => {
            const unlocked = isFormUnlocked(bucket, id);
            const current =
              (bucket === "young" &&
                state.stage !== "bush" &&
                state.stage !== "baby" &&
                state.youngForm === id) ||
              (bucket === "teen" && state.teenForm === id) ||
              (bucket === "adult" && state.adultForm === id);
            const art = window.RaccoonArt
              ? RaccoonArt.render(profileFor(id))
              : "";
            const blurb = (FORM_BLURBS[bucket] && FORM_BLURBS[bucket][id]) || "";
            return `<article class="form-card ${unlocked ? "unlocked" : "locked"} ${
              current ? "current" : ""
            }">
              <div class="form-card-art">${art}</div>
              <strong class="form-card-name">${prettyForm(id)}</strong>
              <small class="form-card-meta">${unlocked ? "Unlocked" : "Locked"} · ${
              current ? "This kit" : blurb
            }</small>
            </article>`;
          })
          .join("");
        return `<div class="forms-section">${title}</div><div class="form-gallery">${cards}</div>`;
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
      <div class="forms-section">All forms</div>
      <p class="path-legend">Every silhouette you can raise. Locked forms still preview dimly — raise kits to unlock them.</p>
      ${formGalleryHtml()}
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
    el.textContent = `Dev Mode: ${state.devMode ? "ON" : "OFF"} · Waste: ${state.messCount}/${MAX_MESS} · Sick: ${state.sick ? "yes" : "no"} · Stubborn: ${state.stubborn ? "yes" : "no"} · ${stageLabel()} · ${formatAge()}`;
    const toggle = $("devToggle");
    if (toggle) toggle.textContent = state.devMode ? "Dev Mode: On" : "Dev Mode: Off";
    syncDevMeters();
  }

  function closeActionMenu() {
    if ($("actionModal")) $("actionModal").hidden = true;
  }

  function openActionMenu() {
    if ($("actionModal")) $("actionModal").hidden = false;
  }

  function closeSoundMenu() {
    if ($("soundModal")) $("soundModal").hidden = true;
  }

  function openSoundMenu() {
    closeSettingsMenu();
    refreshSoundButtons();
    if ($("soundModal")) $("soundModal").hidden = false;
  }

  function closeSettingsMenu() {
    if ($("settingsModal")) $("settingsModal").hidden = true;
  }

  function openSettingsMenu() {
    refreshAlertsButton();
    if ($("settingsModal")) $("settingsModal").hidden = false;
  }

  function openFeed() {
    if (!state.alive || state.stage === "bush" || state.ascending) return;
    closeActionMenu();
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
      tryBecomeStubborn("refuses a proper meal", { announce: false, penalty: 3600 });
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
      // Junk taxes health; illness is roll/cap based, not automatic forever.
      if (state.treatStreak >= 3) {
        state.health = clamp(state.health - (2 + state.treatStreak));
      }
      if (state.treatStreak >= 4 && tryBecomeSick({ announce: false })) {
        state.health = clamp(state.health - 6);
        say("Too much alley grease… he flops, queasy.");
        pulseAnim("sick");
        sfx("sick");
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
    closeActionMenu();
    render();
    save();
  }

  function clean() {
    if (!state.alive || state.messCount <= 0) return;
    state.messCount = Math.max(0, state.messCount - 1);
    state.happy = clamp(state.happy + 3);
    state.health = clamp(state.health + 2);
    state.careScore += 1;
    if (state.messCount <= 0) {
      say("Nest cleared. He sniffs approval.");
    } else {
      say(`One pile gone — ${state.messCount} left.`);
    }
    sfx("clean");
    closeActionMenu();
    render();
    save();
  }

  function renderMessPiles() {
    const layer = $("messLayer");
    if (!layer) return;
    const show = state.alive && !state.ascending && state.messCount > 0;
    layer.hidden = !show;
    if (!show) {
      layer.innerHTML = "";
      return;
    }
    const n = Math.min(MAX_MESS, Math.max(0, state.messCount | 0));
    let html = "";
    for (let i = 0; i < n; i++) {
      const slot = MESS_SLOTS[i % MESS_SLOTS.length];
      html += `<div class="mess" style="left:${slot.left};bottom:${slot.bottom}">${MESS_PILE_SVG}</div>`;
    }
    layer.innerHTML = html;
  }

  function treatIllness() {
    if (!state.alive || state.ascending || state.stage === "bush") return;
    if (!state.sick) {
      say("He’s already feeling fine.");
      render();
      return;
    }
    state.sick = false;
    state.health = clamp(state.health + 14);
    state.happy = clamp(state.happy + 4);
    state.energy = clamp(state.energy - 4);
    state.careScore += 1;
    say("You soothe his tummy. Warmth returns to his ears.");
    pulseAnim("heal");
    sfx("heal");
    closeActionMenu();
    render();
    save();
  }

  function canStartPlay({ rollStubborn = false } = {}) {
    if (!state.alive || state.stage === "bush" || state.stage === "baby") {
      if (state.stage === "baby") {
        say("Too tiny for games — let him wobble a bit first.");
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
    // Only roll stubborn when opening the picker — not again when launching a game.
    if (rollStubborn && !state.stubborn && state.discipline < 35 && Math.random() < 0.22) {
      if (tryBecomeStubborn("refuses to exercise", { announce: false, penalty: 3600 })) {
        say("He flops dramatically. Absolutely not chasing trash.");
        pulseAnim("stubborn");
        sfx("stubborn");
        render();
        save();
        return "stubborn";
      }
    }
    return "ok";
  }

  function openPlayPicker() {
    closeActionMenu();
    if (canStartPlay({ rollStubborn: true }) !== "ok") return;
    $("playPickModal").hidden = false;
  }

  function closePlayPicker() {
    $("playPickModal").hidden = true;
  }

  function openGame() {
    closePlayPicker();
    if (canStartPlay({ rollStubborn: false }) !== "ok") return;
    sfx("play");
    $("gameModal").hidden = false;
    DumpsterDive.start(onGameDone, { ...formProfile(), view: "side" });
  }

  function openDiceGame() {
    closePlayPicker();
    if (canStartPlay({ rollStubborn: false }) !== "ok") return;
    if (!window.DiceHighLow || typeof DiceHighLow.start !== "function") {
      say("High or Low couldn’t load — try a hard refresh.");
      return;
    }
    sfx("play");
    try {
      DiceHighLow.start(onDiceDone);
    } catch (err) {
      console.error(err);
      say("High or Low hit a snag — try again.");
    }
  }

  function closeGame() {
    DumpsterDive.stop(false);
    $("gameModal").hidden = true;
  }

  function closeDiceGame() {
    if (window.DiceHighLow) DiceHighLow.close(false);
  }

  function onDiceDone(result) {
    if (!result || result.bailed) return;
    if (!state.alive) return;

    state.playSessions += 1;
    state.energy = clamp(state.energy - 10);
    state.hunger = clamp(state.hunger - 3);
    state.discipline = clamp(state.discipline + 1);

    if (result.correct) {
      state.happy = clamp(state.happy + 14);
      state.fitness = clamp(state.fitness + 2);
      state.careScore += 2;
      state.health = clamp(state.health + 1);
      say(`d20 shows ${result.roll} — you called it! He chirps with joy.`, 6000);
      bounceHappy();
      pulseAnim("happy");
      setTimeout(() => pulseAnim("hop"), 500);
      sfx("chirp");
    } else {
      state.happy = clamp(state.happy - 6);
      say(`d20 shows ${result.roll} — wrong call. He droops and sighs.`, 6000);
      pulseAnim("sad");
      sfx("grumble");
    }
    render();
    save();

    if (state.energy < 18 && $("diceAgain")) {
      $("diceAgain").hidden = true;
      if ($("diceStatus")) {
        $("diceStatus").textContent += " He’s wiped — rest before another roll.";
      }
    }
  }

  function openResetModal() {
    const modal = $("resetModal");
    if (!modal) return;
    modal.hidden = false;
  }

  function closeResetModal() {
    const modal = $("resetModal");
    if (modal) modal.hidden = true;
  }

  function confirmReset() {
    closeSettingsMenu();
    openResetModal();
  }

  function doResetPet() {
    closeResetModal();
    resetPet();
    say("A new bush is rustling…", 6000);
  }

  function unlockDevAccess({ open = false } = {}) {
    devUnlocked = true;
    ensureDevButton();
    refreshDevButton();
    if (open) {
      if (!state.devMode) setDevMode(true);
      refreshDevStatus();
      syncDevMeters();
      if ($("devModal")) $("devModal").hidden = false;
    }
  }

  function onBrandSecretTap() {
    const now = performance.now();
    brandTapTimes = brandTapTimes.filter((t) => now - t < 2500);
    brandTapTimes.push(now);
    if (brandTapTimes.length < 5) return;
    brandTapTimes = [];
    unlockDevAccess({ open: true });
    say("Dev tools unlocked.", 3200);
  }

  function ensureDevButton() {
    if ($("btnDev")) return;
    const row = document.querySelector(".utility-row");
    if (!row) return;
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "utility-btn";
    btn.id = "btnDev";
    btn.textContent = "Dev";
    btn.addEventListener("click", () => {
      if (!devUnlocked) return;
      if (!state.devMode) setDevMode(true);
      refreshDevStatus();
      syncDevMeters();
      $("devModal").hidden = false;
    });
    row.appendChild(btn);
    row.classList.add("has-dev");
  }

  function refreshDevButton() {
    // Never show Dev in the base layout — only inject after this-session secret unlock.
    if (!devUnlocked) {
      const existing = $("btnDev");
      if (existing) existing.remove();
      const row = document.querySelector(".utility-row");
      if (row) row.classList.remove("has-dev");
      return;
    }
    ensureDevButton();
    const btnDev = $("btnDev");
    if (!btnDev) return;
    btnDev.textContent = state.devMode ? "Dev mode ✓" : "Dev";
  }

  function syncDevMeters() {
    document.querySelectorAll("[data-dev-stat]").forEach((input) => {
      const key = input.dataset.devStat;
      const val = Math.round(Number(state[key] ?? 0));
      input.value = String(val);
      const label = document.querySelector(`[data-dev-val="${key}"]`);
      if (label) label.textContent = String(val);
    });
  }

  function applyDevStat(key, value) {
    if (!devUnlocked) return;
    const v = clamp(Number(value));
    if (!["hunger", "happy", "health", "discipline", "energy", "satiety"].includes(key)) return;
    state[key] = v;
    render();
    save({ touchTick: false });
    syncDevMeters();
    refreshDevStatus();
  }

  function setDevMess(on) {
    if (!devUnlocked) return;
    if (!on) {
      state.messCount = 0;
    } else if (state.alive && state.stage !== "bush") {
      state.messCount = Math.min(MAX_MESS, (state.messCount || 0) + 1);
    }
    render();
    save({ touchTick: false });
    refreshDevStatus();
    say(on ? `Dev: waste ${state.messCount}/${MAX_MESS}.` : "Dev: waste cleared.");
  }

  function setDevSick(on) {
    if (!devUnlocked) return;
    state.sick = !!(on && state.alive);
    render();
    save({ touchTick: false });
    refreshDevStatus();
  }

  function setDevStubborn(on) {
    if (!devUnlocked) return;
    state.stubborn = !!(on && state.alive);
    state.stubbornReason = state.stubborn ? "dev override" : "";
    render();
    save({ touchTick: false });
    refreshDevStatus();
  }

  let lastArtKey = "";

  function artProfile() {
    const view =
      window.RaccoonAnim && typeof RaccoonAnim.getView === "function"
        ? RaccoonAnim.getView()
        : "side";
    return { ...formProfile(), view };
  }

  function refreshArt(force = false) {
    const raccoon = $("raccoon");
    if (!raccoon) return;
    const showBody = state.alive || state.ascending;
    const profile = showBody
      ? artProfile()
      : { stage: "bush", ageSec: 0, genes: {}, view: "front" };
    const bushBucket =
      profile.stage === "bush" ? Math.floor((profile.ageSec || 0) / 8) : 0;
    const key = [
      showBody ? state.stage : "gone",
      profile.youngForm || "",
      profile.teenForm || "",
      profile.adultForm || "",
      profile.smiling ? "1" : "0",
      profile.sick ? "sick" : "",
      profile.stubborn ? "stubborn" : "",
      profile.view || "side",
      bushBucket,
      state.ascending ? "up" : "",
    ].join("|");
    if (!force && key === lastArtKey) return;
    lastArtKey = key;
    raccoon.innerHTML = RaccoonArt.render(profile);
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
    if (state.alertsEnabled && window.JimothyNotify) JimothyNotify.check(state);
  }

  function wireIcons() {
    if ($("btnAction") && $("btnAction").querySelector(".ctrl-icon")) {
      $("btnAction").querySelector(".ctrl-icon").innerHTML = RaccoonArt.icons.action;
    }
    const setMenuIcon = (id, icon) => {
      const el = $(id);
      if (!el) return;
      const slot = el.querySelector(".menu-icon") || el.querySelector(".ctrl-icon");
      if (slot) slot.innerHTML = icon;
    };
    setMenuIcon("btnFeed", RaccoonArt.icons.feed);
    setMenuIcon("btnPlay", RaccoonArt.icons.play);
    setMenuIcon("btnDiscipline", RaccoonArt.icons.scold);
    setMenuIcon("btnHeal", RaccoonArt.icons.heal);
    setMenuIcon("btnClean", RaccoonArt.icons.clean);

    document.querySelectorAll(".food-btn").forEach((btn) => {
      const key = btn.dataset.food;
      const art = btn.querySelector(".food-art");
      if (art && RaccoonArt.icons[key]) art.innerHTML = RaccoonArt.icons[key];
    });
  }

  function bind() {
    if ($("btnAction")) $("btnAction").addEventListener("click", openActionMenu);
    if ($("actionClose")) $("actionClose").addEventListener("click", closeActionMenu);
    if ($("actionModal")) {
      $("actionModal").addEventListener("click", (e) => {
        if (e.target === $("actionModal")) closeActionMenu();
      });
    }
    if ($("btnSettings")) $("btnSettings").addEventListener("click", openSettingsMenu);
    if ($("settingsClose")) $("settingsClose").addEventListener("click", closeSettingsMenu);
    if ($("settingsModal")) {
      $("settingsModal").addEventListener("click", (e) => {
        if (e.target === $("settingsModal")) closeSettingsMenu();
      });
    }
    if ($("btnSound")) $("btnSound").addEventListener("click", openSoundMenu);
    if ($("soundClose")) $("soundClose").addEventListener("click", closeSoundMenu);
    if ($("soundModal")) {
      $("soundModal").addEventListener("click", (e) => {
        if (e.target === $("soundModal")) closeSoundMenu();
      });
    }
    if ($("btnFeed")) $("btnFeed").addEventListener("click", openFeed);
    if ($("btnPlay")) $("btnPlay").addEventListener("click", openPlayPicker);
    if ($("playPickClose")) $("playPickClose").addEventListener("click", closePlayPicker);
    if ($("pickDumpster")) $("pickDumpster").addEventListener("click", openGame);
    if ($("pickDice")) $("pickDice").addEventListener("click", openDiceGame);
    // Dice close is handled inside DiceHighLow (avoids double-binding).
    if ($("btnReset")) $("btnReset").addEventListener("click", confirmReset);
    if ($("resetCancel")) $("resetCancel").addEventListener("click", closeResetModal);
    if ($("resetConfirm")) $("resetConfirm").addEventListener("click", doResetPet);
    if ($("resetModal")) {
      $("resetModal").addEventListener("click", (e) => {
        if (e.target === $("resetModal")) closeResetModal();
      });
    }
    const brand = $("brandTitle");
    if (brand) {
      brand.addEventListener("click", onBrandSecretTap);
      brand.style.cursor = "default";
    }
    if ($("btnDiscipline")) $("btnDiscipline").addEventListener("click", discipline);
    if ($("btnClean")) $("btnClean").addEventListener("click", clean);
    if ($("btnHeal")) $("btnHeal").addEventListener("click", treatIllness);
    const wrap = $("raccoonWrap");
    if (wrap) {
      wrap.style.cursor = "pointer";
      wrap.setAttribute("role", "button");
      wrap.setAttribute("aria-label", "Pet Jimothy");
      wrap.tabIndex = 0;
      wrap.addEventListener("pointerdown", (e) => {
        interactTap();
      });
      wrap.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          interactTap();
        }
      });
    }
    if ($("btnAmbience")) {
      $("btnAmbience").addEventListener("click", () => {
        const next = window.JimothySound
          ? !JimothySound.isAmbienceEnabled()
          : state.ambienceMuted;
        setAmbienceEnabled(next);
      });
    }
    if ($("btnSfx")) {
      $("btnSfx").addEventListener("click", () => {
        const next = window.JimothySound ? !JimothySound.isSfxEnabled() : state.sfxMuted;
        setSfxEnabled(next);
      });
    }
    if ($("btnAlerts")) {
      $("btnAlerts").addEventListener("click", () => {
        toggleAlerts();
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

    // Forms gallery stays in the page for now but is hidden from the main UI.
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
    if ($("devWasteOn")) $("devWasteOn").addEventListener("click", () => setDevMess(true));
    if ($("devWasteOff")) $("devWasteOff").addEventListener("click", () => setDevMess(false));
    if ($("devSickOn")) $("devSickOn").addEventListener("click", () => setDevSick(true));
    if ($("devSickOff")) $("devSickOff").addEventListener("click", () => setDevSick(false));
    if ($("devStubbornOn")) $("devStubbornOn").addEventListener("click", () => setDevStubborn(true));
    if ($("devStubbornOff")) $("devStubbornOff").addEventListener("click", () => setDevStubborn(false));
    document.querySelectorAll("[data-dev-stat]").forEach((input) => {
      input.addEventListener("input", () => applyDevStat(input.dataset.devStat, input.value));
    });
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
    // Keep art in sync with front/side view without rewriting every frame.
    refreshArt(false);
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
      JimothySound.setOnChange(() => {
        refreshSoundButtons();
        save({ touchTick: false });
      });
      JimothySound.setAmbienceEnabled(!state.ambienceMuted, { announce: false });
      JimothySound.setSfxEnabled(!state.sfxMuted, { announce: false });
    }
    refreshSoundButtons();
    if (window.JimothyNotify) {
      JimothyNotify.setOnChange(() => refreshAlertsButton());
      if (state.alertsEnabled) {
        JimothyNotify.setEnabled(true).then(() => refreshAlertsButton());
      }
    }
    refreshAlertsButton();
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
        if (state.alertsEnabled && window.JimothyNotify) JimothyNotify.check(state);
        return;
      }
      syncRealtime({ announceDeath: true });
      render();
      save();
      if (state.alertsEnabled && window.JimothyNotify) JimothyNotify.check(state);
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
