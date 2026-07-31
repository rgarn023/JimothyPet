/**
 * Dumpster Dive — alley rummage: scraps fling out of the dumpster.
 * Catch edible bits, dodge spoil. Stand under the bin to dig.
 */
const DumpsterDive = (() => {
  let canvas;
  let ctx;
  let running = false;
  let rafId = 0;
  let onDone = null;

  let score = 0;
  let timeLeft = 22;
  let playerX = 0;
  let playerFacing = 1;
  let walkPhase = 0;
  let items = [];
  let fx = [];
  let lastSpawn = 0;
  let lastTick = 0;
  let width = 360;
  let height = 480;
  let moveDir = 0;
  let digHold = 0;
  let lidOpen = 0;
  let chewT = 0;
  let dumpster = { x: 0, y: 0, w: 0, h: 0 };
  let formProfile = null;
  let formImg = null;
  let formImgUrl = "";

  const PLAYER_W = 52;
  const GOOD = [
    { kind: "pizza", points: 2, color: "#e0a04a" },
    { kind: "can", points: 3, color: "#a8c4d4" },
    { kind: "berry", points: 2, color: "#6b5aa0" },
    { kind: "fries", points: 1, color: "#f0c57a" },
    { kind: "fish", points: 3, color: "#8eb4c4" },
  ];
  const BAD = { kind: "rotten", points: -2, color: "#5a6b3a" };

  function $(id) {
    return document.getElementById(id);
  }

  function bakeFormArt(profile) {
    formProfile = profile || formProfile || { stage: "young", youngForm: "puff", view: "side" };
    if (formImgUrl) {
      URL.revokeObjectURL(formImgUrl);
      formImgUrl = "";
    }
    formImg = null;
    if (!window.RaccoonArt || typeof RaccoonArt.render !== "function") return;
    const svg = RaccoonArt.render({
      ...formProfile,
      view: "side",
      smiling: false,
    });
    const blob = new Blob([svg], { type: "image/svg+xml;charset=utf-8" });
    formImgUrl = URL.createObjectURL(blob);
    const img = new Image();
    img.onload = () => {
      formImg = img;
    };
    img.onerror = () => {
      formImg = null;
    };
    img.src = formImgUrl;
  }

  function start(doneCallback, profile) {
    canvas = $("gameCanvas");
    ctx = canvas.getContext("2d");
    onDone = doneCallback;
    score = 0;
    timeLeft = 22;
    items = [];
    fx = [];
    lastSpawn = 0.2;
    lastTick = performance.now();
    moveDir = 0;
    digHold = 0;
    lidOpen = 0;
    chewT = 0;
    walkPhase = 0;
    resize();
    playerX = width / 2;
    playerFacing = 1;
    dumpster = { x: width * 0.18, y: 70, w: width * 0.64, h: 78 };
    bakeFormArt(profile || { stage: "young", youngForm: "puff", view: "side" });
    running = true;
    $("gameScore").textContent = "0";
    $("gameTime").textContent = "22";
    bind();
    rafId = requestAnimationFrame(loop);
  }

  function stop(completed) {
    if (!running) return;
    running = false;
    unbind();
    cancelAnimationFrame(rafId);
    if (formImgUrl) {
      URL.revokeObjectURL(formImgUrl);
      formImgUrl = "";
    }
    formImg = null;
    const result = {
      score,
      completed: Boolean(completed),
      stars: score >= 18 ? 3 : score >= 10 ? 2 : score >= 4 ? 1 : 0,
    };
    if (typeof onDone === "function") onDone(result);
  }

  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    width = 360;
    height = 480;
    canvas.width = width * dpr;
    canvas.height = height * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
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
    if (["ArrowLeft", "ArrowRight", "a", "A", "d", "D"].includes(e.key) && moveDir !== 0) {
      moveDir = 0;
    }
  }

  function onPointer(e) {
    const rect = canvas.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * width;
    const prev = playerX;
    playerX = Math.max(PLAYER_W / 2, Math.min(width - PLAYER_W / 2, x));
    if (Math.abs(playerX - prev) > 0.5) playerFacing = playerX >= prev ? 1 : -1;
  }

  function onPointerUp() {}

  function spawnItem(forcedGood = false) {
    const bad = !forcedGood && Math.random() < 0.26;
    const proto = bad ? BAD : GOOD[Math.floor(Math.random() * GOOD.length)];
    const mouthX = dumpster.x + dumpster.w * (0.28 + Math.random() * 0.44);
    const mouthY = dumpster.y + 18;
    const outward = mouthX < width / 2 ? -1 : 1;
    const vx = (Math.random() * 36 + 18) * (Math.random() < 0.5 ? -outward : outward * 0.35);
    const vy = -(70 + Math.random() * 45);
    items.push({
      ...proto,
      x: mouthX,
      y: mouthY,
      r: 13 + Math.random() * 4,
      vx,
      vy,
      rot: Math.random() * Math.PI,
      spin: (Math.random() - 0.5) * 6,
    });
    lidOpen = 1;
    if (window.JimothySound) JimothySound.play("rustle", 0.25);
  }

  function underDumpster() {
    const cx = dumpster.x + dumpster.w / 2;
    return Math.abs(playerX - cx) < dumpster.w * 0.28;
  }

  function addFx(kind, x, y, text) {
    fx.push({ kind, x, y, text, t: 0, life: 0.7 });
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

    lidOpen = Math.max(0, lidOpen - dt * 1.6);
    chewT = Math.max(0, chewT - dt);

    lastSpawn += dt;
    const interval = Math.max(0.7, 1.35 - Math.min(score, 20) * 0.02);
    if (lastSpawn > interval) {
      lastSpawn = 0;
      spawnItem(false);
    }

    const speed = 180;
    const moving = Math.abs(moveDir) > 0;
    if (moving) {
      playerX += moveDir * speed * dt;
      playerFacing = moveDir;
      walkPhase += dt * 12;
      digHold = 0;
    } else if (underDumpster()) {
      digHold += dt;
      walkPhase += dt * 4;
      if (digHold >= 0.55) {
        digHold = 0;
        spawnItem(true);
        addFx("label", playerX, height - 90, "DIG!");
        if (window.JimothySound) JimothySound.play("chitter", 0.35);
      }
    } else {
      digHold = Math.max(0, digHold - dt);
      walkPhase += dt * 2;
    }
    playerX = Math.max(PLAYER_W / 2, Math.min(width - PLAYER_W / 2, playerX));

    const gravity = 210;
    const ground = height - 54;
    for (const item of items) {
      item.vy += gravity * dt;
      item.x += item.vx * dt;
      item.y += item.vy * dt;
      item.rot += item.spin * dt;
      // Soft bounce off alley walls
      if (item.x < 16 || item.x > width - 16) {
        item.vx *= -0.55;
        item.x = Math.max(16, Math.min(width - 16, item.x));
      }
    }

    items = items.filter((item) => {
      if (item.y > height + 40) return false;
      const nearX = Math.abs(item.x - playerX) < PLAYER_W * 0.52;
      const nearY = item.y > ground - 34 && item.y < ground + 12;
      if (nearX && nearY) {
        score = Math.max(0, score + item.points);
        $("gameScore").textContent = String(score);
        chewT = 0.35;
        if (item.points < 0) {
          addFx("splat", item.x, item.y, "");
          addFx("label", item.x, item.y - 12, `${item.points}`);
          if (window.JimothySound) JimothySound.play("grumble", 0.4);
        } else {
          addFx("crumb", item.x, item.y, "");
          addFx("label", item.x, item.y - 14, `+${item.points}`);
          if (window.JimothySound) JimothySound.play("crunch", 0.35);
        }
        return false;
      }
      // Land as litter if missed near ground
      if (item.y >= ground + 6 && item.vy > 0) {
        if (item.kind === "rotten") addFx("splat", item.x, ground, "");
        else addFx("litter", item.x, ground, "");
        return false;
      }
      return true;
    });

    fx = fx.filter((f) => {
      f.t += dt;
      f.y -= 18 * dt;
      return f.t < f.life;
    });

    $("gameTime").textContent = String(Math.ceil(timeLeft));
    draw();
    rafId = requestAnimationFrame(loop);
  }

  function draw() {
    const g = ctx.createLinearGradient(0, 0, 0, height);
    g.addColorStop(0, "#101a14");
    g.addColorStop(0.45, "#152018");
    g.addColorStop(1, "#0b120e");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, width, height);

    // Brick alley
    ctx.strokeStyle = "rgba(154,171,156,0.1)";
    ctx.lineWidth = 1;
    for (let y = 100; y < height - 70; y += 26) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
      for (let x = (y / 26) % 2 === 0 ? 0 : 28; x < width; x += 56) {
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(x, y + 26);
        ctx.stroke();
      }
    }

    // Ground litter / asphalt
    ctx.fillStyle = "#1a281e";
    ctx.fillRect(0, height - 48, width, 48);
    ctx.fillStyle = "rgba(224,160,74,0.12)";
    ctx.fillRect(0, height - 48, width, 3);
    ctx.fillStyle = "rgba(60,48,30,0.35)";
    for (let i = 0; i < 8; i++) {
      ctx.beginPath();
      ctx.ellipse(30 + i * 42, height - 38 + (i % 3), 10, 4, 0, 0, Math.PI * 2);
      ctx.fill();
    }

    drawDumpster();

    // Dig hint
    if (underDumpster() && digHold > 0) {
      ctx.fillStyle = "rgba(240,197,122,0.85)";
      ctx.font = "700 12px Outfit, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("digging…", dumpster.x + dumpster.w / 2, dumpster.y - 8);
      ctx.fillStyle = "rgba(111,191,132,0.5)";
      ctx.fillRect(dumpster.x + 20, dumpster.y - 4, (dumpster.w - 40) * Math.min(1, digHold / 0.55), 3);
    }

    for (const item of items) drawItem(item);
    for (const f of fx) drawFx(f);

    drawPlayer(playerX, height - 58);

    ctx.fillStyle = "rgba(0,0,0,0.28)";
    ctx.fillRect(0, 0, width, 22);
  }

  function drawDumpster() {
    const { x, y, w, h } = dumpster;
    // Shadow
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.beginPath();
    ctx.ellipse(x + w / 2, y + h + 8, w * 0.45, 10, 0, 0, Math.PI * 2);
    ctx.fill();
    // Body
    ctx.fillStyle = "#3d6b4f";
    roundRect(x, y + 16, w, h - 10, 8);
    ctx.fill();
    ctx.fillStyle = "#2a4a38";
    roundRect(x + 8, y + 28, w - 16, h - 30, 6);
    ctx.fill();
    // Mouth / open cavity
    ctx.fillStyle = "#142019";
    roundRect(x + 14, y + 22, w - 28, 28, 4);
    ctx.fill();
    // Lid hinge + open angle
    ctx.save();
    ctx.translate(x + 10, y + 18);
    ctx.rotate(-0.15 - lidOpen * 0.85);
    ctx.fillStyle = "#2f5540";
    roundRect(0, -14, w - 20, 18, 5);
    ctx.fill();
    ctx.fillStyle = "#1b2a22";
    ctx.font = "700 11px Outfit, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("NIGHT FORAGE", (w - 20) / 2, -1);
    ctx.restore();
    // Wheels
    ctx.fillStyle = "#1c1c22";
    ctx.beginPath();
    ctx.arc(x + 22, y + h + 2, 7, 0, Math.PI * 2);
    ctx.arc(x + w - 22, y + h + 2, 7, 0, Math.PI * 2);
    ctx.fill();
  }

  function shade(hex, amt) {
    const n = hex.replace("#", "");
    const v = parseInt(n.length === 3 ? n.split("").map((c) => c + c).join("") : n, 16);
    const r = Math.max(0, Math.min(255, ((v >> 16) & 255) + amt));
    const g = Math.max(0, Math.min(255, ((v >> 8) & 255) + amt));
    const b = Math.max(0, Math.min(255, (v & 255) + amt));
    return `rgb(${r},${g},${b})`;
  }

  function drawItem(item) {
    const ground = height - 54;
    const elev = Math.max(0, ground - item.y);
    const shadowScale = Math.max(0.32, 1 - elev / 240);
    ctx.save();
    ctx.fillStyle = `rgba(0,0,0,${0.28 * shadowScale})`;
    ctx.beginPath();
    ctx.ellipse(item.x + 2, ground + 5, 16 * shadowScale, 5.5 * shadowScale, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    ctx.save();
    ctx.translate(item.x, item.y);
    ctx.rotate(item.rot || 0);
    // Faux pitch: squash while tumbling so scraps read as 3D objects in air.
    const pitch = Math.sin((item.rot || 0) * 1.7) * 0.22;
    ctx.scale(1 + Math.abs(pitch) * 0.12, 1 - Math.abs(pitch) * 0.38);

    if (item.kind === "rotten") {
      const r = item.r || 14;
      const g = ctx.createRadialGradient(-r * 0.3, -r * 0.35, 1, 0, 0, r);
      g.addColorStop(0, "#7a8a4a");
      g.addColorStop(0.55, item.color || "#5a6b3a");
      g.addColorStop(1, "#2e3518");
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.ellipse(0, 0, r, r * 0.78, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "rgba(40,48,20,0.55)";
      ctx.beginPath();
      ctx.ellipse(3, 4, r * 0.55, r * 0.35, 0.3, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#9aab55";
      ctx.beginPath();
      ctx.arc(-5, -3, 3.2, 0, Math.PI * 2);
      ctx.arc(4, 0, 2.6, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "rgba(20,24,10,0.45)";
      ctx.lineWidth = 1.2;
      ctx.beginPath();
      ctx.moveTo(-6, 2);
      ctx.quadraticCurveTo(0, 6, 7, 1);
      ctx.stroke();
    } else if (item.kind === "can") {
      // Cylinder with rim + specular band
      ctx.fillStyle = "#6a7a86";
      roundRect(-11, -11, 22, 24, 5);
      ctx.fill();
      const body = ctx.createLinearGradient(-10, 0, 10, 0);
      body.addColorStop(0, "#6f8494");
      body.addColorStop(0.35, "#d7e6ee");
      body.addColorStop(0.55, "#a8c4d4");
      body.addColorStop(1, "#5a6e7a");
      ctx.fillStyle = body;
      roundRect(-10, -10, 20, 22, 4);
      ctx.fill();
      ctx.fillStyle = "rgba(255,255,255,0.55)";
      ctx.fillRect(-3, -8, 2.2, 18);
      ctx.fillStyle = "#eef6fa";
      roundRect(-9, -3, 18, 5, 2);
      ctx.fill();
      ctx.fillStyle = "#c45c4a";
      roundRect(-7, -2, 14, 3, 1);
      ctx.fill();
      ctx.fillStyle = "#8a9aa4";
      roundRect(-9, -12, 18, 4, 2);
      ctx.fill();
      ctx.fillStyle = "rgba(255,255,255,0.35)";
      roundRect(-7, -11.5, 10, 2, 1);
      ctx.fill();
    } else if (item.kind === "berry") {
      const berries = [
        [-5, 1, 7.2, "#5a4a8a"],
        [5, -2, 7.4, "#6b5aa0"],
        [0, 6, 6.4, "#4a3a72"],
        [2, -7, 4.8, "#7a6ab0"],
      ];
      for (const [bx, by, br, col] of berries) {
        const g = ctx.createRadialGradient(bx - br * 0.35, by - br * 0.4, 1, bx, by, br);
        g.addColorStop(0, shade(col, 55));
        g.addColorStop(0.55, col);
        g.addColorStop(1, shade(col, -40));
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(bx, by, br, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = "rgba(255,255,255,0.35)";
        ctx.beginPath();
        ctx.arc(bx - br * 0.3, by - br * 0.35, br * 0.22, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.strokeStyle = "#3d6b4f";
      ctx.lineWidth = 1.6;
      ctx.beginPath();
      ctx.moveTo(-2, -10);
      ctx.quadraticCurveTo(2, -14, 6, -9);
      ctx.stroke();
    } else if (item.kind === "fries") {
      // Carton depth + fry sticks with highlights
      ctx.fillStyle = "#8a3a2e";
      roundRect(-11, 2, 22, 14, 3);
      ctx.fill();
      const carton = ctx.createLinearGradient(0, 0, 0, 16);
      carton.addColorStop(0, "#d46a56");
      carton.addColorStop(1, "#a04436");
      ctx.fillStyle = carton;
      roundRect(-10, 0, 20, 14, 3);
      ctx.fill();
      ctx.fillStyle = "#f0c57a";
      ctx.font = "700 7px Outfit, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("FRIES", 0, 10);
      const fries = [
        [-7, -12, 3.2, 16, "#e0a04a"],
        [-2, -14, 3.4, 18, "#f0c57a"],
        [3, -11, 3.1, 15, "#d4923a"],
        [7, -13, 2.8, 16, "#e8b45a"],
      ];
      for (const [fx, fy, fw, fh, col] of fries) {
        const g = ctx.createLinearGradient(fx, fy, fx + fw, fy);
        g.addColorStop(0, shade(col, -25));
        g.addColorStop(0.4, shade(col, 30));
        g.addColorStop(1, shade(col, -10));
        ctx.fillStyle = g;
        roundRect(fx, fy, fw, fh, 1.4);
        ctx.fill();
      }
    } else if (item.kind === "fish") {
      const body = ctx.createLinearGradient(0, -6, 0, 6);
      body.addColorStop(0, "#c8e8f0");
      body.addColorStop(0.45, "#8eb4c4");
      body.addColorStop(1, "#4a7080");
      ctx.fillStyle = body;
      ctx.beginPath();
      ctx.ellipse(0, 0, 13, 6.2, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#5a9eb0";
      ctx.beginPath();
      ctx.moveTo(10, 0);
      ctx.lineTo(18, -6);
      ctx.lineTo(16, 0);
      ctx.lineTo(18, 6);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = "#7ec8d4";
      ctx.beginPath();
      ctx.moveTo(-1, -6);
      ctx.lineTo(3, -11);
      ctx.lineTo(6, -5);
      ctx.fill();
      ctx.fillStyle = "#1b2a22";
      ctx.beginPath();
      ctx.arc(-6, -1, 1.4, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "rgba(238,245,234,0.55)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(-2, 1);
      ctx.quadraticCurveTo(4, 3, 8, 0);
      ctx.stroke();
      ctx.fillStyle = "rgba(255,255,255,0.4)";
      ctx.beginPath();
      ctx.ellipse(-3, -2.5, 4, 1.6, -0.3, 0, Math.PI * 2);
      ctx.fill();
    } else {
      // Pizza wedge with crust rim + cheese thickness
      ctx.fillStyle = "#8a4a28";
      ctx.beginPath();
      ctx.moveTo(1, -13);
      ctx.lineTo(14, 12);
      ctx.lineTo(-12, 12);
      ctx.closePath();
      ctx.fill();
      const cheese = ctx.createLinearGradient(0, -12, 0, 12);
      cheese.addColorStop(0, "#f0c57a");
      cheese.addColorStop(0.55, "#e0a04a");
      cheese.addColorStop(1, "#c48432");
      ctx.fillStyle = cheese;
      ctx.beginPath();
      ctx.moveTo(0, -12);
      ctx.lineTo(12, 10);
      ctx.lineTo(-12, 10);
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = "#c45c4a";
      ctx.lineWidth = 3.2;
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(-10, -3);
      ctx.lineTo(10, -3);
      ctx.stroke();
      ctx.fillStyle = "#8a2f2f";
      ctx.beginPath();
      ctx.arc(-3, 3, 2.3, 0, Math.PI * 2);
      ctx.arc(4, 5, 1.8, 0, Math.PI * 2);
      ctx.arc(1, 0, 1.5, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "rgba(255,255,255,0.28)";
      ctx.beginPath();
      ctx.moveTo(-2, -8);
      ctx.lineTo(4, -2);
      ctx.lineTo(-1, -1);
      ctx.closePath();
      ctx.fill();
    }
    ctx.restore();
  }

  function drawFx(f) {
    const a = 1 - f.t / f.life;
    if (f.kind === "label") {
      ctx.fillStyle = `rgba(240,197,122,${a})`;
      ctx.font = "700 13px Outfit, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(f.text, f.x, f.y);
    } else if (f.kind === "splat") {
      ctx.fillStyle = `rgba(90,107,58,${0.55 * a})`;
      ctx.beginPath();
      ctx.ellipse(f.x, f.y, 14 * (1 + f.t), 6, 0, 0, Math.PI * 2);
      ctx.fill();
    } else if (f.kind === "crumb" || f.kind === "litter") {
      ctx.fillStyle = `rgba(224,160,74,${0.45 * a})`;
      ctx.beginPath();
      ctx.arc(f.x - 3, f.y, 2.5, 0, Math.PI * 2);
      ctx.arc(f.x + 3, f.y + 1, 2, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  function drawPlayer(x, y) {
    const bob = chewT > 0 ? Math.sin(performance.now() / 40) * 2 : Math.abs(Math.sin(walkPhase)) * 2;
    const kickTilt = Math.sin(walkPhase) * (chewT > 0 ? 0.02 : 0.06);
    ctx.save();
    ctx.translate(x, y + bob);
    ctx.scale(playerFacing < 0 ? -1 : 1, 1);
    ctx.rotate(kickTilt);

    if (formImg && formImg.complete && formImg.naturalWidth > 0) {
      // Side SVG faces right; feet sit near the bottom of the 120 viewBox.
      const size = 92;
      ctx.drawImage(formImg, -size / 2, -size + 16, size, size);
    } else {
      // Fallback potato if art hasn't loaded yet.
      ctx.fillStyle = "#6a6a74";
      ctx.beginPath();
      ctx.ellipse(0, -10, 20, 16, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#1c1c22";
      ctx.beginPath();
      ctx.ellipse(6, -12, 12, 8, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#f7f3e8";
      ctx.beginPath();
      ctx.arc(10, -13, 2.4, 0, Math.PI * 2);
      ctx.fill();
    }

    if (chewT > 0) {
      ctx.fillStyle = "rgba(224,160,74,0.75)";
      ctx.beginPath();
      ctx.arc(14, -2, 3.2, 0, Math.PI * 2);
      ctx.fill();
    }
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
