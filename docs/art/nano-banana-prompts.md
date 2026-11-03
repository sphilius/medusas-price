# Medusa's Price: Nano Banana art prompt pack

Copy-paste prompts for Nano Banana (Gemini image models). **Phase 1** makes concept art. You pick the finals. **Phase 2** feeds those finals back in as reference images to make the real game assets.

---

## 1. Recommendation: black-figure vase style (flat colour, vector look, exported as PNG)

**Use neither pixel art nor generic vector.** Make the world look like an **Attic black-figure Greek vase painting**:

- Living bodies are solid black silhouettes in profile, with thin terracotta lines "scratched" into them.
- They stand on flat terracotta clay.
- **Petrified things switch to the "white-ground" vase style**: marble-white figures with black lines.
- **One exception: the portrait HUD** is a painted Baroque oil in the manner of Caravaggio. It is the only "painting" in a world of pottery, so the eye finds it instantly.

The files are ordinary PNGs drawn in a flat, vector-like style. You don't need SVGs.

### Why this beats the alternatives

| | Pixel art | Generic vector / painterly | **Black-figure (recommended)** |
|---|---|---|---|
| Can Nano Banana make it cleanly? | ❌ No. It fakes pixel art: mixed pixel sizes, blurry edges, a grid that moves between frames. Every frame needs hand cleanup in Aseprite. | ⚠️ Painterly detail changes from frame to frame, so animation flickers. | ✅ Yes. Flat silhouettes are its strongest case, and the silhouette hides small frame-to-frame differences. |
| Cleanup time | Hours per character | Medium | **Minutes**: remove the magenta, then snap to the palette |
| Fits "Great Works of Art" | Weak. The art reference gets lost. | Okay, but reads as stock art. | **Strong.** The whole game *is* a vase painting, and the run vase feature ends the run as one. |
| Fits your colour code | You'd have to adapt it | You'd have to adapt it | **It already is your colour code**: terracotta = living world, black = bodies in motion, marble = stone, gold = danger |
| Petrify effect | Needs a second set of art | Needs a second set of art | **One palette-swap shader** (black → marble, terracotta lines → black). Black-figure turns into white-ground, which is a real art-history shift. |
| Readable at 64 px | Yes | Muddy under the CanvasModulate tints | Yes. Gold telegraphs pop against black. |

**The deciding factor is the deadline.** With about 69 hours left, the style that needs the least cleanup per frame wins, and the flat 4-colour silhouette needs the least.

### ⚠️ Scope flag
This pack has about 30 prompts. **Do Tier 1 only until it is all in the game.** After each character, export a web build and keep it playable (project workflow rule).

| Tier | What | When |
|---|---|---|
| **1: ship-critical** | C0, C1, C2, C4 → Medusa ×2 sheets, 4 enemy sheets + eye-shading edit, detachables, 5 portraits, 4 backgrounds, itch cover | Tue Nov 3 to Wed Nov 4 |
| **1\*: if the boss ships** | C3 → Perseus sheet | Wed Nov 4 |
| **2: polish** | Victim statues, props, title and ending cards, splash icon, vase fallback, terrain texture | Thu Nov 5, before 6 PM ET |
| **3: only if bored** | Touch icons | never, probably |

---

## 2. Palette (use it in every prompt)

| Role | Hex | Used for |
|---|---|---|
| Black | `#1A1410` | living bodies, outlines |
| Terracotta | `#C8643B` | background clay, incised lines inside black figures |
| Clay dark | `#7A3A22` | terrain, architecture (*new: a darker terracotta so the ground separates from the sky*) |
| Clay pale | `#E2A27A` | faded far-background shapes (*new*) |
| Marble | `#F2EFE8` | stone, statues, cost |
| Gold | `#E8B547` | eyes, gaze, glints, mirrors: danger and power only |
| Magenta | `#FF00FF` | **sprite-sheet background only**: you key it out, so it never appears in the game |

---

## 3. Workflow (follow in order)

1. 🎨 **Concept (Phase 1).** Run each C-prompt on **Nano Banana 2 at 1K** (cheap and fast). Re-roll about 3 to 4 times and pick a favourite.
2. 🔁 **Polish the pick.** Re-run it with your favourite attached and add "refine this, same design", at **2K**.
3. 💾 **Save the finals** to `art/concept/` with exactly these names: `C0_style.png`, `C1_medusa.png`, `C2_enemies.png`, `C3_perseus.png`, `C4_portrait.png`, `C5a_temple.png`, `C5b_cliffs.png`, `C5c_cave.png`, `C5d_storm.png`, `C6_stone.png`.
4. 🏭 **Production (Phase 2).** Run each P-prompt on **Nano Banana Pro at 2K**, with the listed `art/concept/` files attached. Pro holds a character steady across many reference images better than the other models.
5. 🩹 **Fix single frames by editing, not re-rolling.** Attach the sheet and say "keep everything, only change pose 6 so that…". Nano Banana is much better at edits than at hitting a full sheet in one shot.
6. ✂️ **Clean up** (section 6): key out the magenta, snap to the palette, slice into frames, scale to 2× game size.
7. 🎮 **Import into Godot** one character at a time, then test a web export.

