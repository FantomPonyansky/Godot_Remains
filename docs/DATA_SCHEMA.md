# Data schemas

Generated from `godot/scripts/data_schemas.gd` by `tools/data_schema_doc.py`. Do not edit by hand.

Types are `dict`, `array`, `string`, `number`, and `bool`. `DataLib.load` checks these shapes. A file with no section here has no schema.

`list` / `id_field` / `row` / `unique` describe an array of rows. `of` and `fields` describe id-keyed objects. `map` is the object `by_id` returns when several exist. `array_of` / `array_min` constrain array values named in `of`.

## `res://assets/data/advice.json`

- root: `dict`
- req: {`en` `array`, `ru` `array`}

## `res://assets/data/armor_art.json`

- root: `dict`
- of: {`.` `dict`}
- fields: {`base` `string`}

## `res://assets/data/armor_dexter.json`

- root: `dict`
- of: {`.` `array`}
- array_of: `number`
- array_min: `1`

## `res://assets/data/armor_sneak.json`

- root: `dict`
- of: {`.` `array`}
- array_of: `number`
- array_min: `1`

## `res://assets/data/backs.json`

- root: `dict`
- req: {`kinds` `dict`, `dim` `number`, `tile` `number`}
- of: {`kinds` `dict`}
- map: `kinds`

## `res://assets/data/balance/ai.json`

- root: `dict`
- of: {`.` `number`}

## `res://assets/data/balance/body.json`

- root: `dict`
- req: {`rec_mana` `number`, `organ_base` `number`, `organ_per_level` `number`, `stam_max` `number`, `stam_regen` `number`, `stam_run` `number`, `stam_jump` `number`, `breath_max` `number`, `breath_regen` `number`, `breath_drain` `number`, `channel_ticks` `number`, `battle_no_out` `number`, `max_health` `number`, `max_ammo` `number`, `max_magic` `number`, `tele_mana_mult` `number`, `rad_drad2_decay` `number`, `save_ticks` `number`}

## `res://assets/data/balance/difficulty.json`

- root: `dict`
- req: {`price_hp` `number`, `price_mana` `number`, `doctor_raz` `number`, `doctor_raz_mana` `number`, `rows` `array`}
- list: `rows`
- row: {`id` `string`, `beg_hp` `number`, `lvl_hp` `number`, `pet_res` `number`, `organ_mult` `number`, `tele_mana` `number`, `caps_mult` `number`, `neujaz` `number`, `die_damage` `number`, `him_bad_dif` `number`, `bonus_heal_mult` `number`, `price_blood` `number`, `price_organ` `number`, `price_rad` `number`, `price_poison` `number`, `price_cut` `number`, `enemy_hp` `number`, `enemy_ear` `number`}
- unique: `true`

## `res://assets/data/balance/options.json`

- root: `dict`
- req: {`audio` `dict`, `game` `dict`, `ui` `dict`, `input` `dict`, `camera` `dict`}

## `res://assets/data/balance/player.json`

- root: `dict`
- of: {`.` `number`}

## `res://assets/data/balance/progression.json`

- root: `dict`
- req: {`xp_delta` `number`, `xp_delta_fast` `number`, `xp_bend_level` `number`, `xp_bend_span` `number`, `xp_round` `number`, `level_sk_add` `number`, `level_sk_add_hard` `number`, `unit_xp_mult` `number`, `max_tele_massa` `array`, `tele_porog` `array`, `tele_accel` `array`, `unit_levit_mult` `array`}

## `res://assets/data/balance/sats.json`

- root: `dict`
- of: {`.` `number`}

## `res://assets/data/balance/vision.json`

- root: `dict`
- req: {`ldist1` `number`, `ldist2` `number`, `move_px` `number`, `fog_returns` `bool`, `fade` `number`, `mem_level` `number`, `mem_saturation` `number`, `land_vis` `dict`}
- of: {`land_vis` `number`}

## `res://assets/data/balance/water.json`

- root: `dict`
- of: {`.` `number`}

## `res://assets/data/bestiary.json`

- root: `dict`
- req: {`units` `array`}
- list: `units`
- row: {`id` `string`}
- unique: `true`

## `res://assets/data/block_destroy.json`

- root: `dict`
- of: {`.` `number`}

## `res://assets/data/content/consumables.json`

- root: `dict`
- req: {`items` `array`}
- list: `items`
- row: {`id` `string`}
- unique: `true`

## `res://assets/data/content/items.json`

