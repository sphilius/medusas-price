# Medusa's Price: storyboard panel prompts (level transitions)

12 panels in 4 short chapters, about 11 seconds each. They play between levels with a slow drift, and the player can skip them after 2 seconds. Together they tell the story with pictures only.

## The story in one line

Every hero Medusa turns to stone ages her. Her face never changes, but **her reflection does**. Each chapter shows her reflection older, ending with Perseus's mirror shield, and the last panel puts all of it in a museum.

| Chapter | Plays | Beat 1 | Beat 2 | Beat 3 |
|---|---|---|---|---|
| **ch2** | temple → cliffs | Aftermath: she leaves the steps full of statues | The fleet: archers land below the cliffs | The gift: Athena gives Perseus the mirror shield |
| **ch3** | cliffs → cave | Into the dark: she enters the sea cave | The gallery: a cave full of old victims | The mirrors: mirror-bearers follow, her reflection is older |
| **ch4** | cave → Perseus | The storm: a winged figure over the sea | The shield: her stone-grey face in his mirror | Face to face: both of them, lightning between |
| **end** | after the vase | Stone: Perseus is a statue at dawn | The price: she sits alone among her statues | The museum: centuries later, all of it on display |

---

## How to make them (about 20 to 30 minutes)

1. 🎨 Open **Nano Banana 2** (or Pro) in **one chat** and keep using it for all 12 panels, so the style stays the same.
2. 📎 Attach these references to the **first** prompt:
   - `art/concept/C0_style.png` (the style)
   - `art/concept/C1_medsua.png` (Medusa)
   - `art/concept/C3_perseus.png` (Perseus)
   - `art/raw/P10_1_defiant.png` through `P10_5_stone.png` (the 5 portrait stages, used for her reflections)
3. 📋 Paste the **Style block** below, then the panel prompt. For every later panel, paste only the panel prompt and add: *"Same style, palette and characters as the previous panels."*
4. 📐 Settings: aspect ratio **16:9**, resolution **2K**. Re-roll until no letters appear anywhere.
5. 💾 Save each one as `art/raw/story/<slot>.png` (for example `art/raw/story/ch2_1.png`).
6. 🗣️ Tell Claude **"panels saved"**. Claude runs `python tools/build_story.py` (it shrinks them to 1280×720 WebP, about 150 KB each), checks them and pushes.

Any slot you skip is just left out, and a chapter with no panels at all falls back to the single level painting. **Recommended order if time is short:** ch4, then end, then ch2, then ch3. The boss build-up and the ending pay off the most.

---

## Style block (paste first, once)

```
Style: an Attic black-figure Greek vase painting, flattened into a wide 16:9 scene.
Living figures are solid black silhouettes (#1A1410) in strict profile, with thin
terracotta incised lines for anatomy, hair and folds. Background is flat terracotta
clay (#C8643B), darker clay (#7A3A22) for ground and rock, pale clay (#E2A27A) for far
shapes. Anything turned to stone is white-ground marble (#F2EFE8) with fine black
lines. Gold (#E8B547) ONLY for eyes, gazes, glints and polished bronze: danger and
power. Flat colour, no gradients, no 3D shading, no photo texture, clean vector edges.
Medusa: a gorgon with a crown of living black snakes for hair, gold eyes, a
long black peplos. Perseus: a young hoplite hero with winged sandals, a round polished
bronze mirror-shield and a curved harpe sword.
Composition: keep every important figure inside the middle 80% of the frame (the game
slowly zooms and pans each picture). Strong silhouettes that read at a glance.
ABSOLUTELY NO TEXT: no letters, no words, no Greek inscriptions, no signatures, no
captions, no numbers, no speech bubbles. A meander (Greek key) border band is allowed.
```

---

## Chapter 2: temple → cliffs (dusk)

**ch2_1 · Aftermath**
```
Late afternoon on wide temple steps. Five or six enemy soldiers stand frozen as white
marble statues mid-charge, spears raised, scattered down the steps. Medusa, small, a
black silhouette with snake hair, walks away uphill toward a cliff path on the right,
her back half-turned. In the foreground lies a fallen round bronze shield; in its
polished gold surface we see her reflected face, a little older and lined, like a
painted portrait beginning to age.
```

**ch2_2 · The fleet**
```
Dusk. Medusa stands at the edge of a high sea cliff on the left, looking down. Below,
on a dark wine-red sea, three black-sailed Greek ships have beached; tiny black archer
silhouettes climb out and draw bows, a few gold glints on their arrowheads. The sky is
banded deep orange to dark clay. Long shadows.
```

