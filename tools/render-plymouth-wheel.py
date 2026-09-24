#!/usr/bin/env python3
"""Renders the Plymouth boot wheel, a ring rippling into a squiggle and back, as one frame
grid for fenrir.script to Crop. Usage: tools/render-plymouth-wheel.py [out.png]"""

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 128  # one frame, px
COLS, ROWS = 10, 8  # 80 frames; the script plays one per refresh (~50/s)
SS = 4  # supersampling
COLOUR = (0x75, 0xB0, 0xFF, 255)  # assets/schemes/fenrir/default/dark.txt primary

RADIUS = 0.34 * SIZE
STROKE = 0.055 * SIZE
AMPLITUDE = 0.042 * SIZE
WAVES = 10
TRAVEL = 2  # wavelengths the squiggle moves per loop; whole, so the loop is seamless

OUT = Path(__file__).resolve().parent.parent / "archiso/airootfs/usr/share/plymouth/themes/fenrir/wheel.png"


def frame(t: float) -> Image.Image:
    big = SIZE * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    amp = AMPLITUDE * (1 - math.cos(2 * math.pi * t)) / 2
    phase = 2 * math.pi * TRAVEL * t
    c = big / 2
    # Dots stamped densely along the path: a wide PIL line leaves speckled segment joins.
    draw = ImageDraw.Draw(img)
    half = STROKE * SS / 2
    steps = 1440
    for i in range(steps):
        a = 2 * math.pi * i / steps
        r = (RADIUS + amp * math.sin(WAVES * a - phase)) * SS
        x, y = c + r * math.cos(a), c + r * math.sin(a)
        draw.ellipse((x - half, y - half, x + half, y + half), fill=COLOUR)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    count = COLS * ROWS
    sheet = Image.new("RGBA", (SIZE * COLS, SIZE * ROWS), (0, 0, 0, 0))
    for i in range(count):
        sheet.paste(frame(i / count), ((i % COLS) * SIZE, (i // COLS) * SIZE))
    sheet.save(out, optimize=True)
    print(f"{out}: {count} frames of {SIZE}px in a {COLS}x{ROWS} grid")


if __name__ == "__main__":
    main()