**Fixed conventions for every sprite:** side profile, **facing right** (code flips it), feet on a shared baseline, magenta background, no ground shadow.

**Cost estimate** (prices from the composer catalog; check current pricing): about 40 concept images × $0.067 ≈ **$2.70**, plus about 90 production images × $0.134 ≈ **$12**. Roughly **$15 total**.

---

## 4. Phase 1: Concept art

### C0 · Style frame (the master reference) · Tier 1
**Model:** Nano Banana 2 · **Aspect:** 16:9 · **Res:** 1K, then 2K for the final · **Attach:** nothing

```text
A wide side-view gameplay scene for a 2D action platformer, drawn as a flat ancient Greek Attic black-figure vase frieze (a flat painted band, not a picture of a vase). Medusa, a slender young woman whose hair is a mane of living snakes, runs up the steps of a Doric temple at noon while three Greek hoplite soldiers with tall crested helmets and long spears charge down toward her. One soldier, caught in her gaze, has already turned to white marble mid-stride. A soft cone of gold light spreads from Medusa's eye toward the soldiers.

Style: every living figure is a solid near-black (#1A1410) silhouette in strict side profile, with thin incised lines in terracotta orange (#C8643B) showing muscles, cloth folds and armor edges. The background is flat unglazed terracotta clay (#C8643B). The temple, columns and steps are a darker fired-clay brown (#7A3A22) with black outlines. The petrified soldier is flat marble white (#F2EFE8) with fine black incised lines. Gold (#E8B547) appears only in Medusa's eye and the gaze cone. A Greek key meander border runs along the top edge.

Flat fills only: no gradients, no 3D shading, no texture noise, no glossy highlights. Clear silhouettes, figures at the size of gameplay sprites, generous empty space around them. No text, no letters, no Greek inscriptions, no signatures, no watermark.
```
**Watch for:** Greek letters sneaking in (vases often carry inscriptions, so re-roll if you see any) · figures turned to a 3/4 view · a curved vase shape instead of a flat band · gold spreading onto other things.

---

### C1 · Medusa design · Tier 1
**Model:** Nano Banana 2 · **Aspect:** 16:9 · **Res:** 1K · **Attach:** `C0_style.png`

**Step A: pick a design (3 options):**
```text
Character design sheet for Medusa, the player character of a 2D platformer, in exactly the black-figure vase style of the attached reference. Show three design options side by side, full body, strict side profile facing right, standing pose, all the same height, on a perfectly flat solid magenta (#FF00FF) background with wide gaps between them.

Option 1 (left): a tragic young woman in a knee-length belted chiton, bare legs and feet, hair of 6 to 8 thick snakes coiling back and upward, every snake head visible.
Option 2 (middle): an archaic gorgon: the same, plus small swept-back wings at her shoulder blades and a fiercer face.
Option 3 (right): a huntress: a short chiton with a cloak streaming behind her, snakes bound back in one heavy coil like a ponytail.

All three: one bright gold (#E8B547) almond-shaped eye in the profile face. A solid near-black (#1A1410) silhouette body with thin incised terracotta (#C8643B) detail lines. Legs clearly separated so a run cycle will read. Proud and sorrowful, not monstrous. Flat fills, no gradients, no shading, crisp hard edges, bold shapes that still read at 64 pixels tall. No text, no letters, no inscriptions, no watermark.
```
**Recommended pick:** Option 1. The bare legs read best in a run cycle, and the snakes alone make the silhouette unmistakable.

**Step B: model sheet of the chosen design** (attach `C0_style.png` plus your pick):
```text
Model sheet of the attached Medusa design, same black-figure vase style, on flat solid magenta (#FF00FF). Four key poses side by side, all strict side profile facing right, same scale, feet on one shared baseline, wide gaps between poses:
1. standing still,
2. mid-run stride,
3. mid-jump with knees tucked,
4. whip attack: her snake hair lashes forward in a fan of 4 snakes reaching about twice her body height ahead of her.
Keep the costume, the proportions, the number of snakes and the single gold (#E8B547) eye identical in every pose. Flat fills, no gradients, no shading, crisp edges. No text, no letters, no watermark.
```
→ Save Step B as `C1_medusa.png`.

---

### C2 · Enemy lineup · Tier 1
**Model:** Nano Banana 2 · **Aspect:** 16:9 · **Res:** 1K → 2K · **Attach:** `C0_style.png`, `C1_medusa.png`

