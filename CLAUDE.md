# Medusa's Price

**Game:** *Medusa's Price*. You play Medusa, hunted by heroes. Your gaze turns enemies to marble statues that become platforms, and every petrification ages your portrait, which is your health.

**Jam:** Jamference AI Game Jam Hack 3, theme *Great Works of Art*. Submission is a browser build on itch.io. **Deadline: upload by 9 PM ET Thu Nov 5, 2026.**

## HARD RULE: NO TEXT

The game shows **no words, no numbers and no readable glyphs** on screen.

- Allowed: key-cap labels (A, D, Space, J, K) shown as icons, arrows, pips, tallies, the title logo.
- Never add `Label` or `RichTextLabel` nodes with words or digits.
- No debug text in release builds.
- No error popups; fail silently to fallbacks.

## Engine rules

- Godot 4, typed GDScript, Compatibility renderer (WebGL2 safe, no compute shaders).
- Signals over polling.
- One script per scene root.
- Every tunable number lives in `Balance` (`res://autoload/balance.gd`), never inline.
- Every AI feature checks its `Features` flag (`res://autoload/features.gd`) and has a non-AI fallback.
- No API keys or secrets anywhere in the Godot project.
- Comment the top of every script with its purpose.

## Units

1 BL (body length) = 64 px = Medusa's standing height.

## Color code (the wordless UI)

| Color | Hex | Meaning |
|---|---|---|
| Terracotta | `#C8643B` | living world |
| Black | `#1A1410` | bodies in motion |
| Marble white | `#F2EFE8` | stone, cost, cracks |
| Gold | `#E8B547` | danger and power (gaze cone, mirror glints, telegraphs) |

## Player

Run 300 px/s, ground accel 2400 px/s², gravity 1800 px/s², jump apex about 2 BL, coyote time 0.10 s, jump buffer 0.12 s, variable jump height on release.

**Sprint (hold Shift on PC; double-tap-and-hold a direction on touch):** top speed x1.5 (450 px/s) and, because speed carries through a jump, a sprint jump reaches about 1.5x as far. Whether she sprints is fixed on her last ground frame, so Shift in mid-air changes nothing. On touch: tap a direction, lift, press the same direction again within 0.25 s (`Balance.TOUCH_DOUBLE_TAP_WINDOW`) and keep holding; a gold chevron shows beside the arrow while it is on.

## Gaze (hold K)

- Cone 4 BL long, 20 degree half-angle, facing direction only.
- An enemy inside the cone for 0.4 s petrifies (0.7 s for eye-shading soldiers).
- Cost: 1 crack per petrified enemy.
- No gaze during whip anticipation or recovery.

## Whip (J), snake hair

- Reach 2 BL in a slight fan of 3 to 5 snakes.
- Anticipation 0.15 s, active 0.10 s, recovery 0.20 s (jump cancels recovery; no whip or gaze during it).
- In air, gravity x0.5 during active.
- Hit: 0.4 s stagger, 1 BL knockback.
- Mirror-bearer hit: mirror knocked aside for 1.5 s.
- Statues: first hit cracks, second shatters. The whip never moves statues.

## Statues

- Petrified enemies become static bodies on layer 4, frozen in their current pose.
- Push: hold move into a statue for 0.4 s, then it slides at 96 px/s until release, wall or edge (then falls).
- Grinding audio loop while sliding, pitch rising with speed; thud on stop or land.
- States: intact, cracked (visible cracks all over), shattered (rubble, collision removed).

## Enemies

- **Hoplite:** walks, charges, spear reach 1.5 BL, 0.35 s thrust wind-up with a gold glint on the spearhead.
- **Leaper:** jumps gaps toward the player.
- **Archer:** stands on ledges at least 3 BL away, arcing arrows, out of whip range.
- **Mirror-bearer:** gaze into his mirror reflects and costs the player 2 cracks; whip knocks the mirror aside.

## Portrait (only HUD)

Caravaggio's Medusa shield. 5 stages; cracks needed to advance:

| Stage | Name | Cracks |
|---|---|---|
| 1 | Defiant | 6 |
| 2 | Rage | 5 |
| 3 | Grief | 4 |
| 4 | Exhaustion | 3 |
| 5 | Stone | 2 more = death (20 total) |

- **Crack sources:** petrify 1, hoplite or leaper or arrow hit 1, fall into pit 1 (respawn at last safe ledge), reflected gaze 2, any Perseus attack 2.
- **Stage change:** swap painting frame, white flash, clear crack overlay, music crossfade.
- **Mirror pool:** clears current-stage cracks and drops one stage (at stage 1 it only clears cracks).
- **Death:** respawn at last pool used, stage 2, 0 cracks.

## Levels

1. Temple steps (noon). **Default gap size: 4.5 BL (288 px)** where the leaper first shows up (`Balance.LEVEL1_GAP_BL`; it was 5.0 BL until 2026-11-02). A normal jump falls short, a sprint jump clears it, and a jump pressed on the last two coyote frames (about 50 to 65 ms after leaving the edge) just squeaks across.
2. Cliffs over the sea (dusk, archers)
3. Cave of statues (torchlight, mirror-bearers)
4. Boss: Perseus at the cave mouth (storm). Boss arena opens with a pool.

## Perseus

- 3 phases: flight, grounded, desperate (shield-bash charges that shatter statues).
- Shield drops for a window after each attack; base window 1.0 s. About 2 gaze hits per phase.
- Study beat between phases 1 and 2: the mirror replays ghost echoes of the player's last 3 gazes.
- Adapted window = `clamp(median player reaction + 0.15, 0.45, 1.0)` s, and attacks come from the side the player guards least.

## Run ledger

Autoload `RunLedger` logs events as JSON for the AI features (vase, gallery, Perseus adaptation, music).

## AI features (each behind a `Features` flag with fallback)

- Run vase: LLM + image model via Cloudflare Worker.
- Statue gallery: img2img marble renders via the same Worker.
- Perseus adaptation: local.
- Adaptive music: 5 stage loops, build-time.
- Webcam stare mode: MediaPipe in the HTML shell, local only.

## Workflow

Small commits per feature, test in a web export before calling anything done, keep the deadline build playable at every commit.
