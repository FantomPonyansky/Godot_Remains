"""Builds godot/assets/data/trade.json from Remains-Source2 AllData + GameData/Vendors.xml.

Prices (Item.getPrice / getMultPrice), weapon com prices and uniq variants,
armor price/hp, and the vendor stock lists (Vendor.as).
"""
import json
import os
import re
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "reference", "Remains-Source2", "Modules", "core")
OUT = os.path.join(ROOT, "godot", "assets", "data", "trade.json")


def load(path):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    text = re.sub(r"<\?xml[^>]*\?>", "", text)
    return ET.fromstring("<root>" + text + "</root>")


def num(v, default=0.0):
    try:
        f = float(v)
        return int(f) if f == int(f) else f
    except (TypeError, ValueError):
        return default


def main():
    items = {}
    for it in load(os.path.join(SRC, "AllData", "items.xml")).iter("item"):
        iid = it.get("id")
        if not iid:
            continue
        row = {"tip": it.get("tip", "item")}
        for key in ("price", "sell", "kol", "m", "us", "invcat", "keep", "one", "sort", "ftip"):
            if it.get(key) is not None:
                row[key] = num(it.get(key), it.get(key))
        for key in ("base", "mod", "cat", "work", "skill", "perk", "pet"):
            if it.get(key) is not None:
                row[key] = it.get(key)
        if it.get("invis") is not None:
            row["invis"] = 1
        if it.get("lvl") is not None and row["tip"] == "scheme":
            row["skill_lvl"] = num(it.get("lvl"))
        items[iid] = row

    weapons = {}
    for w in load(os.path.join(SRC, "AllData", "weapons.xml")).iter("weapon"):
        wid = w.get("id")
        if not wid:
            continue
        coms = w.findall("com")
        chars = w.findall("char")
        row = {"tip": num(w.get("tip", 0)), "skill": num(w.get("skill", 0)), "lvl": num(w.get("lvl", 0))}
        if coms and coms[0].get("price") is not None:
            row["price"] = num(coms[0].get("price"))
            row["price1"] = num(coms[1].get("price"), 0) if len(coms) > 1 else row["price"] * 3
        if coms and coms[0].get("uniq") is not None:
            row["uniq"] = num(coms[0].get("uniq"))
        if coms and coms[0].get("rep") is not None:
            row["rep"] = num(coms[0].get("rep"))
        if len(chars) > 1:
            row["variants"] = len(chars) - 1
        if w.get("nostand") is not None:
            row["nostand"] = 1
        if w.get("spell") is not None:
            row["spell"] = 1
        ammo = w.find("a")
        if ammo is not None and ammo.text:
            row["ammo"] = ammo.text.strip()
        weapons[wid] = row

    armors = {}
    for a in load(os.path.join(SRC, "AllData", "armors.xml")).iter("armor"):
        aid = a.get("id")
        if not aid:
            continue
        row = {"price": num(a.get("price", 0)), "hp": num(a.get("hp", 0)), "tip": num(a.get("tip", 1))}
        if a.get("clo") is not None:
            row["clo"] = num(a.get("clo"))
        armors[aid] = row

    vendors = {}
    for v in load(os.path.join(SRC, "GameData", "Vendors.xml")).iter("vendor"):
        vid = v.get("id")
        buys = []
        for b in v.findall("buy"):
            row = {"id": b.get("id")}
            if b.get("n") is not None:
                row["n"] = num(b.get("n"))
            for key in ("barter", "lvl", "pmult"):
                if b.get(key) is not None:
                    row[key] = num(b.get(key))
            if b.get("trigger") is not None:
                row["trigger"] = b.get("trigger")
            for key in ("noref", "nocheap", "hardinv"):
                if b.get(key) is not None:
                    row[key] = 1
            buys.append(row)
        tasks = []
        for t in v.findall("task"):
            tasks.append({k: t.get(k) for k in t.keys()})
        vendors[vid] = {"buys": buys, "tasks": tasks}

    doc = {
        "source": "Remains-Source2 AllData items/weapons/armors.xml + GameData/Vendors.xml (tools/extract_trade.py)",
        "items": items,
        "weapons": weapons,
        "armors": armors,
        "vendors": vendors,
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=None, separators=(",", ":"))
    print("items", len(items), "weapons", len(weapons), "armors", len(armors), "vendors", len(vendors))


if __name__ == "__main__":
    main()
