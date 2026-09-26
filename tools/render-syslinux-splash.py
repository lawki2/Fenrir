#!/usr/bin/env python3
"""Renders the BIOS boot menu background (syslinux vesamenu) from Fenrir's wallpaper.
Usage: tools/render-syslinux-splash.py [out.png]"""

import sys
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/wallpaper.webp"
OUT = ROOT / "archiso/syslinux/splash.png"

# vesamenu's default mode (no MENU RESOLUTION); it shows no background at all if the image is larger.
SIZE = (640, 480)
BLUR = 1.2
BRIGHTNESS = 0.38  # the menu's faintest text is 19% white over the background


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    img = ImageOps.fit(Image.open(SRC).convert("RGB"), SIZE, Image.LANCZOS)
    img = img.filter(ImageFilter.GaussianBlur(BLUR))
    img = ImageEnhance.Brightness(img).enhance(BRIGHTNESS)
    img.save(out, optimize=True)
    print(f"{out}: {SIZE[0]}x{SIZE[1]}, {out.stat().st_size // 1024} KiB")


if __name__ == "__main__":
    main()
