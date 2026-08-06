#!/usr/bin/env python3
"""Restore TX-02 as the Qt UI + monospace font after caelestia rewrites
~/dotfiles/config/qtengine/config.json (its bundled template hardcodes
'Sans Serif' / 'Monospace', which clobbers the user's TX-02 on every
wallpaper/scheme change). Run as caelestia's theme.postHook.
"""
import json
import os
import stat
from pathlib import Path

CFG = Path.home() / "dotfiles/config/qtengine/config.json"


def main() -> None:
    if not CFG.is_file():
        return
    # caelestia's atomic_write can leave this read-only (umask-based 600/444);
    # the owner may always chmod their own file, so make it writable first.
    try:
        os.chmod(CFG, 0o644)
    except OSError:
        pass
    data = json.loads(CFG.read_text())
    theme = data.setdefault("theme", {})
    theme.setdefault("font", {})["family"] = "TX-02"
    theme.setdefault("fontFixed", {})["family"] = "TX-02"
    CFG.write_text(json.dumps(data, indent=2) + "\n")
    print(f"[fix-qt-font] restored TX-02 in {CFG}")


if __name__ == "__main__":
    main()
