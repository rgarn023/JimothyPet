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
| [`jimothy-android-1.0.25-gradle.apk`](dist/jimothy-android-1.0.25-gradle.apk) | Phone install with **closed-app alerts** (Gradle + NotificationScheduler) |
| [`jimothy-android-1.0.25-gradle.aab`](dist/jimothy-android-1.0.25-gradle.aab) | Play Console bundle (`com.jimothypet.app`, versionCode 25, **no `USE_EXACT_ALARM`**). Re-sign with your upload keystore — see godot/README.md |

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
| **Action** menu | **Feed**, **Play**, **Scold**, **Heal**, **Clean** |
| **Settings** menu | **Sound**, **Alerts**, **Reset** |
| **Feed** | Wild Berries, Night Crickets, Stream Fish Bits — or Pizza Crust / Dumpster Fries |
| **Play** | **Dumpster Dive** night forage, or **High or Low** d20 gamble — burns energy, builds mood/fitness |
| **Scold** | Discipline when he acts up (max 3 times / 24h; likelier as discipline falls) |
| **Clean** | Clears one waste pile (up to 6 can accumulate) |
| **Heal** | Clear illness when he’s sick (max 2 times / 24h; likelier when health is low) |

Health drains slowly from waste, hunger, and junk food. Discipline fades slowly over time. Illness can still appear rarely even with good care. Satiety stops overfeeding. Baby kits and the bush can’t run a full Dumpster Dive.

## Sound

Open **Settings → Sound** for separate **BG** (night ambience / owl) and **Jimothy** (raccoon SFX) toggles. Preferences are saved.

## Care alerts

**Alerts default ON** on first launch. The button shows **Alerts: Allow** until the phone/browser actually grants permission — tap it to prompt. You’ll get shade notifications when Jimothy is hungry, wants to play, is acting up, left nest waste, or evolves into a **new form**.

**Phone + closed-app alerts:** install the prebuilt [`dist/jimothy-android-1.0.25-gradle.apk`](dist/jimothy-android-1.0.25-gradle.apk) (Godot-on-phone exports usually miss the scheduler plugin). See [`godot/README.md`](godot/README.md). Web needs a user tap to allow notifications on phones. Preference is saved.

Open **Forms** to browse every young / teen / adult silhouette (gallery + evolution paths).

## Forms & Dumpster Dive

- **Forms** shows every young → teen → adult path (care vs neglect forks). Unlocked nodes glow; this kit’s path is outlined.
- **Dumpster Dive** is an alley rummage: food arcs out of the bin, Jimothy walks/chews on catch, and standing under the dumpster digs up a scrap.
