# Jimothy

Your **midnight cryptid** — a real-time Tamagotchi-style pet starring Jimothy (viral short-spine look at adult stage).

## Play in Godot 4.7.1 (recommended for Android)

The game is set up as a **Godot 4.7.1** project:

```text
godot/project.godot
```

1. Install [Godot 4.7.1](https://godotengine.org/download/archive/4.7.1-stable/)
2. Open / import the `godot/` folder
3. Press **Play (F5)**

See [`godot/README.md`](godot/README.md) for Android APK export and details.

## Play in browser (optional web build)

A standalone HTML version also lives at the repo root:

```bash
npm start
# open http://localhost:8080
```

## Download zips

Fresh packs in [`dist/`](dist/):

| Zip | What’s inside |
| --- | --- |
| [`Jimothy-web.zip`](dist/Jimothy-web.zip) | Browser build — unzip and open `index.html`, or host the folder |
| [`Jimothy-godot-only-4.7.1.zip`](dist/Jimothy-godot-only-4.7.1.zip) | Godot 4.7.1 project only |
| [`JimothyPet-godot-4.7.1.zip`](dist/JimothyPet-godot-4.7.1.zip) | Full repo (web + Godot) |

## Life cycle (real time)

| Stage | When |
| --- | --- |
| **Rustling bush** | Start |
| **Baby kit** | ~1 minute |
| **Young kit** | +1 hour (form variance begins) |
| **Teen kit** | +24 hours (form steers adult) |
| **Adult Jimothy** | +24–72 hours more (short-spine viral look, variant flair) |
| **Lifespan** | Adult lasts ~10–20 days — neglect / poor care shortens it |
| **Finale** | Wings + sky ascension, then **Raise another kit** |

Young/teen forms (`puff` / `looper` / `shadow` / `nub` → `dumpling` / `bounder` / `nightlane` / `scruff`) influence adult flair (**Saint**, **Legend**, **Alley Ghost**, **Ballard Blip**) while keeping the short-spine silhouette.

Full wall-clock catch-up when you return (no 1-hour cap). Saves use `jimothy-pet-v2`.

## Care

| Action | What it does |
| --- | --- |
| **Feed** | Wild Berries, Night Crickets, Stream Fish Bits — or Pizza Crust / Dumpster Fries |
| **Play** | **Dumpster Dive** night forage, or **High or Low** d20 gamble — burns energy, builds mood/fitness |
| **Scold** | Discipline when he acts up |
| **Clean** | Clear nest messes |
| **Heal** | Clear illness when he’s sick (grayed out otherwise) |

Satiety stops overfeeding; junk treats can make him sick. Baby kits and the bush can’t run a full Dumpster Dive. Jimothy walks, runs, jumps, and lopes around the stage.

## Sound

Night ambience (crickets / soft wind / distant owl) loops in the background, with raccoon chitters, bush rustles, eating crunches, and an ascend whoosh. Toggle **BG** and **Jimothy** separately; both preferences are saved.

## Care alerts

Toggle **Alerts: On** to get notifications when Jimothy is hungry, wants to play, is acting up, left nest waste, or evolves into a **new form**. Care needs use a 12‑minute cooldown per kind; form milestones always notify. Web uses the browser Notification API (works while the tab/PWA is open); Godot desktop uses OS notifications (`notify-send` / macOS). Preference is saved.

Open **Forms** to browse every young / teen / adult silhouette (gallery + evolution paths).

## Forms & Dumpster Dive

- **Forms** shows every young → teen → adult path (care vs neglect forks). Unlocked nodes glow; this kit’s path is outlined.
- **Dumpster Dive** is an alley rummage: food arcs out of the bin, Jimothy walks/chews on catch, and standing under the dumpster digs up a scrap.
