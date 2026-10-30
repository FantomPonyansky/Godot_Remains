"""Add a few held-weapon vis clips to godot/assets/sprites/weapons/held without rerunning
export_weapons.py (which rewrites the folder and drops the sheet fields added later).

    python export_weapon_extra.py robogatp=visrobogatp robogatp2=visrobogatp2

Each clip's frame 1 is rendered by FFDec from a trimmed SWF of that symbol only; the manifest
gets the clip (file, anchor, emit, png) and the weapon id -> clip entry.
"""

import json
import subprocess
import sys

import export_weapons as ew
import swf_parse as sp


def main(pairs):
    symbols = ew.load_symbols()
    _data, _tags, chars, extras = sp.load()
    wanted = {}
    for pair in pairs:
        wid, name = pair.split("=", 1)
        if name not in symbols:
            sys.exit("no symbol %s" % name)
        wanted[wid] = name
    sids = {name: symbols[name] for name in set(wanted.values())}
    ids = set()
    for sid in sids.values():
        ids |= set(sp.deps_of(chars, sid)[0])
    work = ew.WORK / "extra"
    work.mkdir(parents=True, exist_ok=True)
    swf_path = work / "extra.swf"
    sp.write_swf(chars, extras, ids, swf_path)
    dest = work / "png"
    for child in dest.rglob("*.png") if dest.exists() else []:
        child.unlink()
    dest.mkdir(parents=True, exist_ok=True)
    select = ",".join("%d:1" % sid for sid in sids.values())
    subprocess.check_call([str(ew.FFDEC), "-ignorebackground", "-format", "sprite:png", "-select", select,
                           "-export", "sprite", str(dest), str(swf_path)])
    manifest_path = ew.OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for name, sid in sids.items():
        found = list(dest.glob("DefineSprite_%d*" % sid))
        png = found[0] / "1.png" if found else None
        if png is None or not png.exists():
            sys.exit("not rendered: %s" % name)
        target = ew.OUT / ("%s.png" % name)
        target.write_bytes(png.read_bytes())
        rect = ew.shape_rect(sp, chars, sid)
        entry = {"anchor": [round(-rect[0] / 20.0, 2), round(-rect[2] / 20.0, 2)] if rect else [0, 0],
                 "file": "%s.png" % name}
        emit = ew.emit_of(sp, chars, sid)
        if emit:
            entry["emit"] = [round(emit[0], 2), round(emit[1], 2)]
        entry["png"] = list(ew.png_size(target))
        manifest["clips"][name] = entry
        print(name, entry)
    for wid, name in wanted.items():
        manifest["ids"][wid] = name
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")


if __name__ == "__main__":
    main(sys.argv[1:])
