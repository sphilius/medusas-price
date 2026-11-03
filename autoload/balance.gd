## balance.gd (autoload "Balance")
## Purpose: the single home for EVERY tuning number and color in the game.
## Rule: never type a gameplay number inline in another script; add a const here.
## All values are starting values from the Jam Design Spec - tune them here.
## Units: 1 BL (body length) = 64 px = Medusa's standing height.
extends Node

# ---------------------------------------------------------------------------
# Units
# ---------------------------------------------------------------------------
## Pixels in one body length (BL).
const BL: float = 64.0

# ---------------------------------------------------------------------------
# Physics layer bits (names live in project.godot [layer_names])
# ---------------------------------------------------------------------------
const PHYS_WORLD: int = 1        # layer 1
const PHYS_PLAYER: int = 2       # layer 2
const PHYS_ENEMIES: int = 4      # layer 3
const PHYS_STATUES: int = 8      # layer 4
const PHYS_GAZE: int = 32        # layer 6

# ---------------------------------------------------------------------------
# Color code (the wordless UI)
# ---------------------------------------------------------------------------
## Terracotta = the living world.
const COLOR_TERRACOTTA: Color = Color("C8643B")
## Near-black = bodies in motion.
const COLOR_BLACK: Color = Color("1A1410")
## Marble white = stone, cost, cracks.
const COLOR_MARBLE: Color = Color("F2EFE8")
## Gold = danger and power (gaze cone, mirror glints, telegraphs).
const COLOR_GOLD: Color = Color("E8B547")

# ---------------------------------------------------------------------------
# Player movement
# ---------------------------------------------------------------------------
## Top running speed (px/s).
const PLAYER_RUN_SPEED: float = 300.0
## Sprint (hold Shift, PC only): top speed becomes PLAYER_RUN_SPEED x this. Because the
## speed carries through a jump, a sprint jump also travels farther (about 1.5x the reach
## of a normal jump). Whether she sprints is decided on her last frame on the ground, so
## pressing or releasing Shift in mid-air does not bend the jump arc.
const PLAYER_SPRINT_MULT: float = 1.5
## Ground acceleration (px/s^2).
const PLAYER_GROUND_ACCEL: float = 2400.0
## Gravity (px/s^2).
const PLAYER_GRAVITY: float = 1800.0
## Jump apex height in body lengths (about 2 BL).
const PLAYER_JUMP_APEX_BL: float = 2.0
## Upward launch speed that reaches the apex: v = sqrt(2 * g * h). Negative = up.
## (sqrt(2 * 1800 * 128) = 678.8)
const PLAYER_JUMP_VELOCITY: float = -678.8
## Seconds after leaving a ledge during which jump still works.
const PLAYER_COYOTE_TIME: float = 0.10
## Seconds a jump press is remembered before landing.
const PLAYER_JUMP_BUFFER: float = 0.12
## Releasing jump early multiplies upward speed by this (variable jump height).
const PLAYER_JUMP_CUT: float = 0.5

# ---------------------------------------------------------------------------
# Gaze (hold K)
# ---------------------------------------------------------------------------
## Cone length in BL.
const GAZE_LENGTH_BL: float = 4.0
## Cone half-angle in degrees (facing direction only).
const GAZE_HALF_ANGLE_DEG: float = 20.0
## Seconds an enemy must stay inside the cone to petrify.
const GAZE_HOLD: float = 0.4
## Same, for eye-shading soldiers.
const GAZE_HOLD_EYE_SHADING: float = 0.7
## Where the cone starts, relative to Medusa's center (her eyes).
const GAZE_EYE_OFFSET: Vector2 = Vector2(0.0, -20.0)
## Alpha of the gold cone polygon.
const GAZE_CONE_ALPHA: float = 0.35
## Points along the cone's far arc (more = rounder).
const GAZE_ARC_SEGMENTS: int = 8
## Line-of-sight ray mask: anything on these layers blocks the gaze.
const GAZE_LOS_MASK: int = PHYS_WORLD | PHYS_STATUES

