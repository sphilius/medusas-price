"""make_meander.py - draws one tile of a Greek-key (meander) band for the game.

Dev-only tool. Run from the project root:
    python tools/make_meander.py
Writes art/tiles/meander.png: black key lines on terracotta, with a black rule along
the top and bottom edges. The tile repeats seamlessly left to right (the key's
baseline runs straight through both side edges), so a Parallax2D can tile it.
Pure ornament: no letters, no numbers.

How it is drawn: the picture is laid out on a coarse grid of UNIT-pixel squares.
Each key is one polyline (a list of grid points joined by thick lines), so the
shape is easy to read and change below.
"""
import pathlib

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "art" / "tiles" / "meander.png"

TERRACOTTA = (0xC8, 0x64, 0x3B, 255)
BLACK = (0x1A, 0x14, 0x10, 255)

UNIT = 4          # pixels per grid square (the tile is drawn at 2x and shown at half size)
TILE_W = 10       # grid squares per repeat, left to right
TILE_H = 10       # grid squares top to bottom (rules at rows 0 and 9)

# One key, as grid points. It rises from the baseline (row 7), spirals clockwise and
# ends pointing inward. The baseline itself is drawn across the full width below,
# which is what joins each key to the next one.
KEY = [(1, 7), (1, 2), (7, 2), (7, 6), (3, 6), (3, 4), (5, 4)]


def to_px(point: tuple) -> tuple:
    """Grid point -> pixel at the middle of that grid square."""
    return (point[0] * UNIT + UNIT // 2, point[1] * UNIT + UNIT // 2)


def main() -> None:
    """Draws the tile and saves it. `for row in (0, TILE_H - 1, 7)` loops over a tuple
    of row numbers; `zip(KEY, KEY[1:])` pairs every point with the one after it."""
    img =Image.new("RGBA", (TILE_W * UNIT, TILE_H * UNIT), TERRACOTTA)
    draw = ImageDraw.Draw(img)
    width = TILE_W * UNIT
    # Top and bottom rules, and the baseline that links the keys.
    for row in (0, TILE_H - 1, 7):
        y = row * UNIT + UNIT // 2
        draw.line([(0, y), (width, y)], fill=BLACK, width=UNIT)
    # The key: zip pairs each point with the next one, giving the line segments.
    for start, end in zip(KEY, KEY[1:]):
        draw.line([to_px(start), to_px(end)], fill=BLACK, width=UNIT)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print(f"{OUT} {img.size[0]}x{img.size[1]}")


if __name__ == "__main__":
    main()
