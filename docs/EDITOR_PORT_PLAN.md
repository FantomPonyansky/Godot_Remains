# Plan: port the original room editor (Editor.swf, v1.0.2)

Goal (user, 2026-10-26): replace our map builder (`godot/scenes/map_builder.gd`) with a port of the editor shipped with v1.0.2.

Sources, local only:
- `original/editor_2021/`: `Editor.swf`, `Editor.txt` (the user manual for the room format) and `scripts/`, decompiled ActionScript.
- The editor's own code: `Editor.as` (2,026 lines), `visualEditor.as` (414), `edTile.as` (152), `visedobj.as`, `edTileBack.as`, `MainEd.as`. The rest is stock Flash UI components (`fl/`) and the game's `fe/AllData.as`.

## What the original is

- An 1800 × 950 window. The room grid is 48 × 25 cells at 20 px.
- Each cell has five slots: 1 front wall (solid), 2 back texture, 3 stairs, 4 diagonal / shelf, 5 water. It also has `zForm` 0–3, a squashed front wall.
- Objects (`<obj id code x y …>`) and backdrops (`<back id x y>`). Room properties are the `<options>` XML.
- **Two modes**, chosen by `<land serial="1"/>` in the file:
  - **Map mode** (fixed lands): rooms have x, y and optional z; a minimap shows them; «Слой» switches between storeys z 0 and 1.
  - **Random-room list mode**: a list of rooms, `[back]` rooms sorted last, `(n)` for `level`. Save also writes the computed `<doors>` row (22 border openings).
- **Painting:** drag a rectangle to fill it; Shift paints the outline only; Ctrl erases every slot plus the objects and backdrops in the rectangle; Alt picks the brush from a cell (eyedropper). There are no keyboard shortcuts.
- **Palettes:**
  - front walls are `mat` `ed=1`, back textures `ed=2`, stairs and diagonals `ed=3|4`; water `*` is added by the editor;
  - objects are `obj` with `ed>0`, in two lists: props (`ed` 1–10) and actors (`ed` 11–20); names come from `text_ru.xml`;
  - backdrops are `back` without `nope`.
- **Objects:**
  - «Выбрать объект» selects an object, and clicking again cycles through overlapping ones. Moving or retyping means editing its XML (`x`, `y`, `id`) and pressing «Проверить», which parses and pretty-prints it.
  - «Свойства» edits the room `<options>`.
  - Nested tags (`<item>`, `<move>`, `<scr>`, `<s>`) are kept as written and never edited structurally.
- **Rooms:** «Обновить список» saves the grid under the typed name, which is how a room is copied. «Удалить» deletes and needs Ctrl.
- **Files:** Load (needs Ctrl, no confirmation) reads `rooms/<name>.xml`. Save opens a file dialog.
- **Art:**
  - schematic cell clips (`edTile` symbol 104: `edTileFront_62`, `edTileStairs_63`, `edTileDiagon_64`, `edTileWater_65`, plus `edTileBack`);
  - object icons `ico_*` (`cont`, `door`, `phis`, `term`, `but`, `npc`, `rnd`, `pon`, `mon`, `tur`, `rob`, `mine`) and `kvad` frames;
  - real object art from `texture1.swf` at half scale, switched by `viewVid`.
- **Known bugs:**
  - a backdrop's XML editor never opens;
  - `<doors>` is written but never read back;
  - saving before the first edit writes the old room;
  - map mode cannot be switched inside the editor.

## What ours is

`map_builder.gd` (865 lines) works on the converted JSON (`assets/data/maps/rooms/*.json`, made by `tools/import_rooms.py`). That JSON keeps the original row tokens (`C._F.А…`), objects, options and `doors`. Ours has:
- a generated-land viewer and rebuild;
- code-typing room edits;
- door slots;
- markers;
- and a textured still preview of a built land (`land_preview.gd`). It cannot play-test: nothing in it starts the game.

It has no palettes, no object or property editing, and no XML.

## Decisions to confirm (defaults in brackets)

