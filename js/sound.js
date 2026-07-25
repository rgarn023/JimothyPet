/**
 * Night ambience + raccoon SFX for Jimothy (HTMLAudio).
 * Background (ambience/owl) and Jimothy SFX can be toggled separately.
 * Starts after the first user gesture (browser autoplay rules).
 */
const JimothySound = (() => {
  const BASE = "audio/";
  const FILES = {
    night: "night_ambience.wav",
    chitter: "chitter.wav",
    chirp: "chirp.wav",
    grumble: "grumble.wav",
    rustle: "rustle.wav",
    crunch: "crunch.wav",
    ascend: "ascend.wav",
    hoot: "hoot.wav",
  };
  const BG_KEYS = new Set(["night", "hoot"]);

  let ambienceOn = true;
  let sfxOn = true;
  let unlocked = false;
  let ambience = null;
  const buffers = {};
  let accentTimer = null;
  let onChange = null;

  function notify() {
    if (onChange) onChange({ ambienceOn, sfxOn });
  }

  function setAmbienceEnabled(on, opts = {}) {
    ambienceOn = !!on;
    if (ambienceOn) {
      unlock();
      startAmbience();
      scheduleAccents();
    } else {
      stopAmbience();
      // Keep accents timer only if SFX still wants Jimothy ambient chirps — accents mix both.
      if (!sfxOn) clearAccents();
      else scheduleAccents();
    }
    if (opts.announce !== false && ambienceOn && sfxOn) play("chirp", 0.35);
    notify();
    return ambienceOn;
  }

  function setSfxEnabled(on, opts = {}) {
    sfxOn = !!on;
    if (sfxOn) {
      unlock();
      scheduleAccents();
      if (opts.announce !== false) play("chitter", 0.4);
    } else if (!ambienceOn) {
      clearAccents();
    } else {
      scheduleAccents();
    }
    notify();
    return sfxOn;
  }

  /** Legacy master switch — turns both on/off. */
  function setEnabled(on, opts = {}) {
    const want = !!on;
    setAmbienceEnabled(want, { announce: false });
    setSfxEnabled(want, opts);
    return want;
  }

  function toggle() {
    const next = !(ambienceOn || sfxOn);
    return setEnabled(next);
  }

  function isEnabled() {
    return ambienceOn || sfxOn;
  }

  function isAmbienceEnabled() {
    return ambienceOn;
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
    if (ambienceOn) startAmbience();
    if (ambienceOn || sfxOn) scheduleAccents();
  }

  function ensureAudio(key) {
    if (buffers[key]) return buffers[key];
    const a = new Audio(BASE + FILES[key]);
    a.preload = "auto";
    if (key === "night") {
      a.loop = true;
      a.volume = 0.3;
    } else {
      a.volume = 0.72;
    }
    buffers[key] = a;
    return a;
  }

  function startAmbience() {
    if (!ambienceOn || !unlocked) return;
    const a = ensureAudio("night");
    ambience = a;
    const p = a.play();
    if (p && p.catch) p.catch(() => {});
  }

  function stopAmbience() {
    if (ambience) {
      ambience.pause();
      try {
        ambience.currentTime = 0;
      } catch {
        /* ignore */
      }
    }
  }

  function play(kind, volume = 0.7) {
    if (!unlocked) return;
    if (!FILES[kind]) return;
    const isBg = BG_KEYS.has(kind);
    if (isBg && !ambienceOn) return;
    if (!isBg && !sfxOn) return;
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
        play("crunch", 0.78);
        play("chitter", 0.48);
        break;
      case "refuse":
      case "stubborn":
        play("grumble", 0.78);
        break;
      case "scold":
        play("chitter", 0.65);
        break;
      case "heal":
      case "treat":
        play("chirp", 0.5);
        play("chitter", 0.4);
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
        play("chirp", 0.6);
        play("chitter", 0.45);
        break;
      case "bush":
        play("rustle", 0.7);
        break;
      case "play":
        play("rustle", 0.6);
        play("chitter", 0.5);
        break;
      case "clean":
        play("rustle", 0.45);
        break;
      case "pet":
      case "smile":
      case "nuzzle":
        play("chitter", 0.55);
        break;
      case "hop":
      case "spin":
      case "happy":
        play("chirp", 0.55);
        play("chitter", 0.3);
        break;
      case "speech":
        if (Math.random() < 0.55) play("chitter", 0.35);
        break;
      default:
        break;
    }
  }

  function scheduleAccents() {
    clearAccents();
    if (!ambienceOn && !sfxOn) return;
    const tick = () => {
      accentTimer = setTimeout(() => {
        if (!unlocked || (!ambienceOn && !sfxOn)) return;
        const stage = window.JimothyDebug?.getState?.()?.stage;
        const alive = window.JimothyDebug?.getState?.()?.alive;
        const ascending = window.JimothyDebug?.getState?.()?.ascending;
        if (stage === "bush" && alive && sfxOn) play("rustle", 0.4);
        else if (alive && !ascending && ambienceOn && Math.random() < 0.5) play("hoot", 0.32);
        else if (alive && !ascending && sfxOn && Math.random() < 0.35) play("chitter", 0.28);
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
    startAmbience,
  };
})();

window.JimothySound = JimothySound;
