class_name ItemDB
## Item definitions (content/items.json). An item's tags are what it can do; obstacles ask for
## tags, not for specific items, so the same problem accepts any tool that fits ("pry": the crowbar
## or the claw hammer; "light": the torch or the lighter).

const PATH := "res://content/items.json"
static var _items := {}

static func all() -> Dictionary:
	if _items.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_items = d.get("items", {})
	return _items

static func get_item(id: String) -> Dictionary:
	return all().get(id, {})

static func item_name(id: String) -> String:
	return String(get_item(id).get("name", id))

static func has_tag(id: String, tag: String) -> bool:
	return tag in get_item(id).get("tags", [])

static func category(id: String) -> String:
	return String(get_item(id).get("category", "misc"))
