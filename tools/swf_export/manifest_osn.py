"""Write each numbered clip's held osn frame (export_units.UNITS) into the packed sheet
manifest as "osn" (1-based), for rigs that follow a sheet clip with no rig clip of its
name. Label clips are skipped: their rigs have clips of the label's name.

    python tools/swf_export/manifest_osn.py
"""
import collections
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import export_units  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "godot" / "assets" / "sprites" / "sheets" / "units" / "manifest.json"


def main() -> None:
    raw = MANIFEST.read_text(encoding="utf-8")
    data = json.loads(raw, object_pairs_hook=collections.OrderedDict)
    changed = 0
    for unit, spec in export_units.UNITS.items():
        entry = data.get(unit)
        if entry is None:
            continue
        for clip, (where, _count, _loop) in spec.get("clips", {}).items():
            row = entry.get("clips", {}).get(clip)
            if row is None or not isinstance(where, int):
                continue
            if row.get("osn") != where:
                row["osn"] = where
                changed += 1
    tail = raw[len(raw.rstrip("\n")):]
    MANIFEST.write_bytes((json.dumps(data, indent=1, ensure_ascii=False) + tail).encode("utf-8"))
    print("osn frames written:", changed)


if __name__ == "__main__":
    main()
