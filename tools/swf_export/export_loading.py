"""visualWait (392) skill pictures: sprite 383, 16 frames, 200x200, into godot/assets/ui/loading/N.png."""
import shutil
import subprocess
from pathlib import Path

import swf_trim as st

SID = 383
WORK = Path(__file__).resolve().parents[2] / "tmp" / "_loading_tmp"
OUT = Path(__file__).resolve().parents[2] / "godot" / "assets" / "ui" / "loading"


def main():
    swf = st.Swf()
    if WORK.exists():
        shutil.rmtree(WORK)
    WORK.mkdir(parents=True)
    small = WORK / "wait.swf"
    swf.trim([SID], small)
    subprocess.run([str(st.FFDEC), "-ignorebackground", "-format", "sprite:png", "-selectid", str(SID),
                    "-export", "sprite", str(WORK / "png"), str(small)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    folder = next(p for p in (WORK / "png").iterdir() if p.is_dir())
    files = sorted(folder.glob("*.png"), key=lambda p: int(p.stem))
    OUT.mkdir(parents=True, exist_ok=True)
    for i, png in enumerate(files, 1):
        (OUT / ("%d.png" % i)).write_bytes(png.read_bytes())
    shutil.rmtree(WORK)
    print(len(files), "frames")


if __name__ == "__main__":
    main()
