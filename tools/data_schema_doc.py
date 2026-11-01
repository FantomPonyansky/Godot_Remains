"""Write docs/DATA_SCHEMA.md from godot/scripts/data_schemas.gd.

The markdown is generated so it cannot drift from the schemas DataLib checks.
Run from the repo root: python tools/data_schema_doc.py
"""

import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "godot", "scripts", "data_schemas.gd")
OUT = os.path.join(ROOT, "docs", "DATA_SCHEMA.md")

ORDER = [
    "root", "req", "of", "map", "fields", "list", "id_field", "row",
    "unique", "array_of", "array_min",
]


class Parser(object):
    def __init__(self, text):
        self.text = text
        self.n = len(text)
        self.i = 0

    def peek(self):
        self._skip()
        return self.text[self.i] if self.i < self.n else ""

    def _skip(self):
        while self.i < self.n:
            c = self.text[self.i]
            if c in " \t\r\n":
                self.i += 1
                continue
            if c == "#":
                while self.i < self.n and self.text[self.i] != "\n":
                    self.i += 1
                continue
            break

    def parse(self):
        self._skip()
        c = self.peek()
        if c == "{":
            return self.dict()
        if c == "[":
            return self.array()
        if c == '"':
            return self.string()
        if c == "-" or c.isdigit():
            return self.number()
        if self.text.startswith("true", self.i):
            self.i += 4
            return True
        if self.text.startswith("false", self.i):
            self.i += 5
            return False
        raise ValueError("bad token at %d: %r" % (self.i, self.text[self.i:self.i + 20]))

    def dict(self):
        self._skip()
        if self.text[self.i] != "{":
            raise ValueError("expected {")
        self.i += 1
        out = {}
        while True:
            self._skip()
            if self.peek() == "}":
                self.i += 1
                return out
            key = self.string()
            self._skip()
            if self.text[self.i] != ":":
                raise ValueError("expected : after %s" % key)
            self.i += 1
            out[key] = self.parse()
            self._skip()
            if self.peek() == ",":
                self.i += 1

    def array(self):
        self._skip()
        if self.text[self.i] != "[":
            raise ValueError("expected [")
        self.i += 1
        out = []
        while True:
            self._skip()
            if self.peek() == "]":
                self.i += 1
                return out
            out.append(self.parse())
            self._skip()
            if self.peek() == ",":
                self.i += 1

    def string(self):
        self._skip()
        if self.text[self.i] != '"':
            raise ValueError("expected string")
        self.i += 1
        chars = []
        while self.i < self.n:
            c = self.text[self.i]
            self.i += 1
            if c == '"':
                return "".join(chars)
            if c == "\\":
                esc = self.text[self.i]
                self.i += 1
                chars.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(esc, esc))
                continue
            chars.append(c)
        raise ValueError("unterminated string")

    def number(self):
        self._skip()
        start = self.i
        if self.text[self.i] == "-":
            self.i += 1
        while self.i < self.n and (self.text[self.i].isdigit() or self.text[self.i] == "."):
            self.i += 1
        raw = self.text[start:self.i]
        return float(raw) if "." in raw else int(raw)


def extract_data(text):
    mark = "const _DATA := {"
    at = text.find(mark)
    if at < 0:
        raise ValueError("const _DATA not found")
    parser = Parser(text[at + len(mark) - 1:])
    return parser.dict()


def extract_patterns(text):
    at = text.find("static func for_path")
    if at < 0:
        return []
    body = text[at:]
    out = []
    parser_base = 0
    search = body
    while True:
        rel = search.find("return")
        if rel < 0:
            break
        abs_at = parser_base + rel
        brace = search.find("{", rel)
        if brace < 0 or brace - rel > 40:
            parser_base = abs_at + 6
            search = body[parser_base:]
            continue
        window = body[max(0, abs_at - 400):abs_at]
        cond = ""
        for line in reversed(window.splitlines()):
            stripped = line.strip()
            if stripped.startswith("if "):
                cond = stripped[3:].rstrip(":")
                break
        parser = Parser(body[abs_at + brace - rel:])
        try:
            spec = parser.dict()
        except ValueError:
            break
        if spec:
            out.append((cond or "return", spec))
        parser_base = abs_at + brace - rel + parser.i
        search = body[parser_base:]
    return out


def fmt_value(value):
    if isinstance(value, dict):
        parts = ["`%s` %s" % (k, fmt_value(v)) for k, v in value.items()]
        return "{%s}" % ", ".join(parts) if parts else "{}"
    if isinstance(value, list):
        return "[%s]" % ", ".join(fmt_value(v) for v in value)
    if isinstance(value, bool):
        return "`true`" if value else "`false`"
    return "`%s`" % value


def section(spec):
    lines = []
    seen = set()
    for key in ORDER:
        if key not in spec:
            continue
        seen.add(key)
        lines.append("- %s: %s" % (key, fmt_value(spec[key])))
    for key in spec:
        if key not in seen:
            lines.append("- %s: %s" % (key, fmt_value(spec[key])))
    return "\n".join(lines)


def render(data, patterns):
    parts = [
        "# Data schemas",
        "",
        "Generated from `godot/scripts/data_schemas.gd` by `tools/data_schema_doc.py`. Do not edit by hand.",
        "",
        "Types are `dict`, `array`, `string`, `number`, and `bool`. `DataLib.load` checks these shapes. A file with no section here has no schema.",
        "",
        "`list` / `id_field` / `row` / `unique` describe an array of rows. `of` and `fields` describe id-keyed objects. `map` is the object `by_id` returns when several exist. `array_of` / `array_min` constrain array values named in `of`.",
        "",
    ]
    for path in sorted(data):
        parts.append("## `%s`" % path)
        parts.append("")
        parts.append(section(data[path]))
        parts.append("")
    if patterns:
        parts.append("## Path patterns")
        parts.append("")
        parts.append("These match in `for_path` when the path is not one of the files above. The first match wins.")
        parts.append("")
        for cond, spec in patterns:
            parts.append("### `%s`" % cond)
            parts.append("")
            parts.append(section(spec))
            parts.append("")
    return "\n".join(parts).rstrip() + "\n"


def main():
    text = io.open(SRC, encoding="utf-8").read()
    data = extract_data(text)
    patterns = extract_patterns(text)
    if not data:
        print("no schemas parsed")
        return 1
    io.open(OUT, "w", encoding="utf-8", newline="\n").write(render(data, patterns))
    print("wrote %s (%d files, %d patterns)" % (OUT, len(data), len(patterns)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
