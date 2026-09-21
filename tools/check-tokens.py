#!/usr/bin/env python3
"""Validates every TokenConfig.appearance.* path against Caelestia's qmltypes.

A wrong leaf name resolves to undefined at runtime rather than failing, which
shows up only as "Unable to assign [undefined]" warnings and silently broken
spacing, so this checks them statically instead.
"""

import re
import sys
from pathlib import Path

QMLTYPES = Path("/usr/lib/qt6/qml/Caelestia/Config/caelestia-config.qmltypes")
GROUPS = {
    "spacing": "SpacingTokens", "rounding": "RoundingTokens",
    "padding": "PaddingTokens", "fontSize": "FontSizeTokens",
    "animDurations": "AnimDurationTokens", "curves": "AnimCurves",
}


def members(types: str, name: str) -> set[str]:
    i = types.index(f'name: "caelestia::config::{name}"')
    return set(re.findall(r'Property \{\s*name: "(\w+)"', types[i:i + 1800]))


def main() -> int:
    if not QMLTYPES.exists():
        print("caelestia-config.qmltypes not found; is caelestia-shell installed?")
        return 0

    types = QMLTYPES.read_text()
    valid = {g: members(types, t) for g, t in GROUPS.items()}

    bad = []
    for f in Path("fenrir-installer/qml").rglob("*.qml"):
        for n, line in enumerate(f.read_text().splitlines(), 1):
            for group, leaf in re.findall(r"TokenConfig\.appearance\.(\w+)\.(\w+)", line):
                if group in valid and leaf not in valid[group]:
                    bad.append(f"{f}:{n}: {group}.{leaf} is not a token "
                               f"(have: {', '.join(sorted(valid[group]))})")

    for b in bad:
        print(f"  {b}")
    print(f"  {'FAIL' if bad else 'OK'}: {len(bad)} invalid token reference(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
