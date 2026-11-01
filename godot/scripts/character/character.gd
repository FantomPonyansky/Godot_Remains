extends RefCounted

## One player's state (ARCHITECTURE_PLAN R3.1, MULTIPLAYER_PLAN step 2).
## The character autoloads keep their names and forward their fields to the
## parts of Run.character(); new per-character state goes here, not in a new
## autoload. One part per autoload, named after it.

const _Body := preload("res://scripts/character/body_state.gd")
const _Inventory := preload("res://scripts/character/inventory_state.gd")
const _Effects := preload("res://scripts/character/effects_state.gd")
const _Progression := preload("res://scripts/character/progression_state.gd")
const _MagicBinds := preload("res://scripts/character/magic_binds_state.gd")
const _Condition := preload("res://scripts/character/condition_state.gd")
const _Pets := preload("res://scripts/character/pets_state.gd")
const _Favorites := preload("res://scripts/character/favorites_state.gd")
const _Stash := preload("res://scripts/character/stash_state.gd")

var body := _Body.new()
var inventory := _Inventory.new()
var effects := _Effects.new()
var progression := _Progression.new()
var magic_binds := _MagicBinds.new()
var condition := _Condition.new()
var pets := _Pets.new()
var favorites := _Favorites.new()
var stash := _Stash.new()
