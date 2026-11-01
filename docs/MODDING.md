# Modding

Mods live under the user directory (`UserDir.mods()`): `user://mods/` in the editor, or `mods/` next to the executable in a build. A sandbox run (`--user-dir=`) uses that folder's `mods/`. Nothing here writes over a file in `res://`. Turning a mod off and launching again restores the built-in data, art, and sounds.

The main-menu Mods tab (the free fifth settings sub-tab) lists mods and the loose-room files. Switches are stored immediately and apply on the next launch.

## Folder layout

```
mods/
  rooms/                         built-in loose-rooms mod (id rooms)
    _disabled.json               {"disabled": ["rooms_begin", ...]}
    <file>.json                  room document, same stem as maps/rooms
  <folder>/
    mod.json
    data/                        same relative path as res://assets/data/
      weapons.json
      balance/player.json
    assets/                      same relative path as res://assets/
      ui/cursor/arrow.png
      sounds/shot.ogg
      sprites/weapons/held/manifest.json   JSON here merges like data/
    rooms/
      <file>.json
```

`rooms` is reserved for loose rooms. A folder without `mod.json` is ignored. Code is not loaded from the mod folder.

The player's enabled flags and order are **not** in the mod folder. They are in `settings/mods.cfg` (a build) or `user://mods.cfg` (the editor):

```
[enabled]
sample_arsenal=true
silent=false

[order]
ids=rooms,sample_arsenal,later_arsenal
```

`enabled` overrides `mod.json`. A missing key uses `mod.json`'s `enabled`, which defaults to true. `order/ids` is a comma-separated id list. Ids not listed keep their computed order after the listed ones. Leave `ids` empty to use `after` and `order` from `mod.json`.

## mod.json

```json
{
  "id": "sample_arsenal",
  "name": "Sample arsenal",
  "version": "1.0.0",
  "after": ["other_mod"],
  "order": 0,
  "enabled": true,
  "description": "Optional. Shown on the Mods tab."
}
```

`id` is a required token (`a-z`, `A-Z`, `0-9`, `_`, `-`) and must not be `rooms`. `name` defaults to the id. `version` is a string. `after` is a list of mod ids that must load first. `order` is a number; lower comes first when `after` does not decide. `description` is optional.

## Load order

1. Loose rooms (`rooms`), unless the player disabled that id.
2. Otherwise, mods whose `after` list is already placed, lowest `order`, then id.
3. A cycle is logged (`ModLoader: load-order cycle…`) and the rest are appended by id.
4. Disabled mods stay in that sequence (so `after` can name them) but they do not merge.
5. If `mods.cfg` has `order/ids`, that sequence is applied on top.

A mod that fails is dropped from the active set. Later mods still run.

## Data merge

For each enabled mod, in order, `mods/<folder>/data/<path>` merges over `res://assets/data/<path>`, and a `.json` under `mods/<folder>/assets/<path>` merges over `res://assets/<path>`. Every merged file needs a schema (`data_schemas.gd`); a file without one skips the mod. The built-in file on disk is not modified. `DataLib.load` returns a deep read-only copy of the merge. `DataLib.copy` is the writable copy.

Rules, applied at every object:

- Start from a deep copy of the value so far.
- `"remove": ["id", ...]` deletes those keys from this object, and deletes id-rows in arrays directly inside it. The key `remove` is not kept.
- Where both sides are objects, merge key by key. The mod's value wins. Nested objects merge the same way.
- An array of rows that each have an id (`id`, or the schema's `id_field` on the file's list) is merged by that id. A mod row deep-merges onto the built-in row. A new id is appended.
- An array whose rows have no ids is replaced by the mod array. That includes `order` lists of plain strings. Omit the key to keep the built-in array.
- Two mods that both write the same id: the later mod wins, and one line is logged: `DataLib: duplicate id <id> in <path>: <earlier> then <later>, last wins`.
- After a file is merged, one line lists its ids: `DataLib: merged <res:// path> ids: …`.

The merged value is checked with `data_schemas.gd` (see `docs/DATA_SCHEMA.md`). If any data file in a mod fails to parse or fails that check, the mod is skipped **whole**: none of its data, rooms, or art are applied. One log line, not `push_error`. Mod JSON is parsed by the port, not by `JSON.parse_string`, so a broken file does not also print an engine `ERROR:` line:

