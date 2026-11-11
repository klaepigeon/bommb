class_name Items
extends RefCounted
## What pocketable things are.
const ALL := {
	"living_key": ["Door key", Color(0.75, 0.62, 0.3)],
	"padlock_key": ["Small key", Color(0.7, 0.7, 0.7)],
	"magazine": ["Magazine", Color(0.85, 0.3, 0.3)],
	"needle": ["Knitting needle", Color(0.6, 0.6, 0.7)],
	"shoe_left": ["Red shoe (left)", Color(0.75, 0.08, 0.08)],
	"shoe_right": ["Red shoe (right)", Color(0.75, 0.08, 0.08)],
	"fuse": ["Fuse", Color(0.85, 0.8, 0.6)],
	"matches": ["Matches", Color(0.8, 0.6, 0.3)],
	"revolver": ["Revolver", Color(0.15, 0.15, 0.17)],
	"rounds": ["Rounds", Color(0.7, 0.6, 0.3)],
	"photo": ["Photograph", Color(0.9, 0.88, 0.8)],
}
static func colour(id: String) -> Color:
	if id.begins_with("rednote:"): return Color(0.85, 0.12, 0.1)
	if id.begins_with("note:"): return Color(0.95, 0.87, 0.4)
	return ALL.get(id, ["", Color(0.6, 0.6, 0.6)])[1]
static func title(id: String) -> String:
	return ALL.get(id, [id, Color.WHITE])[0]
