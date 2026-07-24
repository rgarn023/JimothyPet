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

  const teen = () =>
    svg(`
      <ellipse cx="60" cy="100" rx="34" ry="8" fill="#000" opacity="0.2"/>
      <path d="M90 72 Q112 58 108 86 Q98 102 84 92" fill="#63636c"/>
      <path d="M96 78 Q104 74 102 84" fill="none" stroke="#9a9aa4" stroke-width="3" stroke-linecap="round"/>
      <ellipse cx="58" cy="74" rx="36" ry="30" fill="#6a6a74"/>
      <circle cx="58" cy="40" r="27" fill="#767680"/>
      <ellipse cx="34" cy="20" rx="10" ry="15" fill="#4f4f58"/>
      <ellipse cx="82" cy="20" rx="10" ry="15" fill="#4f4f58"/>
      <ellipse cx="34" cy="20" rx="5.5" ry="9" fill="#e6d0b4"/>
      <ellipse cx="82" cy="20" rx="5.5" ry="9" fill="#e6d0b4"/>
      <ellipse cx="58" cy="44" rx="23" ry="14" fill="#222228"/>
      <circle cx="46" cy="40" r="4.5" fill="#f8f4ea"/>
      <circle cx="70" cy="40" r="4.5" fill="#f8f4ea"/>
      <circle cx="47" cy="40.5" r="2.2" fill="#121214"/>
      <circle cx="71" cy="40.5" r="2.2" fill="#121214"/>
      <circle cx="45.5" cy="39" r="1" fill="#fff" opacity="0.7"/>
      <circle cx="69.5" cy="39" r="1" fill="#fff" opacity="0.7"/>
      <ellipse cx="58" cy="50" rx="6.5" ry="4" fill="#c9a292"/>
      <path d="M52 56 Q58 61 64 56" fill="none" stroke="#1e1e24" stroke-width="1.8"/>
      <ellipse cx="38" cy="92" rx="10" ry="7" fill="#55555e"/>
      <ellipse cx="78" cy="92" rx="10" ry="7" fill="#55555e"/>
      <path d="M40 68 Q28 74 32 86" fill="none" stroke="#5a5a64" stroke-width="7" stroke-linecap="round"/>
    `);

  const adult = (variant = "noble") => {
    const accent = variant === "rascal" ? "#d9844a" : "#6fbf84";
    const smirk =
      variant === "rascal"
        ? `<path d="M50 56 Q58 54 66 58" fill="none" stroke="#1e1e24" stroke-width="2"/>`
        : `<path d="M50 56 Q58 62 66 56" fill="none" stroke="#1e1e24" stroke-width="2"/>`;
    return svg(`
      <ellipse cx="60" cy="104" rx="38" ry="8" fill="#000" opacity="0.22"/>
      <path d="M92 70 Q118 50 114 84 Q104 108 86 94" fill="#5e5e68"/>
      <path d="M98 76 Q108 68 106 82 M100 84 Q108 78 106 90" fill="none" stroke="#a0a0aa" stroke-width="3.2" stroke-linecap="round"/>
      <ellipse cx="56" cy="72" rx="40" ry="34" fill="#686872"/>
      <circle cx="56" cy="36" r="30" fill="#74747e"/>
      <ellipse cx="30" cy="14" rx="11" ry="16" fill="#4a4a54"/>
      <ellipse cx="82" cy="14" rx="11" ry="16" fill="#4a4a54"/>
      <ellipse cx="30" cy="14" rx="6" ry="10" fill="#e8d2b6"/>
      <ellipse cx="82" cy="14" rx="6" ry="10" fill="#e8d2b6"/>
      <ellipse cx="56" cy="40" rx="25" ry="15" fill="#1f1f26"/>
      <circle cx="43" cy="36" r="5" fill="#faf6ec"/>
      <circle cx="69" cy="36" r="5" fill="#faf6ec"/>
      <circle cx="44.2" cy="36.6" r="2.4" fill="#101014"/>
      <circle cx="70.2" cy="36.6" r="2.4" fill="#101014"/>
      <circle cx="42.5" cy="35" r="1.1" fill="#fff" opacity="0.75"/>
      <circle cx="68.5" cy="35" r="1.1" fill="#fff" opacity="0.75"/>
      <ellipse cx="56" cy="47" rx="7.5" ry="4.5" fill="#c9a292"/>
      ${smirk}
      <ellipse cx="34" cy="94" rx="12" ry="8" fill="#505058"/>
      <ellipse cx="78" cy="94" rx="12" ry="8" fill="#505058"/>
      <path d="M34 66 Q18 74 24 90" fill="none" stroke="#565660" stroke-width="8" stroke-linecap="round"/>
      <circle cx="78" cy="62" r="7" fill="${accent}" opacity="0.55"/>
      <path d="M74 58 L82 58 M78 54 L78 62" stroke="#142019" stroke-width="1.5" opacity="0.35"/>
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
