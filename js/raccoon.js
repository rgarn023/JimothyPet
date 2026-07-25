/**
 * SVG art + motion for Jimothy — bush rustle, form variance, walk/run/jump.
 * Spirit match for godot/scripts/raccoon_view.gd
 */
const RaccoonArt = (() => {
  const svg = (body, extra = "") =>
    `<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg" aria-hidden="true" ${extra}>${body}</svg>`;

  function g(genes, key, fallback = 0.5) {
    if (!genes || genes[key] == null) return fallback;
    return Number(genes[key]);
  }

  function fur(genes, stage, adultForm) {
    const gray = g(genes, "gray");
    let r = 0.42 + gray * 0.08;
    let green = 0.42 + gray * 0.06;
    let b = 0.46 + gray * 0.05;
    if (stage === "adult" && adultForm === "alley_ghost") {
      r *= 0.9;
      green *= 0.9;
      b *= 0.92;
    }
    const toHex = (n) =>
      Math.round(Math.min(255, Math.max(0, n * 255)))
        .toString(16)
        .padStart(2, "0");
    return `#${toHex(r)}${toHex(green)}${toHex(b)}`;
  }

  function lighten(hex, amount) {
    const n = parseInt(hex.slice(1), 16);
    let r = (n >> 16) & 255;
    let gch = (n >> 8) & 255;
    let b = n & 255;
    if (amount >= 0) {
      r = Math.min(255, Math.round(r + (255 - r) * amount));
      gch = Math.min(255, Math.round(gch + (255 - gch) * amount));
      b = Math.min(255, Math.round(b + (255 - b) * amount));
    } else {
      const a = -amount;
      r = Math.max(0, Math.round(r * (1 - a)));
      gch = Math.max(0, Math.round(gch * (1 - a)));
      b = Math.max(0, Math.round(b * (1 - a)));
    }
    return `#${r.toString(16).padStart(2, "0")}${gch.toString(16).padStart(2, "0")}${b
      .toString(16)
      .padStart(2, "0")}`;
  }

  function ears(cx, cy, spread, up, flare) {
    const f = 1 + flare * 0.35;
    return `
      <ellipse cx="${cx - spread}" cy="${cy - up}" rx="${7 * f}" ry="${11 * f}" fill="#4a4a54"/>
      <ellipse cx="${cx + spread}" cy="${cy - up}" rx="${7 * f}" ry="${11 * f}" fill="#4a4a54"/>
      <ellipse cx="${cx - spread}" cy="${cy - up}" rx="4" ry="6" fill="#e2cdb2"/>
      <ellipse cx="${cx + spread}" cy="${cy - up}" rx="4" ry="6" fill="#e2cdb2"/>
    `;
  }

  function mask(cx, cy, rx, ry, eye, maskGene) {
    const maskC = maskGene > 0.7 ? "#1c1c22" : "#2a2a32";
    return `
      <ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${maskC}"/>
      <circle cx="${cx - eye * 1.35}" cy="${cy - 1}" r="${eye}" fill="#faf6ec"/>
      <circle cx="${cx + eye * 1.35}" cy="${cy - 1}" r="${eye}" fill="#faf6ec"/>
      <circle cx="${cx - eye * 1.15}" cy="${cy - 0.3}" r="${eye * 0.45}" fill="#101014"/>
      <circle cx="${cx + eye * 1.55}" cy="${cy - 0.3}" r="${eye * 0.45}" fill="#101014"/>
      <ellipse cx="${cx}" cy="${cy + eye * 1.15}" rx="${eye * 1.1}" ry="${eye * 0.7}" fill="#c9a292"/>
    `;
  }

  function tail(cx, cy, scale) {
    return `
      <path d="M${cx} ${cy} Q${cx + 26 * scale} ${cy - 14 * scale} ${cx + 22 * scale} ${cy + 12 * scale}
               Q${cx + 14 * scale} ${cy + 18 * scale} ${cx + 4 * scale} ${cy + 8 * scale}"
            fill="#5a5a64"/>
      <path d="M${cx + 6 * scale} ${cy - 2} Q${cx + 16 * scale} ${cy - 8 * scale} ${cx + 18 * scale} ${cy + 2}
               M${cx + 8 * scale} ${cy + 4} Q${cx + 18 * scale} ${cy} ${cx + 16 * scale} ${cy + 10 * scale}"
            fill="none" stroke="#b0b0ba" stroke-width="${2.5 * scale}" stroke-linecap="round"/>
    `;
  }

  function legs(baseY, legScale, ampClass = "leg") {
    const h = 22 * legScale;
    return `
      <g class="legs">
        <path class="${ampClass} l1" d="M46 ${baseY} L42 ${baseY + h}" stroke="#4f4f58" stroke-width="4.5" stroke-linecap="round"/>
        <path class="${ampClass} l2" d="M54 ${baseY + 2} L52 ${baseY + h + 2}" stroke="#4f4f58" stroke-width="4.5" stroke-linecap="round"/>
        <path class="${ampClass} l3" d="M66 ${baseY + 2} L68 ${baseY + h + 2}" stroke="#4f4f58" stroke-width="4.5" stroke-linecap="round"/>
        <path class="${ampClass} l4" d="M74 ${baseY} L80 ${baseY + h}" stroke="#4f4f58" stroke-width="4.5" stroke-linecap="round"/>
        <ellipse cx="42" cy="${baseY + h}" rx="6" ry="3.5" fill="#3a3a44"/>
        <ellipse cx="52" cy="${baseY + h + 2}" rx="6" ry="3.5" fill="#3a3a44"/>
        <ellipse cx="68" cy="${baseY + h + 2}" rx="6" ry="3.5" fill="#3a3a44"/>
        <ellipse cx="80" cy="${baseY + h}" rx="6" ry="3.5" fill="#3a3a44"/>
      </g>
    `;
  }

  function bush(ageSec = 0) {
    const hint = Math.min(1, Math.max(0, ageSec / 60));
    const glint =
      hint > 0.7
        ? `<circle class="bush-glint" cx="56" cy="62" r="2.2" fill="#faf6ec" opacity="0.55"/>
           <circle class="bush-glint" cx="66" cy="64" r="2.2" fill="#faf6ec" opacity="0.45"/>`
        : "";
    return svg(`
      <ellipse cx="60" cy="98" rx="48" ry="10" fill="#000" opacity="0.25"/>
      <g class="bush-foliage">
        <ellipse class="leaf a" cx="42" cy="78" rx="26" ry="22" fill="#2f5a3c"/>
        <ellipse class="leaf b" cx="76" cy="80" rx="28" ry="24" fill="#3d6b4f"/>
        <ellipse class="leaf c" cx="60" cy="68" rx="34" ry="28" fill="#355f44"/>
        <ellipse class="leaf d" cx="52" cy="54" rx="18" ry="16" fill="#4a8a5e"/>
        <ellipse class="leaf e" cx="72" cy="58" rx="16" ry="14" fill="#548a62"/>
      </g>
      ${glint}
    `);
  }

  function baby(genes) {
    const color = fur(genes, "baby");
    const flare = g(genes, "ear_flare");
    return svg(`
      <ellipse cx="60" cy="100" rx="18" ry="5" fill="#000" opacity="0.2"/>
      <ellipse class="body" cx="60" cy="74" rx="18" ry="14" fill="${color}"/>
      <circle class="head" cx="60" cy="58" r="14" fill="${lighten(color, 0.05)}"/>
      ${ears(60, 58, 11, 10, flare)}
      ${mask(60, 60, 11, 7, 2.6, g(genes, "mask"))}
      <ellipse cx="50" cy="88" rx="5" ry="3" fill="#3a3a44"/>
      <ellipse cx="70" cy="88" rx="5" ry="3" fill="#3a3a44"/>
    `);
  }

  function young(genes, form) {
    const color = fur(genes, "young");
    const roundness = g(genes, "roundness");
    let legsMul = 0.7 + g(genes, "legginess") * 0.8;
    let bodyRx = 22 + roundness * 8;
    let bodyRy = 16 + (1 - roundness) * 4;
    if (form === "puff") {
      bodyRx += 4;
      bodyRy += 3;
    } else if (form === "looper") {
      legsMul += 0.35;
    } else if (form === "nub") {
      bodyRx -= 2;
      legsMul -= 0.15;
    }
    const shade = form === "shadow" ? lighten(color, -0.08) : color;
    return svg(`
      <ellipse cx="60" cy="104" rx="24" ry="6" fill="#000" opacity="0.2"/>
      ${tail(78, 68, 0.75)}
      ${legs(70, legsMul)}
      <ellipse class="body" cx="60" cy="66" rx="${bodyRx}" ry="${bodyRy}" fill="${shade}"/>
      <circle class="head" cx="60" cy="52" r="${16 + roundness * 3}" fill="${lighten(shade, 0.04)}"/>
      ${ears(60, 52, 14, 12, g(genes, "ear_flare"))}
      ${mask(60, 54, 14, 9, 3.3, g(genes, "mask"))}
    `);
  }

  function teen(genes, form) {
    const color = fur(genes, "teen");
    let legsMul = 1 + g(genes, "legginess") * 0.7;
    let roundness = g(genes, "roundness");
    if (form === "bounder") legsMul += 0.4;
    else if (form === "dumpling") {
      roundness = Math.max(roundness, 0.7);
      legsMul -= 0.1;
    } else if (form === "nightlane") legsMul += 0.2;
    else if (form === "scruff") roundness *= 0.8;

    return svg(`
      <ellipse cx="60" cy="108" rx="28" ry="6" fill="#000" opacity="0.22"/>
      ${tail(82, 64, 0.9)}
      ${legs(68, legsMul)}
      <ellipse class="body" cx="60" cy="62" rx="${26 + roundness * 6}" ry="${20 + (1 - roundness) * 3}" fill="${color}"/>
      <circle class="head" cx="60" cy="50" r="18" fill="${lighten(color, 0.03)}"/>
      ${ears(60, 50, 16, 14, g(genes, "ear_flare"))}
      ${mask(60, 52, 16, 10, 3.8, g(genes, "mask"))}
    `);
  }

  function adult(genes, form) {
    const color = fur(genes, "adult", form);
    const legsMul = 1.25 + g(genes, "legginess") * 0.45;
    const roundness = 0.7 + g(genes, "roundness") * 0.3;
    const bodyRx = 30 + roundness * 8;
    const bodyRy = 26 + roundness * 4;
    let flair = "";
    if (form === "saint") {
      flair = `<ellipse cx="78" cy="42" rx="7" ry="4" fill="#6fbf84" transform="rotate(-20 78 42)"/>`;
    } else if (form === "legend") {
      flair = `<path d="M76 46 L88 60 L74 62 Z" fill="#e0a04a"/>`;
    } else if (form === "alley_ghost") {
      flair = `<circle cx="80" cy="52" r="3" fill="rgba(217,230,242,0.55)"/>`;
    } else if (form === "ballard_blip") {
      flair = `<ellipse cx="60" cy="68" rx="10" ry="5" fill="rgba(224,160,74,0.35)"/>`;
    }

    return svg(`
      <ellipse cx="60" cy="112" rx="34" ry="7" fill="#000" opacity="0.22"/>
      ${tail(84, 58, 1.05)}
      <g class="legs">
        <path class="leg l1" d="M42 62 L30 98" stroke="#4f4f58" stroke-width="6" stroke-linecap="round"/>
        <path class="leg l2" d="M52 66 L48 102" stroke="#5a5a64" stroke-width="6" stroke-linecap="round"/>
        <path class="leg l3" d="M68 66 L74 102" stroke="#5a5a64" stroke-width="6" stroke-linecap="round"/>
        <path class="leg l4" d="M78 62 L92 98" stroke="#4f4f58" stroke-width="6" stroke-linecap="round"/>
        <ellipse cx="30" cy="100" rx="8" ry="4.5" fill="#3a3a44"/>
        <ellipse cx="48" cy="104" rx="8" ry="4.5" fill="#3a3a44"/>
        <ellipse cx="74" cy="104" rx="8" ry="4.5" fill="#3a3a44"/>
        <ellipse cx="92" cy="100" rx="8" ry="4.5" fill="#3a3a44"/>
      </g>
      <ellipse class="body" cx="60" cy="52" rx="${bodyRx}" ry="${bodyRy}" fill="${color}"/>
      ${ears(60, 52, 20, 24, g(genes, "ear_flare"))}
      ${mask(60, 50, 20, 12, 4.6, g(genes, "mask"))}
      ${flair}
      <path d="M40 56 h-8 M40 60 h-7 M80 56 h8 M80 60 h7"
            stroke="#d0d0d8" stroke-width="1.2" stroke-linecap="round" opacity="0.55"/>
    `);
  }

  const icons = {
    feed: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M7 3v10a3 3 0 006 0V3" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M10 16v5M7 21h6" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M16 4c2 2 3 4 3 7v10" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`,
    play: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3" y="7" width="18" height="12" rx="3" stroke="currentColor" stroke-width="2"/><circle cx="8" cy="13" r="1.5" fill="currentColor"/><circle cx="16" cy="13" r="1.5" fill="currentColor"/><path d="M9 7V5h6v2" stroke="currentColor" stroke-width="2"/></svg>`,
    scold: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 14V8a4 4 0 018 0v6" stroke="currentColor" stroke-width="2"/><path d="M2 14h12v2a4 4 0 01-4 4H6a4 4 0 01-4-4v-2z" stroke="currentColor" stroke-width="2"/><path d="M16 8c2 1.5 3 3.5 3 6M19 6c2.5 2 4 5 4 8" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`,
    clean: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 3v6M8 5l8 4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M7 11h10l-1.5 9h-7L7 11z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/></svg>`,
    berries: `<svg viewBox="0 0 32 32" aria-hidden="true"><circle cx="12" cy="18" r="6" fill="#5a4a8a"/><circle cx="20" cy="16" r="6" fill="#6b5aa0"/><circle cx="16" cy="22" r="5.5" fill="#4a3a72"/><path d="M16 8c0 4-2 6-4 7" stroke="#3d6b4f" stroke-width="2" fill="none"/><ellipse cx="18" cy="8" rx="4" ry="2" fill="#6fbf84"/></svg>`,
    crickets: `<svg viewBox="0 0 32 32" aria-hidden="true"><ellipse cx="16" cy="18" rx="10" ry="5" fill="#6fbf84"/><ellipse cx="22" cy="16" rx="4" ry="3" fill="#548a62"/><path d="M8 16c-3-4-4-8-2-10M10 20c-4 2-6 6-4 8M24 14c3-3 5-2 6 0" stroke="#3d6b4f" stroke-width="1.6" fill="none" stroke-linecap="round"/><circle cx="24" cy="15" r="1.2" fill="#1b2a22"/></svg>`,
    fish: `<svg viewBox="0 0 32 32" aria-hidden="true"><path d="M6 16c6-8 14-8 20 0-6 8-14 8-20 0z" fill="#7ec8d4"/><path d="M26 16l4-5v10l-4-5z" fill="#5a9eb0"/><circle cx="11" cy="15" r="1.5" fill="#1b2a22"/><path d="M8 12c2 1 3 3 2 5" stroke="#eef5ea" stroke-width="1.2" fill="none"/></svg>`,
    pizza: `<svg viewBox="0 0 32 32" aria-hidden="true"><path d="M6 10l10 18 10-18z" fill="#e0a04a"/><path d="M8 11h16" stroke="#c45c4a" stroke-width="3"/><circle cx="14" cy="18" r="2" fill="#8a2f2f"/><circle cx="18" cy="22" r="1.6" fill="#8a2f2f"/></svg>`,
    fries: `<svg viewBox="0 0 32 32" aria-hidden="true"><path d="M9 14h14l-2 14H11L9 14z" fill="#c45c4a"/><rect x="11" y="6" width="2.5" height="10" rx="1" fill="#e0a04a"/><rect x="15" y="4" width="2.5" height="12" rx="1" fill="#f0c57a"/><rect x="19" y="7" width="2.5" height="9" rx="1" fill="#e0a04a"/></svg>`,
  };

  function render(profile = {}) {
    const stage = profile.stage || "bush";
    const genes = profile.genes || {};
    switch (stage) {
      case "bush":
        return bush(profile.ageSec || 0);
      case "baby":
        return baby(genes);
      case "young":
        return young(genes, profile.youngForm || "puff");
      case "teen":
        return teen(genes, profile.teenForm || "bounder");
      case "adult":
        return adult(genes, profile.adultForm || "saint");
      default:
        return bush(0);
    }
  }

  return { render, icons };
})();
window.RaccoonArt = RaccoonArt;

/**
 * Pose / locomotion controller — walk, run, jump, bush rustle.
 */
const RaccoonAnim = (() => {
  let wrap = null;
  let raccoon = null;
  let stage = "bush";
  let ageSec = 0;
  let alive = true;

  let t = 0;
  let poseX = 0;
  let poseY = 0;
  let facing = 1;
  let anim = "idle";
  let animT = 0;
  let animDur = 1.2;
  let walkPhase = 0;
  let jumpPeak = 0;
  let targetX = 0;
  let speed = 0;

  function init(wrapEl, raccoonEl) {
    wrap = wrapEl;
    raccoon = raccoonEl;
  }

  function reset() {
    poseX = 0;
    poseY = 0;
    facing = 1;
    anim = "idle";
    animT = 0;
    animDur = 1.2;
    walkPhase = 0;
    speed = 0;
    if (wrap) {
      wrap.style.opacity = "1";
      wrap.classList.remove("ascending");
      wrap.classList.add("is-bush");
      const wings = wrap.querySelector(".ascend-wings");
      if (wings) wings.remove();
    }
    applyTransform();
  }

  function sync(info) {
    stage = info.stage || "bush";
    ageSec = info.ageSec || 0;
    alive = info.alive !== false || !!info.ascending;
    if (wrap) {
      const showBush = stage === "bush" && alive && anim !== "ascend" && !info.ascending;
      wrap.classList.toggle("is-bush", showBush);
      wrap.classList.toggle("ascending", anim === "ascend" || !!info.ascending);
      wrap.dataset.anim = anim;
      if (showBush) {
        wrap.style.opacity = "1";
        const wings = wrap.querySelector(".ascend-wings");
        if (wings) wings.remove();
      }
    }
  }

  function ensureWings() {
    if (!wrap) return;
    let wings = wrap.querySelector(".ascend-wings");
    if (!wings) {
      wings = document.createElement("div");
      wings.className = "ascend-wings";
      wings.innerHTML = `
        <svg viewBox="0 0 160 80" aria-hidden="true">
          <path class="wing left" d="M80 40 C50 10 20 20 8 38 C30 44 50 50 78 44 Z" />
          <path class="wing right" d="M80 40 C110 10 140 20 152 38 C130 44 110 50 82 44 Z" />
        </svg>`;
      wrap.appendChild(wings);
    }
    return wings;
  }

  function play(kind) {
    anim = kind || "idle";
    animT = 0;
    if (!wrap) return;
    wrap.dataset.anim = anim;

    switch (kind) {
      case "ascend":
        animDur = 4.2;
        ensureWings();
        wrap.classList.add("ascending");
        break;
      case "run":
        animDur = 1.4 + Math.random() * 1;
        speed = 90 + Math.random() * 50;
        targetX = -70 + Math.random() * 140;
        facing = Math.sign(targetX - poseX) || 1;
        break;
      case "walk":
      case "lope":
        animDur = 1.8 + Math.random() * 1.4;
        speed = kind === "walk" ? 35 + Math.random() * 35 : 55 + Math.random() * 40;
        targetX = -65 + Math.random() * 130;
        facing = Math.sign(targetX - poseX) || (Math.random() < 0.5 ? -1 : 1);
        break;
      case "jump":
        animDur = 0.55 + Math.random() * 0.35;
        jumpPeak = 18 + Math.random() * 18;
        facing = Math.random() < 0.5 ? -1 : 1;
        targetX = Math.max(-70, Math.min(70, poseX + facing * (20 + Math.random() * 30)));
        break;
      case "pop":
      case "stretch":
        animDur = 0.8;
        break;
      case "eat":
        animDur = 0.9;
        break;
      case "refuse":
      case "scold":
      case "stubborn":
      case "sick":
        animDur = 1;
        break;
      default:
        animDur = 1 + Math.random();
        speed = 0;
    }
  }

  function applyTransform() {
    if (!wrap) return;
    const scaleX = facing < 0 ? -1 : 1;
    wrap.style.transform = `translate(${poseX}px, ${poseY}px) scaleX(${scaleX})`;
    wrap.dataset.anim = anim;
  }

  function tick(dt) {
    if (!wrap) return;
    if (!alive && anim !== "ascend") return;
    t += dt;
    animT += dt;

    if (anim === "ascend") {
      const u = Math.min(1, animT / animDur);
      const wingSpan = Math.min(1, u / 0.45);
      poseY = -u * 160 - Math.sin(u * Math.PI) * 12;
      poseX = Math.sin(t * 1.6) * (8 * (1 - u * 0.5));
      facing = 1;
      wrap.style.opacity = String(1 - Math.max(0, (u - 0.55) / 0.45));
      const wings = ensureWings();
      if (wings) wings.style.setProperty("--wing-span", String(wingSpan));
      wrap.classList.add("ascending");
      applyTransform();
      return;
    }

    wrap.style.opacity = "1";
    if (stage === "bush") {
      poseX = Math.sin(t * 9) * 2 + Math.sin(t * 3.3) * 1.5;
      poseY = Math.sin(t * 7) * 1.5;
      facing = 1;
      wrap.classList.add("is-bush");
      applyTransform();
      return;
    }

    wrap.classList.remove("is-bush");

    switch (anim) {
      case "walk":
      case "run":
      case "lope": {
        let dir = Math.sign(targetX - poseX) || facing;
        facing = dir;
        const step = speed * dt;
        if (Math.abs(targetX - poseX) <= step) poseX = targetX;
        else poseX += dir * step;
        walkPhase += dt * (speed * 0.12);
        poseY = Math.abs(Math.sin(walkPhase)) * (anim === "walk" ? 3 : 5.5);
        if (Math.abs(poseX - targetX) < 1.5 || animT >= animDur) {
          if (Math.random() < 0.45 && animT < animDur) {
            targetX = -70 + Math.random() * 140;
            facing = Math.sign(targetX - poseX) || facing;
          } else {
            anim = "idle";
            poseY = 0;
          }
        }
        break;
      }
      case "jump": {
        const u = Math.min(1, animT / animDur);
        poseY = -Math.sin(u * Math.PI) * jumpPeak;
        poseX += (targetX - poseX) * Math.min(1, dt * 3.5);
        if (u >= 1) {
          anim = "idle";
          poseY = 0;
        }
        break;
      }
      case "pop": {
        const u = Math.min(1, animT / animDur);
        poseY = -Math.pow(u, 0.3) * 20;
        if (animT >= animDur) {
          anim = "idle";
          poseY = 0;
        }
        break;
      }
      case "eat": {
        poseY = Math.sin(t * 16) * 2;
        if (animT >= animDur) {
          anim = "idle";
          poseY = 0;
        }
        break;
      }
      case "stubborn":
      case "refuse": {
        poseX += Math.sin(t * 18) * 0.6;
        if (animT >= animDur) anim = "idle";
        break;
      }
      default: {
        poseY = Math.sin(t * 2.2) * 2;
        const idleTarget = Math.sin(t * 0.35) * 8;
        poseX += Math.sign(idleTarget - poseX) * Math.min(Math.abs(idleTarget - poseX), 10 * dt);
        break;
      }
    }

    poseX = Math.max(-55, Math.min(55, poseX));
    applyTransform();
  }

  return { init, reset, sync, play, tick };
})();
window.RaccoonAnim = RaccoonAnim;
