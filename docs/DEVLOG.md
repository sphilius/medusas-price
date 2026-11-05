# Medusa's Price devlog

The record of truth for design choices, newest first. Statuses: Made / Changed / Removed / Revisited / Parked / Archived / Proposed.

## At a glance

| ID | Date | Choice | Status |
|---|---|---|---|
| D-005 | 2026-11-05 | Run vase: full AI route + fallback, deployed; live vases still fail the letter check | Revisited |
| D-004 | 2026-11-05 | One painted background layer per level (the `_px` paintings are opaque) | Proposed |
| D-003 | 2026-11-05 | Enemy sprites are scaled to fit their existing hitboxes | Made |
| D-002 | 2026-11-05 | Whip body uses 3 poses spread over the 8 whip frames | Made |
| D-001 | 2026-11-05 | Character art comes from `art/processed` (Nano Banana + art_cleanup), not SpriteCook | Made |

## D-005 · Run vase: AI route + fallback · Revisited
Merged into `s17-art-shaders` and deployed on 2026-11-05 (Sasha's OK). Three live calls all ended in the fallback: the image is painted, but the vision letter check answers YES. Removing hex color codes and the Greek key from the image prompt did not fix it. Players see the painted fallback vase, silently, so the game is safe. Next step is Sasha's call: inspect a rejected image locally, loosen the letter check for decorative patterns, or ship the fallback.

## D-004 · One background layer per level · Proposed
The P11 `_px` paintings came out opaque, so they cannot sit behind the main paintings. Each level scrolls one painting at 0.3x, plus the meander bands (guidebook decision d2-parallax-px).

## D-003 · Enemies fit their hitboxes · Made
At Medusa's 0.5 scale the enemy art came out about 1.7x her height. Scaling each sprite to its collision height keeps every tuned distance and fight the same.

## D-002 · Whip body poses · Made
Sheet B has wind-up, strike and recovery. They map to whip frames [0,0,1,1,1,2,2,2] and follow the whip's own timeline (75/75/50/50/50/50/50 ms), so body and snakes never drift apart.

## D-001 · Art source · Made
No SpriteCook packages exist; all art comes from `art/processed/` through `tools/build_sprites.py`.
