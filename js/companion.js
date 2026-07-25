/**
 * Floating Jimothy companion — Document Picture-in-Picture (Chromium).
 * Stays on top while you use other tabs/apps; closes if the game tab is closed.
 * Not a true OS desktop pet (browsers block that); closest web option.
 */
const JimothyCompanion = (() => {
  let pipWin = null;
  let rafId = 0;
  let enabled = false;
  let onChange = null;
  let getState = () => ({ stage: "bush", alive: true, ascending: false });
  let t = 0;
  let poseX = 0;
  let poseY = 0;
  let facing = 1;
  let targetX = 40;
  let mode = "walk";
  let modeT = 0;
  let hopPeak = 0;

  function supported() {
    return typeof window !== "undefined" && "documentPictureInPicture" in window;
  }

  function isOpen() {
    return !!(pipWin && !pipWin.closed);
  }

  function setOnChange(fn) {
    onChange = fn;
  }

  function setStateGetter(fn) {
    if (typeof fn === "function") getState = fn;
  }

  function setEnabled(on) {
    enabled = !!on;
    if (!enabled) close();
    if (onChange) onChange(enabled, isOpen());
    return enabled;
  }

  function isEnabled() {
    return enabled;
  }

  async function toggle() {
    if (isOpen()) {
      setEnabled(false);
      return false;
    }
    const ok = await open();
    setEnabled(ok);
    return ok;
  }

  async function open() {
    if (!supported()) {
      return false;
    }
    if (isOpen()) return true;
    try {
      pipWin = await documentPictureInPicture.requestWindow({
        width: 200,
        height: 200,
        preferInitialWindowPlacement: true,
      });
    } catch (err) {
      console.warn("Companion PiP failed", err);
      pipWin = null;
      return false;
    }

    const doc = pipWin.document;
    doc.head.innerHTML = "";
    const style = doc.createElement("style");
    style.textContent = `
      html, body {
        margin: 0; padding: 0; width: 100%; height: 100%;
        overflow: hidden;
        background: transparent;
        font-family: Outfit, system-ui, sans-serif;
      }
      body {
        background: radial-gradient(ellipse at 50% 80%, #24382d 0%, #142019 70%);
      }
      #stage {
        position: relative;
        width: 100%; height: 100%;
        cursor: pointer;
      }
      canvas { display: block; width: 100%; height: 100%; }
      #tag {
        position: absolute; left: 0; right: 0; bottom: 6px;
        text-align: center; font-size: 10px; font-weight: 700;
        color: rgba(240,197,122,0.85); pointer-events: none;
        letter-spacing: 0.04em;
      }
      #close {
        position: absolute; top: 4px; right: 6px;
        border: 0; background: rgba(0,0,0,0.35); color: #eef5ea;
        border-radius: 999px; width: 22px; height: 22px;
        font-size: 12px; cursor: pointer; line-height: 1;
      }
    `;
    doc.head.appendChild(style);
    doc.body.innerHTML = `
      <div id="stage">
        <canvas id="c" width="200" height="200"></canvas>
        <div id="tag">Jimothy</div>
        <button id="close" type="button" aria-label="Close companion">×</button>
      </div>
    `;

    doc.getElementById("close").addEventListener("click", () => {
      setEnabled(false);
    });
    doc.getElementById("stage").addEventListener("click", (e) => {
      if (e.target && e.target.id === "close") return;
      // Happy hop on tap
      mode = "hop";
      modeT = 0;
      hopPeak = 18 + Math.random() * 10;
      if (window.JimothySound) JimothySound.cue("pet");
    });

    pipWin.addEventListener("pagehide", () => {
      pipWin = null;
      stopLoop();
      enabled = false;
      if (onChange) onChange(false, false);
    });

    // Reset walk state
    poseX = 0;
    poseY = 0;
    facing = 1;
    targetX = 50;
    mode = "walk";
    modeT = 0;
    t = 0;
    startLoop();
    if (onChange) onChange(true, true);
    return true;
  }

  function close() {
    stopLoop();
    if (pipWin && !pipWin.closed) {
      try {
        pipWin.close();
      } catch {
        /* ignore */
      }
    }
    pipWin = null;
    if (onChange) onChange(enabled, false);
  }

  function startLoop() {
    stopLoop();
    const tick = (now) => {
      if (!isOpen()) {
        stopLoop();
        return;
      }
      const dt = Math.min(0.05, 1 / 60);
      t += dt;
      modeT += dt;
      step(dt);
      draw();
      rafId = pipWin.requestAnimationFrame(tick);
    };
    rafId = pipWin.requestAnimationFrame(tick);
  }

  function stopLoop() {
    if (rafId && pipWin) {
      try {
        pipWin.cancelAnimationFrame(rafId);
      } catch {
        /* ignore */
      }
    }
    rafId = 0;
  }

  function step(dt) {
    const st = getState() || {};
    if (st.stage === "bush") {
      poseX = Math.sin(t * 9) * 3;
      poseY = Math.sin(t * 7) * 2;
      mode = "bush";
      return;
    }
    if (mode === "hop") {
      const u = Math.min(1, modeT / 0.55);
      poseY = -Math.sin(u * Math.PI) * hopPeak;
      if (u >= 1) {
        mode = "walk";
        modeT = 0;
        poseY = 0;
        pickTarget();
      }
      return;
    }
    if (mode === "idle") {
      poseY = Math.sin(t * 2.4) * 2;
      if (modeT > 1.2 + Math.random()) {
        mode = Math.random() < 0.35 ? "hop" : "walk";
        modeT = 0;
        if (mode === "hop") hopPeak = 14 + Math.random() * 12;
        else pickTarget();
      }
      return;
    }
    // walk
    const speed = 55;
    const dir = Math.sign(targetX - poseX) || facing;
    facing = dir;
    poseX += dir * speed * dt;
    poseY = Math.abs(Math.sin(t * 10)) * 3;
    if (Math.abs(poseX - targetX) < 2 || modeT > 2.8) {
      if (Math.random() < 0.4) {
        mode = "idle";
        modeT = 0;
        poseY = 0;
      } else {
        pickTarget();
        modeT = 0;
      }
    }
  }

  function pickTarget() {
    targetX = -60 + Math.random() * 120;
    facing = Math.sign(targetX - poseX) || facing;
  }

  function draw() {
    if (!isOpen()) return;
    const canvas = pipWin.document.getElementById("c");
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    const w = canvas.width;
    const h = canvas.height;
    ctx.clearRect(0, 0, w, h);

    // soft ground
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.beginPath();
    ctx.ellipse(w / 2, h * 0.78, 70, 12, 0, 0, Math.PI * 2);
    ctx.fill();

    const st = getState() || {};
    const cx = w / 2 + poseX;
    const cy = h * 0.62 + poseY;

    if (st.stage === "bush" || mode === "bush") {
      drawBush(ctx, w / 2, h * 0.58);
      return;
    }

    ctx.save();
    ctx.translate(cx, cy);
    ctx.scale(facing, 1);
    drawJimothy(ctx, st.stage || "young");
    ctx.restore();
  }

  function drawBush(ctx, x, y) {
    const rustle = Math.sin(t * 10) * 3;
    ctx.fillStyle = "#2f5a3c";
    ellipse(ctx, x - 18 + rustle, y + 10, 26, 22);
    ctx.fillStyle = "#3d6b4f";
    ellipse(ctx, x + 16 - rustle, y + 12, 28, 24);
    ctx.fillStyle = "#355f44";
    ellipse(ctx, x, y, 34, 28);
    ctx.fillStyle = "#4a8a5e";
    ellipse(ctx, x - 8, y - 12, 18, 16);
  }

  function drawJimothy(ctx, stage) {
    const scale = stage === "baby" ? 0.75 : stage === "adult" ? 1.05 : 0.9;
    ctx.scale(scale, scale);
    // legs
    ctx.strokeStyle = "#4f4f58";
    ctx.lineWidth = 5;
    ctx.lineCap = "round";
    const kick = Math.sin(t * 10) * 3;
    ctx.beginPath();
    ctx.moveTo(-12, 0);
    ctx.lineTo(-16, 18 + kick);
    ctx.moveTo(-4, 2);
    ctx.lineTo(-6, 20 - kick);
    ctx.moveTo(4, 2);
    ctx.lineTo(6, 20 + kick * 0.7);
    ctx.moveTo(12, 0);
    ctx.lineTo(16, 18 - kick * 0.7);
    ctx.stroke();
    // body
    ctx.fillStyle = "#6a6a74";
    ellipse(ctx, 0, -6, 20, 17);
    // ears
    ctx.fillStyle = "#4a4a54";
    ellipse(ctx, -12, -20, 4, 6);
    ellipse(ctx, 12, -20, 4, 6);
    // mask
    ctx.fillStyle = "#1c1c22";
    ellipse(ctx, 0, -8, 14, 8);
    ctx.fillStyle = "#faf6ec";
    ctx.beginPath();
    ctx.arc(-5, -9, 2.4, 0, Math.PI * 2);
    ctx.arc(5, -9, 2.4, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#121214";
    ctx.beginPath();
    ctx.arc(-4.5, -8.5, 1.1, 0, Math.PI * 2);
    ctx.arc(5.5, -8.5, 1.1, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#c9a292";
    ellipse(ctx, 0, -3, 4, 2.4);
  }

  function ellipse(ctx, x, y, rx, ry) {
    ctx.beginPath();
    ctx.ellipse(x, y, rx, ry, 0, 0, Math.PI * 2);
    ctx.fill();
  }

  return {
    supported,
    isOpen,
    isEnabled,
    setEnabled,
    setOnChange,
    setStateGetter,
    toggle,
    open,
    close,
  };
})();

window.JimothyCompanion = JimothyCompanion;
