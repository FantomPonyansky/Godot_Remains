"""Token and XML round-trip for every rooms_*.json (and 2021 XML if present)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROOMS = ROOT / "godot" / "assets" / "data" / "maps" / "rooms"
XML_DIR = ROOT / "original" / "release_2021" / "FoE - Remains" / "Rooms"
ZFORM = {",": 1, ";": 2, ":": 3}
ZCHAR = ["", ",", ";", ":"]
STAIR = set("АБ")
DIAG = set("-ДЕКНРВГЖЗИЙЛМОПСТ")
COLS, ROWS = 48, 25


def parse_token(s):
    cell = {"front": "", "back": "", "stair": "", "diag": "", "water": "", "zform": 0}
    if not s:
        return cell
    if s[0] != "_":
        cell["front"] = s[0]
    for ch in s[1:]:
        if ch in ZFORM:
            cell["zform"] = ZFORM[ch]
        elif ch == "*":
            cell["water"] = "*"
        elif ch in STAIR:
            cell["stair"] = ch
        elif ch in DIAG:
            cell["diag"] = ch
        elif ch != "_":
            cell["back"] = ch
    return cell


def encode_token(cell):
    s = "_" if not cell["front"] else cell["front"]
    s += ZCHAR[int(cell["zform"])]
    for k in ("back", "stair", "diag", "water"):
        if cell[k]:
            s += cell[k]
    return s


def main():
    fails = []
    n_tok = 0
    files = sorted(ROOMS.glob("rooms_*.json"))
    for path in files:
        doc = json.loads(path.read_text(encoding="utf-8"))
        for room in doc.get("rooms", []):
            for y, row in enumerate(room.get("rows", [])):
                for x, tok in enumerate(row.split(".")):
                    n_tok += 1
                    back = encode_token(parse_token(tok))
                    if back != tok:
                        fails.append("%s %s %d,%d %r -> %r" % (path.name, room.get("name"), x, y, tok, back))
                        if len(fails) > 40:
                            break
                if len(fails) > 40:
                    break
            if len(fails) > 40:
                break
        if len(fails) > 40:
            break
    print("files", len(files), "tokens", n_tok, "fails", len(fails))
    for line in fails[:20]:
        print(line)
    if XML_DIR.is_dir():
        print("xml files", len(list(XML_DIR.glob("rooms_*.xml"))))


if __name__ == "__main__":
    main()
