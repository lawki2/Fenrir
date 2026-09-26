# Contributing to Fenrir

Thanks for considering it — Fenrir is early, and there's a lot of room to help.

## Ways to help

- **Try it and report what breaks.** Real hardware/VM combos we haven't
  tested are the most valuable bug reports right now. See "Filing a good
  bug report" below.
- **Pick up something from the roadmap.** The README's "What's next"
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
- The ISO you used (its filename, e.g. `fenrir-linux-260926.iso`). On an
  installed system, also paste the output of
  `pacman -Q fenrir-settings fenrir-splash caelestia-shell`.
- Exact steps to reproduce, if you have them.

## Making changes

1. Fork the repo and create a branch off `master`.
2. Keep PRs focused — one change per PR is easier to review than several
   bundled together.
3. Test your change in a VM built from your branch (see "Building from
   source" in the README). Never run the installer's install step on your
   own machine: it erases the disk you pick.
4. If your change touches the Caelestia side (`fenrir-nexus-patches/`), note
   which `caelestia-shell` version you tested against. Fenrir pins it (see
   `fenrir_aur_pins` in `tools/fenrir-packages.sh`), and files there that are
   copies of upstream files have to be merged again on every Caelestia update
   (`tools/sync-overlay.py`), so keep changes to them small.
5. Open the PR against `master` with a clear description of what changed
   and why.

## Project structure

See "Repository layout" in the [README](README.md#repository-layout).

## Questions

Open an issue, or start a discussion if you're not sure something is
worth an issue yet.
