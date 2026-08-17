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


def _colour_css():
    colours = _load_colours()
    if not colours:
        return ""
    lines = [
        f"@define-color {adwaita_name} {colours[token]};"
        for adwaita_name, token in ADWAITA_COLOUR_MAP.items()
        if token in colours
    ]
    return "\n".join(lines)


# Caelestia's real Material 3 token values, read from caelestia-shell's own
# source (tokens.hpp), not approximated. GTK has no var()-style mechanism
# for non-colour values, so these are just written directly into each rule
# below rather than declared once and reused.
#
# rounding:  extraSmall 4, small 12, normal 17, large 25, full 1000
# spacing:   small 7, smaller 10, normal 12, larger 15, large 20
# padding:   small 5, smaller 7, normal 10, larger 12, large 15
_STRUCTURE_CSS = """
window, .background {
    font-family: "Rubik";
}

textview, .log-view {
    font-family: "CaskaydiaCove NF";
}

button {
    border-radius: 12px; /* rounding.small */
}

entry, .entry {
    border-radius: 12px; /* rounding.small */
}

list.boxed-list, list.content, .card {
    border-radius: 17px; /* rounding.normal */
}

list.boxed-list > row, list.content > row {
    border-radius: 12px; /* rounding.small */
}

/* Material 3 state layers: hover/press are opacity overlays on top of the
   existing fill, not a colour swap. box-shadow inset is the GTK CSS
   equivalent of QML's `opacity: pressed ? 0.1 : hovered ? 0.08 : 0`. */
button:hover, row:hover {
    box-shadow: inset 0 0 0 999px alpha(@window_fg_color, 0.08);
}

button:active, button:checked, row:active {
    box-shadow: inset 0 0 0 999px alpha(@window_fg_color, 0.1);
}
""".strip()


def build_css():
    """Returns the full GTK CSS stylesheet: the live colour scheme mapping
    (only if scheme.json could be read) followed by Caelestia's structural
    design tokens (always applied). Colours have to come first since the
    structural rules reference them via alpha(@window_fg_color, ...)."""
    parts = []
    colour_css = _colour_css()
    if colour_css:
        parts.append(colour_css)
    parts.append(_STRUCTURE_CSS)
    return "\n\n".join(parts)