# ---------------------------------------------------------------------------
# Game feel
# ---------------------------------------------------------------------------
## Hit-stop on petrify: real seconds, and the time scale held during it.
const HITSTOP_DURATION: float = 0.08
const HITSTOP_TIME_SCALE: float = 0.05
## Camera shake on petrify: max offset (px) and decay time (s).
const SHAKE_PETRIFY_PX: float = 6.0
const SHAKE_PETRIFY_TIME: float = 0.2
## Sample rate (Hz) of every placeholder sound generated in code.
const SFX_MIX_RATE: int = 22050
## Placeholder crack sound, generated in code: length (s), random pitch jitter
## (+/-), noise decay rate, thunk frequency (Hz), noise and thunk mix levels,
## and volume (dB).
const CRACK_SFX_LENGTH: float = 0.06
const CRACK_SFX_PITCH_JITTER: float = 0.1
const CRACK_SFX_DECAY: float = 70.0
const CRACK_SFX_THUNK_HZ: float = 110.0
const CRACK_SFX_NOISE_MIX: float = 0.7
const CRACK_SFX_THUNK_MIX: float = 0.5
const CRACK_SFX_VOLUME_DB: float = -6.0

# ---------------------------------------------------------------------------
# Whip (hold J) - snake hair
# ---------------------------------------------------------------------------
## Reach in BL.
const WHIP_REACH_BL: float = 2.0
## Number of snakes in the fan (3 to 5).
const WHIP_SNAKES_MIN: int = 3
const WHIP_SNAKES_MAX: int = 5
## Phase timings in seconds. No whip or gaze during anticipation/recovery.
const WHIP_ANTICIPATION: float = 0.15
const WHIP_ACTIVE: float = 0.10
const WHIP_RECOVERY: float = 0.20
## Gravity multiplier while the lash is active in the air.
const WHIP_AIR_GRAVITY_MULT: float = 0.5
## Enemy stagger (s) and knockback (BL) when hit.
const WHIP_STAGGER: float = 0.4
const WHIP_KNOCKBACK_BL: float = 1.0
## Seconds a mirror-bearer's mirror is knocked aside.
const WHIP_MIRROR_KNOCK: float = 1.5
## Where the snakes grow from, relative to Medusa's center (her head). Reach is
## measured from here, so the tip sits WHIP_REACH_BL ahead of her center.
const WHIP_HEAD_OFFSET: Vector2 = Vector2(0.0, -22.0)
## The hitbox fan is this tall (BL) at its far end and narrows to a point at the head.
const WHIP_END_HEIGHT_BL: float = 0.6
## The fan's centerline droops this many px by its tip, so the lash also lands on
## short enemies (the leaper) standing level with her.
const WHIP_TIP_DROOP: float = 18.0
## Snakes drawn at full fan (3 to 5) and their line width (px).
const WHIP_SNAKES_DRAWN: int = 5
const WHIP_LINE_WIDTH: float = 4.0
## Placeholder animation, one entry per frame: coil, head back, throw, full fan,
## hold, retract, retract, neutral. Extent is the fraction of reach the snakes
## stretch (negative = pulled back behind the head), spread is how open the fan is
## (0 = snakes bundled, 1 = full hitbox width), snakes is how many are drawn.
## Anticipation shows frames 0-1, the active hitbox frames 2-3, recovery 4-7.
const WHIP_FRAME_EXTENT: Array[float] = [0.15, -0.30, 0.60, 1.0, 1.0, 0.65, 0.30, 0.0]
const WHIP_FRAME_SPREAD: Array[float] = [0.0, 0.0, 0.5, 1.0, 1.0, 0.6, 0.2, 0.0]
const WHIP_FRAME_SNAKES: Array[int] = [3, 3, 4, 5, 5, 4, 3, 0]
## How many animation frames belong to anticipation and to the active lash; the
## rest play during recovery. Each phase's frames split its time equally.
const WHIP_ANTICIPATION_FRAMES: int = 2
const WHIP_ACTIVE_FRAMES: int = 2
## Deceleration (px/s^2) of a staggered enemy sliding from a whip knockback. The
## launch speed is derived so the slide covers WHIP_KNOCKBACK_BL: v = sqrt(2 * a * d).
const ENEMY_KNOCKBACK_DECEL: float = 1600.0

