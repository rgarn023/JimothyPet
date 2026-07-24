# Jimothy — Godot 4.7.1

Tamagotchi-style raccoon pet configured for **Godot 4.7.1**.

## Open in Godot

1. Install [Godot 4.7.1](https://godotengine.org/download/archive/4.7.1-stable/)
2. In Godot: **Import** → select this folder’s `project.godot`
3. Press **F5** (or Play)

Project path: `godot/` inside the repo (open the `godot` folder, not the repo root).

## Features

- Growth: Egg → Hatchling → Kit → Teen → Adult (short-spine Jimothy look)
- Feed (healthy meals + treats), Dumpster Dive mini-game, Scold, Clean
- Full real-time catch-up when you return to the app
- Saves to `user://jimothy_save.json`

## Export Android

1. In Godot: **Editor → Manage Export Templates** → install **4.7.1** templates  
2. **Project → Export → Android**
3. Set up Android SDK / debug keystore (Godot docs: Exporting for Android)
4. Export APK/AAB (`package/unique_name` is `com.jimothy.pet`)

Preset is already listed in `export_presets.cfg`.

## Export Web

**Project → Export → Web** (preset included). Useful if you still want a browser build from the same Godot project.

## Controls

| Button | Action |
| --- | --- |
| Feed | Berry Bundle / Acorns / Pizza Crust / Dumpster Fries |
| Play | Dumpster Dive — drag or ←→ / A D |
| Scold | Discipline when he refuses food or play |
| Clean | Clear messes |
