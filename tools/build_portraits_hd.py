"""build_portraits_hd.py - sharp portraits for the big moments.

The HUD shows the portrait small, so art/portrait/stage_N.png is only 128 x 128 px.
Shown large (the intro's portrait-aging beat, the museum) that looks pixelated, so this
script makes 512 x 512 copies straight from the 2048 px Nano Banana originals.

Input:  art/raw/P10_<n>_<name>.png   (the round shield on a flat magenta background)
Output: art/portrait/hd/stage_<n>.webp (512 x 512, transparent outside the shield)

How the cut works: every pixel that is NOT magenta belongs to the painting; their
bounding box is the shield. The box is cropped out, and a circle mask (drawn 4x larger
and shrunk, which smooths its edge) makes everything outside the round shield clear,
so no pink fringe is left.

Run from the project root:  python tools/build_portraits_hd.py
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "raw"
OUT = ROOT / "art" / "portrait" / "hd"
NAMES = ["P10_1_defiant", "P10_2_rage", "P10_3_grief", "P10_4_exhausted", "P10_5_stone"]
SIZE = 512             # output width and height in px
INSET = 0.992          # the mask circle is this fraction of the shield (trims the edge)
SUPERSAMPLE = 4        # mask drawn this many times larger, then shrunk = smooth edge
WEBP_QUALITY = 90


def shield_box(im: Image.Image) -> tuple[int, int, int, int]:
    """Bounding box of the non-magenta pixels. A pixel is magenta when red and blue
    are high and green is low; point() turns each channel into a 0/255 mask."""
    r, g, b = im.convert("RGB").split()
    magenta = ImageChops.multiply(
        ImageChops.multiply(r.point(lambda v: 255 if v > 170 else 0), b.point(lambda v: 255 if v > 170 else 0)),
        g.point(lambda v: 255 if v < 100 else 0),
    )
    return ImageChops.invert(magenta).getbbox()


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for n, name in enumerate(NAMES, start=1):
        with Image.open(SRC / f"{name}.png") as src:
            im = src.convert("RGBA")
        box = shield_box(im)
        # Square the box around its centre (the shield is round).
        cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
        half = max(box[2] - box[0], box[3] - box[1]) / 2
        shield = im.crop((round(cx - half), round(cy - half), round(cx + half), round(cy + half)))
        shield = shield.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
        big = SIZE * SUPERSAMPLE
        mask = Image.new("L", (big, big), 0)
        pad = big * (1 - INSET) / 2
        ImageDraw.Draw(mask).ellipse((pad, pad, big - pad, big - pad), fill=255)
        shield.putalpha(mask.resize((SIZE, SIZE), Image.Resampling.LANCZOS))
        dst = OUT / f"stage_{n}.webp"
        shield.save(dst, "WEBP", quality=WEBP_QUALITY, method=6)
        print(f"{name} -> {dst.relative_to(ROOT)} {dst.stat().st_size / 1e3:.0f} KB")


if __name__ == "__main__":
    main()