# ---------------------------------------------------------------------------
# Statues
# ---------------------------------------------------------------------------
## Seconds of continuous push-contact before a statue starts sliding.
const STATUE_PUSH_DELAY: float = 0.4
## Slide speed (px/s).
const STATUE_PUSH_SPEED: float = 96.0
## Grinding loop pitch range, rising with speed.
const STATUE_GRIND_PITCH_MIN: float = 0.9
const STATUE_GRIND_PITCH_MAX: float = 1.2
## Slide acceleration (px/s^2): a short ramp to full speed, so the grind pitch rises.
const STATUE_PUSH_ACCEL: float = 480.0
## Seconds a slide keeps going after the last push contact (absorbs one-frame gaps).
const STATUE_PUSH_GRACE: float = 0.05
## How square-on the contact must be to count as a push (|normal.x| at least this).
const STATUE_PUSH_NORMAL: float = 0.7
## Gravity for a statue pushed off an edge (px/s^2).
const STATUE_GRAVITY: float = PLAYER_GRAVITY
## A statue still falling after this many seconds went into a pit and is removed.
const STATUE_MAX_FALL_TIME: float = 3.0
## Camera shake when a falling statue lands: max offset (px) and decay time (s).
const SHAKE_STATUE_LAND_PX: float = 4.0
const SHAKE_STATUE_LAND_TIME: float = 0.15
## Placeholder grinding loop, generated in code: length (s), low-pass smoothing
## (0..1, higher = duller), gain, volume (dB).
const GRIND_SFX_LENGTH: float = 0.5
const GRIND_SFX_SMOOTH: float = 0.92
const GRIND_SFX_GAIN: float = 3.0
const GRIND_SFX_VOLUME_DB: float = -10.0
## Placeholder thud, generated in code: length (s), frequency (Hz), decay rate,
## volume (dB), and pitch multiplier for a slide stopping (a landing uses 1.0).
const THUD_SFX_LENGTH: float = 0.18
const THUD_SFX_HZ: float = 55.0
const THUD_SFX_DECAY: float = 25.0
const THUD_SFX_VOLUME_DB: float = -3.0
const THUD_SFX_STOP_PITCH: float = 1.4

# ---------------------------------------------------------------------------
# Statue cracks and shatter (the whip: first hit cracks, second shatters)
# ---------------------------------------------------------------------------
## Fracture lines drawn over a cracked statue (alternating down and across), the
## zigzag segments per line, how far a zigzag strays from its straight path (as a
## fraction of the statue's shorter side), and the line widths (px): the white
## crack on top of a wider dark edge (alpha) so it still reads on marble.
const STATUE_CRACK_LINES: int = 6
const STATUE_CRACK_SEGMENTS: int = 5
const STATUE_CRACK_JITTER: float = 0.12
const STATUE_CRACK_WIDTH: float = 2.0
const STATUE_CRACK_EDGE_WIDTH: float = 4.0
const STATUE_CRACK_EDGE_ALPHA: float = 0.5
## Chip burst when a statue cracks: count, lifetime (s), spread (degrees either side
## of straight up), launch speed range (px/s), and square size range (px).
const STATUE_CHIP_COUNT: int = 10
const STATUE_CHIP_SPREAD_DEG: float = 90.0
const STATUE_CHIP_LIFETIME: float = 0.5
const STATUE_CHIP_SPEED_MIN: float = 90.0
const STATUE_CHIP_SPEED_MAX: float = 220.0
const STATUE_CHIP_SIZE_MIN: float = 2.0
const STATUE_CHIP_SIZE_MAX: float = 4.0
## Rubble burst when a statue shatters (the statue is freed once it ends); 180 degrees
## of spread is a full circle.
const STATUE_RUBBLE_COUNT: int = 32
const STATUE_RUBBLE_SPREAD_DEG: float = 180.0
const STATUE_RUBBLE_LIFETIME: float = 0.9
const STATUE_RUBBLE_SPEED_MIN: float = 80.0
const STATUE_RUBBLE_SPEED_MAX: float = 300.0
const STATUE_RUBBLE_SIZE_MIN: float = 4.0
const STATUE_RUBBLE_SIZE_MAX: float = 9.0
## Placeholder statue-crack sound: the petrify crack at this pitch (lower = heavier).
const STATUE_CRACK_SFX_PITCH: float = 0.75
## Placeholder shatter, generated in code: length (s), noise decay rate, rumble
## frequency (Hz), noise and rumble mix levels, volume (dB).
const SHATTER_SFX_LENGTH: float = 0.5
const SHATTER_SFX_DECAY: float = 9.0
const SHATTER_SFX_RUMBLE_HZ: float = 70.0
const SHATTER_SFX_NOISE_MIX: float = 0.8
const SHATTER_SFX_RUMBLE_MIX: float = 0.5
const SHATTER_SFX_VOLUME_DB: float = -4.0

