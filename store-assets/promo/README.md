# JimothyPet promo — Coming Soon / Testers

Form: https://forms.gle/Lo4vB3r4MM4hTvKSA

Built from **real Godot gameplay** (`--write-movie` + `PromoDemo` when `JIMOTHY_PROMO=1`), with **in-game raccoon SFX** + soft night ambience, then Coming Soon / signup end cards.


| File | Use |
| --- | --- |
| `jimothy-coming-soon-tester-1080x1920.mp4` | Vertical (Reels / Shorts / Stories) ~27s |
| `jimothy-coming-soon-tester-1920x1080.mp4` | Landscape (YouTube) |
| `jimothy-coming-soon-poster.png` | Still from real gameplay |
| `jimothy-tester-signup-poster.png` | Signup + QR still |

Also under `dist/` for easy download.

## Re-record
```bash
export DISPLAY=:1 JIMOTHY_PROMO=1
godot --path godot --rendering-driver opengl3 \
  --write-movie /tmp/raw.avi --fixed-fps 30 --disable-vsync --quit-after 660
```
