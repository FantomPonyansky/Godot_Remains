# Asset pack from the Godot port of Fallout Equestria: Remains

Made for Remains: Unity. Everything here is original Remains content (by Empalu), extracted for the Godot port, plus the port's data tables. It is non-commercial, under the same terms as the original game. Rebuild with `python tools/share_unity_pack.py` in the port repo.

## Resources/ (drop into Assets/Resources)

- `Original/Units/<id>/<sheet>.png` + `artwork.json`: one actor per enemy sheet (78 units), in the `AtlasActorArtwork` schema. The JSON is a TextAsset at the same key as the sprite.
  - Cells, atlas size, `pixelsPerUnit` 50, `pivotX/pivotY` (0..1 from bottom-left), clips at 30 fps.
  - Poses: `stay`→`idle`, `trot`→`walk`, `die`→`down`, `laz`→`climb`. Other clips keep their original names, e.g. `run`, `jump`, `attack`, `shoot`.
  - `weaponSockets` are filled for raider, slaver, zebra, ranger and enclave sheets. Values are px from the cell's top-left and come from the original `wPos` tables. Rotation is in `original.weaponRotation`.
  - `verticalFrames` are empty; the original picks jump frames by velocity in code.
  - `original` keeps the raw clip fields: `ff` (first frame), `stab`, `df`.
  - Sheets face right (`facesLeft: false`) except `necros`. Check radroach (`tarakan`): your atlas says it faces left.
  - Unit ids follow the game's `AllData`, not the FLA file names (FLA `Raider1` is `raider3` here).
  - `units_report.txt` lists clips that live on a second sheet (raider slow walk) and were left out.
- `Original/Audio/Port/*` (sfx, original sound ids as names) and `Original/Music/Port/*`.
  - Index: `Content/port-audio.json`.
  - `Content/port-music-map.json` is the port's land/event to track table.
- `Content/item-text.<lang>.json`: `{schema:1, items:[{id,name,description}]}` for every weapon, item, armor, ammo, spell, perk and skill entry in de, en, pl, ru and zh. Ids are `<tag>.<original id>`, e.g. `weapon.mont` (Crowbar). A `^1` suffix marks the unique variant.

## Other folders

- `Text/`: full `text_*.xml` (all dialogue, units, hints) plus `lang.xml`. The ru file is the 2021 release version.
- `Data/`: the port's JSON tables (weapons, enemies, perks, trade, effects, loot...), converted from `AllData.as` / `GameData.xml`.
- `Weapons/`: held weapon art plus per-weapon JSON (grip, muzzle, magazine).
- `Docs/KNOWLEDGE_BASE.md`: notes on the original's systems, formulas and file layout.

## Not included

- Tiles, decor and backgrounds: your tile manifest already covers them at the same 1x scale.
- Doors, objects and pony parts: yours are higher resolution.