- root: `dict`
- req: {`items` `array`}
- list: `items`
- row: {`id` `string`}
- unique: `true`

## `res://assets/data/content/weapons_catalog.json`

- root: `dict`
- req: {`weapons` `array`}
- list: `weapons`
- row: {`id` `string`}
- unique: `true`

## `res://assets/data/craft_condition.json`

- root: `dict`
- req: {`stations` `dict`, `recipes` `array`, `weapons` `dict`, `armors` `dict`}
- of: {`stations` `dict`, `weapons` `dict`, `armors` `dict`}
- list: `recipes`
- row: {`id` `string`}
- unique: `true`

## `res://assets/data/door_opac.json`

- root: `dict`
- of: {`.` `number`}

## `res://assets/data/effect_items.json`

- root: `dict`
- req: {`items` `array`}
- list: `items`
- row: {`id` `string`}
- unique: `true`

## `res://assets/data/effects.json`

- root: `dict`
- req: {`effects` `array`}
- list: `effects`
- row: {`id` `string`}
- unique: `true`

## `res://assets/data/enemies.json`

- root: `dict`
- req: {`units` `dict`, `aliases` `dict`, `order` `array`}
- of: {`units` `dict`}
- map: `units`

## `res://assets/data/enemy_combat.json`

- root: `dict`
- req: {`units` `dict`}
- of: {`units` `dict`}
- map: `units`

## `res://assets/data/hard_inv.json`

- root: `dict`
- req: {`base` `dict`, `items` `dict`, `perks` `dict`}
- of: {`base` `number`, `items` `dict`, `perks` `array`}
- map: `items`

## `res://assets/data/item_mess.json`

- root: `dict`
- req: {`items` `dict`, `text` `dict`}
- of: {`items` `dict`}
- map: `items`

## `res://assets/data/item_text.json`

- root: `dict`
- of: {`.` `dict`}
- fields: {`name` `dict`}

## `res://assets/data/loot/containers.json`

- root: `dict`
- req: {`boxes` `dict`}
- of: {`boxes` `dict`}
- map: `boxes`

## `res://assets/data/loot/pools.json`

- root: `dict`
- req: {`tips` `dict`, `info` `dict`}
- of: {`tips` `array`, `info` `dict`}
- map: `info`

## `res://assets/data/loot_fall.json`

- root: `dict`
- of: {`.` `string`}

## `res://assets/data/maps/begin_actors.json`

- root: `dict`
- req: {`units` `array`, `hazards` `array`, `traps` `array`, `loot` `array`, `buttons` `array`, `areas` `array`, `doors` `array`}

## `res://assets/data/maps/begin_land.json`

- root: `dict`
- req: {`id` `string`, `rooms` `array`}

## `res://assets/data/maps/begin_visual.json`

- root: `dict`
- req: {`rooms` `array`, `default_backwall` `string`}
- list: `rooms`
- id_field: `name`
- row: {`name` `string`}
- unique: `true`

## `res://assets/data/maps/crate_art.json`

- root: `dict`
- of: {`.` `string`}

## `res://assets/data/maps/door_art.json`

- root: `dict`
- of: {`.` `array`}
- array_of: `number`
- array_min: `7`

## `res://assets/data/maps/held_massa.json`

- root: `dict`
- req: {`massa` `dict`, `mult` `dict`}
- of: {`massa` `number`, `mult` `number`}
- map: `massa`

## `res://assets/data/maps/lands.json`

- root: `dict`
- req: {`order` `array`, `lands` `dict`}
- of: {`lands` `dict`}
- map: `lands`

## `res://assets/data/maps/lock_use.json`

- root: `dict`
- of: {`.` `dict`}

## `res://assets/data/maps/npcs.json`

- root: `dict`
- of: {`.` `dict`}

## `res://assets/data/maps/objs.json`

- root: `dict`
- of: {`.` `dict`}

## `res://assets/data/maps/rooms/rooms_begin.json`

- root: `dict`
- req: {`file` `string`, `rooms` `array`}
- list: `rooms`
- id_field: `name`
- row: {`name` `string`}
- unique: `true`

## `res://assets/data/maps/scripts.json`

- root: `dict`
- of: {`.` `dict`}

## `res://assets/data/maps/tile_catalog.json`

- root: `dict`
- req: {`block` `dict`, `wall` `dict`}
- of: {`block` `array`, `wall` `array`}
- map: `block`

## `res://assets/data/maps/world_marks.json`

