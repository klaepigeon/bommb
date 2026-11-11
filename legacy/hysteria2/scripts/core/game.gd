extends Node
## What the game knows: the nuggets and skills (content/skills.json), what Kurt has seen and read
## (knowledge flags), what he's carrying. One place, so every system asks the same question.

signal nuggets_changed(n: int)
signal skill_bought(id: String)
signal flag_set(name: String)

var trees := {}
var nuggets := 0
var skills := {}
var flags := {}
var ammo_loaded := 0
var ammo_spare := 0
var has_gun := false
var has_shotgun := false
var shells_loaded := 0
var shells_spare := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.open("res://content/skills.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	trees = {"memory": d["memory"], "survival": d["survival"]}

static var _phone := -1
## A phone (or tablet): the old town code asks this to keep its budgets down.
static func is_phone() -> bool:
	if _phone < 0:
		_phone = 1 if (OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--phone")) else 0
	return _phone == 1

func reset() -> void:
	nuggets = 0
	skills = {}
	flags = {}
	ammo_loaded = 0
	ammo_spare = 0
	has_gun = false
	has_shotgun = false
	shells_loaded = 0
	shells_spare = 0

func owned(id: String) -> bool:
	return skills.get(id, false)

func flag(name: String) -> bool:
	return flags.get(name, false)

func set_flag(name: String) -> void:
	if not flags.get(name, false):
		flags[name] = true
		flag_set.emit(name)

func skill(id: String) -> Dictionary:
	for t in trees:
		for s in trees[t]:
			if s["id"] == id:
				return s
	return {}

func tree_of(id: String) -> String:
	for t in trees:
		for s in trees[t]:
			if s["id"] == id:
				return t
	return ""

func add_nuggets(n: int) -> void:
	nuggets += n
	nuggets_changed.emit(nuggets)

func can_buy(id: String) -> bool:
	var s := skill(id)
	return not s.is_empty() and not owned(id) and nuggets >= int(s["cost"])

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	nuggets -= int(skill(id)["cost"])
	skills[id] = true
	if id == "deep_pockets":
		ammo_spare += 7
	nuggets_changed.emit(nuggets)
	skill_bought.emit(id)
	return true

func count(tree: String) -> int:
	var n := 0
	for s in trees[tree]:
		if owned(s["id"]):
			n += 1
	return n