```
ModLoader: skip <id>: <path>: <reason>
```

The game continues with the other mods. A built-in file that itself fails the schema still uses `push_error`, same as before. `-s` scripts do not construct `UserDir`. Mods stay off there unless `--user-dir=` is set, in which case that sandbox is read.

`remove` sits on the object whose ids it deletes. For a row list, put it next to the list. For an id-keyed object such as `enemies.json`'s `units`, put it inside that object.

## Examples

These two files are what `python tools/run_checks.py --only mods` applies (mod id `good`, then a later mod that sets the same weapon's `damage` to 77).

`mods/good/data/weapons.json` — `armature` keeps every built-in field except `damage`. `mod_stick` is a new row (the schema requires `id`, `name`, and `kind`). `bat` is removed from the merged list only:

```json
{
  "weapons": [
    {"id": "armature", "damage": 40},
    {"id": "mod_stick", "name": "Mod stick", "kind": "melee", "damage": 5}
  ],
  "remove": ["bat"]
}
```

`mods/good/data/enemies.json` — `bloat1` stays a complete unit with `hp` replaced. `mod_mite` is a new id. `bloodwing` is removed from `units`. A new enemy that should spawn still needs the same fields as a built-in unit; copy one and change it. This overlay is the shape the check asserts:

```json
{
  "units": {
    "bloat1": {"hp": 99},
    "mod_mite": {"name": "mod_mite", "hp": 1},
    "remove": ["bloodwing"]
  }
}
```

`mod.json` for that mod:

```json
{
  "id": "good",
  "name": "Sample arsenal",
  "version": "1.0.0",
  "after": ["bad"],
  "description": "One weapon tweak and one enemy tweak."
}
```

## New weapon

Stats go in `data/weapons.json` (above) and the shop and inventory row in `data/content/weapons_catalog.json`. The held art goes in `assets/sprites/weapons/held/manifest.json`, which merges like data:

```json
{
  "ids": {"mod_stick": "vismodstick"},
  "clips": {
    "vismodstick": {"file": "vismodstick.png", "png": [24, 4], "anchor": [3, 2], "emit": [20, 1]}
  }
}
```

- `ids` maps the weapon id to its clip. Without it the weapon shows the 10mm pistol.
- `anchor` is the grip, in pixels from the PNG's top-left. It goes on the hoof, the teeth, or the telekinesis point.
- `emit` is the muzzle, measured from the grip with the barrel along +X. Without it the muzzle is the PNG's right edge.
- An animated clip adds `sheet` (path under `held/`), `cell` [w, h], `cols`, `pad`, `map` (one sheet cell per Flash frame), `labels` and `script`. Copy a built-in clip with the same behaviour.
- The PNG is `assets/sprites/weapons/held/<file>`.

Enemies need nothing more. Each body family (`raider_m`, `raider_w`, `zebra`, `ranger`, `encl`, `griffon`) has a hoof point per animation frame in `data/unit_wpos.json`. The game puts the weapon's grip on that point and fires from its muzzle. As in the original, melee, light guns and explosives are held this way; heavy guns are not. Which enemies carry a weapon is `data/enemies.json`.

## New armour

- Stats: `data/craft_condition.json` `armors.<id>` (hit points, `armor`, `marmor`, `resists`, repair component, upgrades). An id listed there is wearable. Extras per suit are in `data/armor_dexter.json` and `data/armor_sneak.json`.
- Look: `data/armor_art.json`.

```json
{"my_suit": {"base": "assault", "hide_mane": false}}
```

The suit uses `base`'s frames on every body part, so it fits the rig with no frame data. Each picture the rig draws for the base, `<part>_<base>_L<n>_S<n>.png` under `assets/rigs/player/art/`, is replaced by `<part>_my_suit_L<n>_S<n>.png` when the mod ships that file. A part without one keeps the base picture, so a mod can repaint one part at a time. The base picture's offset is used unless the mod adds its own entry to `assets/rigs/player/art/png_metadata.json`. Start from the base suit's PNGs to keep the same canvas. `hide_mane` defaults to the base suit's rule.

Replacing a built-in suit's PNG under its own name is a plain art override (see "Art and sound").

## Names

`data/item_text.json` gives an id a name and description, checked before the original text:

```json
{"mod_stick": {"name": {"en": "Mod stick", "ru": "Мод-палка"}, "desc": {"en": "A stick."}}}
```

`name` is required, `desc` optional. A missing language falls back to `en`. The same file can rename a built-in id.

## Art and sound

A file at `mods/<folder>/assets/<path>` replaces `res://assets/<path>` for `png`, `jpg`, `jpeg`, `webp`, `bmp`, `tga`, `ogg`, `wav`, and `mp3`. New paths work the same way: later `load("res://assets/<path>")` returns the mod resource even when the built-in project has no such file.

At boot, `UserDir._init` (the first autoload, after `patches/*.pck` are mounted) decodes each file and installs it:

- Images: `Image.load_from_file` then `ImageTexture.create_from_image`.
- Ogg: `AudioStreamOggVorbis.load_from_file`. Mp3: `AudioStreamMP3.load_from_file`. Wav: `AudioStreamWAV.load_from_file`.
- `take_over_path` on a copy for `res://assets/<path>` and, when the built-in file has a `.import`, on another copy for the remap path (`res://.godot/imported/….ctex`). One resource holds one path.
- `mod_asset_loader.gd`, a `ResourceFormatLoader` added at the front of the loader list, returns that resource for the source path, the remap path, and the `uid://` from the `.import`.

`take_over_path` of the source and the `.ctex` is not enough on its own. `load()` of an imported texture still came back as a new `CompressedTexture2D`: the import remap does not use those two cache keys. The loader is what makes the later `load()` return the mod resource. No built-in file is written. The next boot without the mod loads the original import.

Limits:

- `preload()` in a script, and any node already holding the resource, keep the object they received. Takeover runs in `UserDir._init`, before later autoload scripts are parsed, so a `preload()` in those scripts sees the mod resource. A `preload()` that already ran (this script, or anything the engine loaded before `UserDir`) keeps the original.
- The override is an uncompressed `ImageTexture` (RGBA8 from the file). It does not use the `.import` settings: VRAM compression, lossless texture compression, mipmaps, repeat, or filter. The imported `CompressedTexture2D` stays on disk and is what you get when the mod is off.
- A file that fails to decode is skipped and logged (`ModLoader: art skip …`). That does not drop the rest of the mod. A data-validation failure does drop the mod's art, because the mod is skipped whole.
- Two mods replacing one path: the later mod wins (`ModLoader: art <path> replaced by <id>`).

## Code mods (.pck)

Script and scene changes stay `patches/*.pck` next to the executable. `UserDir._load_patches` mounts them in name order, each over the last, and only in an exported build (the editor skips them). A patch cannot change `project.godot`, the autoload list, or a `class_name` script that is already loaded. `user_dir.gd` itself is the autoload that mounts patches, so a patch cannot replace it. Those changes need a full build. See `HANDOFF.md` "Patches".

## Rooms

Loose rooms stay `mods/rooms/<file>.json`. `_disabled.json` is `{"disabled": [stem, ...]}` and skips that loose file only. The editor still writes these.

An enabled mod may also ship `mods/<folder>/rooms/<file>.json`. `RoomFile.load_doc` starts from the built-in document and overlays each enabled source in load order (loose rooms, then mods). The same room rules as before: per room name the file wins, `remove` drops rooms, and a file with no built-in base is used as-is. A mod skipped for a bad data file does not contribute its rooms.

## Saves

Run document version 2 adds a `mods` provider:

```json
{"version": 1, "active": [{"id": "rooms", "version": ""}, {"id": "good", "version": "1.0.0"}]}
```

It lists the mods that actually loaded, in order, with their versions. Loose rooms use an empty version. A version 1 run document, or a version 2 document with no `mods` key, still loads. Loading does not turn mods on or off; the next save records whatever is active this boot.

If the slot's list is present and differs (ids, versions, or order), the main-menu load dialog asks before loading, and the PipBuck load page shows the same warning on the slot and as a notice. Confirming still loads.
