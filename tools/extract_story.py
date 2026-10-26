"""Story data the port reads, pulled from the original GameData XML.

Writes into godot/assets/data/story/:
  quests.json  Quests.xml: every quest with its attributes, stages (q),
               deposit / reward / next children
  npcs.json    Npcs.xml: every npc with its attributes, dialogs (dial, with
               their scr scripts and reward children), quest and rep children
  items.json   AllData items.xml books and notes: tip, perk, text

Values stay the raw XML strings. Text (names, stage lines, dialogue) is not
here: it lives in the text packs (assets/data/text_*.xml).
"""
import json
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "original" / "reference" / "Remains-Source2" / "Modules" / "core" / "GameData"
OUT = ROOT / "godot" / "assets" / "data" / "story"


def read_xml(path: Path) -> ET.Element:
    return ET.fromstring(path.read_text(encoding="utf-8"))


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


def quests() -> dict:
    out = {}
    for q in read_xml(SRC / "Quests.xml").findall("quest"):
        row = dict(q.attrib)
        row["subs"] = [dict(s.attrib) for s in q.findall("q")]
        for tag in ("deposit", "reward", "next"):
            kids = [dict(k.attrib) for k in q.findall(tag)]
            if kids:
                row[tag] = kids
        out[q.attrib["id"]] = row
    return out


def npcs() -> dict:
    out = {}
    for npc in read_xml(SRC / "Npcs.xml").findall("npc"):
        row = dict(npc.attrib)
        dials = []
        for dial in npc.findall("dial"):
            d = dict(dial.attrib)
            d["scr"] = [script(s) for s in dial.findall("scr")]
            rewards = [dict(r.attrib) for r in dial.findall("reward")]
            if rewards:
                d["reward"] = rewards
            dials.append(d)
        row["dials"] = dials
        quest = npc.find("quest")
        if quest is not None:
            row["quest"] = dict(quest.attrib)
        reps = [dict(r.attrib) for r in npc.findall("rep")]
        if reps:
            row["rep"] = reps
        out[npc.attrib["id"]] = row
    return out


def items() -> dict:
    """AllData items.xml books and notes: what using them does (perk, text)."""
    src = SRC.parent / "AllData" / "items.xml"
    out = {}
    for it in read_xml(src).iter("item"):
        a = it.attrib
        if a.get("tip") in ("book", "note"):
            out[a["id"]] = {k: a[k] for k in ("tip", "perk", "text") if k in a}
    return out


def write(name: str, payload) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / name).write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")
    print("wrote", OUT / name)


def main() -> None:
    write("quests.json", quests())
    write("npcs.json", npcs())
    write("items.json", items())


if __name__ == "__main__":
    main()