# ---------------------------------------------------------------------------
# Pressure plate (scenes/props/pressure_plate.tscn)
# ---------------------------------------------------------------------------
## Width in BL, and how tall (px) the trigger zone is above the plate's surface.
## Anything standing on the floor there overlaps it; something jumping over briefly
## does too, which the plate ignores (see PressurePlate._counts).
const PLATE_WIDTH_BL: float = 1.0
const PLATE_TRIGGER_HEIGHT: float = 8.0
## Slab height (px) and how much of it is left when pressed (scale, 0..1).
const PLATE_SLAB_HEIGHT: float = 6.0
const PLATE_PRESSED_SCALE: float = 0.35

# ---------------------------------------------------------------------------
# Enemies
# ---------------------------------------------------------------------------
## Hoplite spear reach (BL) and thrust wind-up (s, shows a gold glint).
const HOPLITE_SPEAR_REACH_BL: float = 1.5
const HOPLITE_WINDUP: float = 0.35
## Gravity for all enemies (px/s^2).
const ENEMY_GRAVITY: float = PLAYER_GRAVITY
## Enemies below this y (px) fell into a pit and are removed.
const ENEMY_KILL_Y: float = 1600.0
## Player below this y (px) fell into a pit: backstop for when no Pit zone caught her.
const PLAYER_PIT_Y: float = 1400.0
## How far below the feet / ahead of the body (px) the ledge check looks.
const ENEMY_LEDGE_PROBE_DOWN: float = 24.0
const ENEMY_LEDGE_PROBE_AHEAD: float = 8.0
## The ledge ray starts this far (px) above the feet, so it never begins inside the floor.
const ENEMY_LEDGE_PROBE_INSET: float = 4.0
## Half the standing enemy body width / height (px), the ledge probe's origin.
const ENEMY_HALF_WIDTH: float = 20.0
const ENEMY_HALF_HEIGHT: float = 32.0
## Enemy bodies are solid to Medusa (she can't run through them) and touching one hurts.
## The touch zone is the body grown by this many px on every side, so a body pressed
## flat against hers still counts as touching. A whip-staggered enemy blocks but is harmless.
const ENEMY_CONTACT_MARGIN: float = 2.0
## A replacement leaper (owed after a pit fall) waits until Medusa is at least this many
## BL from its spawn point, so it never appears inside her.
const LEAPER_RESPAWN_CLEARANCE_BL: float = 2.0
## Size (px) of the hoplite's gold wind-up glint.
const HOPLITE_GLINT_SIZE: float = 10.0
## Hoplite art geometry, matching scenes/enemies/hoplite.tscn: the Glint
## polygon's radius and the spear tip's x in the Visual's right-facing space (px).
const HOPLITE_GLINT_ART_RADIUS: float = 5.0
const HOPLITE_SPEAR_TIP_X: float = 52.0

## Hoplite: patrol speed, chase speed (px/s), patrol half-width (BL), notice
## range (BL), vertical slack for "same level" (BL), thrust active time and
## recovery after the thrust (s), thrust hitbox thickness (px), and how far
## the spear is drawn back during the wind-up (px).
const HOPLITE_PATROL_SPEED: float = 50.0
const HOPLITE_CHASE_SPEED: float = 90.0
const HOPLITE_PATROL_BL: float = 2.0
const HOPLITE_NOTICE_BL: float = 5.0
const HOPLITE_LEVEL_SLACK_BL: float = 1.0
const HOPLITE_THRUST_ACTIVE: float = 0.12
const HOPLITE_RECOVERY: float = 0.5
const HOPLITE_HITBOX_THICKNESS: float = 14.0
const HOPLITE_SPEAR_DRAW_BACK: float = 16.0