```text
Enemy lineup sheet for a 2D platformer, in exactly the black-figure vase style of the attached references, on a flat solid magenta (#FF00FF) background. Six figures in a row, full body, strict side profile facing right, wide gaps between them. On the far left, for scale only, the attached Medusa standing. Then five Greek enemies, each about Medusa's height unless noted:

1. Hoplite: bronze Corinthian helmet with a tall horsehair crest, muscled cuirass, greaves, a round hoplon shield on his far arm with an incised terracotta blazon, holding a long spear level at hip height pointing forward.
2. Eye-shading hoplite: the same soldier without a shield, his free hand raised flat across his brow to shield his eyes, spear in the other hand.
3. Leaper: a lean light-armed skirmisher, no armor, a Thracian cap, a crescent-shaped wicker shield, a short sword; crouched low and coiled, wider than he is tall, ready to spring.
4. Scythian archer: a tall pointed soft cap with long side flaps, diamond-patterned sleeves and leggings shown with incised lines, a curved composite bow and a bow-case quiver at the hip.
5. Mirror-bearer: a helmeted soldier holding a large round polished mirror on a short handle up in front of his face with both hands; the mirror's face is gold (#E8B547) with a black rim.

All bodies are solid near-black (#1A1410) silhouettes with thin incised terracotta (#C8643B) detail lines. Gold appears only on the mirror face and as a tiny glint on the spearhead. Each enemy must be recognizable by silhouette alone. Flat fills, no gradients, no shading, crisp edges, bold shapes that read at 64 pixels tall. No text, no letters, no Greek inscriptions, no watermark.
```
**Watch for:** enemies drawn larger than Medusa · the archer looking like a hoplite (the pointed cap is his tell) · gold on the helmets.

---

### C3 · Perseus · Tier 1\*
**Model:** Nano Banana 2 · **Aspect:** 16:9 · **Res:** 1K → 2K · **Attach:** `C0_style.png`, `C1_medusa.png`, `C2_enemies.png`

```text
Boss design sheet for Perseus, the final boss of a 2D platformer, in exactly the black-figure vase style of the attached references, on flat solid magenta (#FF00FF). Strict side profile facing right, wide gaps. Far left: the attached Medusa standing, for scale; Perseus is about a quarter taller than her. Then Perseus in three phase poses:

1. Flight: hovering in the air on winged sandals, knees bent, a sickle-sword (harpe) raised.
2. Grounded: feet planted, a large round polished bronze shield held forward like a mirror, its face gold (#E8B547) with a black rim, harpe drawn back.
3. Desperate: charging forward with his shoulder behind the shield in a full-body shield bash, cloak torn and flying.

Costume: a winged cap, winged sandals, a short chlamys cloak, a satchel (kibisis) at his hip, an athletic heroic build. Solid near-black (#1A1410) body with thin incised terracotta (#C8643B) lines; gold only on the shield face and the sandal wings. Flat fills, no gradients, no shading, crisp edges. No text, no letters, no inscriptions, no watermark.
```

---

### C4 · Portrait HUD style test (stage 1, Defiant) · Tier 1
**Model:** Nano Banana Pro · **Aspect:** 1:1 · **Res:** 1K → 2K · **Attach:** nothing (the C1 Medusa is optional, for snake count)

```text
A Baroque oil painting of the severed-yet-living head of Medusa painted on a round convex parade shield, in the manner of Caravaggio's Medusa of 1597: dramatic tenebrist chiaroscuro, a single hard light from the upper left, a dark olive-green shield face behind the head, warm living skin, a crown of writhing snakes in deep greens and bronzes spreading outward toward the rim.

Her expression is DEFIANT: chin raised, lips pressed shut, brows low, eyes narrowed and staring straight at the viewer, gold-flecked irises.

Composition for a small game HUD: the round shield fills the whole square image edge to edge; a thin gilded rim only; the head fills about 70 percent of the circle; strong simple light and dark masses so the face still reads when shrunk to 128 pixels. Everything outside the circle is flat solid magenta (#FF00FF). Visible brushwork and craquelure are fine. No text, no signature, no watermark.
```
**Watch for:** a copy of Caravaggio's scream (stage 2 uses that, stage 1 must stare) · a busy background · the head too small.
→ Save as `C4_portrait.png`. **If you love it, it is also the production stage-1 asset (P10a).**

---

### C5 · Level environments (4 prompts) · Tier 1
**Model:** Nano Banana 2 · **Aspect:** 21:9 · **Res:** 1K → 2K · **Attach:** `C0_style.png`

Run the shared prompt once per level, replacing `{SCENE}` with the matching text below.

```text
A wide side-scrolling 2D platformer background, drawn as a flat ancient Greek black-figure vase frieze in exactly the style of the attached reference. {SCENE}

This image sits BEHIND gameplay, so keep it calm and low-contrast: mostly flat terracotta (#C8643B) and pale clay (#E2A27A), with scenery shapes in dark clay brown (#7A3A22) and only thin black (#1A1410) outlines. No people, no animals, no characters. Keep the bottom fifth of the image simple and empty (the ground tiles go there). Lighting is flat and even (the game tints it for time of day). A Greek key meander band runs along the top edge. Flat fills, no gradients, no 3D shading, no texture noise. No text, no letters, no Greek inscriptions, no watermark.
```

