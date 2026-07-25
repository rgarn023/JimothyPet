/**
 * Dumpster Dive — night forage catch mini-game.
 * Catch edible alley scraps; dodge spoiled waste. Burns energy / builds fitness.
 */
const DumpsterDive = (() => {
  let canvas;
  let ctx;
  let running = false;
  let rafId = 0;
  let onDone = null;

  let score = 0;
  let timeLeft = 20;
  let playerX = 0;
  let items = [];
  let lastSpawn = 0;
  let lastTick = 0;
  let width = 360;
  let height = 480;
  let moveDir = 0;
  let pointerSide = 0;

  const PLAYER_W = 52;
  const PLAYER_H = 40;
  const GOOD = [
    { kind: "pizza", label: "crust", points: 2, color: "#e0a04a" },
    { kind: "can", label: "shiny", points: 3, color: "#a8c4d4" },
    { kind: "berry", label: "berry", points: 2, color: "#6b5aa0" },
    { kind: "fries", label: "fries", points: 1, color: "#f0c57a" },
  ];
  const BAD = { kind: "rotten", label: "ick", points: -2, color: "#5a6b3a" };

  function $(id) {
    return document.getElementById(id);
  }

  function start(doneCallback) {
    canvas = $("gameCanvas");
    ctx = canvas.getContext("2d");
    onDone = doneCallback;
    score = 0;
    timeLeft = 20;
    items = [];
    lastSpawn = 0;
    lastTick = performance.now();
    moveDir = 0;
    pointerSide = 0;
    resize();
    playerX = width / 2;
    running = true;
    $("gameScore").textContent = "0";
    $("gameTime").textContent = "20";
    bind();
    rafId = requestAnimationFrame(loop);
  }

  function stop(completed) {
    if (!running) return;
    running = false;
    unbind();
    cancelAnimationFrame(rafId);
    const result = {
      score,
      completed: Boolean(completed),
      stars: score >= 18 ? 3 : score >= 10 ? 2 : score >= 4 ? 1 : 0,
    };
    if (typeof onDone === "function") onDone(result);
  }

  function resize() {
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    width = 360;
    height = 480;
    canvas.width = width * dpr;
    canvas.height = height * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    // Keep CSS size responsive
    void rect;
  }

  function bind() {
    window.addEventListener("keydown", onKeyDown);
    window.addEventListener("keyup", onKeyUp);
    canvas.addEventListener("pointerdown", onPointer);
    canvas.addEventListener("pointermove", onPointer);
    canvas.addEventListener("pointerup", onPointerUp);
    canvas.addEventListener("pointercancel", onPointerUp);
    canvas.addEventListener("pointerleave", onPointerUp);
  }

  function unbind() {
    window.removeEventListener("keydown", onKeyDown);
    window.removeEventListener("keyup", onKeyUp);
    canvas.removeEventListener("pointerdown", onPointer);
    canvas.removeEventListener("pointermove", onPointer);
    canvas.removeEventListener("pointerup", onPointerUp);
    canvas.removeEventListener("pointercancel", onPointerUp);
    canvas.removeEventListener("pointerleave", onPointerUp);
  }

  function onKeyDown(e) {
    if (e.key === "ArrowLeft" || e.key === "a" || e.key === "A") moveDir = -1;
    if (e.key === "ArrowRight" || e.key === "d" || e.key === "D") moveDir = 1;
    if (e.key === "Escape") stop(false);
  }

  function onKeyUp(e) {
    if (
      ["ArrowLeft", "ArrowRight", "a", "A", "d", "D"].includes(e.key) &&
      moveDir !== 0
    ) {
      moveDir = 0;
    }
  }

  function onPointer(e) {
    const rect = canvas.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * width;
    pointerSide = x < width / 2 ? -1 : 1;
    // Direct follow feels better on touch
    playerX = Math.max(PLAYER_W / 2, Math.min(width - PLAYER_W / 2, x));
  }

  function onPointerUp() {
    pointerSide = 0;
  }

  function spawnItem() {
    const bad = Math.random() < 0.28;
    const proto = bad ? BAD : GOOD[Math.floor(Math.random() * GOOD.length)];
    items.push({
      ...proto,
      x: 24 + Math.random() * (width - 48),
      y: -20,
      r: 14 + Math.random() * 4,
      vy: 140 + Math.random() * 90 + Math.min(score * 2, 80),
    });
  }

  function loop(now) {
    if (!running) return;
    const dt = Math.min(0.033, (now - lastTick) / 1000);
    lastTick = now;

    timeLeft -= dt;
    if (timeLeft <= 0) {
      timeLeft = 0;
      draw();
      $("gameTime").textContent = "0";
      stop(true);
      return;
    }

    lastSpawn += dt;
    if (lastSpawn > 0.55 - Math.min(score * 0.008, 0.25)) {
      lastSpawn = 0;
      spawnItem();
    }

    const speed = 260;
    if (moveDir) playerX += moveDir * speed * dt;
    playerX = Math.max(PLAYER_W / 2, Math.min(width - PLAYER_W / 2, playerX));

    const ground = height - 54;
    for (const item of items) {
      item.y += item.vy * dt;
    }

    // Collisions
    items = items.filter((item) => {
      if (item.y > height + 30) return false;
      const nearX = Math.abs(item.x - playerX) < PLAYER_W * 0.55;
      const nearY = item.y > ground - 28 && item.y < ground + 10;
      if (nearX && nearY) {
        score = Math.max(0, score + item.points);
        $("gameScore").textContent = String(score);
        return false;
      }
      return true;
    });

    $("gameTime").textContent = String(Math.ceil(timeLeft));
    draw();
    rafId = requestAnimationFrame(loop);
  }

  function draw() {
    // Alley background
    const g = ctx.createLinearGradient(0, 0, 0, height);
    g.addColorStop(0, "#152018");
    g.addColorStop(1, "#0b120e");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, width, height);

    // Dumpster
    ctx.fillStyle = "#3d6b4f";
    roundRect(40, 36, width - 80, 54, 8);
    ctx.fill();
    ctx.fillStyle = "#2f5540";
    roundRect(48, 24, width - 96, 20, 6);
    ctx.fill();
    ctx.fillStyle = "#1b2a22";
    ctx.font = "700 14px Outfit, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("NIGHT FORAGE", width / 2, 68);

    // Brick hints
    ctx.strokeStyle = "rgba(154,171,156,0.12)";
    ctx.lineWidth = 1;
    for (let y = 110; y < height - 70; y += 28) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    }

    // Ground
    ctx.fillStyle = "#1a281e";
    ctx.fillRect(0, height - 48, width, 48);
    ctx.fillStyle = "rgba(224,160,74,0.15)";
    ctx.fillRect(0, height - 48, width, 3);

    // Falling items
    for (const item of items) drawItem(item);

    // Player raccoon
    drawPlayer(playerX, height - 58);

    // HUD strip
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.fillRect(0, 0, width, 22);
  }

  function drawItem(item) {
    ctx.save();
    ctx.translate(item.x, item.y);
    if (item.kind === "rotten") {
      ctx.fillStyle = item.color;
      ctx.beginPath();
      ctx.ellipse(0, 0, item.r, item.r * 0.75, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#8a9a4a";
      ctx.beginPath();
      ctx.arc(-4, -2, 3, 0, Math.PI * 2);
      ctx.arc(3, 1, 2.5, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#c45c4a";
      ctx.font = "700 10px Outfit, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("X", 0, 3);
    } else if (item.kind === "can") {
      ctx.fillStyle = item.color;
      roundRect(-10, -12, 20, 24, 4);
      ctx.fill();
      ctx.fillStyle = "#e8f2f6";
      ctx.fillRect(-8, -4, 16, 4);
      ctx.fillStyle = "#e0a04a";
      ctx.beginPath();
      ctx.arc(0, -16, 3, 0, Math.PI * 2);
      ctx.fill();
    } else if (item.kind === "berry") {
      ctx.fillStyle = item.color;
      ctx.beginPath();
      ctx.arc(-4, 0, 7, 0, Math.PI * 2);
      ctx.arc(5, -2, 7, 0, Math.PI * 2);
      ctx.arc(0, 5, 6, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#6fbf84";
      ctx.fillRect(-2, -12, 4, 6);
    } else if (item.kind === "fries") {
      ctx.fillStyle = "#c45c4a";
      roundRect(-10, 0, 20, 14, 3);
      ctx.fill();
      ctx.fillStyle = item.color;
      ctx.fillRect(-7, -10, 3, 14);
      ctx.fillRect(-1, -12, 3, 16);
      ctx.fillRect(5, -9, 3, 13);
    } else {
      // pizza crust
      ctx.fillStyle = item.color;
      ctx.beginPath();
      ctx.moveTo(0, -12);
      ctx.lineTo(12, 10);
      ctx.lineTo(-12, 10);
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = "#c45c4a";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(-9, -4);
      ctx.lineTo(9, -4);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawPlayer(x, y) {
    ctx.save();
    ctx.translate(x, y);
    // Short-spine Jimothy: round body, long legs, almost no neck
    ctx.strokeStyle = "#4f4f58";
    ctx.lineWidth = 5;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(-12, 0);
    ctx.lineTo(-18, 16);
    ctx.moveTo(-4, 2);
    ctx.lineTo(-6, 18);
    ctx.moveTo(4, 2);
    ctx.lineTo(6, 18);
    ctx.moveTo(12, 0);
    ctx.lineTo(18, 16);
    ctx.stroke();
    ctx.fillStyle = "#3a3a44";
    ctx.beginPath();
    ctx.ellipse(-18, 18, 5, 3, 0, 0, Math.PI * 2);
    ctx.ellipse(-6, 20, 5, 3, 0, 0, Math.PI * 2);
    ctx.ellipse(6, 20, 5, 3, 0, 0, Math.PI * 2);
    ctx.ellipse(18, 18, 5, 3, 0, 0, Math.PI * 2);
    ctx.fill();
    // round body / head fused
    ctx.fillStyle = "#6a6a74";
    ctx.beginPath();
    ctx.ellipse(0, -4, 20, 17, 0, 0, Math.PI * 2);
    ctx.fill();
    // ears
    ctx.fillStyle = "#4a4a54";
    ctx.beginPath();
    ctx.ellipse(-12, -18, 4, 6, -0.15, 0, Math.PI * 2);
    ctx.ellipse(12, -18, 4, 6, 0.15, 0, Math.PI * 2);
    ctx.fill();
    // mask
    ctx.fillStyle = "#1c1c22";
    ctx.beginPath();
    ctx.ellipse(0, -6, 14, 8, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#f7f3e8";
    ctx.beginPath();
    ctx.arc(-5, -7, 2.6, 0, Math.PI * 2);
    ctx.arc(5, -7, 2.6, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#121214";
    ctx.beginPath();
    ctx.arc(-4.5, -6.5, 1.2, 0, Math.PI * 2);
    ctx.arc(5.5, -6.5, 1.2, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#c9a292";
    ctx.beginPath();
    ctx.ellipse(0, -1, 4, 2.5, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  function roundRect(x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  return { start, stop };
})();
