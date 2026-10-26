"""Land backdrops (Grafon.drawFon): fon* symbols of texture.swf / texture1.swf into godot/assets/sprites/fon/<name>.png."""
import shutil
import subprocess
import sys
import zlib
from pathlib import Path

import swf_trim as st

WORK = Path(__file__).resolve().parents[2] / "tmp" / "_fon_tmp"
OUT = Path(__file__).resolve().parents[2] / "godot" / "assets" / "sprites" / "fon"


def plain(name):
    raw = (st.ROOT / "original" / "swf" / name).read_bytes()
    if raw[:3] == b"CWS":
        raw = b"FWS" + raw[3:8] + zlib.decompress(raw[8:])
    dest = WORK / ("plain_" + name)
    dest.write_bytes(raw)
    return dest


def main():
    if WORK.exists():
        shutil.rmtree(WORK)
    WORK.mkdir(parents=True)
    OUT.mkdir(parents=True, exist_ok=True)
    done = set()
    for name in ("texture.swf", "texture1.swf"):
        swf = st.Swf(plain(name))
        fons = {k: v for k, v in swf.symbols.items() if k.startswith("fon") and k not in done}
        print(name, fons)
        if "--list" in sys.argv:
            continue
        for sym, sid in fons.items():
            small = WORK / ("%s.swf" % sym)
            swf.trim([sid], small)
            png = WORK / ("png_" + sym)
            subprocess.run([str(st.FFDEC), "-format", "sprite:png", "-selectid", str(sid),
                            "-export", "sprite", str(png), str(small)],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            frames = sorted(p for p in png.rglob("*.png"))
            if frames:
                (OUT / ("%s.png" % sym)).write_bytes(frames[0].read_bytes())
                done.add(sym)
    shutil.rmtree(WORK)
    print(sorted(done))


if __name__ == "__main__":
    main()
