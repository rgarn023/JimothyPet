/**
 * Jimothy raccoon SFX (HTMLAudio).
 * Starts after the first user gesture (browser autoplay rules).
 */
const JimothySound = (() => {
  const BASE = "audio/";
  const FILES = {
    chitter: "chitter.wav",
    chirp: "chirp.wav",
    grumble: "grumble.wav",
    rustle: "rustle.wav",
    crunch: "crunch.wav",
    chew: "chew.wav",
    cry: "cry.wav",
    discipline: "discipline.wav",
    ascend: "ascend.wav",
    sick: "sick.wav",
    heal: "heal.wav",
    sleep: "sleep.wav",
    lights: "lights.wav",
  };
  const CRY_MS = 5000;

  let sfxOn = true;
  let unlocked = false;
  const buffers = {};
  let accentTimer = null;
  let onChange = null;
  let activeCry = null;
  let cryTimer = null;
  let cryBusyUntil = 0;

  function notify() {
    if (onChange) onChange({ ambienceOn: false, sfxOn });
  }

  function setAmbienceEnabled(_on, _opts = {}) {
    // Background ambience removed — always off.
    notify();
    return false;
  }

  function setSfxEnabled(on, opts = {}) {
    sfxOn = !!on;
    if (sfxOn) {
      unlock();
      scheduleAccents();
      if (opts.announce !== false) play("chitter", 0.4);
    } else {
      clearAccents();
      stopCry();
    }
    notify();
    return sfxOn;
  }

  /** Legacy master switch — controls Jimothy SFX only. */
  function setEnabled(on, opts = {}) {
    return setSfxEnabled(!!on, opts);
  }

  function toggle() {
    return setEnabled(!sfxOn);
  }

  function isEnabled() {
    return sfxOn;
  }

  function isAmbienceEnabled() {
    return false;
  }

  function isSfxEnabled() {
    return sfxOn;
  }

  function setOnChange(fn) {
    onChange = fn;
  }

  function unlock() {
    if (unlocked) return;
    unlocked = true;
    Object.keys(FILES).forEach((key) => ensureAudio(key));
    if (sfxOn) scheduleAccents();
  }

  function ensureAudio(key) {
    if (buffers[key]) return buffers[key];
    const a = new Audio(BASE + FILES[key]);
    a.preload = "auto";
    a.volume = 0.72;
    buffers[key] = a;
    return a;
  }

  function stopCry() {
    if (cryTimer) {
      clearTimeout(cryTimer);
      cryTimer = null;
    }
    if (activeCry) {
      try {
        activeCry.pause();
        activeCry.currentTime = 0;
      } catch {
        /* ignore */
      }
      activeCry = null;
    }
    cryBusyUntil = 0;
  }

  function playCry(volume = 0.85) {
    if (!unlocked || !sfxOn) return;
    // One 5s cry per acting-up bout — ignore ambient stubborn pulses.
    if (Date.now() < cryBusyUntil) return;
    stopCry();
    const base = ensureAudio("cry");
    const a = base.cloneNode();
    a.volume = Math.max(0, Math.min(1, volume));
    a.playbackRate = 1.0;
    activeCry = a;
    cryBusyUntil = Date.now() + CRY_MS;
    a.onended = () => {
      if (activeCry === a) activeCry = null;
    };
    const p = a.play();
    if (p && p.catch) p.catch(() => {});
    // Hard stop at exactly 5 seconds.
    cryTimer = setTimeout(() => {
      cryTimer = null;
      if (activeCry === a) {
        try {
          a.pause();
          a.currentTime = 0;
        } catch {
          /* ignore */
        }
        activeCry = null;
      }
    }, CRY_MS);
  }

  function play(kind, volume = 0.7) {
    if (!unlocked) return;
    if (!FILES[kind]) return;
    if (!sfxOn) return;
    if (kind === "cry") {
      playCry(volume);
      return;
    }
    const base = ensureAudio(kind);
    const a = base.cloneNode();
    a.volume = Math.max(0, Math.min(1, volume));
    a.playbackRate = 0.94 + Math.random() * 0.12;
    const p = a.play();
    if (p && p.catch) p.catch(() => {});
  }

  function cue(kind) {
    switch (kind) {
      case "eat":
        play("chew", 0.82);
        play("crunch", 0.45);
        break;
      case "refuse":
      case "grumble":
        play("grumble", 0.78);
        break;
      case "stubborn":
        playCry(0.85);
        break;
      case "scold":
        stopCry();
        play("discipline", 0.88);
        break;
      case "sick":
        play("sick", 0.8);
        break;
      case "heal":
      case "treat":
        play("heal", 0.78);
        play("chirp", 0.35);
        break;
      case "lights":
        play("lights", 0.7);
        break;
      case "fallAsleep":
      case "sleep":
        // "sleep" cue is the settle-in one-shot; ambient sleep pose pulses stay silent.
        play("sleep", 0.75);
        play("rustle", 0.35);
        break;
      case "pop":
      case "stretch":
        play("rustle", 0.7);
        play("chirp", 0.6);
        break;
      case "ascend":
        play("ascend", 0.85);
        break;
      case "baby":
        play("rustle", 0.8);
        play("chirp", 0.7);
        break;
      case "stage":
      case "stageUp":
        play("chirp", 0.85);
        play("chitter", 0.7);
        play("rustle", 0.45);
        break;
      case "bush":
        play("rustle", 0.95);
        play("chitter", 0.55);
        break;
      case "play":
        play("rustle", 0.6);
        play("chitter", 0.5);
        break;
      case "clean":
        play("rustle", 0.55);
        play("chitter", 0.3);
        break;
      case "pet":
      case "smile":
      case "nuzzle":
        // Tap reactions — intentionally loud so pets read clearly.
        play("chitter", 1.0);
        play("chirp", 0.9);
        break;
      case "chirp":
      case "hop":
      case "spin":
      case "happy":
        play("chirp", 1.0);
        play("chitter", 0.85);
        break;
      case "speech":
        if (Math.random() < 0.55) play("chitter", 0.35);
        break;
      default:
        if (FILES[kind]) play(kind, 0.7);
        break;
    }
  }

  function scheduleAccents() {
    clearAccents();
    if (!sfxOn) return;
    const tick = () => {
      accentTimer = setTimeout(() => {
        if (!unlocked || !sfxOn) return;
        const stage = window.JimothyDebug?.getState?.()?.stage;
        const alive = window.JimothyDebug?.getState?.()?.alive;
        const ascending = window.JimothyDebug?.getState?.()?.ascending;
        const sleeping = window.JimothyDebug?.getState?.()?.sleeping;
        if (sleeping) {
          tick();
          return;
        }
        if (stage === "bush" && alive) play("rustle", 0.4);
        else if (alive && !ascending && Math.random() < 0.35) play("chitter", 0.28);
        tick();
      }, 6000 + Math.random() * 8000);
    };
    tick();
  }

  function clearAccents() {
    if (accentTimer) clearTimeout(accentTimer);
    accentTimer = null;
  }

  function bindGestureUnlock() {
    const once = () => {
      unlock();
      window.removeEventListener("pointerdown", once);
      window.removeEventListener("keydown", once);
    };
    window.addEventListener("pointerdown", once);
    window.addEventListener("keydown", once);
  }

  bindGestureUnlock();

  return {
    setEnabled,
    setAmbienceEnabled,
    setSfxEnabled,
    toggle,
    isEnabled,
    isAmbienceEnabled,
    isSfxEnabled,
    setOnChange,
    unlock,
    play,
    cue,
    startAmbience: () => {},
    stopCry,
  };
})();

window.JimothySound = JimothySound;
