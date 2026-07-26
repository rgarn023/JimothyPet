# Jimothy — Godot 4.7.1

Your **midnight cryptid** — a real-time Tamagotchi-style pet configured for **Godot 4.7.1**.

## Open in Godot

1. Install [Godot 4.7.1](https://godotengine.org/download/archive/4.7.1-stable/)
2. Import this folder (`project.godot`)
3. Press **F5**

## Export Android (phone shade alerts) — APK 1.0.10+

### Permissions (Export → Android → Permissions)
Turn **ON**:
- **Post Notifications** (required)
- **Wake Lock**
- **Receive Boot Completed**
- **Set Alarm**

Godot 4.7 has **no** “Schedule Exact Alarm” / “Use Exact Alarm” checkboxes.

### If you build on a phone (Godot Android / GABE)

The previous zip could crash Gradle looking for a missing `android/plugins/*.aar`. **1.0.10 removes that.**

**Easiest path on phone:**
1. Open this project in Godot 4.7.1
2. **Project → Export → Android**
3. Set **Use Gradle Build = Off** (one-click export)
4. Permissions → **Post Notifications** On
5. Export & install
6. Tap **Allow** on the notification prompt

One-click export uses the built-in Android notify path (no Gradle plugin needed).

**Optional Gradle path (desktop or GABE):**
1. **Project Settings → Plugins → NotificationScheduler → Enable**
2. **Project → Install Android Build Template…**
3. **Use Gradle Build = On**
4. Do **not** enable a Plugins entry for `NotificationSchedulerPlugin` under `android/plugins` (that folder is unused now)
5. Export

### After install
- Toast **Jimothy alert sent** + shade notification **Jimothy alerts on**
- If the button says **Alerts: Allow**, tap it
- Or: phone **Settings → Apps → JimothyPet → Notifications → On**

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
- **Alerts** default ON — phone shade notifications for hunger, play, acting up, waste, new forms
- **Sound** toggles in Settings