- root: `dict`
- of: {`.` `array`}
- array_of: `number`
- array_min: `3`

## `res://assets/data/music.json`

- root: `dict`
- req: {`units` `dict`}
- of: {`units` `array`}
- map: `units`

## `res://assets/data/perks.json`

- root: `dict`
- req: {`perks` `array`}
- list: `perks`
- row: {`id` `string`}
- unique: `true`

## `res://assets/data/pip_eff.json`

- root: `dict`
- of: {`.` `dict`}

## `res://assets/data/pony_clips.json`

- root: `dict`
- of: {`.` `dict`}
- fields: {`frames` `number`}

## `res://assets/data/port_strings.json`

- root: `dict`
- of: {`.` `dict`}
- fields: {`en` `string`, `ru` `string`}

## `res://assets/data/skills.json`

- root: `dict`
- req: {`meta` `dict`, `skills` `array`}
- list: `skills`
- row: {`id` `string`}
- unique: `true`

## `res://assets/data/species_fractions.json`

- root: `dict`
- of: {`.` `number`}

## `res://assets/data/spells.json`

- root: `dict`
- req: {`spells` `array`}
- list: `spells`
- row: {`id` `string`}
- unique: `true`

## `res://assets/data/story/items.json`

- root: `dict`
- of: {`.` `dict`}

## `res://assets/data/story/npcs.json`

- root: `dict`
- of: {`.` `dict`}

## `res://assets/data/story/quests.json`

- root: `dict`
- of: {`.` `dict`}

## `res://assets/data/trade.json`

- root: `dict`
- req: {`items` `dict`, `weapons` `dict`, `armors` `dict`, `vendors` `dict`}
- of: {`items` `dict`, `weapons` `dict`, `armors` `dict`, `vendors` `dict`}
- map: `items`

## `res://assets/data/unit_blood.json`

- root: `dict`
- of: {`.` `number`}

## `res://assets/data/unit_classes.json`

- root: `dict`
- req: {`kin` `dict`, `fixed` `dict`}
- of: {`kin` `array`, `fixed` `string`}
- map: `fixed`

## `res://assets/data/unit_loot.json`

- root: `dict`
- of: {`.` `array`}

## `res://assets/data/unit_massa.json`

- root: `dict`
- req: {`units` `dict`}
- of: {`units` `dict`}
- map: `units`
- fields: {`massa` `number`}

## `res://assets/data/unit_parts.json`

- root: `dict`
- of: {`.` `dict`}

## `res://assets/data/unit_wpos.json`

- root: `dict`
- req: {`units` `dict`, `wpos` `dict`}
- of: {`units` `dict`, `wpos` `array`}
- map: `units`

## `res://assets/data/weapons.json`

- root: `dict`
- req: {`weapons` `array`, `tick_rate` `number`}
- list: `weapons`
- row: {`id` `string`, `name` `string`, `kind` `string`}
- unique: `true`

## `res://assets/sprites/debris/debris.json`

- root: `dict`
- of: {`.` `dict`}

## `res://assets/sprites/decals/decals.json`

- root: `dict`
- of: {`.` `dict`}

## `res://assets/sprites/scenes/scenes.json`

- root: `dict`
- of: {`.` `dict`}

## `res://assets/sprites/units/grif_arm/arm.json`

- root: `dict`
- of: {`.` `dict`}

## `res://assets/ui/menu/anim/anim.json`

- root: `dict`
- of: {`.` `dict`}
- fields: {`frames` `number`}

## Path patterns

These match in `for_path` when the path is not one of the files above. The first match wins.

### `p.contains("/rigs/") and p.contains("/symbols/") and file.ends_with(".json")`

- root: `dict`

### `p.contains("/rigs/") and file == "index.json"`

- root: `dict`
- req: {`symbols` `array`}

### `p.contains("/rigs/") and file == "hierarchy.json"`

- root: `dict`
- req: {`bones` `array`}

### `p.contains("/rigs/") and file == "state_machine.json"`

- root: `array`
- id_field: `label`
- row: {`label` `string`, `animation` `string`}

### `p.contains("/rigs/") and file == "png_metadata.json"`

- root: `dict`
- of: {`.` `dict`}
- fields: {`vx` `number`, `vy` `number`}

### `file == "manifest.json"`

- root: `dict`
- of: {`.` `dict`}

### `file.ends_with("anchors.json")`

- root: `dict`
- of: {`.` `array`}
- array_of: `number`
- array_min: `2`
