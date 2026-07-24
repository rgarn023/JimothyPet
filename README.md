# Jimothy

A Tamagotchi-style virtual pet you can play in the **browser** or install on **Android** (and other phones) as a Progressive Web App. Raise **Jimothy the raccoon** through egg → hatchling → kit → teen → adult.

## Play (web)

```bash
npm start
# open http://localhost:8080
```

Or open the folder with any static file server. For install / offline on a phone, the site must be served over **HTTPS** (or localhost).

## Install on Android

1. Open the site in **Chrome**
2. Tap the menu → **Install app** / **Add to Home screen**
3. Jimothy opens fullscreen like a native app and keeps working offline

Same codebase — no separate Android project required for day-to-day play. For a Play Store `.apk` / `.aab` later, this static app can be wrapped with Capacitor or a Trusted Web Activity.

## Real-time care

Jimothy tracks **wall-clock time**:

- While open, meters and age update every second
- When you leave and come back (or reopen the installed app), **all** elapsed real time is applied — no 1-hour cap
- Progress is saved in `localStorage` (and the PWA cache keeps the app shell available offline)

Leaving him alone too long can drain meters and send him back to the woods, just like a classic pet.

## Care

| Action | What it does |
| --- | --- |
| **Feed** | Healthy meals (Berry Bundle, Crunchy Acorns) or treats (Pizza Crust, Dumpster Fries) |
| **Play** | **Dumpster Dive** mini-game — catch raccoon treasures, dodge rotten scraps |
| **Scold** | Discipline Jimothy when he refuses healthy food or exercise |
| **Clean** | Clear messes before they hurt health and happiness |

## Growth

1. **Mystery Egg** — warms and hatches on its own  
2. **Peep Jimothy** — hatchling  
3. **Kit Jimothy** — playful kit  
4. **Teen Jimothy** — sassier, more refusals  
5. **Adult** — the viral short-spine look (**Saint Jimothy** with good care, or **Legend Jimothy** on the chaos path)

## Stack

Static HTML, CSS, and vanilla JavaScript with a small service worker + web app manifest (PWA). No build step for the game itself.

```bash
npm test   # optional Playwright smoke test (needs Chrome)
```
