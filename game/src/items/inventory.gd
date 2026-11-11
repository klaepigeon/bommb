class_name Inventory
extends RefCounted
## What Kurt carries. Counts per item id; the revolver's loaded rounds live on the weapon, loose
## rounds here ("ammo"). Torch charge is item state ("torch" -> charge).

var items := {}               # id -> count
var state := {}               # id -> Dictionary (per-item state: torch charge...)
var order: Array = []         # pickup order, for the UI

func has(id: String, n := 1) -> bool:
	return int(items.get(id, 0)) >= n

func count(id: String) -> int:
	return int(items.get(id, 0))

func add(id: String, n := 1) -> void:
	items[id] = count(id) + n
	if id not in order:
		order.append(id)
	Events.inventory_changed.emit()

func remove(id: String, n := 1) -> bool:
	if not has(id, n):
		return false
	items[id] = count(id) - n
	if items[id] <= 0:
		items.erase(id)
		order.erase(id)
	Events.inventory_changed.emit()
	return true

## the first item carried that has a tag (best first: items list "quality" for a tag)
func with_tag(tag: String) -> String:
	var best := ""
	var best_q := -1.0
	for id in order:
		if ItemDB.has_tag(id, tag):
			var q := float(ItemDB.get_item(id).get("quality", {}).get(tag, 1.0))
			if q > best_q:
				best = id; best_q = q
	return best

func list() -> Array:
	return order.duplicate()

func to_dict() -> Dictionary:
	return {"items": items, "state": state, "order": order}

func from_dict(d: Dictionary) -> void:
	items = d.get("items", {})
	state = d.get("state", {})
	order = d.get("order", items.keys())
	Events.inventory_changed.emit()