| File | `{SCENE}` |
|---|---|
| `C5a_temple.png` | `Level 1, Temple Steps at noon: broad stone steps climbing from left to right toward a Doric temple facade, fluted columns, a triangular pediment, olive trees and a round sun disc.` |
| `C5b_cliffs.png` | `Level 2, Cliffs over the Sea at dusk: jagged sea cliffs with narrow ledges, the sea below drawn as a band of stylized running-wave scrolls, a low sun disc, a few distant cypress trees on the cliff tops.` |
| `C5c_cave.png` | `Level 3, Cave of Statues by torchlight: a deep cave with hanging stalactites and rough rock walls, and in the background faint marble-white (#F2EFE8) silhouettes of many frozen victims in poses of terror, standing like a gallery.` |
| `C5d_storm.png` | `Level 4, the Cave Mouth in a storm: a wide cave opening onto a stormy sea, jagged gold (#E8B547) zigzag lightning in the sky, rain drawn as fine diagonal incised lines, a low round stone pool in the center of the floor.` |

---

### C6 · Stone language (statues, cracks, rubble) · Tier 2
**Model:** Nano Banana 2 · **Aspect:** 16:9 · **Res:** 1K → 2K · **Attach:** `C0_style.png`, `C2_enemies.png`

```text
Reference sheet for petrified figures in a 2D platformer, on flat solid magenta (#FF00FF). Style: Greek WHITE-GROUND vase painting: figures are flat marble white (#F2EFE8) with fine near-black (#1A1410) incised lines, the exact inverse of the attached black-figure soldiers. Strict side profile, facing right, wide gaps between items.

Top row: the attached hoplite frozen mid-lunge as a statue in three states: (1) intact; (2) cracked: black fracture lines spidering across the whole body; (3) shattered: a low pile of marble rubble chunks.
Bottom row: four ancient victim statues of ordinary Greek men and women: (1) standing, (2) both arms raised to shield the face, (3) crouched and cowering, (4) fleeing mid-stride, looking back over the shoulder.

Flat fills, no gradients, no 3D shading, no texture noise, crisp edges, bold shapes that read at 64 pixels tall. No text, no letters, no watermark.
```

---

## 5. Phase 2: Production assets

**Sheet rules shared by every character prompt** (already written into each prompt): same character as the reference, poses fully separated by magenta gaps, identical scale, feet on one baseline, facing right, nothing touching the image edge.

### P1 · Medusa sheet A: movement · Tier 1
**Model:** Nano Banana Pro · **Aspect:** 16:9 · **Res:** 2K · **Attach:** `C0_style.png`, `C1_medusa.png`

```text
Game sprite sheet of the attached Medusa character, exactly matching her design and the black-figure vase style: a solid near-black (#1A1410) silhouette, thin incised terracotta (#C8643B) detail lines, one gold (#E8B547) eye. Eight poses in 2 rows of 4, read left to right, top to bottom. Every pose is full body, strict side profile facing right, the same scale (the figure about 40 percent of the row height), feet on one shared invisible baseline per row, fully separated by wide empty gaps, nothing touching the image edge:

1. idle A: standing relaxed, snakes curling gently upward.
2. idle B: the same, with a slight breath; the snakes shifted into a different curl.
3. run 1: contact: front heel striking, back leg extended.
4. run 2: down: knees bent, weight low.
5. run 3: passing: one leg passing under the body.
6. run 4: up: pushing off the toe, body highest.
7. jump: rising, knees tucked, snakes streaming downward behind her.
8. fall: arms slightly raised, legs reaching down, snakes streaming upward.

The same costume, proportions and number of snakes in every pose. The background is perfectly flat solid magenta (#FF00FF): no ground, no shadows. Flat fills only, no gradients, no shading, crisp hard edges. No text, no letters, no numbers, no watermark.
```
**Watch for:** the run frames all looking alike (fix with an edit: "only change pose 4 so that…") · the snake count changing between poses.

### P2 · Medusa sheet B: actions · Tier 1
**Model:** Nano Banana Pro · **Aspect:** 16:9 · **Res:** 2K · **Attach:** `C0_style.png`, `C1_medusa.png`, your final P1

