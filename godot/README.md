# Jimothy — Godot 4.7.1

Your **midnight cryptid** — a real-time Tamagotchi-style pet configured for **Godot 4.7.1**.

## Open in Godot

1. Install [Godot 4.7.1](https://godotengine.org/download/archive/4.7.1-stable/)
2. Import this folder (`project.godot`)
3. Press **F5**

## Export Android (alerts while app is closed) — APK 1.0.14+

Closed-app shade alerts need the **NotificationScheduler** plugin inside the APK. That requires a **Gradle** export.

### One-time setup
1. **Project Settings → Plugins → NotificationScheduler → Enable** (already on in this project)
2. **Project → Install Android Build Template…**
3. **Project → Export → Android → Use Gradle Build = On** (preset default)

### Permissions (Export → Android → Permissions)
Turn **ON**:
- **Post Notifications** (required)
- **Wake Lock**
- **Receive Boot Completed**
- **Set Alarm**

Custom permissions already include `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`.

Do **not** add a separate Plugins entry under `android/plugins` — the editor plugin pulls AARs from `addons/NotificationSchedulerPlugin/bin/`.

### After install
- Tap **Allow** on the notification prompt (or **Alerts: Allow**) — that sends a one-time test shade alert
- Care alerts only fire **after you leave/close the app** (not while playing, not on reopen)
- Examples: **Jimothy popped out of the bush**, hungry / sick / acting up / waste / bored
- Phone **Settings → Apps → JimothyPet → Notifications → On** if blocked

### If Gradle fails on phone (GABE)
Install the Android Build Template again, confirm `addons/NotificationSchedulerPlugin/bin/release/*.aar` exists, then re-export with Gradle On.

## Download

Zips live in the repo [`dist/`](../dist/) folder:

- `Jimothy-godot-only-4.7.1.zip` — this Godot project
- `JimothyPet-godot-4.7.1.zip` — full repo (web + Godot)
- `Jimothy-web.zip` — browser-only build

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

## Care

- **Feed / Play / Scold / Clean / Heal** via Action menu
- **Alerts** default ON — specific shade notifications for hungry, sick, acting up, waste, bored, bush hatch, new forms
- **Sound** toggles in Settings
