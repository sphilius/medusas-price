# Medusa's Price devlog

The record of truth for design choices, newest first. Statuses: Made / Changed / Removed / Revisited / Parked / Archived / Proposed.

## At a glance

| ID | Date | Choice | Status |
|---|---|---|---|
| D-008 | 2026-11-05 | Full platformer kit and all three levels rebuilt as teach/test/twist rooms | Made |
| D-007 | 2026-11-05 | Terrain drawn as one grounded mass (texkit surface, edges, depth), camera zoom 1.5 | Made |
| D-006 | 2026-11-05 | Levels 2 and 3 built in the generator: statue-climb cliff, archers, mirror-bearers, plate door | Made |
| D-005 | 2026-11-05 | Run vase: full AI route + fallback; empty-reply bug fixed, live vases now pass | Made |
| D-004 | 2026-11-05 | One painted background layer per level (the `_px` paintings are opaque) | Proposed |
| D-003 | 2026-11-05 | Enemy sprites are scaled to fit their existing hitboxes | Made |
| D-002 | 2026-11-05 | Whip body uses 3 poses spread over the 8 whip frames | Made |
| D-001 | 2026-11-05 | Character art comes from `art/processed` (Nano Banana + art_cleanup), not SpriteCook | Made |

## D-008 · Platformer kit, levels rebuilt · Made
Sasha: the levels were walk, hop, petrify; it should be a full platformer. Chose the full kit and a rebuild of all three levels (decision d4).
- **Kit:** moving platforms (lifts and ferries, AnimatableBody2D so riders are carried), crumbling marble ledges (0.5 s, back after 3 s), column ledges you jump up through, spear traps (a statue resting in one jams it, the statue-bridge puzzle), plate-operated gates, and shards that mend one crack. All tunables in Balance; `sim_kit` checks all six (14 checks).
- **Levels** (`tools/build_levels.gd`), each a chain of teach → test → twist rooms. Temple: steps, column climb to a shard, sprint gap with the leaper, spear trench, crumbling bridge, lift to the temple. Cliffs: statue climb, sea ferry, pillar archer, crumbling stair up to the high cliff. Cave: plate gate, spear trench, lift, column shard, crumbling gap, plate door.
- Column ledges step up 3 rows, not 4: a jump rises exactly 4 rows, so 4 would need a perfect jump.

## D-007 · Grounded terrain and zoom · Made
The terrain was a whole painting shrunk to 32 px per tile, floating over a background that had its own ground. Now: texkit `tile` makes a seamless surface drawn in world space; exposed edges get black outlines and a Greek-key lip; ground fills below the view and darkens with depth; the camera zooms 1.5x with limits; backgrounds keep their screen size and fade into a haze, so they read as distance. The cave reuses the cliff rock because texkit's cave result showed seams.

## D-006 · Levels 2 and 3 filled in · Made
The 7 PM browser playthrough found levels 2 and 3 were still the generator's starter rooms: a short floor and an exit 640 px away. Both are now laid out in `tools/build_levels.gd` (which now only rewrites the levels in its BUILD list, so level 1 and the hand-edited boss arena are safe).
- **Cliffs:** petrify a hoplite and push his statue to a 2.5 BL cliff (too high to jump, easy from a 1 BL statue), a clifftop archer, the leaper at a 3 BL gap, an archer on a pillar island, an eye-shading hoplite, two pools. A spare victim statue waits behind the spawn point. It first stood in front of Medusa, where it blocked her gaze at the hoplite.
- **Cave:** three mirror-bearers, a victim statue or an eye-shading hoplite to push up to the shelf, a gap, a pool, and an exit door that is open only while a statue rests on a floor plate 450 px away (`LevelBase.exit_needs_plate`, `lock_exit()`).
The cliff climb and the mirror-bearer were checked by hand in the web build; the plate door is checked in `sim_levels`.

## D-005 · Run vase: AI route + fallback · Made
Merged into `s17-art-shaders` and deployed on 2026-11-05 (Sasha's OK). Three live calls all ended in the fallback. Sasha chose to inspect a rejected vase: run locally with `wrangler dev --var DEBUG_REJECTS:1`, the rejected image had no writing at all. Cause: Claude Haiku 5.5 thinks by default, and thinking used up the tiny token budgets (5 for the YES/NO check, 120 for the frieze), so both replies came back empty. An empty YES/NO counts as "has letters", so every vase failed. Fix: `thinking: {type: "disabled"}` on these calls, plus a letter-check question that says Greek-key borders and other ornament are not writing. The next local vase passed, with a frieze matching the run and no writing. Deployed on 2026-11-05 at 6:57 PM ET (version b13aca74, Sasha's OK); the first live vase came back 200 with no writing.

## D-004 · One background layer per level · Proposed
The P11 `_px` paintings came out opaque, so they cannot sit behind the main paintings. Each level scrolls one painting at 0.3x, plus the meander bands (guidebook decision d2-parallax-px).

## D-003 · Enemies fit their hitboxes · Made
At Medusa's 0.5 scale the enemy art came out about 1.7x her height. Scaling each sprite to its collision height keeps every tuned distance and fight the same.

## D-002 · Whip body poses · Made
Sheet B has wind-up, strike and recovery. They map to whip frames [0,0,1,1,1,2,2,2] and follow the whip's own timeline (75/75/50/50/50/50/50 ms), so body and snakes never drift apart.

## D-001 · Art source · Made
No SpriteCook packages exist; all art comes from `art/processed/` through `tools/build_sprites.py`.
