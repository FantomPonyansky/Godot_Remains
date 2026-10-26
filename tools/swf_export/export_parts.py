"""Export mane, tail, eye, and PipBuck parts. One sprite each. Not pfe.swf."""

import json
import marshal
import re
import struct
import subprocess
import types
from pathlib import Path

PYC = (Path(__file__).resolve().parents[2] / r"tools\__pycache__\_export_polz.cpython-39.pyc")
FFDEC = (Path(__file__).resolve().parents[2] / r"tools\ffdec\ffdec-cli.exe")
WORK = (Path(__file__).resolve().parents[2] / r"original\extracted_swf\body_export\parts")
OUT = (Path(__file__).resolve().parents[2] / r"godot\assets\sprites\pony\parts")

PARTS = {
    "fore0": 226,
    "fore1": 232,
    "tail0": 130,
    "tail1": 135,
    "magic": 239,
}


def load_mod():
    code = marshal.loads(PYC.read_bytes()[16:])
    mod = types.ModuleType("ep")
    exec(code, mod.__dict__)
    return mod


def pngs_of(dest, sid):
    folder = dest / ("DefineSprite_%d" % sid)
    if not folder.exists():
        folders = [p for p in dest.iterdir() if p.is_dir()]
        folder = folders[0] if folders else folder
    return sorted(folder.glob("*.png"), key=lambda p: int(p.stem) if p.stem.isdigit() else 0)


def svg_anchor(swf, sid, dest):
    subprocess.check_call(
        [
            str(FFDEC),
            "-format",
            "sprite:svg",
            "-select",
            "%d:1" % sid,
            "-selectid",
            str(sid),
            "-export",
            "sprite",
            str(dest),
            str(swf),
        ],
        stdout=subprocess.DEVNULL,
    )
    text = next(dest.rglob("1.svg")).read_text(encoding="utf-8", errors="replace")
    match = re.search(r'<g transform="matrix\(([^)]+)\)"', text)
    nums = [float(part) for part in match.group(1).split(",")]
    return [round(nums[4], 2), round(nums[5], 2)]


def main():
    mod = load_mod()
    _data, _tags, chars, extras = mod.load()
    for name, sid in PARTS.items():
        print("part", name, sid, flush=True)
        ids, _extra = mod.deps_of(chars, sid)
        swf = WORK / ("%s.swf" % name)
        WORK.mkdir(parents=True, exist_ok=True)
        mod.write_swf(chars, extras, ids, swf)
        dest = WORK / name
        dest.mkdir(parents=True, exist_ok=True)
        subprocess.check_call(
            [
                str(FFDEC),
                "-ignorebackground",
                "-format",
                "sprite:png",
                "-selectid",
                str(sid),
                "-export",
                "sprite",
                str(dest),
                str(swf),
            ],
            stdout=subprocess.DEVNULL,
        )
        files = pngs_of(dest, sid)
        out = OUT / name
        out.mkdir(parents=True, exist_ok=True)
        for old in out.glob("*.png"):
            old.unlink()
        for i, src in enumerate(files, 1):
            (out / ("%d.png" % i)).write_bytes(src.read_bytes())
        anchor = svg_anchor(swf, sid, WORK / (name + "_svg"))
        anchors = [anchor for _ in files]
        (out / "anchors.json").write_text(json.dumps(anchors), encoding="utf-8")
        print("  frames", len(files), "anchor", anchor, flush=True)


if __name__ == "__main__":
    main()
