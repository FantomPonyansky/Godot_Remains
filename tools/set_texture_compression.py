"""Switch Godot texture imports to VRAM compression.

Walks ``godot/**/*.png.import``. Skips ``assets/extracted/*_images`` (not
exported). Edits only ``compress/mode``, ``compress/high_quality`` and
``mipmaps/generate``.

Rules (first match wins). Paths are relative to ``godot/``.

SKIP
  assets/extracted/*_images/     source dumps, excluded from export

LOSSLESS  compress/mode=0, compress/high_quality=false
  tile-masks       assets/sprites/tiles/masks/
                   tile_outline.gd reads alpha with get_image()/get_pixel().
                   The clips are hard 1 px edges; a 4x4 block would change
                   which texels count as solid. The script can decompress, but
                   the decoded alpha would already be wrong.
  tile-unaligned   assets/sprites/tiles/ and assets/sprites/env/ whose width
                   or height is not a multiple of 4.
                   Godot 4.7 keeps the original get_width/height (a 38x38
                   probe stayed 38x38). The last partial 4x4 block is still
                   mixed with padding, and tFloor is only 10 px tall, so that
                   smear is a large part of a repeating edge. About 6 MB RGBA.
  cpu-loot         assets/sprites/loot/
                   ground_loot.gd calls get_image().get_used_rect() with no
                   decompress for weapons and for item/ammo icons that are
                   not the 104x108 / 57x22 canvases. Ammo is 57x22, so a
                   padded size would also miss the hardcoded anchor. The
                   whole folder is about 10 MB of RGBA.
  pony             assets/sprites/pony/
                   Player frames and parts, 94% not a multiple of 4. Padded
                   4x4 blocks blur each frame's edge differently, so walk
                   loops and clips jitter and differ in size.
  ui-cursor        assets/ui/cursor/          hard-edge pointer
  ui-pip           assets/ui/pip/ and assets/ui/pipbuck_skin.png
                   PipBuck chrome, text and 1 px bezels
  ui-hud           assets/ui/effects/ and assets/ui/lmb/
                   status icons and the click prompt
  ui-imp           assets/ui/imp/             message-box icons and frame
  ui-trade         assets/ui/trol/            trade-category icons
  ui-logo          assets/ui/menu/nazv.png    title lettering
  ui-world         assets/sprites/ui/         world-map plate and signs
  ui-font          any path with a font/ or fonts/ directory
                   (no bitmap font PNGs in the tree; OpenSans is a TTF)
  tiny             max(width, height) <= 32
                   a 4x4 block covers the whole sprite (bullet.png is 10x6).
                   Together these are about 0.1 MB of RGBA.

COMPRESS  compress/mode=2, compress/high_quality=true
  Everything else. Desktop Godot then stores BPTC; with high_quality off
  it would store S3TC/DXT. This covers backgrounds (fon*), tile textures,
  room backs, portraits, unit and object sheets, menu art
  and loading pictures.
  Godot 4.7 reports the original texture size, so sheet column counts
  (enemy.gd width / cell) stay the same. Sprite sheets stay compressed.

mipmaps/generate=false unless that line is already true.

MB figures are uncompressed RGBA from the PNG IHDR (width * height * 4)
and the PNG file size on disk. BPTC/DXT5 is about 1 byte per pixel, so
compressed VRAM is about a quarter of the RGBA figure (no mipmaps).

Usage:
  python tools/set_texture_compression.py --dry-run
  python tools/set_texture_compression.py
"""

from __future__ import annotations

import argparse
import os
import struct
import sys
from collections import defaultdict
from pathlib import Path

GODOT = Path(__file__).resolve().parents[1] / "godot"
KEYS = ("compress/mode", "compress/high_quality", "mipmaps/generate")


def png_size(path: Path):
    with path.open("rb") as handle:
        if handle.read(8) != b"\x89PNG\r\n\x1a\n":
            return None
        handle.read(4)
        if handle.read(4) != b"IHDR":
            return None
        return struct.unpack(">II", handle.read(8))


def skipped(rel: str) -> bool:
    parts = rel.split("/")
    return "extracted" in parts and any(part.endswith("_images") for part in parts)


