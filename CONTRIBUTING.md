# Contributing to Fenrir

Thanks for considering it — Fenrir is early, and there's a lot of room to help.

## Ways to help

- **Try it and report what breaks.** Real hardware/VM combos we haven't
  tested are the most valuable bug reports right now. See "Filing a good
  bug report" below.
- **Pick up something from the roadmap.** The README's "What's planned"
  section and open issues both track what's next. Comment on an issue
  before starting large work, so effort doesn't collide with something
  already in progress.
- **Improve the docs.** If something confused you while installing or
  building, it'll confuse the next person too — a PR fixing that is
  genuinely useful.

## Filing a good bug report

Open an issue and include:

- What you expected to happen, and what happened instead.
- Whether this was on real hardware or a VM, and which one.
- The ISO version (shown on the welcome screen and in the download
  filename, e.g. `fenrir-linux-260826.iso`).
- Exact steps to reproduce, if you have them.

## Making changes

1. Fork the repo and create a branch off `master`.
2. Keep PRs focused — one change per PR is easier to review than several
   bundled together.
3. If your change touches `fenrir-installer/`, test it locally with
   `quickshell -p fenrir-installer/qml` before opening the PR where
   possible — it's much faster than a full ISO rebuild per iteration.
4. If your change touches the Caelestia/Nexus side
   (`fenrir-nexus-patches/`), note which `caelestia-shell` version you
   tested against — that stack moves independently of this repo and pins
   matter (see `build-local-repo.sh`'s `pinned_aur_commits`).
5. Open the PR against `master` with a clear description of what changed
   and why.

## Project structure, briefly

- `fenrir-installer/` — the custom QML/Quickshell installer, replacing
  Calamares. `qml/` is the UI, `lib/` is the Python install backend.
- `fenrir-nexus-patches/` — Fenrir's additions/patches to Caelestia's
  own Nexus settings app, overlaid onto the real `caelestia-shell`
  package at build time.
- `archiso/` — the archiso profile: package lists, skel dotfiles, boot
  config.
- `build-local-repo.sh` — builds Fenrir's AUR-only dependencies
  (Caelestia, a few others) into a local pacman repo ahead of time, so
  the ISO build itself never needs AUR access.
- `buildiso.sh` — builds the actual ISO from the archiso profile.

## Questions

Open an issue, or start a discussion if you're not sure something is
worth an issue yet.
