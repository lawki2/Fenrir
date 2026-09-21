# fenrir-tour

The tiling-WM introduction that used to run inside the installer, moved out so
it can become the first-boot tutorial instead — teaching the desktop while
someone is standing at an installer they're trying to get through is the wrong
moment, and the tutorial's audience is the one that comes second anyway.

Not packaged yet. These are the five steps as they shipped, kept intact so the
first-boot tutorial starts from working screens rather than a blank page:

- `TourLauncher.qml`, `TourClose.qml`, `TourFloat.qml`, `TourMove.qml`,
  `TourWorkspaces.qml` — the steps
- `TourStepBase.qml` — their shared layout

They still import the installer's old local components, so they need porting to
Caelestia's real ones (see `fenrir-installer/qml/common/InstallerPage.qml`)
when this is picked up.
