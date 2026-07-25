/**
 * High or Low — guess a spinning d20 (1–10 low, 11–20 high).
 */
const DiceHighLow = (() => {
  let onDone = null;
  let rolling = false;
  let chosen = null; // "high" | "low"
  let result = 0;
  let rafId = 0;
  let spinT = 0;

  function $(id) {
    return document.getElementById(id);
  }

  function resetUi() {
    const stage = $("diceStage");
    const die = $("d20");
    const num = $("d20Num");
    const status = $("diceStatus");
    const again = $("diceAgain");
    const picks = $("dicePicks");
    if (die) {
      die.classList.remove("spinning", "landed", "win", "lose");
      die.style.transform = "";
    }
    if (num) num.textContent = "?";
    if (status) status.textContent = "Guess High (11–20) or Low (1–10), then watch the d20 tumble.";
    if (again) again.hidden = true;
    if (picks) picks.hidden = false;
    if (stage) stage.dataset.state = "ready";
    chosen = null;
    rolling = false;
    result = 0;
  }

  function start(doneCallback) {
    onDone = doneCallback;
    resetUi();
    $("diceModal").hidden = false;
    bind();
  }

  function close(bail = true) {
    unbind();
    cancelAnimationFrame(rafId);
    rolling = false;
    $("diceModal").hidden = true;
    if (bail && typeof onDone === "function") {
      onDone({ completed: false, correct: false, roll: 0, guess: null, bailed: true });
    }
    onDone = null;
  }

  function bind() {
    unbind();
    $("diceLow")?.addEventListener("click", onPickLow);
    $("diceHigh")?.addEventListener("click", onPickHigh);
    $("diceClose")?.addEventListener("click", onClose);
    $("diceAgain")?.addEventListener("click", onAgain);
  }

  function unbind() {
    $("diceLow")?.removeEventListener("click", onPickLow);
    $("diceHigh")?.removeEventListener("click", onPickHigh);
    $("diceClose")?.removeEventListener("click", onClose);
    $("diceAgain")?.removeEventListener("click", onAgain);
  }

  function onPickLow() {
    pick("low");
  }
  function onPickHigh() {
    pick("high");
  }
  function onClose() {
    // Done — leave without a bail penalty (rolls already applied).
    close(false);
  }
  function onAgain() {
    resetUi();
  }

  function pick(guess) {
    if (rolling) return;
    chosen = guess;
    result = 1 + Math.floor(Math.random() * 20);
    $("dicePicks").hidden = true;
    $("diceStatus").textContent =
      guess === "high" ? "You called High (11–20)…" : "You called Low (1–10)…";
    $("diceStage").dataset.state = "spinning";
    beginSpin();
  }

  function beginSpin() {
    rolling = true;
    const die = $("d20");
    const num = $("d20Num");
    die.classList.remove("landed", "win", "lose");
    die.classList.add("spinning");
    spinT = 0;
    const duration = 2400;
    const start = performance.now();

    const tick = (now) => {
      const u = Math.min(1, (now - start) / duration);
      spinT = u;
      // Flash random faces while tumbling
      if (u < 0.85) {
        num.textContent = String(1 + Math.floor(Math.random() * 20));
      } else {
        num.textContent = String(result);
      }
      // Extra JS wobble on top of CSS spin
      const wobble = (1 - u) * 28;
      const rx = Math.sin(now * 0.02) * wobble + u * 360 * 3;
      const ry = Math.cos(now * 0.017) * wobble + u * 360 * 4;
      const rz = Math.sin(now * 0.013) * wobble * 0.5;
      const scale = 1 + Math.sin(u * Math.PI) * 0.18;
      die.style.transform = `rotateX(${rx}deg) rotateY(${ry}deg) rotateZ(${rz}deg) scale(${scale})`;

      if (u < 1) {
        rafId = requestAnimationFrame(tick);
        return;
      }
      finishSpin();
    };
    rafId = requestAnimationFrame(tick);
  }

  function finishSpin() {
    rolling = false;
    const die = $("d20");
    const num = $("d20Num");
    num.textContent = String(result);
    die.classList.remove("spinning");
    die.classList.add("landed");
    die.style.transform = "rotateX(-18deg) rotateY(22deg) rotateZ(0deg) scale(1)";

    const isHigh = result >= 11;
    const correct = (chosen === "high" && isHigh) || (chosen === "low" && !isHigh);
    die.classList.add(correct ? "win" : "lose");
    $("diceStage").dataset.state = correct ? "win" : "lose";

    const band = isHigh ? "High" : "Low";
    $("diceStatus").textContent = correct
      ? `d20 shows ${result} — ${band}! Jimothy is thrilled.`
      : `d20 shows ${result} — ${band}. Jimothy droops.`;
    $("diceAgain").hidden = false;

    const payload = {
      completed: true,
      correct,
      roll: result,
      guess: chosen,
      bailed: false,
    };
    // Brief beat so the land pose reads, then report (keep callback for Roll again).
    setTimeout(() => {
      if (typeof onDone === "function") onDone(payload);
    }, 650);
  }

  return { start, close };
})();
window.DiceHighLow = DiceHighLow;
