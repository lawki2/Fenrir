#!/usr/bin/env python3
"""Generates Fenrir's own Caelestia colour scheme.

Seed is the warm amber/copper that matches the default wallpaper and the
README badge; "content" keeps the background near-neutral instead of the
muddy brown "vibrant" produces. Rerun after changing SEED or VARIANT.
"""

import sys
from pathlib import Path
from types import SimpleNamespace

SEED = "c8873f"
VARIANT = "content"
OUT = Path(__file__).resolve().parent.parent / "assets/schemes/fenrir/default"

sys.path.insert(0, "/usr/lib/python3.14/site-packages")
try:
    from caelestia.utils.material.generator import gen_scheme, hex_to_hct
except ModuleNotFoundError:
    sys.exit("caelestia-cli must be installed to regenerate the scheme")


def hex6(v):
    return v if isinstance(v, str) else f"{v.to_int() & 0xFFFFFF:06x}"


OUT.mkdir(parents=True, exist_ok=True)
for mode in ("dark", "light"):
    scheme = SimpleNamespace(mode=mode, variant=VARIANT, flavour="default")
    colours = gen_scheme(scheme, hex_to_hct(SEED))
    lines = [f"{name} {hex6(value)}" for name, value in colours.items()]
    (OUT / f"{mode}.txt").write_text("\n".join(lines) + "\n")
    print(f"  wrote {OUT / f'{mode}.txt'} ({len(lines)} colours)")
