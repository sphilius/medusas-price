"""cut_ui_icons.py - dev-only: cuts the six control icons out of art/raw/P18_game_control_icons.png.

The source is a 3 x 2 grid of marble-white shapes on flat magenta (#FF00FF):
    row 1: left arrow, right arrow, down chevron
    row 2: jump (up arrow over a line), whip (snake), gaze (eye)
Each cell is keyed (magenta -> transparent, with soft edges), trimmed to its shape and
scaled to ICON_HEIGHT px tall, then saved as art/sprites/ui/icon_<name>.png.
The game's KeyHint (scripts/key_hint.gd) loads these; if they are missing it draws
nothing above the key-caps, so the game still runs.

Run from the project root:  python tools/cut_ui_icons.py
"""
import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "raw" / "P18_game_control_icons.png"
OUT = ROOT / "art" / "sprites" / "ui"
NAMES = [["left", "right", "down"], ["jump", "whip", "gaze"]]
ICON_HEIGHT = 64  # px; the hint draws them at this size


def key_magenta(img: Image.Image) -> Image.Image:
    """Turns magenta into transparency. A pixel's alpha is how far its green channel
    is above zero: magenta has no green, marble white has full green, and the
    anti-aliased edge pixels in between get a soft partial alpha."""
    rgba = img.convert("RGBA")
    r, g, b, _ = rgba.split()
    alpha = g.point(lambda v: 0 if v < 40 else min(255, int((v - 40) * 255 / 180)))
    # Every visible pixel becomes pure marble white; the alpha carries the shape.
    white = Image.new("RGBA", rgba.size, (242, 239, 232, 255))
    white.putalpha(alpha)
    return white


def main() -> None:
    """Keys the whole sheet once, then cuts, trims, scales and saves each of the 6 cells."""
    OUT.mkdir(parents=True, exist_ok=True)
    # enumerate() gives (index, item) pairs: row 0/1 and its list of names, then
    # col 0/1/2 and each name, so the cell position comes from the loop counters.
    keyed = key_magenta(Image.open(SOURCE))
    cell_w = keyed.width // 3
    cell_h = keyed.height // 2
    for row, names in enumerate(NAMES):
        for col, name in enumerate(names):
            cell = keyed.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
            cell = cell.crop(cell.getbbox())  # trim to the shape
            width = round(cell.width * ICON_HEIGHT / cell.height)
            cell = cell.resize((width, ICON_HEIGHT), Image.LANCZOS)
            cell.save(OUT / f"icon_{name}.png")
            print(f"icon_{name}.png {cell.width}x{cell.height}")


if __name__ == "__main__":
    main()
