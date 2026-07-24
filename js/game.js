/**
 * Jimothy — Tamagotchi-style raccoon pet.
 */
(() => {
  const STORAGE_KEY = "jimothy-pet-v1";
  const TICK_MS = 1000;
  // Accelerated life cycle so stages feel like classic Tamagotchi sessions.
  const STAGE_AGE = {
    egg: 45, // seconds until hatch
    hatchling: 90,
    kit: 150,
    teen: 210,
  };

  const FOOD = {
    berries: {
      name: "Berry Bundle",
      type: "healthy",
      hunger: 28,
      happy: 4,
      health: 8,
      refuseChance: 0.35,
    },
    acorns: {
      name: "Crunchy Acorns",
      type: "healthy",
      hunger: 24,
      happy: 6,
      health: 6,
      refuseChance: 0.3,
    },
    pizza: {
      name: "Pizza Crust",
      type: "treat",
      hunger: 12,
      happy: 22,
      health: -2,
      refuseChance: 0.05,
    },
    fries: {
      name: "Dumpster Fries",
      type: "treat",
      hunger: 10,
      happy: 26,
      health: -4,
      refuseChance: 0.08,
    },
  };

  const STAGE_META = {
    egg: { label: "Egg", name: "Mystery Egg" },
    hatchling: { label: "Hatchling", name: "Peep Jimothy" },
    kit: { label: "Kit", name: "Kit Jimothy" },
    teen: { label: "Teen", name: "Teen Jimothy" },
    adult: { label: "Adult", name: "Jimothy" },
  };

  const state = {
    bornAt: Date.now(),
    lastTick: Date.now(),
    ageSec: 0,
    stage: "egg",
    adultVariant: "noble",
    hunger: 80,
    happy: 80,
    health: 100,
    discipline: 55,
    weight: 1,
    careScore: 0,
    careMistakes: 0,
    stubborn: false,
    stubbornReason: "",
    hasMess: false,
    sick: false,
    alive: true,
    sleep: false,
    treatStreak: 0,
    healthyMeals: 0,
    playSessions: 0,
  };

  let speechTimer = 0;
  let tickHandle = 0;

  const $ = (id) => document.getElementById(id);

  function clamp(n, min = 0, max = 100) {
    return Math.max(min, Math.min(max, n));
  }

  function load() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return;
      const saved = JSON.parse(raw);
      Object.assign(state, saved);
      // Catch up to real wall-clock time (no cap).
      syncRealtime({ announceDeath: false });
    } catch {
      /* fresh pet */
    }
  }

  /**
   * Apply all elapsed real-world seconds since lastTick.
   * Works for browser tabs, installed PWAs, and Android wrappers.
   */
  function syncRealtime({ announceDeath = true } = {}) {
    const now = Date.now();
    const last = state.lastTick || now;
    const elapsed = Math.max(0, Math.floor((now - last) / 1000));
    const wasAlive = state.alive;
    if (elapsed > 0 && state.alive) applyDecay(elapsed);
    state.lastTick = now;
    if (announceDeath && wasAlive && !state.alive) {
      showMessage(
        "Jimothy wandered off…",
        "Time kept moving while you were away. Start a new egg?"
      );
      $("messageOk").dataset.reset = "1";
    }
    return elapsed;
  }

  function save({ touchTick = true } = {}) {
    if (touchTick) state.lastTick = Date.now();
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  }

  function resetPet() {
    Object.assign(state, {
      bornAt: Date.now(),
      lastTick: Date.now(),
      ageSec: 0,
      stage: "egg",
      adultVariant: "noble",
      hunger: 80,
      happy: 80,
      health: 100,
      discipline: 55,
      weight: 1,
      careScore: 0,
      careMistakes: 0,
      stubborn: false,
      stubbornReason: "",
      hasMess: false,
      sick: false,
      alive: true,
      sleep: false,
      treatStreak: 0,
      healthyMeals: 0,
      playSessions: 0,
    });
    save();
    render();
    say("A warm egg. Something wiggles inside…");
  }

  function applyDecay(seconds) {
    // Mild per-second drain; scales with life like classic units.
    const hungerDrain = 0.045 * seconds;
    const happyDrain = 0.035 * seconds;
    state.hunger = clamp(state.hunger - hungerDrain);
    state.happy = clamp(state.happy - happyDrain);
    state.ageSec += seconds;

    if (state.hasMess) {
      state.health = clamp(state.health - 0.02 * seconds);
      state.happy = clamp(state.happy - 0.015 * seconds);
    }
    if (state.hunger < 20) {
      state.health = clamp(state.health - 0.04 * seconds);
      state.happy = clamp(state.happy - 0.02 * seconds);
    }
    if (state.happy < 15) {
      state.health = clamp(state.health - 0.02 * seconds);
    }
    if (state.treatStreak > 3) {
      state.health = clamp(state.health - 0.01 * seconds);
    }

    // Random mess
    if (!state.hasMess && state.stage !== "egg" && Math.random() < seconds * 0.004) {
      state.hasMess = true;
    }

    // Random stubborn tantrum when discipline/hunger/happy are off
    maybeTantrum(seconds);

    if (state.health <= 0 || (state.hunger <= 0 && state.happy <= 0)) {
      state.alive = false;
      state.health = 0;
    }

    evolveIfNeeded();
  }

  function maybeTantrum(seconds) {
    if (state.stage === "egg" || state.stubborn || !state.alive) return;
    const chance =
      (0.002 + (100 - state.discipline) * 0.00004 + (state.hunger < 35 ? 0.002 : 0)) *
      seconds;
    if (Math.random() < chance) {
      state.stubborn = true;
      state.stubbornReason =
        Math.random() < 0.5 ? "refuses healthy food" : "refuses to exercise";
      state.careMistakes += 1;
    }
  }

  function evolveIfNeeded() {
    if (!state.alive) return;
    const prev = state.stage;
    if (state.stage === "egg" && state.ageSec >= STAGE_AGE.egg) {
      state.stage = "hatchling";
      state.weight = 2;
      say("Crack! Peep Jimothy hatched!");
      showMessage("Hatched!", "Peep Jimothy wiggled out of the egg. Feed him and keep him cozy.");
    } else if (state.stage === "hatchling" && state.ageSec >= STAGE_AGE.egg + STAGE_AGE.hatchling) {
      state.stage = "kit";
      state.weight = 5;
      say("Jimothy grew into a kit!");
      showMessage("Growth!", "Kit Jimothy is curious and sticky-pawed. Try Dumpster Dive.");
    } else if (
      state.stage === "kit" &&
      state.ageSec >= STAGE_AGE.egg + STAGE_AGE.hatchling + STAGE_AGE.kit
    ) {
      state.stage = "teen";
      state.weight = 9;
      say("Teen Jimothy! Attitude unlocked.");
      showMessage("Teen Stage", "He's sassier now. Healthy meals and discipline matter more.");
    } else if (
      state.stage === "teen" &&
      state.ageSec >=
        STAGE_AGE.egg + STAGE_AGE.hatchling + STAGE_AGE.kit + STAGE_AGE.teen
    ) {
      state.stage = "adult";
      state.weight = 14;
      const goodCare =
        state.careScore >= 8 &&
        state.careMistakes <= 6 &&
        state.healthyMeals >= 3 &&
        state.discipline >= 45;
      state.adultVariant = goodCare ? "noble" : "rascal";
      const title = goodCare ? "Noble Jimothy" : "Rascal Jimothy";
      STAGE_META.adult.name = title;
      say(goodCare ? "He became Noble Jimothy!" : "He became Rascal Jimothy!");
      showMessage(
        "Fully Grown!",
        goodCare
          ? "Your care paid off — Noble Jimothy tip-toes with class (and still steals snacks)."
          : "Chaos wins — Rascal Jimothy is a dumpster legend with a mischievous streak."
      );
    }
    if (prev !== state.stage) save();
  }

  function say(text, ms = 2600) {
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

  function formatAge() {
    const m = Math.floor(state.ageSec / 60);
    const s = Math.floor(state.ageSec % 60);
    if (m <= 0) return `Age ${s}s`;
    return `Age ${m}m`;
  }

  function clockNow() {
    const d = new Date();
    return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  }

  function alertText() {
    if (!state.alive) return { text: "Jimothy needs a new life… tap OK after the notice.", danger: true };
    if (state.sick) return { text: "Jimothy feels queasy from too many treats.", danger: true };
    if (state.stubborn) {
      return {
        text: `Acting up — ${state.stubbornReason}. Use Scold.`,
        danger: true,
      };
    }
    if (state.hasMess) return { text: "There's a mess. Clean it up!", danger: false };
    if (state.hunger < 25) return { text: "Jimothy is starving for snacks.", danger: true };
    if (state.happy < 25) return { text: "Jimothy is bored. Try Dumpster Dive.", danger: false };
    if (state.health < 30) return { text: "Health is low — feed healthy meals.", danger: true };
    return null;
  }

  function render() {
    $("clock").textContent = clockNow();
    $("ageLabel").textContent = formatAge();
    const meta = STAGE_META[state.stage];
    if (state.stage === "adult") {
      meta.name = state.adultVariant === "noble" ? "Noble Jimothy" : "Rascal Jimothy";
    }
    $("stageChip").textContent = meta.label;
    $("stageName").textContent = state.alive ? meta.name : "Gone to the woods…";

    $("hungerFill").style.width = `${state.hunger}%`;
    $("happyFill").style.width = `${state.happy}%`;
    $("healthFill").style.width = `${state.health}%`;
    $("disciplineFill").style.width = `${state.discipline}%`;

    const wrap = $("raccoonWrap");
    wrap.classList.toggle("stubborn", state.stubborn && state.alive);
    wrap.classList.toggle("sick", state.sick && state.alive);
    $("raccoon").dataset.stage = state.stage;
    $("raccoon").dataset.mood = state.stubborn ? "stubborn" : state.sick ? "sick" : "idle";
    $("raccoon").innerHTML = state.alive
      ? RaccoonArt.render(state.stage, state.adultVariant)
      : RaccoonArt.render("egg");

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

    const btnDiscipline = $("btnDiscipline");
    const btnClean = $("btnClean");
    const btnFeed = $("btnFeed");
    const btnPlay = $("btnPlay");

    btnDiscipline.disabled = !(state.alive && state.stubborn);
    btnClean.disabled = !(state.alive && state.hasMess);
    btnFeed.disabled = !state.alive || state.stage === "egg";
    btnPlay.disabled = !state.alive || state.stage === "egg";

    btnDiscipline.classList.toggle("needs-attention", state.stubborn && state.alive);
    btnClean.classList.toggle("needs-attention", state.hasMess && state.alive);

    if (state.stage === "egg") {
      $("hint").textContent = "The egg is warming… it will hatch on its own.";
    } else if (!state.alive) {
      $("hint").textContent = "Care carefully next time — healthy meals and play raise his path.";
    } else {
      $("hint").textContent =
        "Feed treats or healthy meals, play Dumpster Dive, and scold him if he acts up.";
    }
  }

  function openFeed() {
    if (!state.alive || state.stage === "egg") return;
    $("feedModal").hidden = false;
  }

  function closeFeed() {
    $("feedModal").hidden = true;
  }

  function feed(foodKey) {
    const food = FOOD[foodKey];
    if (!food || !state.alive) return;

    // Stubborn refusal of healthy meals
    if (state.stubborn && food.type === "healthy") {
      say("Nope! Paws crossed. He refuses the healthy meal.");
      closeFeed();
      render();
      return;
    }

    // Discipline-based refusal for healthy food
    const refuseRoll = Math.random();
    const disciplineFactor = (100 - state.discipline) / 100;
    if (
      food.type === "healthy" &&
      refuseRoll < food.refuseChance * (0.45 + disciplineFactor)
    ) {
      state.stubborn = true;
      state.stubbornReason = "refuses healthy food";
      state.careMistakes += 1;
      say(`Jimothy pushes away the ${food.name.toLowerCase()}!`);
      closeFeed();
      render();
      save();
      return;
    }

    state.hunger = clamp(state.hunger + food.hunger);
    state.happy = clamp(state.happy + food.happy);
    state.health = clamp(state.health + food.health);
    state.weight += food.type === "treat" ? 0.4 : 0.2;

    if (food.type === "treat") {
      state.treatStreak += 1;
      if (state.treatStreak >= 4) {
        state.sick = true;
        state.health = clamp(state.health - 10);
        say("Too many treats… Jimothy looks green around the mask.");
      } else {
        say(`Nom nom — ${food.name}!`);
        bounceHappy();
      }
    } else {
      state.treatStreak = 0;
      state.healthyMeals += 1;
      state.careScore += 1;
      state.sick = false;
      state.discipline = clamp(state.discipline + 2);
      say(`Crunch — ${food.name}. Good choice.`);
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
    state.discipline = clamp(state.discipline + 12);
    state.happy = clamp(state.happy - 6);
    state.careScore += 1;
    say("Hey! Listen up, bandit. …okay, okay.");
    render();
    save();
  }

  function clean() {
    if (!state.alive || !state.hasMess) return;
    state.hasMess = false;
    state.happy = clamp(state.happy + 4);
    state.health = clamp(state.health + 3);
    state.careScore += 1;
    say("All tidy. Whiskers gleam.");
    render();
    save();
  }

  function openGame() {
    if (!state.alive || state.stage === "egg") return;

    if (state.stubborn && state.stubbornReason.includes("exercise")) {
      say("He plants his paws. No dumpster diving until you scold him.");
      render();
      return;
    }

    // Chance to refuse play when discipline is low
    if (!state.stubborn && state.discipline < 40 && Math.random() < 0.35) {
      state.stubborn = true;
      state.stubbornReason = "refuses to exercise";
      state.careMistakes += 1;
      say("Jimothy flops over. Absolutely not playing.");
      render();
      save();
      return;
    }

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
      say("Maybe later, alley cat.");
      return;
    }

    state.playSessions += 1;
    state.happy = clamp(state.happy + 10 + result.stars * 6);
    state.hunger = clamp(state.hunger - 6);
    state.health = clamp(state.health + 4 + result.stars);
    state.discipline = clamp(state.discipline + 3);
    state.careScore += result.stars > 0 ? 2 : 1;
    state.weight = Math.max(1, state.weight - 0.15 * result.stars);
    bounceHappy();
    say(
      result.stars >= 3
        ? "Legendary dive! Shiny treasures secured."
        : result.stars >= 1
          ? `Nice dive — score ${result.score}.`
          : `A sleepy dive. Score ${result.score}.`
    );
    render();
    save();
  }

  function onTick() {
    if (!state.alive) {
      render();
      return;
    }
    applyDecay(1);
    if (!state.alive) {
      showMessage(
        "Jimothy wandered off…",
        "Neglect, sickness, or empty meters sent him back to the woods. Start a new egg?"
      );
      $("messageOk").dataset.reset = "1";
    }
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
    $("feedClose").addEventListener("click", closeFeed);
    $("gameClose").addEventListener("click", closeGame);
    $("messageOk").addEventListener("click", () => {
      const shouldReset = $("messageOk").dataset.reset === "1";
      hideMessage();
      if (shouldReset) {
        $("messageOk").dataset.reset = "";
        resetPet();
      }
    });

    document.querySelectorAll(".food-btn").forEach((btn) => {
      btn.addEventListener("click", () => feed(btn.dataset.food));
    });

    $("feedModal").addEventListener("click", (e) => {
      if (e.target === $("feedModal")) closeFeed();
    });
  }

  function init() {
    wireIcons();
    bind();
    load();
    if (!localStorage.getItem(STORAGE_KEY)) {
      say("A warm egg. Something wiggles inside…");
    }
    // Ensure adult name meta is correct after load
    if (state.stage === "adult") {
      STAGE_META.adult.name =
        state.adultVariant === "noble" ? "Noble Jimothy" : "Rascal Jimothy";
    }
    render();
    if (!state.alive) {
      showMessage(
        "Jimothy wandered off…",
        "Your last raccoon headed back to the woods. Start a new egg?"
      );
      $("messageOk").dataset.reset = "1";
    }
    tickHandle = setInterval(onTick, TICK_MS);
    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "hidden") {
        save();
        return;
      }
      // Returning from background / another app: catch up full real time.
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

  // Lightweight debug hook for tests / tinkering in the console.
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
  };
})();
