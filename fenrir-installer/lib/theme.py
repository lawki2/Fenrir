"""Builds a GTK CSS stylesheet from Caelestia's active Material 3 colour scheme.

Caelestia's shell writes its live palette to scheme.json and reads it the
same way (see Colours.qml's FileView). Reusing that file here means the
installer picks up whatever scheme the user actually has active, instead of
shipping a fixed palette of its own.
"""

import json
import os
from pathlib import Path

SCHEME_PATH = ".local/state/caelestia/scheme.json"

# Maps a libadwaita named colour to the Material 3 token that should feed
# it. scheme.json's keys have no "m3" prefix (QML's Colours.load() adds
# that itself when copying values onto its M3Palette object), except for
# the term0-15 terminal colours, which aren't used here.
ADWAITA_COLOUR_MAP = {
    "accent_color": "primary",
    "accent_fg_color": "onPrimary",
    "accent_bg_color": "primary",
    "window_bg_color": "surface",
    "window_fg_color": "onSurface",
    "view_bg_color": "surfaceContainerLow",
    "view_fg_color": "onSurface",
    "headerbar_bg_color": "surfaceContainer",
    "headerbar_fg_color": "onSurface",
    "card_bg_color": "surfaceContainerHigh",
    "card_fg_color": "onSurface",
    "popover_bg_color": "surfaceContainerHighest",
    "popover_fg_color": "onSurface",
    "destructive_bg_color": "error",
    "destructive_fg_color": "onError",
    "success_bg_color": "success",
    "success_fg_color": "onSuccess",
    "borders": "outlineVariant",
}


def _load_colours():
    home = os.environ.get("HOME")
    if not home:
        return None
    path = Path(home) / SCHEME_PATH
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError):
        return None
    colours = data.get("colours", {})
    return {name: f"#{value}" for name, value in colours.items()}


def build_css():
    """Returns a GTK CSS string mapping the active Caelestia scheme onto
    libadwaita's named colours, or None if no scheme could be read."""
    colours = _load_colours()
    if not colours:
        return None

    lines = []
    for adwaita_name, token in ADWAITA_COLOUR_MAP.items():
        value = colours.get(token)
        if value:
            lines.append(f"@define-color {adwaita_name} {value};")
    return "\n".join(lines) if lines else None