## Leaper: leap trigger range (BL), vertical slack (BL), nearest target (BL),
## leap apex height (BL), fastest horizontal leap speed (px/s), pause after
## landing (s) and minimum landing time before it counts (s).
const LEAPER_RANGE_BL: float = 6.0
const LEAPER_LEVEL_SLACK_BL: float = 2.0
const LEAPER_MIN_DISTANCE_BL: float = 1.0
const LEAPER_APEX_BL: float = 1.5
const LEAPER_MAX_SPEED: float = 500.0
const LEAPER_RECOVERY: float = 0.8
const LEAPER_MIN_AIR_TIME: float = 0.1
## Spacing (px) of the floor samples between the leaper and the player when
## checking she is across a gap (smaller than any gap worth leaping).
const LEAPER_GAP_PROBE_STEP: float = 16.0

## Archer: sees the player within this range (BL) and in line of sight; draw time (s,
## gold glint on the arrowhead), cooldown between shots (s), arrow launch speed (px/s)
## and gravity (px/s^2), how much of the player's motion it leads (0 = aims at her
## feet-first position, 1 = full lead), where the arrow leaves the body (px from the
## center, facing side), glint size (px, the art's radius is ARCHER_GLINT_ART_RADIUS).
const ARCHER_RANGE_BL: float = 9.0
const ARCHER_DRAW_TIME: float = 0.5
const ARCHER_COOLDOWN: float = 2.5
const ARCHER_LEAD: float = 0.5
const ARCHER_MUZZLE: Vector2 = Vector2(26.0, -8.0)
const ARCHER_GLINT_SIZE: float = 10.0
const ARCHER_GLINT_ART_RADIUS: float = 5.0
## Arrow: speed (px/s), gravity (px/s^2), seconds it stays stuck in a wall or statue
## before fading away, seconds it may fly before it is dropped, and its length (px).
const ARROW_SPEED: float = 700.0
const ARROW_GRAVITY: float = 600.0
const ARROW_STUCK_TIME: float = 4.0
const ARROW_MAX_FLIGHT: float = 3.0
const ARROW_LENGTH: float = 28.0

## Mirror-bearer: patrol and chase speeds (px/s), patrol half-width (BL), notice range
## (BL), vertical slack (BL), the gap he keeps from Medusa (BL), mirror glint period
## and flash length (s), seconds between reflected gazes (matches her invulnerability),
## and how long the gold reflection beam is drawn (s) and how wide (px).
const MIRROR_PATROL_SPEED: float = 50.0
const MIRROR_CHASE_SPEED: float = 80.0
const MIRROR_PATROL_BL: float = 2.0
const MIRROR_NOTICE_BL: float = 6.0
const MIRROR_LEVEL_SLACK_BL: float = 1.0
const MIRROR_STOP_BL: float = 1.5
const MIRROR_GLINT_PERIOD: float = 1.0
const MIRROR_GLINT_TIME: float = 0.15
const MIRROR_REFLECT_COOLDOWN: float = 1.0
const MIRROR_BEAM_TIME: float = 0.25
const MIRROR_BEAM_WIDTH: float = 5.0
## Mirror centre relative to the body, facing side (px); the knocked-aside mirror
## swings by this many degrees (it hangs down and away from the gaze).
const MIRROR_HELD_OFFSET: Vector2 = Vector2(26.0, -10.0)
const MIRROR_KNOCK_DEG: float = 80.0
const MIRROR_GLINT_SIZE: float = 14.0
const MIRROR_GLINT_ART_RADIUS: float = 5.0

## DEFAULT size of the level 1 gap (BL): the open space between the near and far ledges
## in scenes/test_room.tscn, where the leaper first shows up. This is the default size;
## it was 5.0 BL until it was shrunk by half a body length on 2026-11-02. The scene holds
## the real geometry (LedgeNear's right edge to LedgeFar's left edge); sim_enemies.gd
## fails if the scene and this number ever disagree, so change them together.
const LEVEL1_GAP_BL: float = 4.5

## Player hurt: stun time (s), invulnerability (s), flicker half-period (s),
## knockback launch speed (px/s, x and upward y), and friction while stunned.
const PLAYER_HURT_TIME: float = 0.5
const PLAYER_INVULN_TIME: float = 1.0
const PLAYER_FLICKER_PERIOD: float = 0.08
const PLAYER_FLICKER_ALPHA: float = 0.3
const PLAYER_KNOCKBACK_X: float = 240.0
const PLAYER_KNOCKBACK_Y: float = 220.0
const PLAYER_HURT_FRICTION: float = 400.0

