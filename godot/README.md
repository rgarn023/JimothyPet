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
- **Care alerts:** real **OS / browser / Android** shade notifications when hungry, bored, acting up, nest waste, or a **new form**. **Alerts default ON**; the button shows **Alerts: Allow** until the phone grants permission. Phone APKs need the Gradle steps below.
- Forest backdrop + clearing floor; Jimothy walks / runs / jumps / lopes
- **Tap Jimothy** for smile / hop / nuzzle / spin reactions

## Download

Zips live in the repo [`dist/`](../dist/) folder:

- `Jimothy-godot-only-4.7.1.zip` — this Godot project
- `JimothyPet-godot-4.7.1.zip` — full repo (web + Godot)
- `Jimothy-web.zip` — browser-only build

## Export Android (phone shade alerts)

Phone alerts use the **NotificationScheduler** addon (`addons/NotificationSchedulerPlugin`, Godot 4.7).

1. Install Godot **4.7.1** export templates + Android SDK  
2. Confirm **Project → Project Settings → Plugins → NotificationScheduler** is **Enable**  
3. **Project → Install Android Build Template…** (once — creates `android/build`)  
4. **Project → Export → Android**  
   - **Use Gradle Build** = On (required)  
   - Package `com.jimothy.pet`  
5. Export / install the APK (**version 1.0.6+**)  
6. First launch: accept **Allow notifications**  
7. You should see a short Toast **“Jimothy alert sent”** and a shade notification **“Jimothy alerts on”** within ~1s  
8. If the Alerts button says **Alerts: Allow**, tap it and grant permission (or phone **Settings → Apps → JimothyPet → Notifications → On**)

One-click / non-Gradle Android export will not include the scheduler plugin.
