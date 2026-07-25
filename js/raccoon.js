/**
 * SVG art + motion for Jimothy — side-profile walks, distinct form silhouettes.
 * Spirit match for godot/scripts/raccoon_view.gd
 */
const RaccoonArt = (() => {
  const svg = (body, extra = "") =>
    `<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg" aria-hidden="true" ${extra}>${body}</svg>`;

  function g(genes, key, fallback = 0.5) {
    if (!genes || genes[key] == null) return fallback;
    return Number(genes[key]);
  }

  function toHex(n) {
    return Math.round(Math.min(255, Math.max(0, n * 255)))
      .toString(16)
      .padStart(2, "0");
  }

  function rgb(r, green, b) {
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

  /** Form-specific base fur (side silhouette reads through color + shape). */
  function formFur(stage, form, genes) {
    const gray = g(genes, "gray");
    if (stage === "young") {
      if (form === "puff") return rgb(0.55 + gray * 0.08, 0.5 + gray * 0.05, 0.48);
      if (form === "looper") return rgb(0.48 + gray * 0.06, 0.44, 0.4);
      if (form === "shadow") return rgb(0.22 + gray * 0.04, 0.22, 0.26);
      if (form === "nub") return rgb(0.42, 0.38 + gray * 0.05, 0.34);
    }
    if (stage === "teen") {
      if (form === "dumpling") return rgb(0.58, 0.52, 0.48);
      if (form === "bounder") return rgb(0.46, 0.42, 0.4);
      if (form === "nightlane") return rgb(0.2, 0.22, 0.3);
      if (form === "scruff") return rgb(0.4, 0.34, 0.3);
    }
    if (stage === "adult") {
      if (form === "saint") return rgb(0.4, 0.46, 0.4);
      if (form === "legend") return rgb(0.45, 0.4, 0.36);
      if (form === "alley_ghost") return rgb(0.55, 0.58, 0.64);
      if (form === "ballard_blip") return rgb(0.48, 0.38, 0.3);
    }
    return rgb(0.42 + gray * 0.08, 0.42 + gray * 0.06, 0.46 + gray * 0.05);
  }

  function sideLegs(hipY, frontX, backX, legH, strokeW = 4.5) {
    const foot = "#3a3a44";
    const leg = "#4f4f58";
    return `
      <g class="legs">
        <path class="leg l1" d="M${backX} ${hipY} L${backX - 4} ${hipY + legH}" stroke="${leg}" stroke-width="${strokeW}" stroke-linecap="round"/>
        <path class="leg l2" d="M${backX + 6} ${hipY + 1} L${backX + 8} ${hipY + legH + 1}" stroke="${leg}" stroke-width="${strokeW * 0.9}" stroke-linecap="round" opacity="0.55"/>
        <path class="leg l3" d="M${frontX - 4} ${hipY + 1} L${frontX - 6} ${hipY + legH}" stroke="${leg}" stroke-width="${strokeW * 0.9}" stroke-linecap="round" opacity="0.55"/>
        <path class="leg l4" d="M${frontX} ${hipY} L${frontX + 5} ${hipY + legH}" stroke="${leg}" stroke-width="${strokeW}" stroke-linecap="round"/>
        <ellipse cx="${backX - 4}" cy="${hipY + legH}" rx="5.5" ry="3" fill="${foot}"/>
        <ellipse cx="${frontX + 5}" cy="${hipY + legH}" rx="5.5" ry="3" fill="${foot}"/>
      </g>
    `;
  }

  function sideEye(x, y, r, smiling, gleam = "#faf6ec") {
    if (smiling) {
      return `<path d="M${x - r * 1.2} ${y} Q${x} ${y - r * 1.1} ${x + r * 1.2} ${y}"
        fill="none" stroke="${gleam}" stroke-width="2" stroke-linecap="round"/>`;
    }
    return `
      <circle cx="${x}" cy="${y}" r="${r}" fill="${gleam}"/>
      <circle cx="${x + r * 0.25}" cy="${y}" r="${r * 0.45}" fill="#101014"/>
    `;
  }

  function ringedTail(baseX, baseY, len, rings = true) {
    const tipX = baseX - len;
    const tipY = baseY - len * 0.25;
    let stripes = "";
    if (rings) {
      for (let i = 0; i < 4; i++) {
        const t = 0.2 + i * 0.18;
        const sx = baseX + (tipX - baseX) * t;
        const sy = baseY + (tipY - baseY) * t;
        stripes += `<ellipse cx="${sx}" cy="${sy}" rx="4" ry="3.2" fill="#c8c8d0" opacity="0.75" transform="rotate(-25 ${sx} ${sy})"/>`;
      }
    }
    return `
      <path d="M${baseX} ${baseY} Q${baseX - len * 0.45} ${baseY - len * 0.55} ${tipX} ${tipY}"
            fill="none" stroke="#5a5a64" stroke-width="8" stroke-linecap="round"/>
      ${stripes}
    `;
  }

  /** Pointed leaf tip for a jagged bushy silhouette. */
  function leafTip(cx, cy, len, wid, fill, rot = 0, cls = "leaf") {
    return `<path class="${cls}" transform="translate(${cx} ${cy}) rotate(${rot})"
      d="M0 ${-len * 0.55} Q${wid} 0 0 ${len * 0.45} Q${-wid} 0 0 ${-len * 0.55} Z"
      fill="${fill}"/>`;
  }

  /** Soft oval fill leaf for dense body. */
  function leafPad(cx, cy, rx, ry, fill, rot = 0, cls = "leaf") {
    return `<ellipse class="${cls}" cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${fill}"
      transform="rotate(${rot} ${cx} ${cy})"/>`;
  }

  function bush(ageSec = 0) {
    const hint = Math.min(1, Math.max(0, ageSec / 60));
    const glint =
      hint > 0.7
        ? `<circle class="bush-glint" cx="50" cy="78" r="2" fill="#faf6ec" opacity="0.55"/>
           <circle class="bush-glint" cx="68" cy="80" r="1.8" fill="#faf6ec" opacity="0.4"/>`
        : "";
    const deep = ["#1e3f2a", "#244a32", "#2a5236", "#2f5a3c"];
    const mid = ["#355f44", "#3d6b4f", "#3a6648", "#2d5740"];
    const lite = ["#4a8a5e", "#548a62", "#5aa870", "#6fbf84"];
    const body = [];
    // Wide low pads — shrub mass (wider than tall)
    const pads = [
      [20, 88, 14, 10, -8], [36, 84, 16, 11, 6], [54, 82, 18, 12, -4], [72, 84, 16, 11, 8],
      [90, 88, 14, 10, -6], [28, 74, 13, 10, 12], [46, 70, 15, 11, -10], [64, 70, 15, 11, 10],
      [82, 74, 13, 10, -12], [38, 92, 14, 9, 4], [58, 94, 16, 9, -6], [78, 92, 14, 9, 8],
      [40, 62, 12, 9, -14], [58, 60, 14, 10, 2], [76, 62, 12, 9, 16],
      [48, 78, 12, 9, 0], [66, 78, 12, 9, 0],
    ];
    const leafCls = ["leaf a", "leaf b", "leaf c", "leaf d", "leaf e"];
    pads.forEach(([x, y, rx, ry, rot], i) => {
      body.push(leafPad(x, y, rx, ry, mid[i % mid.length], rot, leafCls[i % leafCls.length]));
    });
    // Under-layer darker pads
    [[24, 90, 12, 8], [50, 96, 18, 8], [80, 90, 12, 8], [34, 68, 10, 8], [70, 66, 10, 8]].forEach(
      ([x, y, rx, ry], i) =>
        body.unshift(leafPad(x, y, rx, ry, deep[i % deep.length], i * 7, leafCls[(i + 2) % leafCls.length]))
    );
    // Lots of tip leaves poking out for a bushy ragged edge
    const tips = [
      [14, 82, 11, 5, -70], [18, 70, 10, 4.5, -50], [24, 60, 10, 4.5, -35],
      [34, 54, 10, 4.5, -20], [46, 50, 11, 5, -8], [58, 48, 11, 5, 4],
      [70, 50, 11, 5, 16], [82, 54, 10, 4.5, 30], [90, 62, 10, 4.5, 45],
      [96, 74, 10, 4.5, 60], [100, 86, 10, 4.5, 75],
      [12, 92, 9, 4, -85], [104, 92, 9, 4, 85],
      [30, 58, 9, 4, -28], [50, 52, 9, 4, 0], [74, 56, 9, 4, 28],
      [22, 78, 8, 3.5, -55], [40, 64, 8, 3.5, -15], [62, 62, 8, 3.5, 12],
      [84, 68, 8, 3.5, 40], [42, 88, 8, 3.5, -40], [78, 86, 8, 3.5, 40],
      [36, 72, 7, 3, 20], [56, 68, 7, 3, -18], [72, 74, 7, 3, 25],
    ];
    tips.forEach(([x, y, len, wid, rot], i) => {
      body.push(leafTip(x, y, len, wid, lite[i % lite.length], rot, leafCls[i % leafCls.length]));
    });
    return svg(`
      <ellipse cx="58" cy="106" rx="52" ry="7" fill="#000" opacity="0.2"/>
      <!-- tiny twigs only at soil line -->
      <path d="M44 100 C46 96 48 94 50 92" fill="none" stroke="#4a3424" stroke-width="1.8" stroke-linecap="round"/>
      <path d="M70 100 C68 96 66 94 64 92" fill="none" stroke="#3d2c1e" stroke-width="1.6" stroke-linecap="round"/>
      <g class="bush-foliage">${body.join("")}</g>
      ${glint}
    `);
  }

  /** Side-profile baby kit — round potato facing right. */
  function baby(genes, smiling = false) {
    const color = formFur("baby", "", genes);
    const belly = lighten(color, 0.18);
    return svg(`
      <ellipse cx="62" cy="102" rx="22" ry="5" fill="#000" opacity="0.2"/>
      <path d="M40 72 Q28 68 26 78 Q30 86 42 80" fill="${color}"/>
      ${sideLegs(78, 72, 48, 16, 3.8)}
      <ellipse class="body" cx="58" cy="72" rx="22" ry="14" fill="${color}"/>
      <ellipse cx="62" cy="76" rx="12" ry="8" fill="${belly}" opacity="0.55"/>
      <ellipse class="head" cx="78" cy="62" rx="13" ry="12" fill="${lighten(color, 0.04)}"/>
      <ellipse cx="88" cy="64" rx="5" ry="3.5" fill="#c9a292"/>
      <ellipse cx="74" cy="52" rx="5" ry="7" fill="#4a4a54"/>
      <ellipse cx="74" cy="52" rx="2.5" ry="4" fill="#e2cdb2"/>
      <ellipse cx="78" cy="64" rx="9" ry="6" fill="#2a2a32"/>
      ${sideEye(82, 63, 2.4, smiling)}
    `);
  }

  function young(genes, form, smiling = false) {
    const color = formFur("young", form, genes);
    const belly = lighten(color, 0.2);
    let bodyRx = 26;
    let bodyRy = 15;
    let bodyY = 66;
    let headX = 84;
    let headR = 14;
    let legH = 22;
    let frontX = 74;
    let backX = 46;
    let accent = "";
    let tail = ringedTail(38, 68, 22, form !== "puff");

    if (form === "puff") {
      bodyRx = 28;
      bodyRy = 20;
      bodyY = 64;
      legH = 14;
      headR = 15;
      tail = `
        <ellipse cx="34" cy="70" rx="10" ry="8" fill="${lighten(color, 0.08)}"/>
        <ellipse cx="30" cy="68" rx="6" ry="5" fill="${lighten(color, 0.18)}"/>
      `;
      accent = `
        <ellipse cx="78" cy="50" rx="6" ry="5" fill="${lighten(color, 0.15)}" opacity="0.8"/>
        <ellipse cx="70" cy="48" rx="5" ry="4" fill="${lighten(color, 0.12)}" opacity="0.7"/>
        <ellipse cx="62" cy="72" rx="14" ry="9" fill="${belly}" opacity="0.65"/>
      `;
    } else if (form === "looper") {
      bodyRx = 24;
      bodyRy = 11;
      bodyY = 58;
      legH = 34;
      headX = 86;
      headR = 12;
      frontX = 76;
      backX = 44;
      accent = `
        <path d="M50 52 Q62 46 74 52" fill="none" stroke="#e0a04a" stroke-width="2.2" stroke-linecap="round" opacity="0.7"/>
        <ellipse cx="64" cy="62" rx="10" ry="5" fill="${belly}" opacity="0.4"/>
      `;
    } else if (form === "shadow") {
      bodyRx = 28;
      bodyRy = 12;
      bodyY = 70;
      legH = 20;
      headX = 88;
      accent = `
        <ellipse cx="88" cy="68" rx="14" ry="9" fill="#121218"/>
        <path d="M40 62 L70 58" stroke="#1a1a22" stroke-width="6" stroke-linecap="round" opacity="0.55"/>
      `;
      tail = ringedTail(36, 72, 28, true);
    } else if (form === "nub") {
      bodyRx = 20;
      bodyRy = 14;
      bodyY = 68;
      headX = 80;
      headR = 16;
      legH = 16;
      frontX = 70;
      backX = 48;
      tail = `<ellipse cx="40" cy="72" rx="5" ry="4" fill="${lighten(color, -0.05)}"/>`;
      accent = `
        <path d="M72 54 L76 46 L80 54" fill="#4a4a54"/>
        <path d="M66 56 L68 50 L72 56" fill="#4a4a54"/>
        <ellipse cx="78" cy="78" rx="6" ry="3" fill="#3a3a44"/>
        <path d="M84 74 Q88 78 84 80" fill="none" stroke="${lighten(color, -0.1)}" stroke-width="2"/>
      `;
    }

    const ear =
      form === "nub"
        ? ""
        : `<ellipse cx="${headX - 4}" cy="${bodyY - headR - 2}" rx="5" ry="8" fill="#4a4a54"/>
           <ellipse cx="${headX - 4}" cy="${bodyY - headR - 2}" rx="2.5" ry="4.5" fill="#e2cdb2"/>`;

    const snoutFill = form === "shadow" ? "#1c1c22" : "#c9a292";
    const eyeGleam = form === "shadow" ? "#d0d8e8" : "#faf6ec";

    return svg(`
      <ellipse cx="62" cy="104" rx="28" ry="6" fill="#000" opacity="0.2"/>
      ${tail}
      ${sideLegs(bodyY + 8, frontX, backX, legH, form === "looper" ? 4 : 4.5)}
      <ellipse class="body" cx="60" cy="${bodyY}" rx="${bodyRx}" ry="${bodyRy}" fill="${color}"/>
      ${accent}
      <ellipse class="head" cx="${headX}" cy="${bodyY - 4}" rx="${headR}" ry="${headR * 0.92}" fill="${lighten(color, 0.05)}"/>
      ${ear}
      <ellipse cx="${headX + 8}" cy="${bodyY - 2}" rx="6" ry="4" fill="${snoutFill}"/>
      <ellipse cx="${headX}" cy="${bodyY - 2}" rx="${headR * 0.75}" ry="${headR * 0.55}" fill="${
      form === "shadow" ? "#121218" : "#2a2a32"
    }" opacity="${form === "shadow" ? 0.95 : 0.85}"/>
      ${sideEye(headX + 2, bodyY - 4, form === "shadow" ? 3.2 : 2.8, smiling, eyeGleam)}
    `);
  }

  function teen(genes, form, smiling = false) {
    const color = formFur("teen", form, genes);
    const belly = lighten(color, 0.18);
    let bodyRx = 30;
    let bodyRy = 16;
    let bodyY = 62;
    let headX = 88;
    let headR = 15;
    let legH = 26;
    let frontX = 78;
    let backX = 44;
    let accent = "";
    let tail = ringedTail(34, 64, 26, true);

    if (form === "dumpling") {
      bodyRx = 34;
      bodyRy = 24;
      bodyY = 64;
      legH = 12;
      headR = 14;
      accent = `
        <ellipse cx="64" cy="72" rx="18" ry="12" fill="${belly}" opacity="0.7"/>
        <path d="M82 58 Q88 62 82 64" fill="none" stroke="#faf6ec" stroke-width="1.6" opacity="0.5"/>
      `;
      tail = `<ellipse cx="32" cy="68" rx="9" ry="7" fill="${lighten(color, 0.05)}"/>`;
    } else if (form === "bounder") {
      bodyRx = 26;
      bodyRy = 13;
      bodyY = 54;
      legH = 38;
      backX = 42;
      frontX = 76;
      accent = `
        <ellipse cx="48" cy="58" rx="8" ry="14" fill="${lighten(color, -0.05)}" opacity="0.35"/>
        <path d="M70 48 L78 40" stroke="#e0a04a" stroke-width="2" stroke-linecap="round" opacity="0.65"/>
      `;
    } else if (form === "nightlane") {
      bodyRx = 34;
      bodyRy = 11;
      bodyY = 66;
      legH = 24;
      headX = 94;
      headR = 13;
      accent = `
        <ellipse cx="70" cy="62" rx="20" ry="6" fill="#101018" opacity="0.45"/>
        <circle cx="96" cy="64" r="2" fill="#c8d8f0" opacity="0.85"/>
      `;
      tail = ringedTail(30, 68, 34, true);
    } else if (form === "scruff") {
      bodyRx = 28;
      bodyRy = 15;
      bodyY = 64;
      legH = 24;
      accent = `
        <path d="M48 50 L52 42 L56 50 L60 44 L64 52 L70 46 L74 54" fill="none" stroke="${lighten(
          color,
          -0.12
        )}" stroke-width="3" stroke-linecap="round"/>
        <path d="M84 48 L90 40" stroke="#4a4a54" stroke-width="3" stroke-linecap="round"/>
        <path d="M78 50 L80 44" stroke="#4a4a54" stroke-width="2.5" stroke-linecap="round"/>
        <path d="M86 68 L94 70" stroke="#8a5a4a" stroke-width="2" opacity="0.7"/>
      `;
    }

    const earY = bodyY - headR - 2;
    const eye =
      form === "dumpling" && !smiling
        ? `<path d="M${headX - 2} ${bodyY - 2} Q${headX + 2} ${bodyY - 5} ${headX + 6} ${
            bodyY - 2
          }" fill="none" stroke="#faf6ec" stroke-width="2" stroke-linecap="round"/>`
        : sideEye(headX + 2, bodyY - 3, form === "nightlane" ? 3.4 : 3, smiling, form === "nightlane" ? "#d8e4f8" : "#faf6ec");

    return svg(`
      <ellipse cx="64" cy="106" rx="32" ry="6" fill="#000" opacity="0.22"/>
      ${tail}
      ${sideLegs(bodyY + 10, frontX, backX, legH, form === "bounder" ? 5.2 : 4.8)}
      <ellipse class="body" cx="62" cy="${bodyY}" rx="${bodyRx}" ry="${bodyRy}" fill="${color}"/>
      ${accent}
      <ellipse class="head" cx="${headX}" cy="${bodyY - 2}" rx="${headR}" ry="${headR * 0.9}" fill="${lighten(
      color,
      0.04
    )}"/>
      <ellipse cx="${headX - 3}" cy="${earY}" rx="5.5" ry="9" fill="#4a4a54"/>
      <ellipse cx="${headX - 3}" cy="${earY}" rx="2.8" ry="5" fill="#e2cdb2"/>
      <ellipse cx="${headX + 9}" cy="${bodyY}" rx="7" ry="4.5" fill="${
      form === "nightlane" ? "#1a1a24" : "#c9a292"
    }"/>
      <ellipse cx="${headX}" cy="${bodyY}" rx="${headR * 0.72}" ry="${headR * 0.5}" fill="${
      form === "nightlane" ? "#0e1018" : "#2a2a32"
    }" opacity="0.9"/>
      ${eye}
    `);
  }

  function adult(genes, form, smiling = false) {
    // Short-spine Jimothy in profile: fused head/body potato + long stilts, facing right.
    const color = formFur("adult", form, genes);
    const belly = lighten(color, 0.16);
    let bodyRx = 34;
    let bodyRy = 28;
    let bodyY = 52;
    let legH = 42;
    let frontX = 78;
    let backX = 42;
    let accent = "";
    let mist = "";
    let snout = "#c9a292";
    let eyeGleam = "#faf6ec";
    let earExtra = "";

    if (form === "saint") {
      bodyRy = 30;
      accent = `
        <ellipse cx="64" cy="60" rx="14" ry="10" fill="${belly}" opacity="0.45"/>
        <ellipse cx="86" cy="30" rx="8" ry="5" fill="#6fbf84" transform="rotate(-18 86 30)"/>
        <ellipse cx="78" cy="28" rx="4" ry="3" fill="#548a62" opacity="0.7"/>
        <circle cx="70" cy="34" r="1.6" fill="#b8e0c0" opacity="0.7"/>
        <circle cx="96" cy="40" r="1.3" fill="#b8e0c0" opacity="0.55"/>
      `;
      earExtra = `<ellipse cx="78" cy="26" rx="6" ry="10" fill="#4a4a54"/><ellipse cx="78" cy="26" rx="3" ry="5.5" fill="#e2cdb2"/>`;
    } else if (form === "legend") {
      bodyRx = 32;
      bodyRy = 26;
      legH = 46;
      accent = `
        <path d="M72 40 L98 48 L74 56 Z" fill="#e0a04a"/>
        <ellipse cx="58" cy="48" rx="8" ry="12" fill="${lighten(color, -0.08)}" opacity="0.35"/>
        <path d="M88 44 L102 50" stroke="#f0c57a" stroke-width="2.5" stroke-linecap="round"/>
      `;
      eyeGleam = "#fff3d0";
      earExtra = `<ellipse cx="76" cy="24" rx="7" ry="12" fill="#4a4a54"/><ellipse cx="76" cy="24" rx="3.2" ry="6" fill="#e2cdb2"/>`;
    } else if (form === "alley_ghost") {
      bodyRx = 36;
      bodyRy = 24;
      legH = 44;
      snout = "#b8c4d4";
      eyeGleam = "#e8f0ff";
      mist = `
        <ellipse cx="36" cy="56" rx="10" ry="6" fill="rgba(200,220,240,0.28)"/>
        <ellipse cx="28" cy="48" rx="7" ry="4" fill="rgba(200,220,240,0.2)"/>
        <ellipse cx="100" cy="58" rx="8" ry="5" fill="rgba(200,220,240,0.22)"/>
      `;
      accent = `
        <ellipse cx="86" cy="50" rx="16" ry="12" fill="rgba(230,240,255,0.18)"/>
      `;
      earExtra = `<ellipse cx="78" cy="26" rx="5.5" ry="11" fill="#6a7380"/><ellipse cx="78" cy="26" rx="2.6" ry="5.5" fill="#d0d8e0"/>`;
    } else if (form === "ballard_blip") {
      bodyRx = 33;
      bodyRy = 27;
      legH = 40;
      accent = `
        <path d="M70 58 Q86 70 98 58" fill="none" stroke="#c45c4a" stroke-width="4" stroke-linecap="round"/>
        <ellipse cx="64" cy="62" rx="12" ry="8" fill="rgba(224,160,74,0.35)"/>
        <ellipse cx="84" cy="74" rx="7" ry="4" fill="#3a3a44"/>
      `;
      earExtra = `
        <path d="M74 18 L80 32 L70 30 Z" fill="#4a4a54"/>
        <path d="M78 20 L79 26" stroke="#e2cdb2" stroke-width="2"/>
        <path d="M82 24 L88 20" stroke="#4a4a54" stroke-width="2" stroke-linecap="round"/>
      `;
    } else {
      earExtra = `<ellipse cx="78" cy="26" rx="6" ry="11" fill="#4a4a54"/><ellipse cx="78" cy="26" rx="3" ry="5.5" fill="#e2cdb2"/>`;
    }

    const whisk = `
      <path d="M92 50 h10 M92 54 h8 M92 58 h9" stroke="#d0d0d8" stroke-width="1.2" stroke-linecap="round" opacity="0.55"/>
    `;

    return svg(`
      <ellipse cx="64" cy="110" rx="36" ry="7" fill="#000" opacity="0.22"/>
      ${mist}
      ${ringedTail(30, 54, 28, form !== "alley_ghost")}
      ${form === "alley_ghost" ? `<path d="M34 54 Q18 40 12 52" fill="none" stroke="#a8b4c4" stroke-width="7" stroke-linecap="round" opacity="0.7"/>` : ""}
      ${sideLegs(bodyY + 14, frontX, backX, legH, 6)}
      <ellipse class="body" cx="64" cy="${bodyY}" rx="${bodyRx}" ry="${bodyRy}" fill="${color}"/>
      ${accent}
      ${earExtra}
      <ellipse cx="90" cy="${bodyY + 2}" rx="9" ry="6" fill="${snout}"/>
      <ellipse cx="78" cy="${bodyY}" rx="18" ry="12" fill="${
      form === "alley_ghost" ? "#3a4250" : "#1c1c22"
    }" opacity="0.88"/>
      ${sideEye(84, bodyY - 2, 4.2, smiling, eyeGleam)}
      ${whisk}
      <path d="M40 56 h-8 M40 60 h-7" stroke="#d0d0d8" stroke-width="1.2" stroke-linecap="round" opacity="0.4"/>
    `);
  }

  function frontLegs(hipY, spacing, legH, strokeW = 4.5) {
    const foot = "#3a3a44";
    const leg = "#4f4f58";
    const lx = 60 - spacing;
    const rx = 60 + spacing;
    return `
      <g class="legs front-legs">
        <path d="M${lx} ${hipY} L${lx - 2} ${hipY + legH}" stroke="${leg}" stroke-width="${strokeW}" stroke-linecap="round"/>
        <path d="M${rx} ${hipY} L${rx + 2} ${hipY + legH}" stroke="${leg}" stroke-width="${strokeW}" stroke-linecap="round"/>
        <ellipse cx="${lx - 2}" cy="${hipY + legH}" rx="6" ry="3.2" fill="${foot}"/>
        <ellipse cx="${rx + 2}" cy="${hipY + legH}" rx="6" ry="3.2" fill="${foot}"/>
      </g>
    `;
  }

  function frontEyes(cx, cy, r, smiling, gleam = "#faf6ec") {
    const gap = r * 2.2;
    if (smiling) {
      return `
        <path d="M${cx - gap - r} ${cy} Q${cx - gap} ${cy - r} ${cx - gap + r} ${cy}" fill="none" stroke="${gleam}" stroke-width="2" stroke-linecap="round"/>
        <path d="M${cx + gap - r} ${cy} Q${cx + gap} ${cy - r} ${cx + gap + r} ${cy}" fill="none" stroke="${gleam}" stroke-width="2" stroke-linecap="round"/>
      `;
    }
    return `
      <circle cx="${cx - gap}" cy="${cy}" r="${r}" fill="${gleam}"/>
      <circle cx="${cx - gap + r * 0.2}" cy="${cy}" r="${r * 0.42}" fill="#101014"/>
      <circle cx="${cx + gap}" cy="${cy}" r="${r}" fill="${gleam}"/>
      <circle cx="${cx + gap + r * 0.2}" cy="${cy}" r="${r * 0.42}" fill="#101014"/>
    `;
  }

  /** Front-facing Jimothy — looks at the player / screen. */
  function frontCreature(stage, form, genes, smiling = false) {
    const color = formFur(stage, form || "", genes);
    const belly = lighten(color, 0.2);
    let bodyRx = 28;
    let bodyRy = 24;
    let bodyY = 58;
    let headR = 20;
    let headY = 42;
    let legH = 28;
    let legSpread = 14;
    let strokeW = 4.5;
    let earY = 24;
    let earRx = 7;
    let earRy = 11;
    let snout = "#c9a292";
    let mask = "#1c1c22";
    let gleam = "#faf6ec";
    let accent = "";
    let mist = "";

    if (stage === "baby") {
      bodyRx = 20;
      bodyRy = 16;
      bodyY = 68;
      headR = 16;
      headY = 54;
      legH = 16;
      legSpread = 10;
      strokeW = 3.6;
      earY = 40;
      earRx = 5;
      earRy = 8;
    } else if (stage === "young") {
      bodyRx = 24;
      bodyRy = 20;
      bodyY = 62;
      headR = 18;
      headY = 46;
      legH = 22;
      legSpread = 12;
      earY = 30;
      if (form === "puff") {
        bodyRx = 26;
        bodyRy = 22;
        accent = `<ellipse cx="60" cy="66" rx="12" ry="8" fill="${belly}" opacity="0.55"/>`;
      } else if (form === "shadow") {
        mask = "#0e1018";
        gleam = "#e8f0ff";
      } else if (form === "looper") {
        accent = `<ellipse cx="42" cy="58" rx="6" ry="4" fill="${lighten(color, 0.1)}" opacity="0.5"/>`;
      } else if (form === "nub") {
        legH = 16;
      }
    } else if (stage === "teen") {
      bodyRx = 27;
      bodyRy = 22;
      bodyY = 60;
      headR = 19;
      headY = 44;
      legH = 30;
      if (form === "dumpling") {
        bodyRx = 30;
        bodyRy = 24;
      } else if (form === "bounder") {
        legH = 34;
      } else if (form === "nightlane") {
        mask = "#0e1018";
        snout = "#1a1a24";
        gleam = "#e8f0ff";
      } else if (form === "scruff") {
        accent = `<path d="M48 36 L52 28 M68 36 L72 28" stroke="#4a4a54" stroke-width="2" stroke-linecap="round"/>`;
      }
    } else {
      // adult
      bodyRx = 32;
      bodyRy = 26;
      bodyY = 56;
      headR = 22;
      headY = 40;
      legH = 38;
      legSpread = 16;
      strokeW = 5.5;
      earY = 20;
      earRx = 7.5;
      earRy = 12;
      if (form === "saint") {
        accent = `
          <ellipse cx="60" cy="62" rx="12" ry="8" fill="${belly}" opacity="0.4"/>
          <circle cx="48" cy="34" r="1.5" fill="#b8e0c0" opacity="0.65"/>
          <circle cx="74" cy="36" r="1.2" fill="#b8e0c0" opacity="0.5"/>
        `;
      } else if (form === "legend") {
        accent = `<path d="M52 48 L70 54 L54 60 Z" fill="#e0a04a"/>`;
        gleam = "#fff3d0";
      } else if (form === "alley_ghost") {
        snout = "#b8c4d4";
        mask = "#3a4250";
        gleam = "#e8f0ff";
        mist = `
          <ellipse cx="34" cy="58" rx="8" ry="5" fill="rgba(200,220,240,0.25)"/>
          <ellipse cx="88" cy="60" rx="7" ry="4" fill="rgba(200,220,240,0.2)"/>
        `;
      } else if (form === "ballard_blip") {
        accent = `<path d="M48 66 Q60 74 72 66" fill="none" stroke="#c45c4a" stroke-width="3.5" stroke-linecap="round"/>`;
      }
    }

    const formId =
      stage === "young" ? form : stage === "teen" ? form : stage === "adult" ? form : "";
    const tailPeek =
      stage === "baby"
        ? `<ellipse cx="34" cy="70" rx="7" ry="5" fill="${lighten(color, 0.05)}"/>`
        : `<path d="M28 58 Q18 50 16 62" fill="none" stroke="#5a5a64" stroke-width="7" stroke-linecap="round"/>
           <ellipse cx="20" cy="54" rx="3.5" ry="2.8" fill="#c8c8d0" opacity="0.7"/>`;

    return svg(`
      <ellipse cx="60" cy="108" rx="30" ry="6" fill="#000" opacity="0.2"/>
      ${mist}
      ${tailPeek}
      ${frontLegs(bodyY + 12, legSpread, legH, strokeW)}
      <ellipse class="body" cx="60" cy="${bodyY}" rx="${bodyRx}" ry="${bodyRy}" fill="${color}"/>
      <ellipse cx="60" cy="${bodyY + 4}" rx="${bodyRx * 0.55}" ry="${bodyRy * 0.45}" fill="${belly}" opacity="0.45"/>
      ${accent}
      <ellipse class="head" cx="60" cy="${headY}" rx="${headR}" ry="${headR * 0.95}" fill="${lighten(color, 0.04)}"/>
      <ellipse cx="50" cy="${earY}" rx="${earRx}" ry="${earRy}" fill="#4a4a54"/>
      <ellipse cx="50" cy="${earY}" rx="${earRx * 0.45}" ry="${earRy * 0.55}" fill="#e2cdb2"/>
      <ellipse cx="70" cy="${earY}" rx="${earRx}" ry="${earRy}" fill="#4a4a54"/>
      <ellipse cx="70" cy="${earY}" rx="${earRx * 0.45}" ry="${earRy * 0.55}" fill="#e2cdb2"/>
      <ellipse cx="60" cy="${headY + 2}" rx="${headR * 0.72}" ry="${headR * 0.42}" fill="${mask}" opacity="0.9"/>
      ${frontEyes(60, headY + 1, stage === "baby" ? 2.6 : stage === "adult" ? 3.6 : 3.1, smiling, gleam)}
      <ellipse cx="60" cy="${headY + headR * 0.42}" rx="${headR * 0.28}" ry="${headR * 0.18}" fill="${snout}"/>
      <circle cx="60" cy="${headY + headR * 0.32}" r="1.6" fill="#2a2a32"/>
      <path d="M42 ${headY + 4} h-8 M42 ${headY + 8} h-6 M78 ${headY + 4} h8 M78 ${headY + 8} h6"
        stroke="#d0d0d8" stroke-width="1.1" stroke-linecap="round" opacity="0.45"/>
    `.replace("FORM", formId || ""));
  }

  const icons = {
    feed: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M7 3v10a3 3 0 006 0V3" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M10 16v5M7 21h6" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M16 4c2 2 3 4 3 7v10" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`,
    play: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3" y="7" width="18" height="12" rx="3" stroke="currentColor" stroke-width="2"/><circle cx="8" cy="13" r="1.5" fill="currentColor"/><circle cx="16" cy="13" r="1.5" fill="currentColor"/><path d="M9 7V5h6v2" stroke="currentColor" stroke-width="2"/></svg>`,
    scold: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 14V8a4 4 0 018 0v6" stroke="currentColor" stroke-width="2"/><path d="M2 14h12v2a4 4 0 01-4 4H6a4 4 0 01-4-4v-2z" stroke="currentColor" stroke-width="2"/><path d="M16 8c2 1.5 3 3.5 3 6M19 6c2.5 2 4 5 4 8" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`,
    clean: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 3v6M8 5l8 4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M7 11h10l-1.5 9h-7L7 11z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/></svg>`,
    heal: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2"/></svg>`,
    berries: `<svg viewBox="0 0 32 32" aria-hidden="true"><circle cx="12" cy="18" r="6" fill="#5a4a8a"/><circle cx="20" cy="16" r="6" fill="#6b5aa0"/><circle cx="16" cy="22" r="5.5" fill="#4a3a72"/><path d="M16 8c0 4-2 6-4 7" stroke="#3d6b4f" stroke-width="2" fill="none"/><ellipse cx="18" cy="8" rx="4" ry="2" fill="#6fbf84"/></svg>`,
    crickets: `<svg viewBox="0 0 32 32" aria-hidden="true"><ellipse cx="16" cy="18" rx="10" ry="5" fill="#6fbf84"/><ellipse cx="22" cy="16" rx="4" ry="3" fill="#548a62"/><path d="M8 16c-3-4-4-8-2-10M10 20c-4 2-6 6-4 8M24 14c3-3 5-2 6 0" stroke="#3d6b4f" stroke-width="1.6" fill="none" stroke-linecap="round"/><circle cx="24" cy="15" r="1.2" fill="#1b2a22"/></svg>`,
    fish: `<svg viewBox="0 0 32 32" aria-hidden="true"><path d="M6 16c6-8 14-8 20 0-6 8-14 8-20 0z" fill="#7ec8d4"/><path d="M26 16l4-5v10l-4-5z" fill="#5a9eb0"/><circle cx="11" cy="15" r="1.5" fill="#1b2a22"/><path d="M8 12c2 1 3 3 2 5" stroke="#eef5ea" stroke-width="1.2" fill="none"/></svg>`,
    pizza: `<svg viewBox="0 0 32 32" aria-hidden="true"><path d="M7 8l9 20 9-20z" fill="#8a4a28"/><path d="M8 9l8 18 8-18z" fill="#e0a04a"/><path d="M9 12h14" stroke="#c45c4a" stroke-width="3" stroke-linecap="round"/><circle cx="13" cy="18" r="2.2" fill="#8a2f2f"/><circle cx="18" cy="22" r="1.8" fill="#8a2f2f"/><circle cx="16" cy="15" r="1.4" fill="#8a2f2f"/><path d="M14 10l3 4 1-3" fill="rgba(255,255,255,0.35)"/></svg>`,
    fries: `<svg viewBox="0 0 32 32" aria-hidden="true"><path d="M8 16h16l-2.5 13H10.5L8 16z" fill="#c45c4a"/><path d="M9 16h14l-1 4H10z" fill="#d46a56"/><rect x="11" y="22" width="10" height="2.5" rx="1" fill="#f0c57a"/><rect x="12" y="25.5" width="8" height="1.5" rx="0.7" fill="#f0c57a" opacity="0.7"/><rect x="10" y="5" width="3" height="13" rx="1.2" fill="#e0a04a"/><rect x="14.5" y="3" width="3.2" height="15" rx="1.2" fill="#f0c57a"/><rect x="19" y="6" width="2.8" height="12" rx="1.2" fill="#d4923a"/><rect x="11" y="5" width="1" height="11" fill="rgba(255,255,255,0.35)"/></svg>`,
  };

  function render(profile = {}) {
    const stage = profile.stage || "bush";
    const genes = profile.genes || {};
    const smiling = !!profile.smiling;
    const view = profile.view || "side";
    if (stage === "bush") return bush(profile.ageSec || 0);
    if (view === "front") {
      const form =
        stage === "young"
          ? profile.youngForm || "puff"
          : stage === "teen"
            ? profile.teenForm || "bounder"
            : stage === "adult"
              ? profile.adultForm || "saint"
              : "";
      return frontCreature(stage, form, genes, smiling);
    }
    switch (stage) {
      case "baby":
        return baby(genes, smiling);
      case "young":
        return young(genes, profile.youngForm || "puff", smiling);
      case "teen":
        return teen(genes, profile.teenForm || "bounder", smiling);
      case "adult":
        return adult(genes, profile.adultForm || "saint", smiling);
      default:
        return bush(0);
    }
  }

  return { render, icons };
})();
window.RaccoonArt = RaccoonArt;

/**
 * Pose / locomotion — side walks + front-facing idle; facing changes are gated.
 */
const RaccoonAnim = (() => {
  const SIDE_ANIMS = new Set(["walk", "run", "lope", "jump", "hop", "sniff"]);

  let wrap = null;
  let raccoon = null;
  let stage = "bush";
  let ageSec = 0;
  let alive = true;

  let t = 0;
  let poseX = 0;
  let poseY = 0;
  let facing = 1;
  let desiredFacing = 1;
  let faceCooldown = 0;
  let anim = "idle";
  let animT = 0;
  let animDur = 1.2;
  let walkPhase = 0;
  let jumpPeak = 0;
  let targetX = 0;
  let speed = 0;
  let headDip = 0;
  let eatFood = "berries";
  let foodEl = null;

  function init(wrapEl, raccoonEl) {
    wrap = wrapEl;
    raccoon = raccoonEl;
  }

  function getView() {
    if (stage === "bush") return "front";
    if (SIDE_ANIMS.has(anim)) return "side";
    return "front";
  }

  function requestFacing(dir) {
    if (!dir) return;
    desiredFacing = dir < 0 ? -1 : 1;
  }

  function commitFacing(dt) {
    faceCooldown = Math.max(0, faceCooldown - dt);
    if (getView() !== "side") return;
    if (desiredFacing === facing) return;
    if (faceCooldown > 0) return;
    facing = desiredFacing;
    faceCooldown = 0.42;
  }

  function reset() {
    poseX = 0;
    poseY = 0;
    facing = 1;
    desiredFacing = 1;
    faceCooldown = 0;
    anim = "idle";
    animT = 0;
    animDur = 1.2;
    walkPhase = 0;
    speed = 0;
    headDip = 0;
    if (wrap) {
      wrap.style.opacity = "1";
      wrap.classList.remove("ascending");
      wrap.classList.add("is-bush");
      const wings = wrap.querySelector(".ascend-wings");
      if (wings) wings.remove();
      clearFoodProp();
    }
    applyTransform();
  }

  function clearFoodProp() {
    if (foodEl) {
      foodEl.remove();
      foodEl = null;
    }
  }

  function ensureFoodProp(kind) {
    if (!wrap) return null;
    clearFoodProp();
    foodEl = document.createElement("div");
    foodEl.className = "eat-food";
    foodEl.dataset.food = kind || "berries";
    const key = kind || "berries";
    const icon =
      window.RaccoonArt && RaccoonArt.icons && RaccoonArt.icons[key]
        ? RaccoonArt.icons[key]
        : "";
    foodEl.innerHTML = icon
      ? `<div class="eat-food-art">${icon}</div>`
      : key === "pizza"
        ? `<span class="crumb crust"></span>`
        : key === "fries"
          ? `<span class="crumb fries"></span><span class="crumb fry f1"></span><span class="crumb fry f2"></span><span class="crumb fry f3"></span>`
          : key === "fish"
            ? `<span class="crumb fish"></span>`
            : key === "crickets"
              ? `<span class="crumb bug"></span>`
              : `<span class="crumb berry"></span><span class="crumb berry b2"></span>`;
    wrap.appendChild(foodEl);
    return foodEl;
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
      wrap.dataset.view = getView();
      wrap.dataset.facing = getView() === "front" ? "front" : facing < 0 ? "left" : "right";
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

  function play(kind, opts = {}) {
    // Don't let ambient walks cut off a slow eat / ascent.
    if (
      ["eat", "ascend"].includes(anim) &&
      ["walk", "run", "lope", "jump", "sniff", "stretch", "idle", "stubborn", "sick"].includes(kind)
    ) {
      return;
    }
    anim = kind || "idle";
    animT = 0;
    if (!wrap) return;
    wrap.dataset.anim = anim;

    switch (kind) {
      case "ascend":
        animDur = 4.2;
        ensureWings();
        wrap.classList.add("ascending");
        clearFoodProp();
        break;
      case "run":
        animDur = 1.6 + Math.random() * 1.2;
        speed = 100 + Math.random() * 55;
        targetX = -78 + Math.random() * 156;
        requestFacing(Math.sign(targetX - poseX) || (Math.random() < 0.5 ? -1 : 1));
        faceCooldown = 0;
        facing = desiredFacing;
        break;
      case "walk":
      case "lope":
        animDur = 2.2 + Math.random() * 1.6;
        speed = kind === "walk" ? 40 + Math.random() * 40 : 60 + Math.random() * 45;
        targetX = -78 + Math.random() * 156;
        requestFacing(Math.sign(targetX - poseX) || (Math.random() < 0.5 ? -1 : 1));
        faceCooldown = 0;
        facing = desiredFacing;
        break;
      case "jump":
        animDur = 0.55 + Math.random() * 0.35;
        jumpPeak = 18 + Math.random() * 18;
        requestFacing(Math.random() < 0.5 ? -1 : 1);
        faceCooldown = 0;
        facing = desiredFacing;
        targetX = Math.max(-78, Math.min(78, poseX + facing * (28 + Math.random() * 36)));
        break;
      case "pop":
        animDur = 0.85;
        break;
      case "stretch":
        animDur = 1.05;
        break;
      case "eat":
        animDur = 2.6;
        eatFood = opts.food || eatFood || "berries";
        ensureFoodProp(eatFood);
        break;
      case "sniff":
        animDur = 1;
        break;
      case "smile":
      case "happy":
        animDur = 0.95;
        break;
      case "sad":
        animDur = 1.35;
        break;
      case "hop":
        animDur = 0.7;
        jumpPeak = 22 + Math.random() * 12;
        requestFacing(Math.random() < 0.5 ? -1 : 1);
        faceCooldown = 0;
        facing = desiredFacing;
        targetX = Math.max(-70, Math.min(70, poseX + facing * (16 + Math.random() * 24)));
        break;
      case "nuzzle":
      case "heal":
        animDur = 1.05;
        break;
      case "spin":
        animDur = 0.85;
        break;
      case "rustle":
        animDur = 1.15;
        break;
      case "refuse":
        animDur = 0.95;
        break;
      case "scold":
        animDur = 0.9;
        break;
      case "stubborn":
      case "sick":
        animDur = 1.1;
        break;
      default:
        animDur = 1 + Math.random();
        speed = 0;
    }
  }

  function applyTransform() {
    if (!wrap) return;
    const view = getView();
    // Side art faces right; flip only while in side-view travel.
    const scaleX = view === "side" && facing < 0 ? -1 : 1;
    wrap.style.transform = `translate(${poseX}px, ${poseY + headDip * 0.35}px) scaleX(${scaleX})`;
    wrap.dataset.anim = anim;
    wrap.dataset.view = view;
    wrap.dataset.facing = view === "front" ? "front" : facing < 0 ? "left" : "right";
    wrap.style.setProperty("--head-dip", String(headDip));
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
      const amp = anim === "rustle" ? 9 + Math.sin(animT * 34) * 3.5 : 4.2;
      poseX = Math.sin(t * 11) * amp + Math.sin(t * 4.1) * (amp * 0.85) + Math.sin(t * 17) * (amp * 0.22);
      poseY = Math.sin(t * 8.2) * (amp * 0.8) + Math.cos(t * 13) * (amp * 0.25);
      facing = 1;
      wrap.classList.add("is-bush");
      wrap.classList.toggle("is-rustling", anim === "rustle");
      if (anim === "rustle" && animT >= animDur) anim = "idle";
      applyTransform();
      return;
    }

    wrap.classList.remove("is-bush");

    switch (anim) {
      case "walk":
      case "run":
      case "lope": {
        const dir = Math.sign(targetX - poseX) || facing;
        requestFacing(dir);
        const step = speed * dt;
        if (Math.abs(targetX - poseX) <= step) poseX = targetX;
        else poseX += dir * step;
        walkPhase += dt * (speed * 0.12);
        poseY = Math.abs(Math.sin(walkPhase)) * (anim === "walk" ? 3 : 5.5);
        if (Math.abs(poseX - targetX) < 1.5 || animT >= animDur) {
          if (Math.random() < 0.55 && animT < animDur) {
            targetX = -78 + Math.random() * 156;
            requestFacing(Math.sign(targetX - poseX) || facing);
          } else {
            anim = "idle";
            poseY = 0;
          }
        }
        break;
      }
      case "jump":
      case "hop": {
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
        poseY = -Math.pow(u, 0.3) * 22;
        if (animT >= animDur) {
          anim = "idle";
          poseY = 0;
        }
        break;
      }
      case "stretch": {
        const u = Math.min(1, animT / animDur);
        poseY = -Math.sin(u * Math.PI) * 6;
        headDip = -Math.sin(u * Math.PI) * 4;
        walkPhase += dt * 4;
        if (animT >= animDur) {
          anim = "idle";
          poseY = 0;
          headDip = 0;
        }
        break;
      }
      case "eat": {
        const u = Math.min(1, animT / animDur);
        // Slow reach → long chew → settle so the food reads clearly.
        if (u < 0.28) {
          headDip = (u / 0.28) * 10;
          poseY = (u / 0.28) * 3;
        } else if (u < 0.82) {
          headDip = 8 + Math.sin(t * 10) * 2.2;
          poseY = 2 + Math.sin(t * 8) * 1.2;
          walkPhase += dt * 4.5;
        } else {
          const settle = (u - 0.82) / 0.18;
          headDip = 8 * (1 - settle);
          poseY = 2 * (1 - settle);
        }
        if (foodEl) {
          const reach = Math.min(1, u / 0.32);
          const fade = 1 - Math.max(0, (u - 0.62) / 0.32);
          foodEl.style.setProperty("--reach", String(reach));
          foodEl.style.opacity = String(Math.max(0, fade));
        }
        if (animT >= animDur) {
          anim = "idle";
          poseY = 0;
          headDip = 0;
          clearFoodProp();
        }
        break;
      }
      case "refuse": {
        // Head-shake without flipping art every frame (avoids glitch).
        poseX += Math.sin(t * 14) * 0.9;
        headDip = Math.sin(Math.min(1, animT / animDur) * Math.PI) * 4;
        if (animT >= animDur) {
          anim = "idle";
          headDip = 0;
        }
        break;
      }
      case "scold": {
        const u = Math.min(1, animT / animDur);
        poseY = Math.sin(u * Math.PI) * 2;
        headDip = 3 + Math.sin(t * 14) * 2;
        if (animT >= animDur) {
          anim = "idle";
          headDip = 0;
        }
        break;
      }
      case "sniff": {
        headDip = 6 + Math.sin(t * 10) * 2;
        poseY = Math.sin(t * 3) * 1;
        const sniffTarget = Math.sin(t * 0.7) * 28;
        const sniffDir = Math.sign(sniffTarget - poseX) || facing;
        requestFacing(sniffDir);
        poseX += sniffDir * Math.min(Math.abs(sniffTarget - poseX), 18 * dt);
        if (animT >= animDur) {
          anim = "idle";
          headDip = 0;
        }
        break;
      }
      case "smile":
      case "happy": {
        const u = Math.min(1, animT / animDur);
        poseY = Math.sin(u * Math.PI) * 3;
        headDip = -Math.sin(u * Math.PI) * 2;
        if (animT >= animDur) {
          anim = "idle";
          poseY = 0;
          headDip = 0;
        }
        break;
      }
      case "sad": {
        const u = Math.min(1, animT / animDur);
        headDip = 7 + Math.sin(u * Math.PI) * 3;
        poseY = Math.sin(t * 2.2) * 0.8;
        poseX += Math.sin(t * 3) * 0.25;
        if (animT >= animDur) {
          anim = "idle";
          headDip = 0;
        }
        break;
      }
      case "heal":
      case "nuzzle": {
        const u = Math.min(1, animT / animDur);
        poseX += Math.sin(t * 6) * 0.45;
        headDip = 4 + Math.sin(u * Math.PI) * 5;
        if (animT >= animDur) {
          anim = "idle";
          headDip = 0;
        }
        break;
      }
      case "spin": {
        const u = Math.min(1, animT / animDur);
        // One slow turn cue, not rapid left/right flips.
        if (u > 0.45 && u < 0.55) requestFacing(facing < 0 ? 1 : -1);
        poseY = -Math.sin(u * Math.PI) * 10;
        poseX += Math.sin(t * 10) * 0.6;
        if (animT >= animDur) {
          anim = "idle";
          poseY = 0;
        }
        break;
      }
      case "rustle": {
        if (animT >= animDur) anim = "idle";
        break;
      }
      case "stubborn":
      case "sick": {
        poseX += Math.sin(t * 10) * 0.35;
        headDip = 2;
        if (animT >= animDur) anim = "idle";
        break;
      }
      default: {
        // Idle: face the screen, gentle bob, settle toward center (no rapid flips).
        poseY = Math.sin(t * 2.4) * 2.2 + Math.sin(t * 5.1) * 0.6;
        poseX += (0 - poseX) * Math.min(1, dt * 1.35);
        headDip = Math.sin(t * 1.7) * 1.4;
        walkPhase += dt * 1.2;
        break;
      }
    }

    poseX = Math.max(-78, Math.min(78, poseX));
    commitFacing(dt);
    applyTransform();
  }

  function getAnim() {
    return anim;
  }

  function isBusy() {
    return ["eat", "ascend", "refuse", "pop"].includes(anim);
  }

  return { init, reset, sync, play, tick, getView, getAnim, isBusy };
})();
window.RaccoonAnim = RaccoonAnim;
