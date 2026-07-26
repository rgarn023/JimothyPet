/**
 * Care notifications — specific needs (hungry / sick / acting up / waste / bored)
 * and combinations, plus new-form milestones.
 * Uses Notification API (+ service worker when the tab is hidden).
 */
const JimothyNotify = (() => {
  const COOLDOWN_MS = 12 * 60 * 1000;
  let enabled = false;
  let lastSent = { care: 0, form: 0 };
  let lastCareFp = "";
  let onChange = null;

  function supported() {
    return typeof window !== "undefined" && "Notification" in window;
  }

  function permission() {
    if (!supported()) return "unsupported";
    return Notification.permission; // granted | denied | default
  }

  function isEnabled() {
    return enabled && permission() === "granted";
  }

  function setOnChange(fn) {
    onChange = fn;
  }

  function loadCooldowns() {
    try {
      const raw = localStorage.getItem("jimothy-notify-cooldowns");
      if (raw) {
        const parsed = JSON.parse(raw);
        lastSent = { ...lastSent, ...parsed };
        if (parsed.lastCareFp) lastCareFp = String(parsed.lastCareFp);
      }
    } catch {
      /* ignore */
    }
  }

  function saveCooldowns() {
    try {
      localStorage.setItem(
        "jimothy-notify-cooldowns",
        JSON.stringify({ ...lastSent, lastCareFp })
      );
    } catch {
      /* ignore */
    }
  }

  loadCooldowns();

  async function requestPermission() {
    if (!supported()) return "unsupported";
    if (Notification.permission === "granted") return "granted";
    if (Notification.permission === "denied") return "denied";
    try {
      const result = await Notification.requestPermission();
      return result;
    } catch {
      return Notification.permission;
    }
  }

  async function setEnabled(on) {
    if (!on) {
      enabled = false;
      if (onChange) onChange(false);
      return false;
    }
    if (!supported()) {
      enabled = false;
      if (onChange) onChange(false);
      return false;
    }
    const perm = await requestPermission();
    enabled = perm === "granted";
    if (onChange) onChange(enabled);
    return enabled;
  }

  async function show(kind, title, body, opts = {}) {
    const force = !!opts.force;
    if (!isEnabled()) return false;
    const now = Date.now();
    if (!force && now - (lastSent[kind] || 0) < COOLDOWN_MS) return false;
    lastSent[kind] = now;
    saveCooldowns();

    const notifOpts = {
      body,
      icon: "icons/icon-192.png",
      badge: "icons/icon-192.png",
      tag: opts.tag || `jimothy-${kind}`,
      renotify: true,
      data: { kind, url: "./" },
    };

    try {
      if ("serviceWorker" in navigator) {
        try {
          const reg = await navigator.serviceWorker.ready;
          if (reg && reg.showNotification) {
            await reg.showNotification(title, notifOpts);
            return true;
          }
        } catch {
          /* fall through */
        }
      }
      const n = new Notification(title, notifOpts);
      n.onclick = () => {
        window.focus();
        n.close();
      };
      return true;
    } catch (err) {
      console.warn("notify failed", err);
      return false;
    }
  }

  function notifyForm(stage, formLabel) {
    const pretty = formLabel || capitalize(stage);
    let title = "Jimothy found a new form";
    let body = `He’s a ${pretty} now. Open the app to see him.`;
    if (stage === "baby") {
      title = "Jimothy popped out of the bush";
      body = "Baby kit Jimothy burst from the leaves. Open the app!";
    } else if (stage === "young") {
      body = `Young kit form: ${pretty}. Check Form paths for his forks.`;
    } else if (stage === "teen") {
      body = `Teen kit form: ${pretty}. Adult flair is taking shape.`;
    } else if (stage === "adult") {
      body = `${pretty} Jimothy — fully grown short-spine cryptid.`;
    }
    return show("form", title, body, {
      force: true,
      tag: `jimothy-form-${stage}-${String(formLabel || stage).replace(/\s+/g, "-")}`,
    });
  }

  function capitalize(s) {
    return String(s || "")
      .replace(/_/g, " ")
      .replace(/\b\w/g, (c) => c.toUpperCase());
  }

  function careSnapshot(state) {
    const flags = [];
    const lines = [];

    if (state.sick) {
      flags.push("sick");
      lines.push("Sick — open Action → Heal (upset stomach).");
    }
    if (state.stubborn) {
      flags.push("acting up");
      lines.push(
        state.stubbornReason
          ? `Acting up — he’s ${state.stubbornReason}. Scold him.`
          : "Acting up — open Action → Scold."
      );
    }
    if (state.hunger < 25) {
      flags.push("hungry");
      lines.push("Hungry — feed him a real meal.");
    }
    const messCount = state.messCount || (state.hasMess ? 1 : 0);
    if (messCount > 0 || state.hasMess) {
      flags.push("waste");
      lines.push(
        messCount <= 1
          ? "Waste — one pile in the nest. Clean it."
          : `Waste — ${messCount} piles in the nest. Clean them.`
      );
    }
    const canPlay = state.stage !== "baby" && state.energy >= 18 && state.happy < 25;
    if (canPlay) {
      flags.push("bored");
      lines.push("Bored — open Play for a game.");
    } else if (state.health < 30 && !state.sick) {
      flags.push("run-down");
      lines.push("Run-down — skip treats; offer fish or berries.");
    }

    return { flags, lines, fp: flags.join("|") };
  }

  function careTitle(flags) {
    const n = flags.length;
    if (n === 0) return "Jimothy needs care";
    if (n === 1) {
      switch (flags[0]) {
        case "sick":
          return "Jimothy is sick";
        case "acting up":
          return "Jimothy is acting up";
        case "hungry":
          return "Jimothy is hungry";
        case "waste":
          return "Jimothy left a mess";
        case "bored":
          return "Jimothy is bored";
        case "run-down":
          return "Jimothy is run-down";
        default:
          return "Jimothy needs care";
      }
    }
    if (n === 2) return `Jimothy: ${flags[0]} & ${flags[1]}`;
    return `Jimothy needs care (${n} things)`;
  }

  function predictEvents(state) {
    const out = [];
    if (!state || !state.alive || state.ascending) return out;
    const HUNGER_RATE = 0.0028;
    const HAPPY_RATE = 0.0022;
    const MAX_DELAY = 7 * 24 * 3600;
    const age = Number(state.ageSec || 0);
    const clampDelay = (d) => Math.max(1, Math.min(MAX_DELAY, Math.ceil(d)));

    if (state.stage === "bush") {
      out.push({
        key: "bush",
        delay: clampDelay(60 - age),
        title: "Jimothy popped out of the bush",
        body: "Baby kit Jimothy burst from the leaves. Open the app!",
      });
      return out;
    }

    if (state.sick) {
      out.push({
        key: "sick",
        delay: 1,
        title: "Jimothy is sick",
        body: "Upset stomach — open Action → Heal.",
      });
    }
    if (state.stubborn) {
      out.push({
        key: "acting",
        delay: state.sick ? 2 : 1,
        title: "Jimothy is acting up",
        body: state.stubbornReason
          ? `He’s ${state.stubbornReason}. Open Action → Scold.`
          : "Open Action → Scold.",
      });
    }
    if (state.hunger < 25) {
      out.push({
        key: "hungry",
        delay: 1,
        title: "Jimothy is hungry",
        body: "He’s hunting for a real meal. Time to feed him.",
      });
    } else if (state.hunger > 25) {
      out.push({
        key: "hungry",
        delay: clampDelay((state.hunger - 25) / HUNGER_RATE),
        title: "Jimothy is hungry",
        body: "He’s hunting for a real meal. Time to feed him.",
      });
    }

    const messCount = state.messCount || (state.hasMess ? 1 : 0);
    if (messCount > 0 || state.hasMess) {
      out.push({
        key: "waste",
        delay: 1,
        title: "Jimothy left a mess",
        body:
          messCount > 1
            ? `${messCount} waste piles in the nest — Clean them.`
            : "One waste pile in the nest — Clean it.",
      });
    }

    if (state.stage !== "baby") {
      if (state.happy < 25 && state.energy >= 18) {
        out.push({
          key: "bored",
          delay: 1,
          title: "Jimothy is bored",
          body: "Restless energy — open Play for a game.",
        });
      } else if (state.happy > 25) {
        out.push({
          key: "bored",
          delay: clampDelay((state.happy - 25) / HAPPY_RATE),
          title: "Jimothy is bored",
          body: "Restless energy — open Play for a game.",
        });
      }
    }
    return out;
  }

  async function scheduleBackground(state) {
    if (!isEnabled() || !state) return 0;
    if (!("serviceWorker" in navigator) || typeof TimestampTrigger === "undefined") {
      return 0;
    }
    let reg;
    try {
      reg = await navigator.serviceWorker.ready;
    } catch {
      return 0;
    }
    if (!reg || !reg.showNotification) return 0;

    const events = predictEvents(state);
    let n = 0;
    for (const ev of events) {
      try {
        await reg.showNotification(ev.title, {
          body: ev.body,
          icon: "icons/icon-192.png",
          badge: "icons/icon-192.png",
          tag: `jimothy-sched-${ev.key}`,
          renotify: true,
          showTrigger: new TimestampTrigger(Date.now() + ev.delay * 1000),
          data: { kind: ev.key, url: "./" },
        });
        n += 1;
      } catch {
        /* browser may block Notification Triggers */
      }
    }
    return n;
  }

  /** Inspect pet state and fire one combined care alert when needed. */
  function check(state) {
    if (!state || !state.alive || state.ascending) return;
    if (!isEnabled()) return;

    // Always refresh closed-tab / background schedules when supported.
    scheduleBackground(state);

    if (state.stage === "bush") return;

    const snap = careSnapshot(state);
    if (!snap.flags.length) {
      lastCareFp = "";
      saveCooldowns();
      return;
    }

    const now = Date.now();
    if (snap.fp === lastCareFp && now - (lastSent.care || 0) < COOLDOWN_MS) {
      return;
    }

    show("care", careTitle(snap.flags), snap.lines.join("\n"), {
      force: true,
      tag: `jimothy-care-${snap.fp.replace(/\|/g, "-")}`,
    }).then((ok) => {
      if (ok) {
        lastCareFp = snap.fp;
        saveCooldowns();
      }
    });
  }

  return {
    supported,
    permission,
    isEnabled,
    setEnabled,
    setOnChange,
    check,
    show,
    notifyForm,
    scheduleBackground,
  };
})();

window.JimothyNotify = JimothyNotify;
