"""AllData <perk> / <skill> / <item> textvar and eff rows for PipPage.effStr -> godot/assets/data/pip_eff.json."""
import json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "original", "decompiled_2021", "new", "scripts", "fe", "AllData.as")
OUT = os.path.join(ROOT, "godot", "assets", "data", "pip_eff.json")

ATTR = re.compile(r"(\w+)='([^']*)'")
text = open(SRC, encoding="utf-8").read()
out = {}
for tag in ("perk", "skill", "item"):
    for m in re.finditer(r"<%s id='(\w+)'[^>]*>([\s\S]*?)</%s>" % (tag, tag), text):
        body = m.group(2)
        tv = [dict(ATTR.findall(x)) for x in re.findall(r"<textvar ([^>]*)/>", body)]
        eff = [dict(ATTR.findall(x)) for x in re.findall(r"<eff ([^>]*)/>", body)]
        if tv or eff:
            out[m.group(1)] = {"textvar": tv, "eff": eff}
json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(len(out), "entries")
