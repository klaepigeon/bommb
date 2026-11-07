class_name Items
extends RefCounted
## The item catalogue (assets/data/items.json): data, not code paths. Every item has a name,
## a category, where it's used (`use`: board before you roll, passive while you carry it,
## a ghost's turn, roulette, the room, or on someone else), what it targets, a price, a
## rarity, how long it lasts and an icon. What each one DOES is ItemManager. Three slots.

const MAX_HELD := 3
const RARITY_ORDER := ["common", "uncommon", "rare", "contraband"]

static var _cat: Dictionary = {}


static func all() -> Dictionary:
	if _cat.is_empty():
		_cat = Assets.load_json("res://assets/data/items.json").get("items", {})
	return _cat


static func def(id: String) -> Dictionary:
	return all().get(id, {})


static func has(id: String) -> bool:
	return all().has(id)


static func name_of(id: String) -> String:
	return str(def(id).get("name", id.to_upper()))


static func desc_of(id: String) -> String:
	return str(def(id).get("desc", ""))


static func use_of(id: String) -> String:
	return str(def(id).get("use", ""))


static func target_of(id: String) -> String:
	return str(def(id).get("target", "none"))


static func usable_on_board(id: String) -> bool:
	return use_of(id) == "board"


static func price_of(id: String) -> int:
	return int(def(id).get("price", 5))


static func ids_where(f: Callable) -> Array:
	var out := []
	for k in all().keys():
		if f.call(k, all()[k]):
			out.append(k)
	return out


## A random item you could find lying about (not ghost-only, not the rigged gift). `pool`:
## "any", a use ("board", "roulette"...), a category, or a rarity. `worse` (the Cage tipping
## it): the least useful end.
static func roll(rng: RandomNumberGenerator, pool := "any", worse := false) -> String:
	if worse:
		return ["hairpin", "bandage", "reverse_gear"][rng.randi_range(0, 2)]
	var w := {"common": 6, "uncommon": 3, "rare": 1, "contraband": 1}
	var ids := ids_where(func(k, d):
		if d.get("rarity", "") == "none" or d.get("cat", "") == "ghost" or k == "lazarus_rat":
			return false
		return pool == "any" or d.get("use", "") == pool or d.get("cat", "") == pool or d.get("rarity", "") == pool)
	if ids.is_empty():
		return "bandage"
	ids.sort()
	var total := 0
	for k in ids:
		total += int(w.get(str(def(k).get("rarity", "common")), 1))
	var r := rng.randi_range(0, total - 1)
	for k in ids:
		r -= int(w.get(str(def(k).get("rarity", "common")), 1))
		if r < 0:
			return k
	return ids[0]
