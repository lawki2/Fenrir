#!/usr/bin/env python3
"""Thin CLI wrapper around backend.py so a QML/Quickshell frontend can
drive the install as a subprocess. backend.py itself is untouched here —
this only adds a process boundary around it, in and out via JSON/stdout.

Usage:
    cli.py list-disks
        Prints a JSON array of {path, size, model} to stdout.

    cli.py install '<json>'
        <json> is an InstallPlan as a JSON object, passed as a single
        argument rather than over stdin (Quickshell's Process type has no
        clean way to signal EOF on stdin after writing to it). Streams
        plain progress lines to stdout as the install runs. Prints a final
        "INSTALL_OK" or "INSTALL_ERROR: <message>" line and exits 0 or 1.
"""

import json
import sys

import backend


def _cmd_list_disks():
    print(json.dumps(backend.list_disks()))


def _cmd_install(plan_json):
    plan_data = json.loads(plan_json)
    plan = backend.InstallPlan(**plan_data)

    def progress(line):
        print(line, flush=True)

    try:
        backend.run_install(plan, progress)
    except Exception as exc:
        # Catch everything, not just InstallError, so INSTALL_OK/INSTALL_ERROR
        # always prints — otherwise QML waits forever on a silently-dead process.
        print(f"INSTALL_ERROR: {exc}", flush=True)
        sys.exit(1)
    print("INSTALL_OK", flush=True)


def main():
    if sys.argv[1:2] == ["list-disks"] and len(sys.argv) == 2:
        _cmd_list_disks()
    elif sys.argv[1:2] == ["install"] and len(sys.argv) == 3:
        _cmd_install(sys.argv[2])
    else:
        print(f"usage: {sys.argv[0]} list-disks|install '<plan json>'", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
