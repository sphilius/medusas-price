# itch.io page: Medusa's Price

Paste each block into the matching field on **kingriot.itch.io/medusas-price → Edit game**.
Images to upload are in this folder: `cover_630x500.png` (Cover image) and `screens/` (Screenshots).

---

## Title
Medusa's Price

## Short description / tagline (shows under the title in listings)
Your gaze turns heroes to stone. Every statue ages your portrait.

## Genre
Platformer

## Tags (itch allows up to 10)
platformer, 2D, greek-mythology, medusa, art, boss-battle, short, godot, game-jam, atmospheric

## Kind of project / embed settings
- HTML · "This file will be played in the browser" on the html5 build
- Viewport: **1280 × 720**, tick **Fullscreen button** and **Mobile friendly** (touch buttons appear on phones), orientation **Landscape**
- Tick **Automatically start on page load**: off (the title card waits for a key anyway)

---

## Description (main body)

**You are Medusa. They are coming for you.**

Heroes climb the temple steps to take your head. Your gaze turns them to marble, and the statues become the platforms you climb, the blocks you push, the bridges you cross.

But every hero you turn to stone ages your portrait. It is your only health bar: a painted shield in the manner of Caravaggio that sinks from **Defiant** to **Rage**, **Grief**, **Exhaustion** and finally **Stone**. Your face never changes. Your portrait does.

Fight with your snake hair instead and you keep your youth, but heroes take 4 to 7 lashes, archers stay out of reach, and mirror-bearers throw your own gaze back at you. There is one healing pool per level. Use it well.

At the cave mouth, Perseus waits with a mirror for a shield.

**A game with no words.** No text, no numbers, no menus to read. The whole world is an Attic black-figure vase painting: black bodies in motion, terracotta earth, marble for stone and cost, gold for danger and power.

### Controls

| | Keyboard | Touch |
|---|---|---|
| Move | A / D or ← / → | left / right buttons |
| Jump | Space (hold for higher) | jump button |
| Sprint | hold Shift (carries through a jump) | double-tap and hold a direction |
| Snake whip | J | whip button |
| Gaze | hold K | gaze button |
| Push a statue | walk into it and keep holding | same |

**Tips without spoilers:** lash an enemy while its weapon glints gold to parry. A parried enemy can be finished by your snakes. Statues jam spike traps. Gold shards mend the portrait a little.

### About

Made in 5 days for **Jamference AI Game Jam Hack 3**, theme *Great Works of Art*.

- **The run vase:** when you beat Perseus, your run is painted onto a black-figure amphora. A small Claude model reads what happened (who you petrified, how you fought, how old your portrait got) and writes a frieze, an image model paints it, and a check makes sure no letters sneak onto the pot. If anything fails or you are offline, a hand-made vase appears instead.
- **Perseus learns:** he watches how fast you react when his shield drops and which side you guard least, then shortens his window and attacks from your blind side.
- **The score** follows the portrait: five loops, one per stage, thinning as she ages.

Built with Godot 4 (Compatibility renderer, WebGL2) and Claude Code. Art made with Nano Banana from hand-written briefs, cleaned up and palette-locked by script. Music made with ElevenLabs.

### Credits

- Design, direction, art direction, music: **Sasha (kingriot)**
- Code: Sasha with Claude Code
- Sound effects (all CC0, freesound.org): stone21, Stone_in_Focus_FILMish, magnuswaker, OutbreakProtocol, dslrguide, SciFiSounds, CrownieYT, saturdaysoundguy, GameAudio, qubodup, C_Rogers, Deathscyp, rokenjocu, saha213131, arseniiv
- Portrait after *Medusa* by Caravaggio (1597–98, public domain)

Best in Chrome or Firefox on desktop. About 10 to 15 minutes to finish.

---

## Jam submission field (if the jam form asks for "How did you use AI?")

AI is in the pipeline and in the game. Pipeline: art from Nano Banana briefs, music from ElevenLabs, code with Claude Code. In the game: the run vase (Claude writes a wordless frieze from your run log, an image model paints it, a letter check rejects any writing, fallback vase offline), and Perseus adapts his shield window and attack side to how you play. No API keys ship in the build; the AI calls go through a rate-limited Cloudflare Worker.
