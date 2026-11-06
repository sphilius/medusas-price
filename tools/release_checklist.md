# Release checklist: Medusa's Price

Run this before every itch.io upload that players will see. Tick each box in order.
If a step fails, fix it, re-export, and start the checklist again from step 1.

## 1. Automated checks (on this PC, about 10 minutes)

- [ ] All sims pass. In Git Bash from the project root, run `bash tools/run_sims.sh`. The last line must read `0 sim(s) failed`.
- [ ] The no-text audit is clean. Run `godot --headless --path . --script res://tools/no_text_audit.gd`. The last line must read `0 hit(s)`; the only ALLOWED lines are the key-cap letters in `key_hint.gd`.
- [ ] Release export. Run `godot --headless --path . --export-release "Web" build/itch_web/index.html`. Under about 45 MB is fine; the engine `.wasm` alone is about 38 MB.

## 2. Release build has no debug features

- [ ] The number keys 1 to 5 do nothing (no level skip).
- [ ] The browser console (F12) shows no `fps` lines.
- [ ] No overlay, numbers or error popups appear anywhere.

## 3. Browsers (play the itch page, not localhost)

Do one pass in each browser: title → level 1 → at least the first gap → press 4 is NOT possible, so play on.

- [ ] Chrome: plays, sound starts after the first click or key, the canvas fills the window when it is resized.
- [ ] Firefox: same.
- [ ] Safari (or iPhone/iPad Safari): same, and the touch buttons appear on a phone.

## 4. Network-off run (every AI feature falls back)

- [ ] Load the itch page, then turn the network off (Chrome DevTools → Network → Offline).
- [ ] Play to the vase screen (a quick run is fine). The painted fallback vase appears and nothing else changes: no error text, no hang.

## 5. One full run, start to finish

- [ ] Title → temple → cliffs → cave → Perseus → vase → ending → back to the title.
- [ ] In level 2, the hoplite's statue can be pushed to the cliff and climbed.
- [ ] In level 3, the door opens only while a statue rests on the plate.
- [ ] With the network ON, the vase is AI-painted (not the fallback) and has no writing on it.
- [ ] Screenshot every screen and check by eye: no words or numbers anywhere (the title logo and key-cap letters are allowed).

## 6. Upload

- [ ] Dry run first: `butler push build/itch_web "kingriot/medusas-price:html5" --userversion <version> --dry-run`
- [ ] Sasha says yes, then push without `--dry-run`.
- [ ] `butler status kingriot/medusas-price:html5` shows the build as processed (√).
- [ ] Record the push (version, build number, date) in the playtest guidebook changelog.
