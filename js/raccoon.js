/**
 * SVG art for Jimothy across growth stages.
 */
const RaccoonArt = (() => {
  const svg = (body) =>
    `<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">${body}</svg>`;

  const egg = () =>
    svg(`
      <ellipse cx="60" cy="68" rx="28" ry="34" fill="#e8dcc0" stroke="#b9a888" stroke-width="3"/>
      <ellipse cx="52" cy="55" rx="8" ry="5" fill="#fff6e4" opacity="0.55"/>
      <path class="egg-crack" d="M52 42 L58 52 L54 58 L62 68" fill="none" stroke="#6b5a3e" stroke-width="2.5" stroke-linecap="round"/>
      <circle cx="60" cy="78" r="3" fill="#3a2a1c" opacity="0.35"/>
    `);

  const hatchling = () =>
    svg(`
      <ellipse cx="60" cy="92" rx="22" ry="6" fill="#000" opacity="0.18"/>
      <ellipse cx="60" cy="72" rx="26" ry="22" fill="#6b6b72"/>
      <circle cx="60" cy="48" r="20" fill="#75757d"/>
      <ellipse cx="45" cy="36" rx="7" ry="10" fill="#5c5c64"/>
      <ellipse cx="75" cy="36" rx="7" ry="10" fill="#5c5c64"/>
      <ellipse cx="45" cy="36" rx="4" ry="6" fill="#d9c4a8"/>
      <ellipse cx="75" cy="36" rx="4" ry="6" fill="#d9c4a8"/>
      <ellipse cx="60" cy="50" rx="16" ry="10" fill="#2a2a30"/>
      <circle cx="52" cy="48" r="3.2" fill="#f4f0e4"/>
      <circle cx="68" cy="48" r="3.2" fill="#f4f0e4"/>
      <circle cx="52.5" cy="48.5" r="1.5" fill="#1a1a1e"/>
      <circle cx="68.5" cy="48.5" r="1.5" fill="#1a1a1e"/>
      <ellipse cx="60" cy="56" rx="4" ry="2.5" fill="#c4a090"/>
      <path d="M42 70 Q36 78 40 86" fill="none" stroke="#5c5c64" stroke-width="5" stroke-linecap="round"/>
      <circle cx="78" cy="78" r="5" fill="#8a8a92"/>
    `);

  const kit = () =>
    svg(`
      <ellipse cx="60" cy="96" rx="28" ry="7" fill="#000" opacity="0.18"/>
      <path d="M88 78 Q104 70 100 88 Q92 96 82 90" fill="#6b6b72"/>
      <ellipse cx="60" cy="74" rx="32" ry="26" fill="#6f6f78"/>
      <circle cx="60" cy="44" r="24" fill="#7a7a84"/>
      <ellipse cx="40" cy="28" rx="9" ry="13" fill="#55555e"/>
      <ellipse cx="80" cy="28" rx="9" ry="13" fill="#55555e"/>
      <ellipse cx="40" cy="28" rx="5" ry="8" fill="#e2cdb2"/>
      <ellipse cx="80" cy="28" rx="5" ry="8" fill="#e2cdb2"/>
      <ellipse cx="60" cy="48" rx="20" ry="12" fill="#26262c"/>
      <circle cx="50" cy="45" r="4" fill="#f7f3e8"/>
      <circle cx="70" cy="45" r="4" fill="#f7f3e8"/>
      <circle cx="51" cy="45.5" r="2" fill="#151518"/>
      <circle cx="71" cy="45.5" r="2" fill="#151518"/>
      <ellipse cx="60" cy="54" rx="5.5" ry="3.5" fill="#c9a292"/>
      <path d="M56 58 Q60 62 64 58" fill="none" stroke="#2a2a30" stroke-width="1.5"/>
      <ellipse cx="42" cy="88" rx="8" ry="6" fill="#5c5c64"/>
      <ellipse cx="78" cy="88" rx="8" ry="6" fill="#5c5c64"/>
      <circle cx="88" cy="68" r="6" fill="#d9c4a8" opacity="0.35"/>
    `);

  // Teen starts rounding out — foreshadowing the short-spine legend.
  const teen = () =>
    svg(`
      <ellipse cx="60" cy="104" rx="30" ry="7" fill="#000" opacity="0.2"/>
      <path d="M86 62 Q108 48 104 78 Q94 92 80 80" fill="#63636c"/>
      <path d="M92 66 Q100 62 98 74 M94 72 Q102 68 100 80" fill="none" stroke="#9a9aa4" stroke-width="2.8" stroke-linecap="round"/>
      <!-- longer legs -->
      <path d="M42 70 L36 98" stroke="#55555e" stroke-width="5.5" stroke-linecap="round"/>
      <path d="M54 72 L50 100" stroke="#5c5c64" stroke-width="5.5" stroke-linecap="round"/>
      <path d="M68 72 L72 100" stroke="#5c5c64" stroke-width="5.5" stroke-linecap="round"/>
      <path d="M78 70 L86 98" stroke="#55555e" stroke-width="5.5" stroke-linecap="round"/>
      <ellipse cx="36" cy="100" rx="7" ry="4" fill="#4a4a54"/>
      <ellipse cx="50" cy="102" rx="7" ry="4" fill="#4a4a54"/>
      <ellipse cx="72" cy="102" rx="7" ry="4" fill="#4a4a54"/>
      <ellipse cx="86" cy="100" rx="7" ry="4" fill="#4a4a54"/>
      <!-- compact round body + head almost fused -->
      <ellipse cx="60" cy="58" rx="30" ry="26" fill="#6a6a74"/>
      <circle cx="60" cy="48" r="22" fill="#767680"/>
      <ellipse cx="42" cy="30" rx="8" ry="12" fill="#4f4f58"/>
      <ellipse cx="78" cy="30" rx="8" ry="12" fill="#4f4f58"/>
      <ellipse cx="42" cy="30" rx="4.5" ry="7" fill="#e6d0b4"/>
      <ellipse cx="78" cy="30" rx="4.5" ry="7" fill="#e6d0b4"/>
      <ellipse cx="60" cy="50" rx="18" ry="12" fill="#222228"/>
      <circle cx="50" cy="47" r="4" fill="#f8f4ea"/>
      <circle cx="70" cy="47" r="4" fill="#f8f4ea"/>
      <circle cx="51" cy="47.5" r="2" fill="#121214"/>
      <circle cx="71" cy="47.5" r="2" fill="#121214"/>
      <ellipse cx="60" cy="56" rx="5.5" ry="3.5" fill="#c9a292"/>
      <path d="M54 60 Q60 64 66 60" fill="none" stroke="#1e1e24" stroke-width="1.6"/>
    `);

  /**
   * Adult Jimothy — the viral short-spine silhouette:
   * round compact body, almost no neck, long spindly legs.
   */
  const adult = (variant = "noble") => {
    const accent = variant === "rascal" ? "#d9844a" : "#6fbf84";
    const mouth =
      variant === "rascal"
        ? `<path d="M54 52 Q60 50 66 54" fill="none" stroke="#1e1e24" stroke-width="1.8"/>`
        : `<path d="M54 53 Q60 57 66 53" fill="none" stroke="#1e1e24" stroke-width="1.8"/>`;
    const flair =
      variant === "rascal"
        ? `<g opacity="0.9">
            <path d="M78 40 l10 14 -12 2 z" fill="#e0a04a"/>
            <path d="M80 44 h8" stroke="#c45c4a" stroke-width="2"/>
          </g>`
        : `<g opacity="0.85">
            <ellipse cx="78" cy="36" rx="7" ry="4" fill="${accent}" transform="rotate(-20 78 36)"/>
            <path d="M72 36 Q78 28 84 36" fill="none" stroke="#3d6b4f" stroke-width="1.5"/>
          </g>`;

    return svg(`
      <ellipse cx="60" cy="108" rx="34" ry="6" fill="#000" opacity="0.22"/>

      <!-- ringed tail out back -->
      <path d="M88 58 Q112 42 108 70 Q100 86 84 74" fill="#5a5a64"/>
      <path d="M94 56 Q104 48 102 62 M96 64 Q106 58 104 72 M98 72 Q106 68 104 80"
            fill="none" stroke="#b0b0ba" stroke-width="3" stroke-linecap="round"/>

      <!-- long front + hind legs (the signature lope) -->
      <path d="M40 62 L28 102" stroke="#4f4f58" stroke-width="6" stroke-linecap="round"/>
      <path d="M52 66 L46 104" stroke="#5a5a64" stroke-width="6" stroke-linecap="round"/>
      <path d="M68 66 L74 104" stroke="#5a5a64" stroke-width="6" stroke-linecap="round"/>
      <path d="M80 62 L94 102" stroke="#4f4f58" stroke-width="6" stroke-linecap="round"/>
      <ellipse cx="28" cy="104" rx="8" ry="4.5" fill="#3a3a44"/>
      <ellipse cx="46" cy="106" rx="8" ry="4.5" fill="#3a3a44"/>
      <ellipse cx="74" cy="106" rx="8" ry="4.5" fill="#3a3a44"/>
      <ellipse cx="94" cy="104" rx="8" ry="4.5" fill="#3a3a44"/>

      <!-- one round potato body — head fused, short spine silhouette -->
      <ellipse cx="60" cy="52" rx="34" ry="30" fill="#6a6a74"/>
      <ellipse cx="48" cy="44" rx="10" ry="8" fill="#7a7a84" opacity="0.35"/>

      <!-- ears perched on the orb -->
      <ellipse cx="38" cy="26" rx="8" ry="12" fill="#4a4a54"/>
      <ellipse cx="82" cy="26" rx="8" ry="12" fill="#4a4a54"/>
      <ellipse cx="38" cy="26" rx="4.5" ry="7" fill="#e2cdb2"/>
      <ellipse cx="82" cy="26" rx="4.5" ry="7" fill="#e2cdb2"/>

      <!-- bandit mask across the front of the round body -->
      <ellipse cx="60" cy="46" rx="22" ry="13" fill="#1c1c22"/>
      <circle cx="48" cy="44" r="5" fill="#faf6ec"/>
      <circle cx="72" cy="44" r="5" fill="#faf6ec"/>
      <circle cx="49.2" cy="44.6" r="2.4" fill="#101014"/>
      <circle cx="73.2" cy="44.6" r="2.4" fill="#101014"/>
      <circle cx="47.5" cy="43" r="1.1" fill="#fff" opacity="0.8"/>
      <circle cx="71.5" cy="43" r="1.1" fill="#fff" opacity="0.8"/>

      <ellipse cx="60" cy="54" rx="6.5" ry="4" fill="#c9a292"/>
      ${mouth}
      ${flair}

      <!-- tiny whisker ticks -->
      <path d="M40 52 h-8 M40 56 h-7 M80 52 h8 M80 56 h7"
            stroke="#d0d0d8" stroke-width="1.2" stroke-linecap="round" opacity="0.55"/>
    `);
  };

  const icons = {
    feed: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M7 3v10a3 3 0 006 0V3" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M10 16v5M7 21h6" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M16 4c2 2 3 4 3 7v10" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`,
    play: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3" y="7" width="18" height="12" rx="3" stroke="currentColor" stroke-width="2"/><circle cx="8" cy="13" r="1.5" fill="currentColor"/><circle cx="16" cy="13" r="1.5" fill="currentColor"/><path d="M9 7V5h6v2" stroke="currentColor" stroke-width="2"/></svg>`,
    scold: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 14V8a4 4 0 018 0v6" stroke="currentColor" stroke-width="2"/><path d="M2 14h12v2a4 4 0 01-4 4H6a4 4 0 01-4-4v-2z" stroke="currentColor" stroke-width="2"/><path d="M16 8c2 1.5 3 3.5 3 6M19 6c2.5 2 4 5 4 8" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`,
    clean: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 3v6M8 5l8 4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M7 11h10l-1.5 9h-7L7 11z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/></svg>`,
    berries: `<svg viewBox="0 0 32 32" aria-hidden="true"><circle cx="12" cy="18" r="6" fill="#5a4a8a"/><circle cx="20" cy="16" r="6" fill="#6b5aa0"/><circle cx="16" cy="22" r="5.5" fill="#4a3a72"/><path d="M16 8c0 4-2 6-4 7" stroke="#3d6b4f" stroke-width="2" fill="none"/><ellipse cx="18" cy="8" rx="4" ry="2" fill="#6fbf84"/></svg>`,
    acorns: `<svg viewBox="0 0 32 32" aria-hidden="true"><ellipse cx="16" cy="12" rx="8" ry="5" fill="#8a5a3a"/><path d="M10 12c0 8 3 14 6 14s6-6 6-14" fill="#c4a06a"/><path d="M16 7v-3" stroke="#5a4030" stroke-width="2"/></svg>`,
    pizza: `<svg viewBox="0 0 32 32" aria-hidden="true"><path d="M6 10l10 18 10-18z" fill="#e0a04a"/><path d="M8 11h16" stroke="#c45c4a" stroke-width="3"/><circle cx="14" cy="18" r="2" fill="#8a2f2f"/><circle cx="18" cy="22" r="1.6" fill="#8a2f2f"/></svg>`,
    fries: `<svg viewBox="0 0 32 32" aria-hidden="true"><path d="M9 14h14l-2 14H11L9 14z" fill="#c45c4a"/><rect x="11" y="6" width="2.5" height="10" rx="1" fill="#e0a04a"/><rect x="15" y="4" width="2.5" height="12" rx="1" fill="#f0c57a"/><rect x="19" y="7" width="2.5" height="9" rx="1" fill="#e0a04a"/></svg>`,
  };

  function render(stage, variant) {
    switch (stage) {
      case "egg":
        return egg();
      case "hatchling":
        return hatchling();
      case "kit":
        return kit();
      case "teen":
        return teen();
      case "adult":
        return adult(variant);
      default:
        return egg();
    }
  }

  return { render, icons };
})();
