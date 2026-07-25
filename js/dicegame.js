/**
 * High or Low — guess a spinning 3D d20 (1–10 low, 11–20 high).
 * True icosahedron projected onto canvas.
 */
const DiceHighLow = (() => {
  let onDone = null;
  let rolling = false;
  let chosen = null;
  let result = 0;
  let rafId = 0;
  let canvas = null;
  let ctx = null;

  // Regular icosahedron (golden-ratio vertices)
  const PHI = (1 + Math.sqrt(5)) / 2;
  const RAW = [
    [0, 1, PHI],
    [0, -1, PHI],
    [0, 1, -PHI],
    [0, -1, -PHI],
    [1, PHI, 0],
    [-1, PHI, 0],
    [1, -PHI, 0],
    [-1, -PHI, 0],
    [PHI, 0, 1],
    [-PHI, 0, 1],
    [PHI, 0, -1],
    [-PHI, 0, -1],
  ].map((v) => {
    const len = Math.hypot(v[0], v[1], v[2]);
    return [v[0] / len, v[1] / len, v[2] / len];
  });

  // 20 triangular faces (vertex indices)
  const FACES = [
    [0, 1, 8],
    [0, 8, 4],
    [0, 4, 5],
    [0, 5, 9],
    [0, 9, 1],
    [1, 9, 7],
    [1, 7, 6],
    [1, 6, 8],
    [8, 6, 10],
    [8, 10, 4],
    [4, 10, 2],
    [4, 2, 5],
    [5, 2, 11],
    [5, 11, 9],
    [9, 11, 7],
    [3, 6, 7],
    [3, 7, 11],
    [3, 11, 2],
    [3, 2, 10],
    [3, 10, 6],
  ];

  // Numbers 1–20 mapped to faces (standard-ish opposite pairing vibe)
  const FACE_NUMS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11];

  let rot = { x: -0.35, y: 0.45, z: 0.1 };
  let targetRot = { x: -0.35, y: 0.45, z: 0.1 };
  let faceNormals = [];

  function $(id) {
    return document.getElementById(id);
  }

  function faceNormal(face) {
    const a = RAW[face[0]];
    const b = RAW[face[1]];
    const c = RAW[face[2]];
    const ux = b[0] - a[0];
    const uy = b[1] - a[1];
    const uz = b[2] - a[2];
    const vx = c[0] - a[0];
    const vy = c[1] - a[1];
    const vz = c[2] - a[2];
    let nx = uy * vz - uz * vy;
    let ny = uz * vx - ux * vz;
    let nz = ux * vy - uy * vx;
    const len = Math.hypot(nx, ny, nz) || 1;
    // Point outward from origin
    const cx = (a[0] + b[0] + c[0]) / 3;
    const cy = (a[1] + b[1] + c[1]) / 3;
    const cz = (a[2] + b[2] + c[2]) / 3;
    if (nx * cx + ny * cy + nz * cz < 0) {
      nx = -nx;
      ny = -ny;
      nz = -nz;
    }
    return [nx / len, ny / len, nz / len];
  }

  faceNormals = FACES.map(faceNormal);

  function rotatePoint(p, r) {
    let [x, y, z] = p;
    // X
    let y1 = y * Math.cos(r.x) - z * Math.sin(r.x);
    let z1 = y * Math.sin(r.x) + z * Math.cos(r.x);
    y = y1;
    z = z1;
    // Y
    let x2 = x * Math.cos(r.y) + z * Math.sin(r.y);
    let z2 = -x * Math.sin(r.y) + z * Math.cos(r.y);
    x = x2;
    z = z2;
    // Z
    let x3 = x * Math.cos(r.z) - y * Math.sin(r.z);
    let y3 = x * Math.sin(r.z) + y * Math.cos(r.z);
    return [x3, y3, z];
  }

  /** Rotation that aims a face normal toward +Z (camera). */
  function rotationForFace(faceIndex) {
    const n = faceNormals[faceIndex];
    // yaw then pitch to aim n at (0,0,1)
    const yaw = Math.atan2(n[0], n[2]);
    const hyp = Math.hypot(n[0], n[2]);
    const pitch = -Math.atan2(n[1], hyp);
    return { x: pitch + 0.12, y: -yaw + 0.08, z: 0.05 };
  }

  function ensureCanvas() {
    canvas = $("d20Canvas");
    if (!canvas) return false;
    ctx = canvas.getContext("2d");
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const css = 220;
    canvas.width = css * dpr;
    canvas.height = css * dpr;
    canvas.style.width = `${css}px`;
    canvas.style.height = `${css}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    return true;
  }

  function project(p, scale, cx, cy) {
    // Closer camera = stronger perspective foreshortening
    const dist = 2.55;
    const z = p[2] + dist;
    const f = (scale * dist) / z;
    return [cx + p[0] * f, cy - p[1] * f, z];
  }

  function drawDie(opts = {}) {
    if (!ctx && !ensureCanvas()) return;
    const w = 220;
    const h = 220;
    const cx = w / 2;
    const cy = h / 2 + 2;
    const scale = 86;
    ctx.clearRect(0, 0, w, h);

    // Soft ground shadow (stretches a bit while spinning)
    const spinStretch = opts.spinning ? 1.25 : 1;
    ctx.save();
    const g = ctx.createRadialGradient(cx, h - 26, 4, cx, h - 26, 60);
    g.addColorStop(0, "rgba(0,0,0,0.45)");
    g.addColorStop(1, "rgba(0,0,0,0)");
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.ellipse(cx, h - 26, 56 * spinStretch, 14, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    const verts = RAW.map((v) => rotatePoint(v, rot));
    const light = [0.35, 0.55, 0.75]; // key light from upper-right / camera
    const faces = FACES.map((face, i) => {
      const pts = face.map((vi) => project(verts[vi], scale, cx, cy));
      const avgZ = (pts[0][2] + pts[1][2] + pts[2][2]) / 3;
      const n = rotatePoint(faceNormals[i], rot);
      const ndot = Math.max(0, n[0] * light[0] + n[1] * light[1] + n[2] * light[2]);
      return { i, pts, avgZ, n, ndot, num: FACE_NUMS[i] };
    });

    // Painter's algorithm — far to near; skip back faces
    faces
      .filter((f) => f.n[2] > 0.04)
      .sort((a, b) => b.avgZ - a.avgZ)
      .forEach((f) => {
        const lit = 0.22 + 0.78 * f.ndot;
        let base;
        if (opts.landed) {
          if (f.num === result) {
            base = opts.win ? [120, 200, 145] : [210, 100, 85];
          } else {
            base = opts.win ? [55, 85, 70] : [75, 58, 68];
          }
        } else {
          // Slight hue variance per face so facets read in motion
          base = [78 + (f.i % 5) * 6, 62 + (f.i % 3) * 4, 130 + (f.i % 4) * 5];
        }
        const r = Math.min(255, Math.round(base[0] * lit + f.ndot * 28));
        const gch = Math.min(255, Math.round(base[1] * lit + f.ndot * 18));
        const b = Math.min(255, Math.round(base[2] * lit + f.ndot * 10));

        // Depth darkening for far faces
        const depth = Math.min(1, Math.max(0.55, 1.15 - (f.avgZ - 2.2) * 0.35));

        ctx.beginPath();
        ctx.moveTo(f.pts[0][0], f.pts[0][1]);
        ctx.lineTo(f.pts[1][0], f.pts[1][1]);
        ctx.lineTo(f.pts[2][0], f.pts[2][1]);
        ctx.closePath();
        ctx.fillStyle = `rgb(${Math.round(r * depth)},${Math.round(gch * depth)},${Math.round(b * depth)})`;
        ctx.fill();

        // Specular glint near camera-facing faces
        if (f.ndot > 0.75) {
          const mx = (f.pts[0][0] + f.pts[1][0] + f.pts[2][0]) / 3;
          const my = (f.pts[0][1] + f.pts[1][1] + f.pts[2][1]) / 3;
          const gloss = ctx.createRadialGradient(mx - 4, my - 6, 1, mx, my, 18);
          gloss.addColorStop(0, "rgba(255,255,255,0.22)");
          gloss.addColorStop(1, "rgba(255,255,255,0)");
          ctx.fillStyle = gloss;
          ctx.fill();
        }

        ctx.strokeStyle =
          f.num === result && opts.landed
            ? "rgba(255,236,190,0.85)"
            : "rgba(240,197,122,0.4)";
        ctx.lineWidth = f.num === result && opts.landed ? 2.4 : 1.05;
        ctx.stroke();

        // Number at face centroid (larger on facing faces)
        const mx = (f.pts[0][0] + f.pts[1][0] + f.pts[2][0]) / 3;
        const my = (f.pts[0][1] + f.pts[1][1] + f.pts[2][1]) / 3;
        const fontSize = 10 + Math.max(0, f.n[2]) * 14;
        ctx.save();
        ctx.fillStyle =
          f.num === result && opts.landed
            ? opts.win
              ? "#eef5ea"
              : "#fff0ec"
            : "#f0c57a";
        ctx.font = `700 ${fontSize}px "Fraunces", Georgia, serif`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.shadowColor = "rgba(0,0,0,0.55)";
        ctx.shadowBlur = 3;
        ctx.fillText(String(f.num), mx, my);
        ctx.restore();
      });
  }

  function resetUi() {
    const stage = $("diceStage");
    const status = $("diceStatus");
    const again = $("diceAgain");
    const picks = $("dicePicks");
    if (status) status.textContent = "Guess High (11–20) or Low (1–10), then watch the d20 tumble.";
    if (again) again.hidden = true;
    if (picks) picks.hidden = false;
    if (stage) stage.dataset.state = "ready";
    chosen = null;
    rolling = false;
    result = 0;
    rot = { x: -0.35, y: 0.45, z: 0.1 };
    ensureCanvas();
    drawDie();
  }

  function start(doneCallback) {
    onDone = doneCallback;
    resetUi();
    $("diceModal").hidden = false;
    bind();
    // Idle gentle spin
    idleSpin(true);
  }

  let idle = false;
  function idleSpin(on) {
    idle = on;
    if (!on) return;
    const tick = (now) => {
      if (!idle || rolling || $("diceModal")?.hidden) {
        idle = false;
        return;
      }
      rot.y += 0.012;
      rot.x = -0.35 + Math.sin(now * 0.001) * 0.08;
      drawDie();
      rafId = requestAnimationFrame(tick);
    };
    cancelAnimationFrame(rafId);
    rafId = requestAnimationFrame(tick);
  }

  function close(bail = true) {
    unbind();
    idle = false;
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
    close(false);
  }
  function onAgain() {
    resetUi();
    idleSpin(true);
  }

  function pick(guess) {
    if (rolling) return;
    idle = false;
    cancelAnimationFrame(rafId);
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
    ensureCanvas();
    const duration = 2600;
    const startT = performance.now();
    const startRot = { ...rot };
    const faceIdx = FACE_NUMS.indexOf(result);
    targetRot = rotationForFace(faceIdx >= 0 ? faceIdx : 0);
    // Extra full tumbles before settling
    const tumbleX = startRot.x + Math.PI * 2 * (3 + Math.random() * 2);
    const tumbleY = startRot.y + Math.PI * 2 * (4 + Math.random() * 2);
    const tumbleZ = startRot.z + Math.PI * 2 * (1 + Math.random());

    const easeOut = (t) => 1 - Math.pow(1 - t, 3);

    const tick = (now) => {
      const u = Math.min(1, (now - startT) / duration);
      const e = easeOut(u);
      if (u < 0.72) {
        // Chaotic tumble
        const chaos = 1 - u / 0.72;
        rot.x = startRot.x + (tumbleX - startRot.x) * (u / 0.72) + Math.sin(now * 0.03) * chaos * 0.8;
        rot.y = startRot.y + (tumbleY - startRot.y) * (u / 0.72) + Math.cos(now * 0.025) * chaos * 0.9;
        rot.z = startRot.z + (tumbleZ - startRot.z) * (u / 0.72) + Math.sin(now * 0.02) * chaos * 0.5;
      } else {
        // Settle onto result face
        const s = (u - 0.72) / 0.28;
        const se = easeOut(s);
        const fromX = tumbleX;
        const fromY = tumbleY;
        const fromZ = tumbleZ;
        rot.x = fromX + (targetRot.x - fromX) * se;
        rot.y = fromY + (targetRot.y - fromY) * se;
        rot.z = fromZ + (targetRot.z - fromZ) * se;
      }
      drawDie({ spinning: true });
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
    rot = { ...targetRot };
    const isHigh = result >= 11;
    const correct = (chosen === "high" && isHigh) || (chosen === "low" && !isHigh);
    $("diceStage").dataset.state = correct ? "win" : "lose";
    drawDie({ landed: true, win: correct });

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
    setTimeout(() => {
      if (typeof onDone === "function") onDone(payload);
    }, 650);
  }

  return { start, close };
})();
window.DiceHighLow = DiceHighLow;
