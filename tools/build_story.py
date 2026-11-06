"""build_story.py - shrink the generated storyboard panels into small game files.

Input:  art/raw/story/<name>.png   (straight from Nano Banana, any size; art/raw is
                                    kept out of git and out of the Godot export)
Output: art/story/<name>.webp      (1280 x 720, WebP, about 1/10 the size of a 2K PNG)

<name> is the slot the game expects (see docs/art/storyboard_prompts.md and
Balance.TRANSITION_STORIES): ch2_1 .. ch2_3, ch3_1 .. ch3_3, ch4_1 .. ch4_3,
end_1 .. end_3. Any other file name is copied too, so nothing is lost.

Each image is scaled to COVER 1280 x 720 (fills it, the overflow is cut off evenly
on both sides) so a panel that came out at a slightly different shape still fits.

Run from the project root:  python tools/build_story.py
"""
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "raw" / "story"
OUT = ROOT / "art" / "story"
SIZE = (1280, 720)      # the game's screen size in px
WEBP_QUALITY = 88       # 0-100: higher = sharper and bigger; 88 keeps flat colour clean


def main() -> None:
    """Convert every PNG/JPG/WebP in art/raw/story. `with Image.open(...) as im` is a
    context manager: the file is closed again as soon as the block ends."""
    OUT.mkdir(parents=True, exist_ok=True)
    files = sorted(p for p in SRC.glob("*") if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"))
    if not files:
        print(f"no images in {SRC}")
    for src in files:
        with Image.open(src) as im:
            # ImageOps.fit = scale to cover SIZE, then crop the overflow around the centre.
            panel = ImageOps.fit(im.convert("RGB"), SIZE, Image.Resampling.LANCZOS)
        dst = OUT / (src.stem + ".webp")
        panel.save(dst, "WEBP", quality=WEBP_QUALITY, method=6)
        print(f"{src.name} -> {dst.name} {dst.stat().st_size / 1e3:6.0f} KB")


if __name__ == "__main__":
    main()
