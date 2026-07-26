# Jimothy — Godot 4.7.1

Your **midnight cryptid** — a real-time Tamagotchi-style pet configured for **Godot 4.7.1**.

## Open in Godot

1. Install [Godot 4.7.1](https://godotengine.org/download/archive/4.7.1-stable/)
2. Import this folder (`project.godot`)
3. Press **F5**

## Life cycle (real time)

| Stage | When |
| --- | --- |
| **Rustling bush** | Start |
| **Baby kit** | ~1 minute |
| **Young kit** | +1 hour (form variance begins) |
| **Teen kit** | +24 hours (form steers adult) |
| **Adult Jimothy** | +24–72 hours more (short-spine viral look, variant flair) |
| **Lifespan** | Adult lasts ~10–20 days (neglect shortens this) |
| **Finale** | Wings grow, he rises into the sky → **Raise another kit** |

Young/teen forms (puff, looper, shadow, nub → dumpling, bounder, nightlane, scruff) influence the adult flair (Saint, Legend, Alley Ghost, Ballard Blip) while keeping the internet-famous short-spine silhouette.

## Care

- **Feed:** Wild berries, night crickets, stream fish (proper forage) or pizza crust / dumpster fries (junk)
- Satiety stops overfeeding; junk can upset his stomach
- **Play:** Dumpster Dive night forage, or High or Low (spinning d20) — burns energy, builds mood/fitness
- **Scold / Clean:** Discipline refusals; clear nest messes
- **Form paths:** young → teen forks → adult (care vs neglect), with unlock highlighting
- **Dev mode:** toggle on, then fast-forward to each stage (or the ascend finale)
- **Sound:** raccoon chitters, rustles, crunch, chew, cry, ascend, etc. — toggle in **Settings → Sound → Jimothy: On**. Android APKs load imported WAV samples via `ResourceLoader` (re-export after pulling latest if an older build was silent).
- **Care alerts:** real **OS / browser / Android** notifications when hungry, bored, acting up, nest waste, or a **new form** — toggle **Settings → Alerts: On** (allow the permission prompt). In-editor desktop may use OS toasts; phone alerts need an Android APK or the web/PWA build.
- Forest backdrop + clearing floor; Jimothy walks / runs / jumps / lopes
- **Tap Jimothy** for smile / hop / nuzzle / spin reactions

## Download

Zips live in the repo [`dist/`](../dist/) folder:

- `Jimothy-godot-only-4.7.1.zip` — this Godot project
- `JimothyPet-godot-4.7.1.zip` — full repo (web + Godot)
- `Jimothy-web.zip` — browser-only build

## Export Android

1. Install Godot **4.7.1** export templates  
2. Configure Android SDK  
3. **Project → Export → Android** (`com.jimothy.pet`)  
4. Export includes **POST_NOTIFICATIONS** — after install, open the app → **Settings → Alerts: On** and accept the Android permission prompt  
5. You should see a confirmation notification (“Jimothy alerts on”). Care needs (hungry, play, acting up, waste, new form) then appear in the phone shade  
6. If no prompt appears: phone **Settings → Apps → JimothyPet → Notifications → On**
