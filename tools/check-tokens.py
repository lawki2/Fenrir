#!/usr/bin/env python3
"""Validates Tokens.* and TokenConfig.appearance.* paths against Caelestia's qmltypes.

A wrong leaf name resolves to undefined at runtime rather than failing, which
shows up only as "Unable to assign [undefined]" warnings, or a TypeError on a
page nobody opened yet, so this checks them statically instead.
"""

import re
import sys
from pathlib import Path

QMLTYPES = Path("/usr/lib/qt6/qml/Caelestia/Config/caelestia-config.qmltypes")

DEFAULT_ROOTS = (
    "fenrir-installer/qml",
    "fenrir-greeter/qml",
    "fenrir-nexus-patches",
)

# TokenConfig.appearance.<group>.<leaf>
APPEARANCE_GROUPS = {
    "spacing": "SpacingTokens", "rounding": "RoundingTokens",
    "padding": "PaddingTokens", "fontSize": "FontSizeTokens",
    "animDurations": "AnimDurationTokens", "curves": "AnimCurves",
}

# Tokens.<group>.<leaf>
TOKEN_GROUPS = {
    "spacing": "SpacingTokens", "rounding": "RoundingTokens",
    "padding": "PaddingTokens",
}


def parse_components(types: str) -> dict:
    """name -> (prototype, {property names}), one entry per Component block."""
    out = {}
    for block in types.split("Component {")[1:]:
        name = re.search(r'name: "([\w:]+)"', block)
        if not name:
            continue
        proto = re.search(r'prototype: "([\w:]+)"', block)
        props = set(re.findall(r'Property \{\s*name: "(\w+)"', block))
        out[name.group(1)] = (proto.group(1) if proto else None, props)
    return out


def members(components: dict, name: str) -> set:
    """Properties of a type plus everything it inherits."""
    full = f"caelestia::config::{name}" if "::" not in name else name
    seen, out = set(), set()
    while full and full in components and full not in seen:
        seen.add(full)
        proto, props = components[full]
        out |= props
        full = proto
    return out


def qml_files(roots) -> list:
    files = []
    for root in roots:
        p = Path(root)
        if p.is_file():
            files.append(p)
        elif p.is_dir():
            files.extend(sorted(p.rglob("*.qml")))
    return files


def main() -> int:
    if not QMLTYPES.exists():
        print("caelestia-config.qmltypes not found; is caelestia-shell installed?")
        return 0

    components = parse_components(QMLTYPES.read_text())
    appearance = {g: members(components, t) for g, t in APPEARANCE_GROUPS.items()}
    tokens = {g: members(components, t) for g, t in TOKEN_GROUPS.items()}

    # Tokens.font.<group>.<leaf>, where each group is its own style type.
    font_groups = {}
    for group, type_name in re.findall(
        r'Property \{\s*name: "(\w+)"\s*type: "caelestia::config::(\w+FontStyle|FontStyle)"',
        QMLTYPES.read_text(),
    ):
        font_groups[group] = members(components, type_name)

    roots = sys.argv[1:] or DEFAULT_ROOTS
    bad = []
    for f in qml_files(roots):
        for n, line in enumerate(f.read_text().splitlines(), 1):
            for group, leaf in re.findall(r"TokenConfig\.appearance\.(\w+)\.(\w+)", line):
                if group in appearance and leaf not in appearance[group]:
                    bad.append(f"{f}:{n}: appearance.{group}.{leaf} is not a token "
                               f"(have: {', '.join(sorted(appearance[group]))})")
            for group, leaf in re.findall(r"\bTokens\.font\.(\w+)\.(\w+)", line):
                if group not in font_groups:
                    bad.append(f"{f}:{n}: font.{group} is not a font group "
                               f"(have: {', '.join(sorted(font_groups))})")
                elif leaf not in font_groups[group]:
                    bad.append(f"{f}:{n}: font.{group}.{leaf} is not a style "
                               f"(have: {', '.join(sorted(font_groups[group]))})")
            for group, leaf in re.findall(r"\bTokens\.(\w+)\.(\w+)", line):
                if group in tokens and leaf not in tokens[group]:
                    bad.append(f"{f}:{n}: {group}.{leaf} is not a token "
                               f"(have: {', '.join(sorted(tokens[group]))})")

    for b in bad:
        print(f"  {b}")
    print(f"  {'FAIL' if bad else 'OK'}: {len(bad)} invalid token reference(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
