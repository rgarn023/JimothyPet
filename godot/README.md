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
- **Play:** Dumpster Dive night forage — burns energy, builds fitness
- **Scold / Clean:** Discipline refusals; clear nest messes
- **Form paths:** young → teen forks → adult (care vs neglect), with unlock highlighting
- **Dev mode:** toggle on, then fast-forward to each stage (or the ascend finale)
- **Sound:** looping night ambience (crickets / wind) + raccoon chitters, rustles, crunch, and ascend whoosh — toggle with **Sound: On/Off**
- Forest backdrop + clearing floor; Jimothy walks / runs / jumps / lopes
- **Tap Jimothy** for smile / hop / nuzzle / spin reactions

### Floating pet on Android?

A web **Float** companion exists in the HTML build (Chrome PiP). A true Android “runs over other apps” pet needs a native overlay service (`SYSTEM_ALERT_WINDOW`) — not included in the pure Godot export yet. A home-screen status widget is the lighter native option.

## Export Android

1. Install Godot **4.7.1** export templates  
2. Configure Android SDK  
3. **Project → Export → Android** (`com.jimothy.pet`)