def classify(rel: str, width: int, height: int):
    if skipped(rel):
        return "skip", "extracted"
    if "/tiles/masks/" in rel or rel.startswith("assets/sprites/tiles/masks/"):
        return "lossless", "tile-masks"
    unaligned = width % 4 != 0 or height % 4 != 0
    if unaligned and (
        rel.startswith("assets/sprites/tiles/") or rel.startswith("assets/sprites/env/")
    ):
        return "lossless", "tile-unaligned"
    if rel.startswith("assets/sprites/loot/"):
        return "lossless", "cpu-loot"
    if rel.startswith("assets/sprites/pony/"):
        return "lossless", "pony"
    if rel.startswith("assets/ui/cursor/"):
        return "lossless", "ui-cursor"
    if rel.startswith("assets/ui/pip/") or rel == "assets/ui/pipbuck_skin.png":
        return "lossless", "ui-pip"
    if rel.startswith("assets/ui/effects/") or rel.startswith("assets/ui/lmb/"):
        return "lossless", "ui-hud"
    if rel.startswith("assets/ui/imp/"):
        return "lossless", "ui-imp"
    if rel.startswith("assets/ui/trol/"):
        return "lossless", "ui-trade"
    if rel == "assets/ui/menu/nazv.png":
        return "lossless", "ui-logo"
    if rel.startswith("assets/sprites/ui/"):
        return "lossless", "ui-world"
    parts = rel.split("/")
    if "font" in parts or "fonts" in parts:
        return "lossless", "ui-font"
    # A 4x4 block covers the whole sprite. These are a fraction of a megabyte.
    if max(width, height) <= 32:
        return "lossless", "tiny"
    return "compress", compress_group(rel)


def compress_group(rel: str) -> str:
    groups = (
        ("fon", "assets/sprites/fon/"),
        ("tiles", "assets/sprites/tiles/"),
        ("env", "assets/sprites/env/"),
        ("backs", "assets/sprites/backs/"),
        ("portraits", "assets/portraits/"),
        ("portraits-gui", "assets/sprites/gui/"),
        ("sheets", "assets/sprites/sheets/"),
        ("units", "assets/sprites/units/"),
        ("objects", "assets/sprites/objects/"),
        ("pony", "assets/sprites/pony/"),
        ("weapons", "assets/sprites/weapons/"),
        ("projectiles", "assets/sprites/projectiles/"),
        ("npcs", "assets/sprites/npcs/"),
        ("props", "assets/sprites/props/"),
        ("scenes", "assets/sprites/scenes/"),
        ("doors", "assets/sprites/doors/"),
        ("decals", "assets/sprites/decals/"),
        ("debris", "assets/sprites/debris/"),
        ("water", "assets/sprites/water/"),
        ("fx", "assets/sprites/fx/"),
        ("areas", "assets/sprites/areas/"),
        ("sats", "assets/sprites/sats/"),
        ("menu", "assets/ui/menu/"),
        ("loading", "assets/ui/loading/"),
    )
    for name, prefix in groups:
        if rel.startswith(prefix):
            return name
    return "other"


def read_params(text: str):
    found = {}
    for line in text.splitlines():
        body = line.rstrip("\r")
        if "=" not in body or body.startswith("["):
            continue
        key, value = body.split("=", 1)
        if key in KEYS:
            found[key] = value
    return found


def patch(text: str, updates: dict):
    found = set()
    out = []
    for line in text.splitlines(keepends=True):
        body = line.rstrip("\r\n")
        ending = line[len(body) :]
        if "=" in body:
            key = body.split("=", 1)[0]
            if key in updates:
                out.append("%s=%s%s" % (key, updates[key], ending))
                found.add(key)
                continue
        out.append(line)
    missing = [key for key in KEYS if key not in found]
    return "".join(out), missing


def target_params(action: str, current: dict):
    if action == "compress":
        mips = current.get("mipmaps/generate", "false")
        if mips != "true":
            mips = "false"
        return {
            "compress/mode": "2",
            "compress/high_quality": "true",
            "mipmaps/generate": mips,
        }
    return {
        "compress/mode": "0",
        "compress/high_quality": "false",
        "mipmaps/generate": "false" if current.get("mipmaps/generate") != "true" else "true",
    }


def walk_imports():
    for dirpath, dirs, files in os.walk(GODOT):
        rel_dir = Path(dirpath).relative_to(GODOT).as_posix()
        parts = [] if rel_dir == "." else rel_dir.split("/")
        if ".godot" in parts:
            dirs[:] = []
            continue
        if "extracted" in parts:
            dirs[:] = [name for name in dirs if not name.endswith("_images")]
        else:
            dirs[:] = [name for name in dirs if name != ".godot"]
        for name in files:
            if name.endswith(".png.import"):
                yield Path(dirpath) / name


