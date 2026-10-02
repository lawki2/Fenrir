# Fenrir design

How Fenrir looks and moves, and the rules that keep it that way. Fenrir is built on
[Caelestia](https://github.com/caelestia-dots/shell), so most of this is Caelestia's design
system. This file records what Fenrir uses from it, what Fenrir adds, and where the two meet.

When this file and the code disagree, the code wins. Fix whichever one is out of date.

## Principles

- **The row of windows is the desktop.** Fenrir uses a scrolling layout. Windows sit side by
  side in columns, and the screen is a viewport you move along the row. Shell chrome should
  stay out of the row's way. It appears when asked for and leaves when it's done.
- **One frame, everything grows out of it.** The screen is wrapped in a thin rounded frame.
  The dock, the drawers and the panels are parts of that frame bulging inward. Nothing floats
  free of it.
- **Calm, dark, cool.** The brand comes from the default wallpaper: blue sky over water, with
  low-chroma blues on near-black surfaces. Accent colour marks what matters, and everything
  else stays quiet.
- **Everything is schemable.** The brand is a default, not a constant. Every colour in the
  running OS comes from the user's active scheme, so a different wallpaper or scheme changes
  all of it.
- **Import, don't fork.** Fenrir UI is built from Caelestia's real components and tokens, so it
  can't drift from the rest of the shell.

## Brand

### Source

- **Wallpaper:** `assets/wallpaper.webp` (2560×1440). The shell, the boot menu background and
  the brand palette all derive from it.
- **Seed:** `#89b2d3`. This is the colour Caelestia's own scorer picks from the wallpaper's
  thumbnail, the same step the dynamic scheme runs (HCT hue 242, chroma 30, tone 71).
- **Variant:** tonal spot. This is matugen's default, and Caelestia calls it `tonalspot`.
- **Mode:** dark.

### Dynamic by default, Fenrir as the fixed brand

A new user starts on the **dynamic** scheme in dark mode with the tonal spot variant
(`archiso/airootfs/etc/skel/.local/state/caelestia/scheme.json`). Dynamic re-derives the
palette from whatever wallpaper is set. On the default wallpaper it produces exactly the brand
palette. Change the wallpaper and the whole system follows.

The **Fenrir** scheme (`assets/schemes/fenrir/default/{dark,light}.txt`, spliced into
caelestia-cli) is the same palette frozen. It is the brand reference, and it's there for
users who want the Fenrir look whatever their wallpaper is. It sits in the scheme list next to
Caelestia's own schemes.

### Palette (dark)

These hex values are for brand material outside the running OS, such as the website, README
images and the boot chain (see "Where literal colours are allowed"). Inside the OS, refer to
the role, never the hex.

| Role | Hex | Use |
|---|---|---|
| `primary` | `#a8cbe8` | Accent: active state, focused workspace, selection, the boot wheel |
| `onPrimary` | `#20435b` | Text and icons on `primary` |
| `primaryContainer` | `#34566f` | Tinted fills that need less weight than `primary` |
| `onPrimaryContainer` | `#cbe7ff` | Text on `primaryContainer` |
| `secondary` | `#b7c9d9` | Secondary accents |
| `secondaryContainer` | `#2d3d4a` | Tonal buttons and chips |
| `tertiary` | `#dcddff` | The rare contrast accent (lavender) |
| `background` / `surface` | `#0b0f11` | The frame, window backgrounds, the boot screen |
| `surfaceContainerLow` | `#101418` | One step up |
| `surfaceContainer` | `#151a1f` | Cards, rows |
| `surfaceContainerHigh` | `#1b2025` | Raised rows, hovered surfaces |
| `surfaceContainerHighest` | `#20272c` | The highest raised layer |
| `onSurface` | `#e0e6ee` | Body text |
| `onSurfaceVariant` | `#a5acb3` | Subtext, inactive icons |
| `outline` | `#6f767d` | Rings and dividers, used sparingly |
| `outlineVariant` | `#42494f` | Empty workspace dots, faint separators |
| `error` | `#fa746f` | Danger and failure |

The light palette exists (primary `#346484` on `#f8f9fd`) for users who switch modes, but
Fenrir ships and is designed in dark.

### Regenerating the brand

Change `SEED` or `VARIANT` in `tools/gen-fenrir-scheme.py` and run it. It uses caelestia-cli's
own generator, so the result matches what dynamic produces. Then update the files that carry
literal brand colours:

1. `fenrir-settings/hypr/scheme/default.lua`. This is Hyprland's fallback before Caelestia
   writes `scheme/current.lua`, generated from the dark scheme.
2. The skel `scheme.json` colours.
3. `tools/render-plymouth-wheel.py` `COLOUR` (= `primary`), then run it.
4. `fenrir-splash/plymouth/fenrir.script` and `fenrir-splash/qml/shell.qml` (= `background`).
5. If the wallpaper changed: `tools/render-syslinux-splash.py`, and the credit in
   `THIRD_PARTY.md`.

## Colour in the OS

- **Use roles from `Colours.palette`** (`Colours.palette.m3primary`, `m3surfaceContainer`, …),
  or from `Colours.tPalette` for surfaces that should honour transparency. Never write a hex
  value or `Qt.rgba` in UI code.
- **Elevation is tone, not shadow.** A raised element moves up the `surfaceContainer*` steps.
  `Colours.layer()` does this for nested surfaces. Shell surfaces don't get drop shadows.
- **Named colours are harmonised.** The scheme's `red`, `green` and `blue` and the terminal
  colours are pulled toward the seed hue, so `red` is light blue in the brand palette. Use
  `error` for danger, and never use a named colour to mean something.
- **State is an overlay.** Hover and press tint the element with its `on*` colour at 8% and
  10% opacity (Caelestia's `StateLayer`). Selection is a persistent fill (`primary` or
  `secondaryContainer`), not a hover colour.
- **Borders are rare.** Components are defined by fill, shape and state layer. A border only
  appears where Caelestia uses one: radio rings, focus outlines, the 1 px window border.
- **Translucency is on.** Fenrir's skel enables Caelestia's transparency (`base` 0.85,
  `layers` 0.4), and Hyprland blurs behind it (size 8, 2 passes). Design for both states,
  because a user can turn it off.

### Where literal colours are allowed

These run before the scheme exists or outside Quickshell, so they carry brand hex values, and
each one is listed in the regeneration steps above:

- the Plymouth background and wheel;
- fenrir-splash's fallback fill under the wallpaper;
- Hyprland's fallback `scheme/default.lua`;
- the syslinux boot menu (stock archiso text colours over a dimmed wallpaper).

Anywhere else, a literal colour is a bug.

## Shape and the frame

| | Value | Source |
|---|---|---|
| Frame thickness | 10 px | Caelestia `border.thickness` |
| Frame rounding | 25 px | `border.rounding` |
| Blob smoothing | 20 px | `border.smoothing` |
| Window rounding | 15 px | `windowRounding` in `fenrir-settings/hypr/variables.lua` |
| Window border | 1 px, `primary` at 90% when focused, `onSurfaceVariant` at 7% otherwise | `variables.lua` |
| Window opacity | 0.95 | `variables.lua` |
| Gaps | 5 between windows, 10 to the frame, 20 for a lone window, 20 between workspaces | `variables.lua` |

The frame and every panel attached to it are drawn as one `BlobGroup` in
`modules/drawers/ContentWindow.qml`. The frame is a `BlobInvertedRect`, and each panel is a
`BlobRect` merged into it with an SDF smooth union. The smooth union is what makes panels curve
into the frame instead of sitting on it. A new edge-attached panel joins that group. It never
draws its own rounded rectangle.

Component radii use `Tokens.rounding`, and pills and switches use `full`.

## Shell layout

```
╭──────────────╮ workspace Map ╭──────────────╮
│               ╰─────────────╯               │
│                                             │
│   ┌─────────┐ ┌───────────────┐ ┌──────┐    │
│   │         │ │               │ │      │ →  │   the row scrolls sideways
│   │         │ │   focused     │ │      │    │
│   └─────────┘ └───────────────┘ └──────┘    │
╭─╯                                           │
│ tray                                        │
│ clock                                       │
│ status                                      │
│ power                                       │
╰─────────────────────────────────────────────╯
```

### Dock (default)

- Tray, clock, status icons and power sit in a column at the **bottom left**, inside a bulge of
  the frame. Above the dock, the left edge curves back in to the normal 10 px.
- The dock **overlaps** windows. It doesn't reserve the whole left edge, so the row keeps the
  full screen width. The cost is that the leftmost window's bottom-left corner can sit under
  it. That is accepted.
- **Settings > Panels > Dock** offers "Persistent" and "Show on hover". With persistent off and
  hover on, the dock hides into the frame, and touching the left edge beside it brings it
  back. These reuse Caelestia's `bar.persistent` and `bar.showOnHover`.
- Scrolling on the upper half of the dock changes volume, and on the lower half brightness.

### Workspace Map

- Workspaces show as a horizontal strip in a bulge at the **top centre**. Caelestia's workspace
  widget is laid sideways (`vertical: false`). Each workspace is a shape, and its windows'
  icons follow in column order, so the Map reads like the row.
- It appears for about a second after a workspace switch, and while Super is held for more
  than 0.3 s. It's display-only after a switch. After a Super peek it takes clicks, and stays
  while hovered.
- It is hidden over fullscreen windows and while the dashboard is open.

### Taskbar style

Settings > Panels > Dock > Style > "Taskbar" brings back Caelestia's full-height left bar,
with workspaces and the active window in it. In this style the Map is off.

### Fenrir shell settings

The style lives in `~/.config/caelestia/fenrir.json` (`barStyle`: `dock` | `taskbar`). Its
only reader and writer is `services/FenrirShell.qml`. Add a key there for any future
shell setting Caelestia's `shell.json` has no place for. Don't add new keys to `shell.json`.

### Everything else

The other drawers keep their upstream edges and behaviour: dashboard, launcher, sidebar,
notifications, OSDs and the lock screen. Drawers that upstream centres are centred on the
whole screen, not on the area beside the bar, because the dock doesn't take a whole edge.

## Windows and scrolling

- New columns open at 50% of the screen width. `Super+=` and `Super+-` step through 35, 50,
  65 and 100%. A single column fills the screen.
- Focus stops at the ends of the row (no wrap-around). The row follows focus, and clicking a
  partly hidden window brings it into view.
- Workspaces stack vertically, and Hyprland animates them with `slidevert`. Columns move
  sideways. Keep that spatial model in any new diagram, gesture or animation: sideways is
  the row, vertical is workspaces.
- The keyboard and gesture model is niri's. See `fenrir-settings/hypr/hyprland/keybinds.lua`
  and the first-boot tour.

## Type

Caelestia 2.4 uses Material 3 type roles. Each role has `large`, `medium` and `small` sizes
(in pt):

| Role | Sizes | Weight | Use |
|---|---|---|---|
| `Tokens.font.headline` | 32 / 28 / 24 | Medium | Big numbers (clock, weather) and the welcome heading |
| `Tokens.font.title` | 22 / 16 / 14 | Medium | Page titles, card titles |
| `Tokens.font.body` | 16 / 14 / 12 | Regular | Most text; `body.small` is the everyday size |
| `Tokens.font.label` | 14 / 12 / 11 | Medium, small Regular | Buttons, chips, row labels |
| `Tokens.font.mono` | 16 / 14 / 12 | Regular | Code, paths, terminal (CaskaydiaCove Nerd Font) |
| `Tokens.font.icon` | 36 / 24 / 18 / 15 (`extraLarge` → `small`) | | Material Symbols Rounded, through `MaterialIcon` |

Fenrir's family is **Rubik** everywhere. Caelestia 2.4 defaults the text roles to Google Sans
Flex, which Fenrir doesn't ship, so the skel `shell.json` sets `appearance.font.{headline,title,
body,label}.family` to Rubik. The clock and workspace labels are Rubik upstream already
(`Tokens.font.clock`, `Tokens.font.workspaces`).

- Users can change families. Read them from tokens, never write a family name.
- Icons are always Material Symbols **Rounded**. Selected states fill the icon (the `fill`
  axis) rather than swapping glyphs.
- Hierarchy comes from size and colour (`onSurface` against `onSurfaceVariant`), and rarely
  from weight.

## Spacing

`Tokens.spacing` (between elements), `Tokens.padding` (inside elements) and `Tokens.rounding`
share one scale:

| `extraSmall` | `small` | `medium` | `large` | `largeIncreased` | `extraLarge` | `extraLargeIncreased` | `extraExtraLarge` |
|---|---|---|---|---|---|---|---|
| 4 | 8 | 12 | 16 | 20 | 28 | 32 | 48 |

There is no `normal`. A wrong leaf name silently resolves to `undefined`, so run
`tools/check-tokens.py` after touching tokens.

## Motion

- **Durations** (`Tokens.anim.durations`, ms): `small` 200, `normal` 400, `large` 600,
  `extraLarge` 1000. On the expressive scale, spatial is 350/500/650 (things that move or
  resize), and effects are 150/200/300 (fades and colour).
- **Curves** are Material 3 bezier splines: `standard`, `emphasized` (two segments),
  `expressiveDefaultSpatial` and the rest. Never write a raw duration or a curve.
- **In QML**, animate through `Anim` and `CAnim` (for colours): `Behavior on x { Anim {} }`.
  A drawer opens by animating one driving value (an offset or scale) that both position and
  opacity follow. Pages animate their own entrance, not their container.
- **In Hyprland**, windows enter with `emphasizedDecel` and leave with `emphasizedAccel`, and
  moves and workspaces use `standard`. `animationSpeed` in Settings scales all of them.
- Motion confirms where something came from: drawers come out of the frame, and the Map comes
  down from the top. Nothing just appears.

## Components

Build Fenrir UI from Caelestia's components:

- `qs.components` provides `StyledText`, `MaterialIcon`, `StateLayer`, `Anim` and controls.
- `qs.modules.nexus.common` provides `SectionHeader` and the rows `ToggleRow`, `SelectRow`,
  `StepperRow`, `SliderRow`, `NavRow`, `InfoRow`, `TextFieldRow`, plus `ItemList`. Set
  `first`/`last` on consecutive rows to group them into one rounded card.

Patterns:

- **Settings pages:** section headers are plain text, not cards. Rows sit in connected groups.
  Each row has a label, then a short subtext that says what the setting does.
- **Long option lists in the installer** (timezones, keymaps, disks) open a full-page picker
  (`common/Picker.qml`), not a dropdown.
- **Icon-only buttons** are circles with a quiet permanent fill.
- **Text fields** are quiet and generously rounded. The search field is a near pill. Never use
  a saturated fill or an accent underline.

## Fenrir's own surfaces

| Surface | Where | Notes |
|---|---|---|
| Settings (Nexus) pages | `fenrir-nexus-patches/…/modules/nexus/pages/` | Add each page to both registries at the same index, and keep `popout` keys on the pages bar popouts open |
| Welcome and first-boot tour | `…/modules/welcome/` | Diagrams use theme roles and the row/workspace axes above |
| Installer | `fenrir-installer/qml/` | A standalone Quickshell that symlinks Caelestia's `components`, `utils` and Nexus `common`. It keeps only a `Colours` shim (it runs as root without Hyprland IPC) and `InstallerPage` |
| Windows | any | Use a `FloatingWindow` with `surfaceFormat.opaque: false`, sized from the screen by `Tokens.sizes.nexus` ratios, with the screen set on `Tokens` and `Config`. Never a layer-shell surface for an app window |
| Boot chain | Limine → Plymouth → SDDM → fenrir-splash | Limine is silent (`quiet: yes`, no menu). Plymouth draws the `primary` wheel on `background`. fenrir-splash covers the session start and fades out to the wallpaper |

## Writing

- Use sentence case for titles, labels and buttons: "Show on hover", not "Show On Hover".
- Use British spelling, as the UI already does: colour, behaviour.
- Subtext describes the effect in plain words ("Reveal the dock when the cursor touches the
  left edge beside it"), not the mechanism or the config key.
- Name things the way the UI shows them: the dock, the Map, the row, workspaces, Settings.

## Changing Caelestia

- `fenrir-nexus-patches/etc/xdg/quickshell/caelestia/` overlays the shell. Each overlaid
  upstream file has to be merged again on every Caelestia update (`tools/sync-overlay.py`),
  so keep changes small and mark each one with a `// Fenrir:` comment.
- Prefer a new file over editing an upstream one: a service, a module or a page.
- Comments are one or two lines at most, and say why, never what changed when.
- Never write a vendor config from memory. Copy the real upstream file and change it.

## Open items

- **Wallpaper licence.** The wallpaper is a painting by the pixiv artist Gracile
  (https://www.pixiv.net/en/users/3434849, found on wallhaven as `d8vv8j`). There is no licence
  attached, so it can't ship in a public ISO without the artist's permission. `THIRD_PARTY.md`
  still credits the previous wallpaper until this is settled.
- **Syslinux menu colours** are archiso's stock values over the dimmed wallpaper. They're
  readable, but not brand-tuned.
- **Needs real hardware:** the Super-hold timing, the dock's hover reveal, tray icons in the
  dock, and detached popouts (they sit about 25 px off centre, which is accepted for now).