## Test dummy: walk speed (px/s), patrol half-width (BL), seconds between jumps,
## jump launch speed (negative = up; apex ~1.6 BL, ~0.67 s in the air).
const DUMMY_WALK_SPEED: float = 80.0
const DUMMY_PATROL_BL: float = 2.0
const DUMMY_JUMP_INTERVAL: float = 3.0
const DUMMY_JUMP_VELOCITY: float = -600.0

# ---------------------------------------------------------------------------
# Portrait (the only HUD) - cracks needed to advance each stage
# Stage 1 Defiant, 2 Rage, 3 Grief, 4 Exhaustion, 5 Stone (20 total = death)
# ---------------------------------------------------------------------------
const PORTRAIT_STAGE_COUNT: int = 5
const PORTRAIT_THRESHOLDS: Array[int] = [6, 5, 4, 3, 2]
## Crack costs by source.
const CRACKS_PETRIFY: int = 1
const CRACKS_HIT: int = 1        # hoplite, leaper, arrow
const CRACKS_PIT: int = 1
const CRACKS_REFLECT: int = 2    # own gaze reflected by a mirror
const CRACKS_PERSEUS: int = 2    # any Perseus attack
## Stage a player respawns at after death (0 cracks).
const DEATH_RESPAWN_STAGE: int = 2

# ---------------------------------------------------------------------------
# Portrait HUD (scenes/ui/portrait_hud.tscn): wordless, top-left
# ---------------------------------------------------------------------------
## Shield width = height (px) and gap from the screen corner (px).
const HUD_SIZE: float = 140.0
const HUD_MARGIN: float = 16.0
## Width (px) of the round frame's rim, and the frame's segments (more = rounder).
const HUD_FRAME_WIDTH: float = 6.0
const HUD_CIRCLE_SEGMENTS: int = 48
## Placeholder painting per stage, bright (Defiant) to gray (Stone).
const PORTRAIT_STAGE_COLORS: Array[Color] = [
	Color("F2D9A0"), Color("D9A066"), Color("B07A55"), Color("8A7468"), Color("6B6B6B"),
]
## Hairline cracks: line width (px), zigzag points per crack, how far the zigzag
## strays (fraction of the shield radius), how deep a crack reaches (fraction of
## the radius, from the rim inward), and how far it may lean off the straight line.
const CRACK_LINE_WIDTH: float = 2.0
## The wider dark edge drawn under each hairline (width px, alpha) so it reads on a bright painting.
const CRACK_EDGE_WIDTH: float = 4.0
const CRACK_EDGE_ALPHA: float = 0.55
const CRACK_POINTS: int = 5
const CRACK_JITTER: float = 0.12
const CRACK_REACH_MIN: float = 0.55
const CRACK_REACH_MAX: float = 0.95
## White flash over the shield on a stage change: peak alpha and fade time (s).
const HUD_FLASH_ALPHA: float = 0.9
const HUD_FLASH_TIME: float = 0.3
## Flinch on a hit: shake (px), scale dip and time (s).
const HUD_FLINCH_PX: float = 6.0
const HUD_FLINCH_SCALE: float = 0.9
const HUD_FLINCH_TIME: float = 0.22
## Snap on a petrify: scale pop and time (s).
const HUD_SNAP_SCALE: float = 1.12
const HUD_SNAP_TIME: float = 0.14
## Soften at a pool: warm glow peak alpha and fade time (s).
const HUD_SOFTEN_ALPHA: float = 0.55
const HUD_SOFTEN_TIME: float = 0.9
## Soften at a pool: the shield swells by this scale as the glow fades.
const HUD_SOFTEN_SCALE: float = 1.05
## Side (px) of the placeholder painting textures generated in code (round, solid color).
const HUD_TEXTURE_SIZE: int = 128
## Shield canvas layer, above the world. The death desaturate sits just below it.
const HUD_LAYER: int = 10