1. **Format.** [Edit the game's JSON and also import and export the original XML.] The original XML round-trip lets rooms move between the original, this port and the Unity remake.
2. **Art.** [Both views, as in the original, with no new extraction: a textured view from the port's own art and a schematic view drawn in code.]
3. **What to keep from ours.** [Keep the generated-land rebuild and textured preview as extra buttons; drop the rest. Play-testing is new (step 9).]
4. **Improvements over the original.** [Undo/redo, confirmations instead of Ctrl-guards, keyboard and gamepad-free editing (mouse only, like the original), English and Russian labels, the known bugs fixed.]
5. **Shipping: decided (user, 2026-10-27).** The editor ships in release builds for everyone, and its results plug into the game with no rebuild. Rooms saved in a release build go to `mods/rooms/` in the user dir, which the game reads over the built-in rooms (steps 2 and 10).

## Steps

### 1. Room document model and codec (2–3 days)

Status: partial. Room doc, token codec, and `doors_from_rows` are in. `godot/tests/test_room_xml.gd` checks JSON → XML → JSON (30 files, 670 rooms; rows, x/y/z, options, doors match). Not done: byte-for-byte JSON save, and reimport of every 2021 `Rooms/*.xml`.

- `scripts/editor/room_doc.gd`, a room file in memory:
  - the land node, kept verbatim;
  - rooms by name, each with x, y, z, a 48 × 25 grid of five slots plus zForm, objects, backdrops, options, and the source XML of each object;
  - the mode: map or random.
- `room_codec.gd`: cell token encode and decode exactly as `edTile.as:47–75` / `109–148`, sharing the parser with `map/room_file.gd`; port `getDoors` (`Editor.as:685–744`).
- Round-trip test (a `tools/` scene): every `rooms_*.json` loads and saves byte-for-byte the same; every 2021 `Rooms/*.xml` imports, exports and re-imports with no change.

### 2. File I/O and the player rooms folder (2–3 days)

Status: partial. Overlay, delta (integral floats and recomputed doors ignored), `_disabled.json` on/off, unsaved confirm, revert. Not done: a dev choice of `res://` vs mods, a message when a mod file is broken, import that writes the mods folder before Save.

- `RoomFile` reads `<user dir>/mods/rooms/` before `res://assets/data/maps/rooms/`:
  - a room with the same name in the same file replaces the built-in one;
  - new rooms are added to that file's set;
  - a new file is added to the index list.
  - The game reads them on the next land entry (`art_cache` already empties the room cache there).
- Each mod room file records the base file it extends, so a game update that changes built-in rooms does not wipe player edits.
- Open: built-in or mod JSON, or an original XML (FileDialog).
- Save:
  - game JSON: release builds always write the mods folder; dev runs choose built-in `res://` or the mods folder;
  - Export XML: `<all>`, `<land>`, `<room name x y z>`, 25 `<a>` rows, `<obj>` / `<back>` / `<options>` / `<doors>`.
- Import XML into the mods folder, so rooms made for the original editor plug in directly.
- After a save, call `RoomFile.drop_cache()` so a play-test sees the change.
- Unsaved changes are flagged and confirmed before leaving or loading.
- A broken mod file is skipped with a message, never a crash; the built-in rooms stay.

### 3. Palettes from data (1–2 days)

Status: partial. Swatches for ed 1–4 and water, object lists split at ed 10/11, backdrop ids from `backs.json`. The room backdrop list is the `backwall` values `play_land` paints. EN/RU names are `ed_tile_*` and `ed_wall_*` in `port_strings.json`. Not loaded from tile data at runtime; object names stay the `n` field.

- Materials with `ed` 1–4 come from the port's tile data. If the `ed` field was not imported, add it to the data extractor from `AllData.as` `mat`. Water `*` is added like the original.
- Objects: `maps/objs.json` already has `ed`, `ico`, `size`, `wid`. Two lists split at `ed` 10/11; headers for empty ids; names from `OriginalLines` in the current language.
- Backdrops: the back decor table without `nope`.

### 4. Editor art (1 day, no extraction)

Status: partial. Textured toggle (`editor_view.gd`) draws with `TileCatalog.decode` / `file_for` / `front_file` / `beam_texture` and `RoomLook.backwall_rects`, same order as `land_preview`. Schematic color swatches stay the default. Not drawn: outlines, room tint, `back_decor` sprites, object art.

- Textured view: the port's own tile art, `obj_art`, `back_decor` and `fon` backgrounds, drawn at the editor scale (the same art the game builds rooms with).
- Schematic view, drawn in code as `map_builder` already does: a fill colour per front material, lines for stairs and diagonals, a blue tint for water, half alpha for the back layer, id letters when «ids» is on.
- Object and backdrop lists: a thumbnail of the real art; a coloured badge per `ed` group for objects without art (spawns, areas, random enemies).
- The original's editor-only symbols (`edTile` clips, `ico_*`, `kvad`) are not needed.

### 5. Screen and layout (3–4 days)

Status: partial. Palette tabs (fronts, backs, stairs, beams, water, objects, backdrops, options), storey and map/random toggles, layer toggles including textured. Wheel and +/− zoom 0.5×–3×; middle mouse or Space+drag pans. Not a fixed 1800×950 copy of the Flash window.

- `scenes/room_editor.tscn` plus `scripts/editor/room_editor.gd`, laid out like `visualEditor`:
  - grid with front, back, objects and backdrops layers;
  - the three palette tabs (front / back / details);
  - the two object lists and the backdrop list, and the room list;
  - the minimap (map mode);
  - text fields for file, room name, selected XML and hover info;
  - the button row and the six view toggles.
- Scales to the window; the grid can zoom (the original is fixed at 20 px).

### 6. Tools (3–4 days)

Status: partial. Paint, outline, erase, eyedropper, height, slot erase, objects, backdrop place, options form, XML apply, copy, delete confirm, minimap, storey, map/random toggle, new map cell. No room sort and no placement ghost.

- Rectangle paint, Shift outline, erase (the original's Ctrl, plus a right-drag), Alt eyedropper, zForm brush, slot erasers («Стереть передний план / задний план / детали / задники», «Стереть объекты»).
- Place an object or backdrop with the placement ghost. New objects get a 16-character `code` as in `Editor.code`, and the editor checks that codes are unique (Editor.txt warns about duplicates).
- Select and cycle objects; the XML field shows the selected object, «Проверить» parses, applies and reformats, and bad XML is shown in red instead of silently ignored.
- «Свойства» for room options; backdrop XML works (an original bug, fixed).
- Room list: copy by new name, delete with confirmation, sort by tip, level and id.
- Map mode: minimap click and hover, storey toggle, create a room on an empty cell, and a check that passes match the neighbours (Editor.txt asks the author to watch this by hand). A toggle switches map and random mode.

### 7. Checks beyond «Проверить» (1–2 days)

Status: partial. `editor_check.gd` warns and does not write.

- Known attributes per object kind and for room options from `Editor.txt`; unknown ones are warned about, not removed.
- `allact` / `allid` / `uid` / script targets that point nowhere; `back="X"` without a `tip="back"` room; door rows that disagree with the walls.
- Validation only; nothing writes until the author saves.

### 8. Undo and safety (1 day)

Status: done. Undo/redo, 3-minute autosave, and Save / Discard / Cancel before open, import, and leaving. Delete and revert always ask.

- Undo/redo of paint, place, delete and XML edits (a snapshot per action; rooms are small).
- Autosave of the open file to the user dir every few minutes.

### 9. Play-test and preview (2–3 days, new)

Status: done. Generate, Play land, Play room, and return to the editor. A test writes no world save.

- «Сгенерировать»: build the random land from this file with a seed and show the schematic and textured preview (`LandGen.build` / `present`, `land_preview.gd`, kept from our builder).
- «Играть комнату», new: save, drop the room cache, then start game.tscn in a temporary test land holding only the open room, with the player at its entrance or a clicked cell.
- «Играть локацию», new: the same with the land generated from this file and the shown seed.
- Esc or death returns to the editor with the file still open. A test run makes no world save and uses a throwaway character (or the last one, by choice).

### 10. Release entry and switch-over (2 days)

Status: partial. Main-menu entry, guide, editor per-file checkbox, revert, and the same on/off list on the PipBuck options page (`_fill_room_mods`). No separate master switch on that page. `map_builder` retired 2026-10-27.

- The main menu gets a "Room editor" entry for everyone, not only dev runs. The editor scene and its art are included in the export presets.
- Options get a "Player rooms" switch (on by default) plus a list of mod files to enable or disable, and "Open rooms folder".
- A short guide (`build/EDITOR_GUIDE.md`, the English and Russian Editor.txt content plus the new features) ships next to the game.
- Done: `map_builder.gd`, its scene, and `.uid` are in `_trash/map_builder/` (repo-relative `godot/scenes/`).
- Docs:
  - `IMPLEMENTED.md`: new section "Room editor";
  - `KNOWLEDGE_BASE.md`: editor facts;
  - `PORT_RULES.md`: the chosen decisions;
  - `HANDOFF.md`: paths.

Total: about 19–29 focused days. Step 1 and the round-trip test come first, because every later step trusts the codec.
