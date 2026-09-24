#!/usr/bin/env python3
"""Process boundary between the QML frontend and backend.py.

    cli.py list-disks  JSON array of {path, size, model}
    cli.py install     plan JSON in $FENRIR_INSTALL_PLAN; progress lines, then
                       INSTALL_OK or INSTALL_ERROR: <msg>

The plan carries the password, so it's in the environment: argv is readable by
every user via ps, and Quickshell's Process can't signal EOF on stdin.
"""

import json
import os
import sys

import backend


def _cmd_list_disks():
    print(json.dumps(backend.list_disks()))


def _cmd_install(plan_json):
    def progress(line):
        print(line, flush=True)

    try:
        if not plan_json:
            raise ValueError("no install plan in $FENRIR_INSTALL_PLAN")
        plan = backend.InstallPlan(**json.loads(plan_json))
        backend.run_install(plan, progress)
    except Exception as exc:
        # Everything, not just InstallError, or QML waits forever on a dead process.
        print(f"INSTALL_ERROR: {exc}", flush=True)
        sys.exit(1)
    print("INSTALL_OK", flush=True)


def main():
    if sys.argv[1:2] == ["list-disks"] and len(sys.argv) == 2:
        _cmd_list_disks()
    elif sys.argv[1:2] == ["install"] and len(sys.argv) == 2:
        # Popped, so none of the install's child processes inherit it.
        _cmd_install(os.environ.pop("FENRIR_INSTALL_PLAN", ""))
    else:
        print(f"usage: {sys.argv[0]} list-disks|install (plan in $FENRIR_INSTALL_PLAN)", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