# ---------------------------------------------------------------------------
# Touch controls (scenes/ui/touch_controls.tscn): on-screen buttons for phones
# ---------------------------------------------------------------------------
# Positions are in game pixels on the 1280 x 720 screen (centre of each button).
# Left thumb: walk left / right, with a small kneel button above them.
const TOUCH_LEFT_POS: Vector2 = Vector2(130.0, 590.0)
const TOUCH_RIGHT_POS: Vector2 = Vector2(310.0, 590.0)
const TOUCH_DOWN_POS: Vector2 = Vector2(220.0, 440.0)
# Right thumb: gaze (hold), whip (tap), jump (hold for height).
const TOUCH_GAZE_POS: Vector2 = Vector2(1090.0, 420.0)
const TOUCH_WHIP_POS: Vector2 = Vector2(960.0, 600.0)
const TOUCH_JUMP_POS: Vector2 = Vector2(1150.0, 590.0)
# Button radii (px). About 9 mm or more on a phone held in landscape.
const TOUCH_MOVE_RADIUS: float = 76.0
const TOUCH_DOWN_RADIUS: float = 56.0
const TOUCH_ACTION_RADIUS: float = 80.0
## A finger counts as on a button up to this many radii from its centre (forgiving thumbs).
const TOUCH_HIT_SCALE: float = 1.25
## Disc and icon opacity while idle and while a finger is down (idle stays see-through).
const TOUCH_IDLE_DISC_ALPHA: float = 0.32
const TOUCH_PRESSED_DISC_ALPHA: float = 0.65
const TOUCH_ICON_ALPHA: float = 0.8
## Width (px) of the ring around each button and of the whip/arrow strokes.
const TOUCH_RING_WIDTH: float = 5.0
const TOUCH_ICON_STROKE: float = 7.0
## Pressed buttons shrink to this scale.
const TOUCH_PRESSED_SCALE: float = 0.92
## Segments for round shapes (more = rounder).
const TOUCH_CIRCLE_SEGMENTS: int = 40
## "Turn your phone sideways" overlay: size of the phone icon (px), stroke width (px) and
## seconds per half turn. Big on purpose: held upright the whole 1280 px width shrinks to
## about a third, so a small picture would be unreadable.
const TOUCH_ROTATE_PHONE_SIZE: Vector2 = Vector2(280.0, 460.0)
const TOUCH_ROTATE_STROKE: float = 16.0
const TOUCH_ROTATE_TURN_TIME: float = 1.1
## Touch layer, above the portrait HUD.
const TOUCH_LAYER: int = 20
## Double-tap sprint: tap a direction button, lift, and press the SAME direction again within
## this many seconds; she sprints (like holding Shift) until that finger lifts or slides off.
const TOUCH_DOUBLE_TAP_WINDOW: float = 0.25
## While sprinting, a gold second arrow (a "double chevron") shows beside the direction
## arrow. Its tip x, back x and half-height, as fractions of the button radius.
const TOUCH_SPRINT_MARK_TIP: float = 0.84
const TOUCH_SPRINT_MARK_BACK: float = 0.46
const TOUCH_SPRINT_MARK_HALF: float = 0.30

# ---------------------------------------------------------------------------
# Respawn props and death
# ---------------------------------------------------------------------------
## Distance (px) from Medusa's center to her feet; props sit on the floor, she is placed
## this far above them.
const PLAYER_FEET_OFFSET: float = 32.0
## Safe ledge marker: trigger size (BL) and the flag drawn on it (px).
const SAFE_LEDGE_WIDTH_BL: float = 1.0
const SAFE_LEDGE_HEIGHT_BL: float = 1.5
const SAFE_LEDGE_POLE_HEIGHT: float = 44.0
const SAFE_LEDGE_FLAG_SIZE: float = 14.0
## Pit kill zone default size (BL). A scene can override it per instance.
const PIT_WIDTH_BL: float = 6.0
const PIT_HEIGHT_BL: float = 6.0
## Mirror pool: width and trigger height (BL), basin depth (px), and seconds of standing
## still inside before it heals without a kneel.
const POOL_WIDTH_BL: float = 2.0
const POOL_HEIGHT_BL: float = 1.0
const POOL_DEPTH: float = 8.0
const POOL_STAND_TIME: float = 1.0
## Death: seconds to turn to marble, hold as a statue, and fade the screen back.
const DEATH_STONE_TIME: float = 1.0
const DEATH_HOLD_TIME: float = 0.5
const DEATH_FADE_BACK_TIME: float = 0.4

