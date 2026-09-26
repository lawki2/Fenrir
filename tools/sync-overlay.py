#!/usr/bin/env python3
"""Three-way merges Fenrir's copies of upstream Caelestia files onto a new release.

    tools/sync-overlay.py 2.4.0 2.5.0          report what a bump would do
    tools/sync-overlay.py 2.4.0 2.5.0 --write  apply it; conflicts keep git markers

Afterwards, load every Fenrir page in the Nexus harness: a merge can't catch an
API change in an upstream component that a Fenrir-only page uses.
"""

import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

RELEASES = "https://github.com/caelestia-dots/shell/releases/download"
OVERLAY = Path(__file__).resolve().parent.parent / "fenrir-nexus-patches/etc/xdg/quickshell/caelestia"


def fetch(version, dest):
    archive = dest / f"{version}.tar.gz"
    urllib.request.urlretrieve(f"{RELEASES}/v{version}/caelestia-shell-v{version}.tar.gz", archive)
    with tarfile.open(archive) as tar:
        tar.extractall(dest / version, filter="data")
    # The top-level directory's name varies by release ("release/" in 2.4.0).
    (root,) = (dest / version).iterdir()
    return root


def main():
    args = [a for a in sys.argv[1:] if a != "--write"]
    if len(args) != 2:
        sys.exit(__doc__)
    old, new = args
    write = "--write" in sys.argv

    with tempfile.TemporaryDirectory() as tmp:
        base_root, theirs_root = fetch(old, Path(tmp)), fetch(new, Path(tmp))
        fenrir_only = 0
        for ours in sorted(f for f in OVERLAY.rglob("*") if f.is_file()):
            rel = ours.relative_to(OVERLAY)
            base, theirs = base_root / rel, theirs_root / rel
            if not base.exists():
                if theirs.exists():
                    print(f"COLLISION  {rel}  (upstream now ships a file at this path)")
                else:
                    fenrir_only += 1
                continue
            if not theirs.exists():
                print(f"REMOVED    {rel}  (upstream deleted it; decide by hand)")
                continue
            if base.read_bytes() == theirs.read_bytes():
                print(f"unchanged  {rel}")
                continue

            if b"\0" in ours.read_bytes() + base.read_bytes() + theirs.read_bytes():
                print(f"BINARY     {rel}  (changed upstream; decide by hand)")
                continue

            # Exit status is the conflict count, capped at 127; above that merge-file itself failed.
            merged = subprocess.run(
                ["git", "merge-file", "-p", "-L", "fenrir", "-L", f"v{old}", "-L", f"v{new}",
                 str(ours), str(base), str(theirs)],
                capture_output=True, text=True,
            )
            if merged.returncode < 0 or merged.returncode > 127:
                sys.exit(f"git merge-file failed on {rel}: {merged.stderr}")
            status = "merged" if merged.returncode == 0 else f"CONFLICT ({merged.returncode})"
            print(f"{status:<10} {rel}")
            if write:
                ours.write_text(merged.stdout)

        print(f"\n{fenrir_only} Fenrir-only files not in either release, left alone.")
        if not write:
            print("Dry run: nothing written. Re-run with --write to apply.")


if __name__ == "__main__":
    main()
