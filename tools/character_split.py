"""Move an autoload's per-character fields into a state class (ARCHITECTURE_PLAN R3.1).

    python tools/character_split.py <autoload.gd> <part> <state.gd> name1 name2 ...

Each `var name ...` line in the autoload moves verbatim to the state class and is
replaced by a property with the same name and type that forwards to
`Run.character().<part>`. Host constants or static vars used in a default are
read through a preload of the host. Prints what it could not convert and exits 1
without writing when any line is unsupported.
"""
import io
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "godot"
DECL = re.compile(r"^var (\w+)(\s*:\s*([\w\[\]\.]+))?\s*(:=|=)?\s*(.*?)\s*(#.*)?$")


def infer(expr: str) -> str:
    e = expr.strip()
    if re.fullmatch(r"-?\d+", e):
        return "int"
    if re.fullmatch(r"-?\d+\.\d*(e-?\d+)?|-?\d*\.\d+", e):
        return "float"
    if e in ("true", "false"):
        return "bool"
    if e.startswith('"') or e.startswith("'"):
        return "String"
    if e.startswith("{"):
        return "Dictionary"
    if e.startswith("["):
        return "Array"
    m = re.match(r"(Packed\w+Array|Vector2i?|Color|Dictionary|Array|StringName|Rect2)[(.]", e)
    if m:
        return m.group(1)
    return ""


def main() -> int:
    host_rel, part, state_rel = sys.argv[1], sys.argv[2], sys.argv[3]
    names = sys.argv[4:]
    host = ROOT / host_rel
    text = io.open(host, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in text else "\n"
    rows = text.split(nl)
    host_names = set(re.findall(r"^(?:static var|const)\s+(\w+)", text, re.M))
    found, bad, moved, first = {}, [], [], None
    for i, line in enumerate(rows):
        m = DECL.match(line)
        if m and m.group(1) in names:
            found[m.group(1)] = i
    for n in names:
        if n not in found:
            bad.append(f"{n}: no single-line `var` declaration")
    out_rows = list(rows)
    uses_host = False
    for n in names:
        if n not in found:
            continue
        i = found[n]
        m = DECL.match(rows[i])
        typ = m.group(3) or infer(m.group(5) or "")
        if not typ:
            bad.append(f"{n}: cannot infer type from `{rows[i].strip()}`")
            continue
        expr = m.group(5) or ""
        for hn in host_names:
            if re.search(r"(?<![\w.])" + hn + r"\b", expr):
                expr = re.sub(r"(?<![\w.])" + hn + r"\b", "_Host." + hn, expr)
                uses_host = True
        decl = f"var {n}: {typ}" + (f" = {expr}" if expr else "")
        if m.group(6):
            decl += "  " + m.group(6)
        moved.append(decl)
        out_rows[i] = f"var {n}: {typ}:{nl}\tget: return _{part}().{n}{nl}\tset(value): _{part}().{n} = value"
        first = i if first is None else min(first, i)
    if bad:
        print("\n".join(bad))
        return 1
    cls = "_" + "".join(w.capitalize() for w in part.split("_")) + "State"
    helper = [
        f"const {cls} := preload(\"res://{state_rel}\")",
        f"var _{part}_ref: {cls}",
        "",
        f"## This autoload's fields live on Run.character().{part}; the properties below forward there.",
        f"func _{part}() -> {cls}:",
        f"\tif _{part}_ref == null:",
        f"\t\t_{part}_ref = Run.character().{part}",
        f"\treturn _{part}_ref",
        "",
    ]
    out_rows[first:first] = helper
    io.open(host, "w", encoding="utf-8", newline="").write(nl.join(out_rows))
    state = ["extends RefCounted", "",
             f"## One character's {Path(host_rel).stem} fields (ARCHITECTURE_PLAN R3.1).",
             f"## {Path(host_rel).name} forwards a property of the same name to each.", ""]
    if uses_host:
        state.append(f"const _Host := preload(\"res://{host_rel}\")")
        state.append("")
    state += moved
    (ROOT / state_rel).parent.mkdir(parents=True, exist_ok=True)
    io.open(ROOT / state_rel, "w", encoding="utf-8", newline="\n").write("\n".join(state) + "\n")
    print(f"moved {len(moved)} fields to {state_rel}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
