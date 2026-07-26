/**
 * Care notifications — hungry, play, acting up, waste, new form.
 * Uses Notification API (+ service worker when the tab is hidden).
 */
const JimothyNotify = (() => {
  const COOLDOWN_MS = 12 * 60 * 1000; // per-kind cooldown (care needs)
  let enabled = false;
  let lastSent = { hungry: 0, play: 0, stubborn: 0, waste: 0, form: 0 };
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
      if (raw) lastSent = { ...lastSent, ...JSON.parse(raw) };
    } catch {
      /* ignore */
    }
  }

  function saveCooldowns() {
    try {
      localStorage.setItem("jimothy-notify-cooldowns", JSON.stringify(lastSent));
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

  function canSend(kind) {
    if (!isEnabled()) return false;
    const now = Date.now();
    return now - (lastSent[kind] || 0) >= COOLDOWN_MS;
  }

  async function show(kind, title, body, opts = {}) {
    const force = !!opts.force;
    if (!force && !canSend(kind)) return false;
    if (!isEnabled()) return false;
    lastSent[kind] = Date.now();
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
      // Prefer the service worker on phones / PWAs — more reliable as a system notification.
      if ("serviceWorker" in navigator) {
        try {
          const reg = await navigator.serviceWorker.ready;
          if (reg && reg.showNotification) {
            await reg.showNotification(title, notifOpts);
            return true;
          }
        } catch {
          /* fall through to Notification API */
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

  /** Rare milestone — new form / stage. Bypasses care cooldown. */
  function notifyForm(stage, formLabel) {
    const pretty = formLabel || capitalize(stage);
    const title = "Jimothy found a new form";
    let body = `He’s a ${pretty} now. Open the app to see him.`;
    if (stage === "baby") {
      body = "Baby kit Jimothy burst from the bush!";
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
    return String(s || "").replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
  }

  /** Inspect pet state and fire care alerts when needed. */
  function check(state) {
    if (!state || !state.alive || state.ascending || state.stage === "bush") return;

    if (state.stubborn) {
      show(
        "stubborn",
        "Jimothy is acting up",
        state.stubbornReason
          ? `He’s ${state.stubbornReason}. Open the app and scold him.`
          : "He’s being stubborn — open the app and scold him."
      );
    }

    if (state.hunger < 25) {
      show("hungry", "Jimothy is hungry", "He’s hunting for a real meal. Time to feed him.");
    }

    const canPlay =
      state.stage !== "baby" && state.energy >= 18 && state.happy < 25;
    if (canPlay) {
      show(
        "play",
        "Jimothy wants to play",
        "Restless cryptid energy — try a Dumpster Dive night run."
      );
    }

    if ((state.messCount || 0) > 0 || state.hasMess) {
      show(
        "waste",
        "Jimothy left a mess",
        "Nest waste is piling up — open the app and Clean."
      );
    }
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
  };
})();

window.JimothyNotify = JimothyNotify;