```text
Second game sprite sheet of the attached Medusa, at exactly the same scale and style as the attached first sheet. Eight poses in 2 rows of 4, full body, strict side profile facing right, feet on one shared baseline per row, fully separated by wide magenta gaps, nothing touching the edge. Leave extra empty space in front of poses 1 to 3 for the lashing snakes:

1. whip wind-up: head pulled back, snakes coiled tight behind her head like drawn bowstrings.
2. whip strike: her snakes lash forward in a fan of 4, reaching about twice her height ahead of her, jaws open.
3. whip recovery: snakes recoiling back toward her head, her body still leaning forward.
4. gaze: leaning forward, chin down, her single gold (#E8B547) eye wide and blazing, snakes flared out like a hood.
5. hurt: recoiling backward, head snapped back, arms flung out.
6. push: leaning hard into an invisible block in front of her, both palms forward, legs braced far apart.
7. kneel: down on one knee, one hand reaching toward the ground as if touching water.
8. petrified: arms raised against her face, frozen in a final moment.

The same costume, proportions and snake count as sheet 1. Near-black (#1A1410) silhouette, thin incised terracotta (#C8643B) lines; gold only in the eye. Perfectly flat solid magenta (#FF00FF) background, no ground, no shadows. Flat fills only, no gradients, crisp edges. No text, no letters, no numbers, no watermark.
```
(Pose 4 is also used for Perseus's "ghost echoes" of your gazes.)

### P3 · Hoplite · Tier 1
**Model:** Nano Banana Pro · **Aspect:** 16:9 · **Res:** 2K · **Attach:** `C0_style.png`, `C2_enemies.png`, your final P1 (for scale)

> The spear is a separate sprite that the code slides back and forth, so **draw him without it** (it comes from P9).

```text
Game sprite sheet of the Hoplite from the attached enemy lineup, at the same scale as the attached Medusa sheet, in the same black-figure vase style. Eight poses in 2 rows of 4, full body, strict side profile facing right, feet on one baseline per row, fully separated by wide magenta gaps, nothing touching the edge.

IMPORTANT: do NOT draw a spear. In every pose his spear hand is closed in an empty fist at hip height, as if gripping an invisible horizontal spear. Keep his round shield on the far arm.

1 to 4. walk cycle: contact, down, passing, up.
5. wind-up: weight on the back foot, spear fist pulled far back past his hip.
6. thrust: deep lunge forward, spear arm fully extended.
7. recover: straightening up, spear fist returning to the hip.
8. stagger: knocked backward, helmet crest whipping, shield arm flung wide.

Near-black (#1A1410) silhouette, thin incised terracotta (#C8643B) lines, no gold. Perfectly flat solid magenta (#FF00FF) background, no ground, no shadows. Flat fills, no gradients, crisp edges. No text, no letters, no watermark.
```

### P4 · Eye-shading hoplite (edit of P3) · Tier 1
**Model:** Nano Banana Pro · **Aspect:** 16:9 · **Res:** 2K · **Attach:** your final P3 sheet, `C2_enemies.png`

```text
Edit the attached hoplite sprite sheet. Keep every pose, the layout, the scale, the style and the magenta background exactly the same. Change only this: remove his shield, and in every one of the 8 poses raise his free hand flat across his brow to shade his eyes, like the eye-shading soldier in the attached lineup. In pose 8 (stagger) the hand is flung up but still near his face. Still no spear. No text, no watermark.
```

### P5 · Leaper · Tier 1
**Model:** Nano Banana Pro · **Aspect:** 3:2 · **Res:** 2K · **Attach:** `C0_style.png`, `C2_enemies.png`, your final P1

```text
Game sprite sheet of the Leaper from the attached enemy lineup, at the same scale as the attached Medusa sheet (crouched, he is a little wider than he is tall and shorter than her), in the same black-figure vase style. Six poses in 2 rows of 3, strict side profile facing right, feet on one baseline per row, fully separated by wide magenta gaps, nothing touching the edge:

1. waiting crouch, wicker shield up.
2. tensing crouch, lower, coiled like a spring.
3. takeoff: legs straightening explosively, body angled up.
4. mid-leap: body stretched out horizontally, sword forward.
5. landing: deep crouch absorbing the impact.
6. stagger: knocked backward off balance.

Near-black (#1A1410) silhouette, thin incised terracotta (#C8643B) lines, no gold. Perfectly flat solid magenta (#FF00FF) background, no ground, no shadows. Flat fills, no gradients, crisp edges. No text, no letters, no watermark.
```

### P6 · Scythian archer · Tier 1
**Model:** Nano Banana Pro · **Aspect:** 16:9 · **Res:** 2K · **Attach:** `C0_style.png`, `C2_enemies.png`, your final P1

> The arrow is a separate sprite (P9), so the bow shows no arrow except while drawn.

```text
Game sprite sheet of the Scythian Archer from the attached enemy lineup, at the same scale as the attached Medusa sheet, in the same black-figure vase style. Eight poses in 2 rows of 4, strict side profile facing right, feet on one baseline per row, fully separated by wide magenta gaps, nothing touching the edge. The bow is part of him in every pose:

1. idle A: bow held low.
2. idle B: the same, a slight shift of weight, cap flaps moved.
3. reaching back to the quiver at his hip.
4. nocking: bow raised, an arrow on the string, the string not yet drawn.
5. full draw: string pulled back to the ear, aiming upward at about 30 degrees.
6. release: the string snapped forward, no arrow on the bow, drawing hand open behind him.
7. cooldown: lowering the bow.
8. stagger: knocked backward, bow arm flung out.

Near-black (#1A1410) silhouette, incised terracotta (#C8643B) diamond patterns on the sleeves and leggings, no gold. Perfectly flat solid magenta (#FF00FF) background, no ground, no shadows. Flat fills, no gradients, crisp edges. No text, no letters, no watermark.
```

### P7 · Mirror-bearer · Tier 1
**Model:** Nano Banana Pro · **Aspect:** 16:9 · **Res:** 2K · **Attach:** `C0_style.png`, `C2_enemies.png`, your final P1

> The mirror is a separate sprite that the code swings aside, so **draw him without it**.

```text
Game sprite sheet of the Mirror-bearer from the attached enemy lineup, at the same scale as the attached Medusa sheet, in the same black-figure vase style. Eight poses in 2 rows of 4, strict side profile facing right, feet on one baseline per row, fully separated by wide magenta gaps, nothing touching the edge.

IMPORTANT: do NOT draw the mirror. His hands are closed in empty fists as if gripping the handle of an invisible mirror held up in front of his face.

1 to 4. walk cycle: contact, down, passing, up (his hands stay up in front of his face).
5. braced: feet planted wide, both fists pushed forward at face height.
6. mirror knocked aside: both arms flung out to one side, torso twisting, face exposed.
7. stagger: knocked backward.
8. idle: standing, fists in front of his face.

Near-black (#1A1410) silhouette, thin incised terracotta (#C8643B) lines, no gold. Perfectly flat solid magenta (#FF00FF) background, no ground, no shadows. Flat fills, no gradients, crisp edges. No text, no letters, no watermark.
```

### P8 · Perseus · Tier 1\*
**Model:** Nano Banana Pro · **Aspect:** 16:9 · **Res:** 2K · **Attach:** `C0_style.png`, `C3_perseus.png`, your final P1

> The shield is separate (P9) so the code can drop it during the vulnerable window.

```text
Game sprite sheet of Perseus from the attached boss sheet, about a quarter taller than the attached Medusa at the same scale, in the same black-figure vase style. Eight poses in 2 rows of 4, strict side profile facing right, fully separated by wide magenta gaps, nothing touching the edge.

IMPORTANT: do NOT draw his shield. His shield arm is bent forward with an empty fist, as if holding an invisible round shield.

1. hover A: in the air on winged sandals, knees bent, harpe raised.
2. hover B: the same, sandal wings in the opposite flap.
3. dive attack: plunging diagonally down, harpe forward.
4. grounded stance: feet planted, shield fist forward, harpe drawn back.
5. harpe slash: a sweeping forward cut.
6. shield down: exhausted, shield arm dropped to his side, chest open, head low (the vulnerable moment).
7. shield-bash charge: running with his shoulder lowered behind the shield fist.
8. defeated: fallen to one knee.

Near-black (#1A1410) silhouette, thin incised terracotta (#C8643B) lines; gold (#E8B547) only on the sandal wings. Perfectly flat solid magenta (#FF00FF) background, no ground, no shadows. Flat fills, no gradients, crisp edges. No text, no letters, no watermark.
```

### P9 · Detachable weapons and props · Tier 1
**Model:** Nano Banana Pro · **Aspect:** 16:9 · **Res:** 2K · **Attach:** `C0_style.png`, `C2_enemies.png`, `C3_perseus.png`, your final P1

```text
Game sprite sheet of separate weapon and prop sprites, in the attached black-figure vase style, at the same scale as the attached Medusa sheet. Items spread out with wide gaps on flat solid magenta (#FF00FF), nothing touching the edge, each shown flat in side view:

1. Hoplite spear, lying perfectly horizontal pointing right: about 1.5 times Medusa's height long, a leaf-shaped spearhead, a butt-spike on the back end, near-black (#1A1410).
2. Arrow, perfectly horizontal pointing right: a thin shaft, a small barbed head, fletching, near-black.
3. Round hand mirror on a short handle, facing the viewer: the mirror face is flat gold (#E8B547), the rim and handle near-black with incised terracotta (#C8643B) lines; about half Medusa's height.
4. Perseus's round shield, facing the viewer: the face is flat gold (#E8B547) like a mirror, a thick near-black rim with an incised terracotta meander pattern; about two thirds of Medusa's height.

Flat fills, no gradients, no shading, crisp edges. No text, no letters, no watermark.
```

### P10 · Portrait stages 1 to 5 · Tier 1
**Model:** Nano Banana Pro · **Aspect:** 1:1 · **Res:** 2K · **Attach:** see each row

**P10a Defiant** = your final `C4_portrait.png`. Then run each later stage as an **edit**, attaching `C4_portrait.png` **plus the previous stage**:

```text
Edit the attached Medusa shield painting. Keep exactly the same painting: the same composition, shield, rim, lighting, brushwork, head size and position, the same magenta outside the circle. Change only her state to: {STAGE}. No text, no signature, no watermark.
```

| Stage | Save as | `{STAGE}` |
|---|---|---|
| 2 Rage | `portrait_2_rage.png` | `RAGE: mouth wide open in a scream like Caravaggio's Medusa, brows knotted, eyes wide, snakes lashing outward wildly; her skin is still alive, with only the tips of a few snakes turned to pale grey stone.` |
| 3 Grief | `portrait_3_grief.png` | `GRIEF: brows raised and drawn together, eyes glistening and glancing down, a tear on her cheek, mouth closed and trembling; her jaw and one cheek, about a quarter of her face, have turned to cold veined white marble, and a few snakes are frozen as stone.` |
| 4 Exhaustion | `portrait_4_exhaustion.png` | `EXHAUSTION: eyelids heavy and half closed, head tilting, mouth slack; half of her face and most of the snakes are cold veined white marble; the remaining skin is pale and grey.` |
| 5 Stone | `portrait_5_stone.png` | `STONE: her entire head and every snake are cold white marble, eyes blank and smooth like a statue, expression serene and empty; the shield's green behind her is dimmed to grey.` |

**Watch for:** the composition drifting between stages (always attach stage 1 *and* the previous stage) · the marble looking like makeup: it should read as carved stone.

### P11 · Backgrounds (4) · Tier 1
**Model:** Nano Banana Pro · **Aspect:** 21:9 · **Res:** 2K · **Attach:** that level's `C5*` final, `C0_style.png`

```text
Redraw the attached level background as a clean final game background layer. Keep the same layout, landmarks and style. Remove every person, figure and animal. Keep it calm and low-contrast: terracotta (#C8643B) and pale clay (#E2A27A) fields, scenery in dark clay brown (#7A3A22), only thin black (#1A1410) outlines. Flat, even lighting. Keep the bottom fifth simple. Make the left and right edges match so the image can repeat horizontally. Flat fills, no gradients, no texture noise. No text, no letters, no Greek inscriptions, no watermark.
```
Optional far layer for parallax: the same prompt plus `Only the distant sky band and farthest shapes, even paler, everything else flat pale clay.`

### P12 · Terrain texture · Tier 2
> ⚠️ **Honest call:** image models are weak at exact 32 px seamless tiles. The terrain is only 2 to 4 tiles, and **drawing them by hand in Aseprite takes about 20 minutes and is more reliable.** Use this prompt as a reference to copy from, or downscale it if it comes out clean.

**Model:** Nano Banana 2 · **Aspect:** 1:1 · **Res:** 1K · **Attach:** `C0_style.png`, that level's `C5*`

```text
A seamless tileable square texture for 2D platformer ground, in the attached black-figure vase style: {BIOME}. Big simple shapes, as if designed to be shrunk to 64 by 64 pixels: at most 4 large blocks or rocks across. A thick black (#1A1410) line along the very top edge with a narrow Greek key meander band just below it. Flat fills only in dark clay brown (#7A3A22), terracotta (#C8643B) and black. No gradients, no texture noise, no text, no watermark.
```
`{BIOME}` options: `cut temple masonry blocks` (levels 1 and 4) · `rough sea-cliff rock` (level 2) · `rough cave rock` (level 3).

### P13 · Victim statues and rubble · Tier 2
**Model:** Nano Banana Pro · **Aspect:** 3:2 · **Res:** 2K · **Attach:** `C6_stone.png`, your final P1 (for scale)

```text
Game sprite sheet in the attached white-ground marble style: flat marble white (#F2EFE8) figures with fine near-black (#1A1410) incised lines, at the same scale as the attached Medusa sheet. Six items in 2 rows of 3, strict side profile facing right, feet on one baseline per row, fully separated by wide gaps on flat solid magenta (#FF00FF):

1. victim statue standing, 2. victim statue with both arms raised to shield the face, 3. victim statue crouched and cowering, 4. victim statue fleeing mid-stride, looking back,
5. a low pile of marble rubble chunks, 6. eight small separate marble shards and chips of different shapes, spread apart.

Flat fills, no gradients, no 3D shading, crisp edges. No text, no letters, no watermark.
```

### P14 · Level props · Tier 2
**Model:** Nano Banana Pro · **Aspect:** 16:9 · **Res:** 2K · **Attach:** `C0_style.png`, your final P1

```text
Game prop sprite sheet in the attached black-figure vase style, at the same scale as the attached Medusa sheet. Eight props in 2 rows of 4, side view, fully separated by wide gaps on flat solid magenta (#FF00FF), nothing touching the edge:

1. mirror pool: a low round stone basin, dark clay brown (#7A3A22) with black outlines, its water surface a flat gold (#E8B547) ellipse; about Medusa's width.
2. wall torch bracket: an iron bracket and cup, near-black, with NO flame.
3. checkpoint marker: a short wooden pole with a small triangular pennant, near-black with incised terracotta (#C8643B) lines.
4. pressure plate: a flat stone slab set in the floor, dark clay brown with black outlines.
5. level exit: a tall temple doorway with a lintel and posts, the inside solid near-black; about twice Medusa's height.
6. broken Doric column stump.
7. hanging stalactite cluster.
8. a decorative amphora.

Flat fills, no gradients, no shading, crisp edges. No text, no letters, no Greek inscriptions, no watermark.
```

### P15 · Title card, logo and ending card · Tier 2
**Model:** Nano Banana Pro · **Aspect:** 16:9 · **Res:** 2K · **Attach:** `C0_style.png`, `C1_medusa.png`, `C4_portrait.png`

**Title card (wordless, the background behind the logo):**
```text
A title screen illustration in the attached black-figure vase style: a single huge profile of Medusa's head in near-black (#1A1410), filling the right half of the frame, snakes spreading across the top, one blazing gold (#E8B547) eye; terracotta (#C8643B) background with a meander band along the top and bottom edges; the left half stays calm empty terracotta for the logo. Flat fills, no gradients. No text, no letters, no inscriptions, no watermark.
```
**Logo** (the only allowed text; the rule permits the title logo): aspect 3:1 if available, otherwise 21:9.
```text
A game title logo reading exactly "MEDUSA'S PRICE" in bold, carved-looking ancient Greek-style capital letters (Latin alphabet, not Greek letters), near-black (#1A1410) with a thin gold (#E8B547) inner line, a small snake curling through the letter S, on flat solid magenta (#FF00FF). No other text, no watermark.
```
**Ending card (wordless):**
```text
An ending illustration in Greek white-ground vase style: Medusa, now a flat marble white (#F2EFE8) statue with fine black incised lines, standing serene among a quiet gallery of other marble statues, in side profile; a soft terracotta (#C8643B) background with a meander band along the top. Melancholy and calm. Flat fills, no gradients. No text, no letters, no inscriptions, no watermark.
```

### P16 · itch.io cover and splash icon · cover Tier 1, splash Tier 2
**Cover** (itch wants 630×500: generate at **5:4** and crop) · **Attach:** `C0_style.png`, `C1_medusa.png`, `C2_enemies.png`
```text
A game cover illustration in the attached black-figure vase style: Medusa in near-black (#1A1410) silhouette at center-left, snakes lashing, her gold (#E8B547) gaze cone striking a hoplite who is half-turned to marble white (#F2EFE8), more soldiers charging from the right; terracotta (#C8643B) ground, meander bands top and bottom; a strong, readable composition even as a small thumbnail. Flat fills, no gradients. No text, no letters, no inscriptions, no watermark.
```
(Text is fine on the itch page itself; the no-text rule is for in-game screens. Add the logo over it if you like.)

**Splash / favicon** (1:1, scaled to 64×64 → `web/splash.png`):
```text
A simple bold game icon: Medusa's head in side profile as a solid near-black (#1A1410) silhouette with 6 snake locks and one gold (#E8B547) eye, centered on a flat terracotta (#C8643B) circle with a thin black rim. Extremely simple shapes that read at 64 by 64 pixels. Flat fills, no gradients, no text, no watermark.
```

### P17 · Run vase fallback · Tier 2
Shown when `Features.VASE_AI` is off or the Worker fails. **Model:** Nano Banana 2 · **Aspect:** 3:4 · **Res:** 2K · **Attach:** `C0_style.png`, `C1_medusa.png`
```text
A front view of an ancient Greek black-figure amphora, centered on a flat dark background (#1A1410). The terracotta (#C8643B) body of the vase carries one wide frieze band showing, in black-figure silhouettes, Medusa standing alone among fallen marble-white (#F2EFE8) soldiers; meander bands above and below; glossy black neck and foot. Flat, clean, no text, no letters, no Greek inscriptions, no signatures, no watermark.
```

### P18 · Touch control icons · Tier 3 (the code-drawn discs already work)
**Model:** Nano Banana 2 · **Aspect:** 3:2 · **Res:** 1K
```text
Six simple game control icons in 2 rows of 3, flat marble white (#F2EFE8) shapes on flat solid magenta (#FF00FF), each centered in its own space with wide gaps: left arrow, right arrow, down chevron, an up arrow over a short line (jump), a curling snake (whip), an almond eye (gaze). Thick bold shapes that read at 48 pixels. No letters, no numbers, no text, no watermark.
```

---

## 6. Cleanup and Godot integration notes

1. **Key out the magenta** → transparent background.
2. **Snap colours to the palette**: every pixel goes to the nearest palette colour, alpha untouched. This removes the AI's colour drift and edge fuzz in one pass.
3. **Slice by islands**: each pose is a separate blob, so cut it out automatically, then align every frame by the bottom of the feet.
4. **Scale to 2× game size**: Medusa's body is 64 px in game, so frames are about 128 px tall. Set the `Sprite2D`/`AnimatedSprite2D` scale to 0.5. This stays crisp at 1080p, where the 1280×720 window scales by 1.5×.
5. **Statues**: today the code tints the placeholder polygons marble white. With textures, a plain tint will **not** work: black × white is still black. They need a small **palette-swap shader**: black → marble, terracotta lines → black, gold kept. The statue crack lines also need to switch from white to black so they show on marble.
6. **Spear, mirror, shield and arrow** stay separate `Sprite2D`s under the existing `Visual/Spear`, `Visual/Mirror` nodes, so the current code that moves them keeps working.
7. **Portraits**: downscale each to 128×128 (`Balance.HUD_TEXTURE_SIZE`) and put them in `_stage_textures` in `scripts/portrait_hud.gd`.
