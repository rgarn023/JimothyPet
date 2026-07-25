/**
 * Night ambience + raccoon SFX for Jimothy (Web Audio / HTMLAudio).
 * Starts ambience after the first user gesture (browser autoplay rules).
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

  let enabled = true;
  let unlocked = false;
  let ambience = null;
  const buffers = {};
  let accentTimer = null;
  let onChange = null;

  function setEnabled(on, opts = {}) {
    const announce = opts.announce !== false;
    enabled = !!on;
    if (enabled) {
      unlock();
      startAmbience();
      if (announce) play("chirp", 0.45);
      scheduleAccents();
    } else {
      stopAmbience();
      clearAccents();
    }
    if (onChange) onChange(enabled);
    return enabled;
  }

  function toggle() {
    return setEnabled(!enabled);
  }

  function isEnabled() {
    return enabled;
  }

  function setOnChange(fn) {
    onChange = fn;
  }

  function unlock() {
    if (unlocked) return;
    unlocked = true;
    // Warm-decode all clips
    Object.keys(FILES).forEach((key) => ensureAudio(key));
    if (enabled) {
      startAmbience();
      scheduleAccents();
    }
  }

  function ensureAudio(key) {
    if (buffers[key]) return buffers[key];
    const a = new Audio(BASE + FILES[key]);
    a.preload = "auto";
    if (key === "night") {
      a.loop = true;
      a.volume = 0.28;
    } else {
      a.volume = 0.7;
    }
    buffers[key] = a;
    return a;
  }

  function startAmbience() {
    if (!enabled || !unlocked) return;
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
    if (!enabled || !unlocked) return;
    if (!FILES[kind]) return;
    const base = ensureAudio(kind);
    // Clone so overlapping SFX work
    const a = base.cloneNode();
    a.volume = Math.max(0, Math.min(1, volume));
    a.playbackRate = 0.94 + Math.random() * 0.12;
    const p = a.play();
    if (p && p.catch) p.catch(() => {});
  }

  function cue(kind) {
    switch (kind) {
      case "eat":
        play("crunch", 0.75);
        play("chitter", 0.5);
        break;
      case "refuse":
      case "stubborn":
        play("grumble", 0.75);
        break;
      case "scold":
        play("chitter", 0.65);
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
    if (!enabled) return;
    const tick = () => {
      accentTimer = setTimeout(() => {
        if (!enabled || !unlocked) return;
        const stage = window.JimothyDebug?.getState?.()?.stage;
        const alive = window.JimothyDebug?.getState?.()?.alive;
        const ascending = window.JimothyDebug?.getState?.()?.ascending;
        if (stage === "bush" && alive) play("rustle", 0.4);
        else if (alive && !ascending && Math.random() < 0.45) play("hoot", 0.3);
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
    toggle,
    isEnabled,
    setOnChange,
    unlock,
    play,
    cue,
    startAmbience,
  };
})();

window.JimothySound = JimothySound;