**ch2_3 · The gift**
```
Far away from Medusa: on the deck of a ship at dusk, a young hero (Perseus) kneels in
profile. A tall goddess (Athena) with a crested helmet and an owl on her shoulder hands
him a round, mirror-polished bronze shield; the shield blazes gold, catching the last
sun. Winged sandals beside him on the deck. Calm, solemn, like a sacred vase scene.
Medusa is not in this panel.
```

## Chapter 3: cliffs → cave (torchlight)

**ch3_1 · Into the dark**
```
Night on the cliffs. Arrows (gold glints) stick out of the rock around a dark sea-cave
mouth. Medusa, black silhouette, steps down rough stone steps into the cave, one hand
on the wall; her snakes coil and look back over her shoulder toward the arrows. A
single torch inside the cave throws warm light on the entrance.
```

**ch3_2 · The gallery of the lost**
```
Inside a great torch-lit cavern. Dozens of white marble statues of earlier heroes line
both sides: shields up, mouths open, frozen in fear or mid-lunge, some cracked, some
broken at the knees, dust around them. Medusa, small and black, walks between the rows
down the middle. The statues are her past; she does not look at them.
```

**ch3_3 · The mirrors**
```
A narrow cave tunnel. Behind Medusa (left), a line of black soldier silhouettes
advances holding large round bronze mirrors in front of their faces; the mirrors glow
gold. In the nearest mirror we see Medusa's reflected face: grieving, deeply lined,
with fine white cracks spreading from the eyes, much older than she looks herself.
She glances back at it.
```

## Chapter 4: cave → Perseus (storm)

**ch4_1 · The storm**
```
The cave mouth opens onto a storm. Rain in straight diagonal lines, a dark sea with
white wave crests, a jagged gold lightning bolt. Far out over the water, a small black
figure flies in on winged sandals, a round shield on his arm glinting gold. Medusa's
silhouette in the cave mouth, foreground left, watching him come.
```

**ch4_2 · The shield**
```
Extreme close-up: Perseus's round polished bronze shield fills most of the frame, rim
gripped by his black hand, the curved harpe sword visible at one edge. In the mirror
surface, reflected: Medusa's face turned almost entirely to grey-white stone, cracked
all over, only her gold eyes still alive. This is the last stage of her portrait.
```

**ch4_3 · Face to face**
```
Wide shot of a storm-lashed rocky arena at the cave mouth. Medusa on the left, snakes
raised, gold eyes blazing. Perseus on the right just landing on winged sandals, shield
raised, harpe drawn. Lightning splits the sky between them. Between them on the floor,
a shallow round pool reflects both figures. Rain, tension, perfect symmetry.
```

## Epilogue (after the run vase, before the ending card)

**end_1 · Stone**
```
Dawn after the storm. Perseus stands as a white marble statue mid-lunge, his mirror
shield lowered and cracked across. The clouds break; pale gold light. Puddles on the
rock. Medusa's silhouette is small in the background, walking away.
```

**end_2 · The price**
```
Medusa sits alone on a rock among many white marble statues at dawn, head bowed, her
snakes drooping and quiet. Beside her lies Perseus's shield face-up; in its surface,
her reflection is fully stone. Her own face, in profile, is unchanged. Still, sad and
quiet: the price of winning.
```

**end_3 · The museum**
```
Centuries later: a quiet, high-ceilinged museum gallery drawn in the same black-figure
vase style. The white marble statues from the story (soldiers, archers, Perseus with
his shield) stand on plinths in a row. On the far wall hangs a round painted shield
with Medusa's face (like Caravaggio's Medusa). Small modern black-silhouette visitors
look up at it. A single gold glint in the painted eyes. No plaques, no labels, no text.
```

---

## Optional: a better title-card story

The intro reel uses `art/story/panel_1_temple.webp` to `panel_4_gaze.webp`. To replace them, save new PNGs as `art/raw/story/panel_1_temple.png` (and so on) and run `python tools/build_story.py`, the same as the chapter panels.

- **panel_1_temple:** *"The empty temple of the gorgon at noon, wide temple steps, olive trees, a calm sky. No figures."*
- **panel_2_gorgon:** *"Close profile of Medusa's face in shadow inside the temple, gold eye open, snakes waking."*
- **panel_3_heroes:** *"A line of black hoplite silhouettes charging up the temple steps, spears forward, dust."*
- **panel_4_gaze:** *"Medusa's gold gaze as a cone of light; the front soldier turning to white marble from the spear tip back."*