def collect():
    rows = []
    problems = []
    for imp in walk_imports():
        rel = imp.relative_to(GODOT).as_posix()[: -len(".import")]
        png = imp.with_name(imp.name[: -len(".import")])
        if not png.is_file():
            problems.append("missing png %s" % rel)
            continue
        size = png_size(png)
        if size is None:
            problems.append("bad png %s" % rel)
            continue
        text = imp.read_text(encoding="utf-8")
        current = read_params(text)
        if len(current) != 3:
            problems.append("missing keys %s" % rel)
            continue
        action, group = classify(rel, size[0], size[1])
        rows.append(
            {
                "imp": imp,
                "rel": rel,
                "action": action,
                "group": group,
                "w": size[0],
                "h": size[1],
                "rgba": size[0] * size[1] * 4,
                "png": png.stat().st_size,
                "text": text,
                "current": current,
            }
        )
    return rows, problems


def mb(n: int) -> float:
    return n / 1048576.0


def print_table(title: str, buckets: dict):
    print(title)
    print("%-16s %7s %10s %10s" % ("category", "count", "rgbaMB", "pngMB"))
    ordered = sorted(buckets.items(), key=lambda item: -item[1]["rgba"])
    total_n = total_rgba = total_png = 0
    for name, stat in ordered:
        print(
            "%-16s %7d %10.1f %10.1f"
            % (name, stat["n"], mb(stat["rgba"]), mb(stat["png"]))
        )
        total_n += stat["n"]
        total_rgba += stat["rgba"]
        total_png += stat["png"]
    print(
        "%-16s %7d %10.1f %10.1f" % ("TOTAL", total_n, mb(total_rgba), mb(total_png))
    )
    print()
    return total_n, total_rgba, total_png


def add_stat(buckets, key, row):
    stat = buckets[key]
    stat["n"] += 1
    stat["rgba"] += row["rgba"]
    stat["png"] += row["png"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true", help="print counts only")
    args = parser.parse_args()
    rows, problems = collect()
    before = defaultdict(lambda: {"n": 0, "rgba": 0, "png": 0})
    lossless = defaultdict(lambda: {"n": 0, "rgba": 0, "png": 0})
    compress = defaultdict(lambda: {"n": 0, "rgba": 0, "png": 0})
    skipped_b = defaultdict(lambda: {"n": 0, "rgba": 0, "png": 0})
    changed = 0
    held_mips = []
    odd_compress_rgba = 0
    odd_compress_n = 0
    for row in rows:
        add_stat(before, "mode=%s" % row["current"]["compress/mode"], row)
        if row["action"] == "skip":
            add_stat(skipped_b, row["group"], row)
            continue
        bucket = lossless if row["action"] == "lossless" else compress
        add_stat(bucket, row["group"], row)
        if row["action"] == "compress" and (row["w"] % 4 or row["h"] % 4):
            odd_compress_n += 1
            odd_compress_rgba += row["rgba"]
        updates = target_params(row["action"], row["current"])
        if any(row["current"].get(key) != value for key, value in updates.items()):
            changed += 1
            if updates["mipmaps/generate"] == "true":
                held_mips.append(row["rel"])
            if not args.dry_run:
                new_text, missing = patch(row["text"], updates)
                if missing:
                    problems.append("unpatched %s (%s)" % (row["rel"], ",".join(missing)))
                    continue
                with row["imp"].open("w", encoding="utf-8", newline="") as handle:
                    handle.write(new_text)
    print("files %d" % len(rows))
    print_table("BEFORE (current compress/mode)", before)
    _, lossless_rgba, _ = print_table("AFTER lossless", lossless)
    _, compress_rgba, _ = print_table("AFTER compress (mode=2, high_quality=true)", compress)
    if skipped_b:
        print_table("SKIP", skipped_b)
    verb = "would change" if args.dry_run else "changed"
    print("files whose import lines %s: %d" % (verb, changed))
    print(
        "compressed but not a multiple of 4: %d  rgbaMB %.1f"
        % (odd_compress_n, mb(odd_compress_rgba))
    )
    print(
        "VRAM estimate after (lossless RGBA + BPTC ~1/4): %.0f MB"
        % (mb(lossless_rgba) + mb(compress_rgba) / 4.0)
    )
    if held_mips:
        print("mipmaps left on:")
        for rel in held_mips:
            print("  %s" % rel)
    if problems:
        print("problems %d" % len(problems))
        for line in problems[:20]:
            print("  %s" % line)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
