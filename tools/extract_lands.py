"""Land data the port spawns from, pulled from the original sources.

Writes into godot/assets/data/maps/:
  lands.json    Lands.xml: every land, its options, land scripts and trials (prob, waves)
  scripts.json  Scripts.xml: named scripts that rooms reference by scr="id"
  objs.json     AllData/objs.xml: every placeable object id and its attributes
  npcs.json     Npcs.xml: npc ids, their dialogs and dialog scripts

Room files (rooms/*.json, with each obj's child elements) are import_rooms.py's.
"""
import json
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "original" / "reference" / "Remains-Source2" / "Modules" / "core"
OUT = ROOT / "godot" / "assets" / "data" / "maps"


def read_xml(path: Path) -> ET.Element:
    return ET.fromstring(path.read_text(encoding="utf-8"))


def node(el: ET.Element) -> dict:
    out = {"tag": el.tag}
    if el.attrib:
        out["attrs"] = dict(el.attrib)
    kids = [node(k) for k in el]
    if kids:
        out["kids"] = kids
    return out


def script(el: ET.Element) -> dict:
    """Script.as: the element's own act is the first step, then every <s> child."""
    out = {k: v for k, v in el.attrib.items() if k in ("id", "eve", "item")}
    acts = []
    for step in [el] + [s for s in el if s.tag == "s"]:
        a = step.attrib
        if "act" not in a:
            continue
        acts.append({k: a[k] for k in ("act", "targ", "val", "t", "n", "opt1", "opt2") if k in a})
    out["acts"] = acts
    return out


def lands() -> dict:
    root = read_xml(SRC / "GameData" / "Lands.xml")
    out = {}
    order = []
    for land in root.findall("land"):
        lid = land.attrib["id"]
        row = dict(land.attrib)
        opt = land.find("options")
        row["options"] = dict(opt.attrib) if opt is not None else {}
        row["scr"] = [script(s) for s in land.findall("scr")]
        probs = []
        for prob in land.findall("prob"):
            p = dict(prob.attrib)
            p["cons"] = [dict(c.attrib) for c in prob.findall("con")]
            p["scr"] = [script(s) for s in prob.findall("scr")]
            waves = []
            for wave in prob.findall("wave"):
                waves.append({"t": wave.attrib.get("t", ""), "objs": [dict(o.attrib) for o in wave.findall("obj")]})
            if waves:
                p["waves"] = waves
            probs.append(p)
        row["probs"] = probs
        out[lid] = row
        order.append(lid)
    return {"order": order, "lands": out}


def named_scripts() -> dict:
    root = read_xml(SRC / "GameData" / "Scripts.xml")
    return {s.attrib["id"]: script(s) for s in root.findall("scr") if "id" in s.attrib}


def objs() -> dict:
    root = read_xml(SRC / "AllData" / "objs.xml")
    return {o.attrib["id"]: dict(o.attrib) for o in root.iter("obj") if "id" in o.attrib}


def npcs() -> dict:
    root = read_xml(SRC / "GameData" / "Npcs.xml")
    out = {}
    for npc in root.findall("npc"):
        row = dict(npc.attrib)
        dials = []
        for dial in npc.findall("dial"):
            d = dict(dial.attrib)
            d["scr"] = [script(s) for s in dial.findall("scr")]
            dials.append(d)
        row["dials"] = dials
        out[npc.attrib["id"]] = row
    return out


def write(name: str, payload) -> None:
    path = OUT / name
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")
    print("wrote", path, path.stat().st_size)


def main() -> None:
    write("lands.json", lands())
    write("scripts.json", named_scripts())
    write("objs.json", objs())
    write("npcs.json", npcs())


if __name__ == "__main__":
    main()