# ---------------------------------------------------------------------------
# Perseus (boss)
# ---------------------------------------------------------------------------
const PERSEUS_PHASES: int = 3
## Gaze hits needed per phase.
const PERSEUS_GAZE_HITS_PER_PHASE: int = 2
## Base shield-down window after each attack (s).
const SHIELD_WINDOW_BASE: float = 1.0
## Adapted window = clamp(median reaction + OFFSET, MIN, MAX).
const SHIELD_WINDOW_ADAPT_OFFSET: float = 0.15
const SHIELD_WINDOW_MIN: float = 0.45
const SHIELD_WINDOW_MAX: float = 1.0
## How many of the player's last gazes the mirror replays in the study beat.
const PERSEUS_ECHO_COUNT: int = 3

# ---------------------------------------------------------------------------
# AI Worker (Cloudflare Worker that talks to the LLM / image models)
# ---------------------------------------------------------------------------
## Base URL of the deployed Worker. Replace CHANGE-ME with the real workers.dev subdomain
## after `wrangler deploy`. No keys live here: the Worker holds the secrets.
const WORKER_URL: String = "https://medusas-price-worker.medusas-price-worker-dark-roots-creations.workers.dev"
## Seconds before a /test request gives up (image models can be slow on a cold start).
const AI_TEST_TIMEOUT_S: float = 60.0
## Debug-build F10 test image: longest side (px) and where its center sits in the
## 1280x720 screen (upper middle; drawn on its own CanvasLayer, so the follow camera
## does not move it).
const AI_DEBUG_SPRITE_SIZE: float = 512.0
const AI_DEBUG_SPRITE_POS: Vector2 = Vector2(640.0, 300.0)
## Origin header sent on desktop (non-web) runs. Browsers set Origin themselves; the
## Worker only answers allowlisted origins, and it allows http://localhost on any port.
const AI_DESKTOP_ORIGIN: String = "http://localhost"

# ---------------------------------------------------------------------------
# Level kit (scenes/levels/level_base.tscn) and level flow (autoload GameFlow)
# ---------------------------------------------------------------------------
## Side of one terrain tile in px (2 tiles = 1 BL). The placeholder tileset uses it.
const TILE_SIZE: int = 32
## Tint multiplied over the whole level (CanvasModulate) for each time of day.
## Noon: warm and bright. Dusk: orange-violet. Torchlight: dark (torches add light back).
## Storm: desaturated blue.
const LIGHT_NOON: Color = Color(1.0, 0.95, 0.84)
const LIGHT_DUSK: Color = Color(0.95, 0.62, 0.68)
const LIGHT_TORCH: Color = Color(0.16, 0.13, 0.18)
const LIGHT_STORM: Color = Color(0.48, 0.55, 0.68)
## Storm lightning: seconds between flashes (random in this range), the flash color,
## and how long the flash holds and then fades back. Two flashes in a row feel like thunder.
const LIGHTNING_MIN_S: float = 6.0
const LIGHTNING_MAX_S: float = 12.0
const LIGHTNING_COLOR: Color = Color(0.92, 0.96, 1.0)
const LIGHTNING_HOLD_S: float = 0.06
const LIGHTNING_FADE_S: float = 0.25
const LIGHTNING_DOUBLE_GAP_S: float = 0.12
## Torch (scenes/props/torch.tscn): light radius (px), strength, flicker amount (fraction
## of strength) and speed (changes per second).
const TORCH_RADIUS: float = 220.0
const TORCH_ENERGY: float = 1.3
const TORCH_FLICKER: float = 0.2
const TORCH_FLICKER_RATE: float = 12.0
## Level exit door: width and height in BL.
const LEVEL_EXIT_WIDTH_BL: float = 1.0
const LEVEL_EXIT_HEIGHT_BL: float = 2.0
## Fade to black between levels: seconds out and seconds back in.
const FADE_OUT_S: float = 0.35
const FADE_IN_S: float = 0.35
## Victim statue (scenes/props/victim_statue.tscn): body size (px) when standing, and
## the shorter body height (px) of the crouched pose. The feet stay where a standing
## enemy's feet would be, so it sits on the floor like any statue.
const VICTIM_BODY_SIZE: Vector2 = Vector2(40.0, 64.0)
const VICTIM_CROUCH_HEIGHT: float = 40.0
