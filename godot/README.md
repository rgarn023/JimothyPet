# Jimothy — Godot 4.7.1

Your **midnight cryptid** — a real-time Tamagotchi-style pet configured for **Godot 4.7.1**.

## Open in Godot

1. Install [Godot 4.7.1](https://godotengine.org/download/archive/4.7.1-stable/)
2. Import this folder (`project.godot`)
3. Press **F5**

## Export Android (alerts while app is closed) — 1.0.16+

Closed-app shade alerts need the **NotificationScheduler** plugin inside the APK. That requires a **Gradle** export.

### Phone-only (no desktop)
Gradle exports often fail in Godot-on-Android / GABE. Use the prebuilt Gradle APK instead:

1. Download [`dist/jimothy-android-1.0.22-gradle.apk`](../dist/jimothy-android-1.0.22-gradle.apk)
2. Install it (allow “Install unknown apps” if asked)
3. Open JimothyPet → **Alerts: Allow** → you should get: *“Care alerts only appear after you close or leave the app.”*
4. Leave/close the app to test care alerts

The `.apk` is fine for sideload. For Play Console use the **`.aab`** below.

### Play Console AAB (signed upload)
Prebuilt Gradle AAB (package **`com.jimothypet.app`**, versionCode **22**, closed-app alerts):

- [`dist/jimothy-android-1.0.22-gradle.aab`](../dist/jimothy-android-1.0.22-gradle.aab)

**Important:** Play expects package `com.jimothypet.app` and your registered **upload key**  
(SHA1 `F9:7F:31:C7:7A:05:E5:88:CF:55:9C:B9:0D:23:89:83:65:85:B6:40`).  
The GitHub AAB is **not** signed with that key — re-sign before upload.

1. Confirm your keystore SHA1 matches Play:
   ```bash
   keytool -list -v -keystore /storage/emulated/0/Download/jimothy-release.keystore
   ```
2. Re-sign in Termux (below), then verify:
   ```bash
   keytool -printcert -jarfile jimothy-play.aab | grep SHA1
   ```

#### Termux: sign AAB with your keystore
```bash
# Install tools once
pkg install openjdk-17 unzip zip

cd /storage/emulated/0/Download
cp jimothy-android-1.0.22-gradle.aab jimothy-play.aab
# Remove old signature, then sign with YOUR keystore (alias jimothy):
zip -d jimothy-play.aab 'META-INF/*'
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
  -keystore /storage/emulated/0/Download/jimothy-release.keystore \
  jimothy-play.aab jimothy
jarsigner -verify jimothy-play.aab
keytool -printcert -jarfile jimothy-play.aab | grep SHA1
```
Upload `jimothy-play.aab` in Play Console (Desktop Chrome if phone upload fails).

### Desktop / successful Gradle export
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
Use the prebuilt APK above. Phone Gradle exports usually cannot include NotificationScheduler.

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
