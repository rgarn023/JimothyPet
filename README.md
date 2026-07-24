# Jimothy

A Tamagotchi-style virtual pet you can play in the browser or on your phone. Raise **Jimothy the raccoon** through egg → hatchling → kit → teen → adult.

## Play

Open `index.html` in a browser, or serve the folder locally:

```bash
python3 -m http.server 8080
```

Then visit `http://localhost:8080`. On a phone, add the page to your home screen for an app-like feel.

## Care

| Action | What it does |
| --- | --- |
| **Feed** | Healthy meals (Berry Bundle, Crunchy Acorns) or treats (Pizza Crust, Dumpster Fries) |
| **Play** | **Dumpster Dive** mini-game — catch raccoon treasures, dodge rotten scraps |
| **Scold** | Discipline Jimothy when he refuses healthy food or exercise |
| **Clean** | Clear messes before they hurt health and happiness |

Meters drain over time (including while you’re away). Neglect can send him back to the woods — then you start a new egg.

## Growth

1. **Mystery Egg** — warms and hatches on its own  
2. **Peep Jimothy** — hatchling  
3. **Kit Jimothy** — playful kit  
4. **Teen Jimothy** — sassier, more refusals  
5. **Adult** — **Noble Jimothy** (good care) or **Rascal Jimothy** (chaos path)

Progress is saved in `localStorage`.

## Stack

Static HTML, CSS, and vanilla JavaScript — no build step.
