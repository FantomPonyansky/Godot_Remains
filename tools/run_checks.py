"""One command for every automatic check (architecture step R0.1, TODO 6.1).

    python tools/run_checks.py               all checks
    python tools/run_checks.py --list        names only
    python tools/run_checks.py --only a,b    some checks
    python tools/run_checks.py --skip a,b    all but some
    python tools/run_checks.py --import      reimport assets first
    python tools/run_checks.py --out tmp/checks_b   separate logs for a second runner

Each check prints one line `CHECK <name>: ok N fail M [note]`. A check fails on
a fail count, a nonzero exit, a timeout, or a `SCRIPT ERROR` / `Parse Error` /
`Compile Error` / `ERROR:` line (push_error counts; ERROR_OK lists engine noise). Full output goes to tmp/checks/<name>.log; each Godot run
gets a fresh user dir in tmp/checks/ud_<name> so the player's data is never
touched. Exit code 1 when any check failed.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(ROOT, "tools", "godot", "Godot_v4.7.2-stable_win64_console.exe")
PROJECT = os.path.join(ROOT, "godot")
OUT = os.path.join(ROOT, "tmp", "checks")

ERROR_LINE = re.compile(r"SCRIPT ERROR|Parse Error|Compile Error|^ERROR: ")
# Engine noise on every run (shader compiler, headless exit). Not our errors.
ERROR_OK = re.compile(r"custom_samplers|\b1 resources still in use at exit")
CHECK_LINE = re.compile(r"CHECK \w+: ok (\d+) fail (\d+)(.*)")
# test_room_xml: room XML vs JSON mismatches on 2026-10-31 (11 object rows).
# Fails only when the count grows.
XML_MISMATCH_BASELINE = 11
PARSE_GRACE_S = 5


def godot(name, args, user_args=()):
    """Godot command with a fresh sandbox user dir (our --user-dir, after --)."""
    ud = os.path.join(OUT, "ud_" + name)
    shutil.rmtree(ud, ignore_errors=True)
    os.makedirs(ud, exist_ok=True)
    return [GODOT, "--headless", "--path", PROJECT] + list(args) + ["--", "--user-dir=" + ud] + list(user_args)


def golden(land):
    """Replay hashes recorded before a refactor; delete the file to record new ones after an intended gameplay change."""
    return "golden=" + os.path.join(PROJECT, "tests", "fixtures", "replay_golden_%s.txt" % land)


def parse_check(text):
    m = None
    for m in CHECK_LINE.finditer(text):
        pass
    if m is None:
        return None
    return int(m.group(1)), int(m.group(2)), m.group(3).strip()


def parse_validate(text):
    m = re.search(r"validate errors (\d+) warnings (\d+)", text)
    if m is None:
        return None
    return 1, int(m.group(1)), "warnings %s" % m.group(2)


def parse_pool(text):
    m = re.search(r"POOL_OK hit (\d+)", text)
    if m:
        return 1, 0, "hit %s" % m.group(1)
    m = re.search(r"POOL_FAIL (.*)", text)
    return (0, 1, m.group(1).strip()) if m else None


def parse_xml(text):
    m = re.search(r"xml mismatches (\d+) (.*)", text)
    if m is None:
        return None
    n = int(m.group(1))
    return (1, 0, "mismatches %d" % n) if n <= XML_MISMATCH_BASELINE else (0, 1, "mismatches %d > %d %s" % (n, XML_MISMATCH_BASELINE, m.group(2).strip()[:100]))


def parse_codec(text):
    m = re.search(r"files (\d+) tokens (\d+) fails (\d+)", text)
    if m is None:
        return None
    return int(m.group(1)), int(m.group(3)), "tokens %s" % m.group(2)


def parse_boot(text):
    return 1, 0, ""


# name: (command builder, result parser, timeout seconds)
CHECKS = {
    "compile_all": (lambda: godot("compile_all", ["res://tests/test_compile_all.tscn"]), parse_check, 300),
    "boot_game": (lambda: godot("boot_game", ["res://scenes/game.tscn", "--quit-after", "240"]), parse_boot, 300),
    "boot_menu": (lambda: godot("boot_menu", ["res://scenes/main_menu.tscn", "--quit-after", "120"]), parse_boot, 300),
    "room_xml": (lambda: godot("room_xml", ["-s", "res://tests/test_room_xml.gd"]), parse_xml, 300),
    "editor_validate": (lambda: godot("editor_validate", ["-s", "res://tests/test_editor_validate.gd"]), parse_validate, 300),
    "room_pool": (lambda: godot("room_pool", ["-s", "res://tests/test_room_pool.gd"]), parse_pool, 300),
    "room_codec": (lambda: [sys.executable, os.path.join(ROOT, "tools", "test_room_codec.py")], parse_codec, 300),
    "mods": (lambda: godot("mods", ["res://tests/test_mods.tscn"]), parse_check, 180),
    "save_roundtrip": (lambda: godot("save_roundtrip", ["res://tests/save_roundtrip.tscn"]), parse_check, 240),
    "save_roundtrip_story": (lambda: godot("save_roundtrip_story", ["res://tests/save_roundtrip.tscn"], ["land=surf"]), parse_check, 240),
    "save_roundtrip_rnd": (lambda: godot("save_roundtrip_rnd", ["res://tests/save_roundtrip.tscn"], ["land=random_mane"]), parse_check, 240),
    "save_migrate": (lambda: godot("save_migrate", ["res://tests/save_migrate.tscn"], ["src=" + os.path.join(PROJECT, "tests", "fixtures", "slot_format2")]), parse_check, 240),
    "replay": (lambda: godot("replay", ["--fixed-fps", "60", "res://tests/replay_check.tscn"], [golden("begin")]), parse_check, 300),
    "replay_story": (lambda: godot("replay_story", ["--fixed-fps", "60", "res://tests/replay_check.tscn"], ["land=surf", golden("surf")]), parse_check, 300),
    "replay_arena": (lambda: godot("replay_arena", ["--fixed-fps", "60", "res://tests/replay_check.tscn"], ["room=rooms_perf_arena:arena_1_2", golden("arena")]), parse_check, 300),
}


def run(name):
    build, parse, timeout = CHECKS[name]
    log_path = os.path.join(OUT, name + ".log")
    start = time.time()
    timed_out = False
    with open(log_path, "w", encoding="utf-8", errors="replace") as log:
        proc = subprocess.Popen(build(), cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        parse_seen = None
        while proc.poll() is None:
            time.sleep(1.0)
            if time.time() - start > timeout:
                timed_out = True
                break
            # A scene whose script does not parse never quits: stop it early.
            if parse_seen is None:
                with open(log_path, encoding="utf-8", errors="replace") as f:
                    if "Parse Error" in f.read():
                        parse_seen = time.time()
            elif time.time() - parse_seen > PARSE_GRACE_S:
                break
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        code = proc.returncode if not timed_out else -1
    with open(log_path, encoding="utf-8", errors="replace") as f:
        text = f.read()
    errors = [line for line in text.splitlines() if ERROR_LINE.search(line) and not ERROR_OK.search(line)]
    result = parse(text)
    ok, fail, note = result if result else (0, 1, "no result line")
    notes = [note] if note else []
    if timed_out:
        fail, notes = fail + 1, notes + ["timeout %ds" % timeout]
    elif code != 0 and fail == 0:
        fail, notes = 1, notes + ["exit %d" % code]
    if errors:
        fail += len(errors)
        notes.append("script errors %d, first: %s" % (len(errors), errors[0].strip()[:100]))
    print("CHECK %s: ok %d fail %d%s  (%.0fs)" % (name, ok, fail, " " + "; ".join(notes) if notes else "", time.time() - start))
    sys.stdout.flush()
    return fail == 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", default="")
    ap.add_argument("--skip", default="")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--import", dest="do_import", action="store_true")
    ap.add_argument("--out", default="", help="log and sandbox folder (default tmp/checks); one per parallel runner")
    args = ap.parse_args()
    if args.out:
        global OUT
        OUT = os.path.abspath(args.out)
    if args.list:
        print("\n".join(CHECKS))
        return 0
    names = [n for n in args.only.split(",") if n] or list(CHECKS)
    unknown = [n for n in names + args.skip.split(",") if n and n not in CHECKS]
    if unknown:
        print("unknown checks: " + ", ".join(unknown))
        return 2
    names = [n for n in names if n not in args.skip.split(",")]
    os.makedirs(OUT, exist_ok=True)
    if args.do_import:
        CHECKS["import"] = (lambda: godot("import", ["--import"]), parse_boot, 900)
        names.insert(0, "import")
    failed = [n for n in names if not run(n)]
    print("checks %d failed %d%s" % (len(names), len(failed), ": " + ", ".join(failed) if failed else ""))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
