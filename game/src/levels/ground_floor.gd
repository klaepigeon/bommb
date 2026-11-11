class_name GroundFloorLayout
## Building 14, ground floor. Out of the maze, Kurt walks in through the building's own front door
## and he's in the lobby. Apartment 13 is down the corridor. The Super walks this floor.
##
##   z=0  +-------------+    +---------+           +---------------+
##        | THE LODGE   |    | STAIRS  |           | APARTMENT 13  |
##        | (his room)  |    | (under) |           |  (the end)    |
##   z=6  +----D--------+----D--------+           +-----D---------+
##        |     LOBBY  mailboxes      |== CORRIDOR (11 12 13 14 15) ==|
##        |                           |-----------------D-------------+
##  z=13  +---------+arch+------------+         | LAUNDRY  |
##                  |VEST|  <- the street door (white beyond)
##
## Ways into 13: the key from mailbox 13 (in the open), the key board in his lodge (his room),
## pick the lock (slow, quiet), force it (fast, loud).

const TUBE := "#d0ecd8"
const WARM := "#ffc888"

static func layout() -> Dictionary:
	var rooms := {
		"vestibule": {"rect": [4.5, 13, 7.5, 16.5], "wall": "green_paint", "floor": "concrete", "surface": "concrete", "skirting": false,
			"lights": [{"p": [6.0, 2.5, 14.8], "c": TUBE, "e": 0.6, "r": 4.0, "fix": "tube"}], "acoustics": {"size": 0.4, "damp": 0.3, "wet": 0.35}, "ambience": "drone"},
		"lobby": {"rect": [0, 6, 12, 13], "h": 3.2, "wall": "green_paint", "floor": "concrete", "surface": "concrete", "skirting": false, "circuit": "A", "flicker": 0.25,
			"lights": [{"p": [3.5, 3.1, 9.5], "c": TUBE, "e": 0.8, "r": 6.0, "fix": "tube"}, {"p": [9.0, 3.1, 9.5], "c": TUBE, "e": 0.7, "r": 6.0, "fix": "tube"}],
			"acoustics": {"size": 0.8, "damp": 0.25, "wet": 0.45}, "ambience": "drone"},
		"lodge": {"rect": [0, 0, 5, 6], "wall": "plaster", "floor": "lino", "surface": "tile", "circuit": "B", "alter": {"mould": 0.5},
			"lights": [{"p": [2.5, 2.1, 3.0], "c": WARM, "e": 0.8, "r": 5.0, "fix": "shade"}], "acoustics": {"size": 0.3, "damp": 0.6, "wet": 0.15}},
		"stairs": {"rect": [8, 2.5, 12, 6], "wall": "green_paint", "floor": "concrete", "surface": "concrete", "skirting": false,
			"ambient": [0.03, 0.03, 0.035], "acoustics": {"size": 0.7, "damp": 0.3, "wet": 0.5}},
		"corridor": {"rect": [12, 8, 30, 10], "wall": "green_paint", "floor": "concrete", "surface": "concrete", "skirting": false, "circuit": "A",
			"lights": [{"p": [15.0, 2.5, 9.0], "c": WARM, "e": 0.6, "r": 4.5}, {"p": [22.0, 2.5, 9.0], "c": WARM, "e": 0.45, "r": 4.0}, {"p": [28.0, 2.5, 9.0], "c": WARM, "e": 0.6, "r": 4.5}],
			"acoustics": {"size": 0.6, "damp": 0.3, "wet": 0.4}},
		"laundry": {"rect": [19.5, 10, 25, 14], "wall": "tile_wall", "floor": "tile_floor", "surface": "tile", "circuit": "B",
			"lights": [{"p": [22.2, 2.4, 12.0], "c": "#e0e8ff", "e": 0.5, "r": 4.5}], "acoustics": {"size": 0.35, "damp": 0.1, "wet": 0.45}},
		"apt13": {"rect": [23, 3, 30, 8], "wall": "damask", "floor": "parquet", "surface": "wood", "alter": {"wrong": 0.15},
			"lights": [{"p": [26.5, 2.3, 5.5], "c": WARM, "e": 0.7, "r": 5.0, "fix": "bulb"}], "acoustics": {"size": 0.3, "damp": 0.7, "wet": 0.12}},
	}
	var openings := [
		{"p": [6.0, 16.5], "axis": "x", "w": 1.4, "h": 2.3, "door": {"id": "street_door", "style": "door_padded", "swing": -1, "jammed": "white"}},
		{"p": [6.0, 13.0], "axis": "x", "w": 1.6, "h": 2.4},
		{"p": [2.5, 6.0], "axis": "x", "w": 0.9, "door": {"id": "lodge_door", "swing": -1, "open": 0.4}},
		{"p": [10.0, 6.0], "axis": "x", "w": 1.4, "h": 2.4},
		{"p": [12.0, 9.0], "axis": "z", "w": 1.6, "h": 2.4},
		{"p": [14.5, 8.0], "axis": "x", "w": 0.9, "door": {"id": "flat11", "style": "door_padded", "swing": 1, "jammed": "locked"}},
		{"p": [16.5, 10.0], "axis": "x", "w": 0.9, "door": {"id": "flat12", "style": "door_padded", "swing": -1, "jammed": "locked"}},
		{"p": [26.5, 8.0], "axis": "x", "w": 0.9, "door": {"id": "apt13_door", "style": "door_padded", "swing": -1, "locked": true, "key": "key:apt13"}},
		{"p": [22.2, 10.0], "axis": "x", "w": 0.9, "door": {"id": "laundry_door", "swing": 1, "open": 0.3}},
		{"p": [28.0, 10.0], "axis": "x", "w": 0.9, "door": {"id": "flat15", "style": "door_padded", "swing": -1, "jammed": "locked"}},
		{"p": [18.5, 8.0], "axis": "x", "w": 0.9, "door": {"id": "flat14", "style": "door_padded", "swing": 1, "jammed": "locked"}},
	]
	var f := [
		# ---- the vestibule
		{"t": "radiator", "room": "vestibule", "p": [4.6, 14.8], "r": -90, "w": 0.6},
		{"t": "paper", "room": "vestibule", "p": [7.45, 14.8], "r": 90, "doc": "building_notice"},
		# ---- the lobby: mailboxes (13's has a key in it), bottles, a dead lift
		{"t": "mailboxes", "room": "lobby", "p": [0.2, 9.5], "r": -90, "id": "mailboxes"},
		{"t": "prop", "room": "lobby", "kind": "bottle", "p": [5.0, 7.0], "lift": 0.15},
		{"t": "prop", "room": "lobby", "kind": "bottle", "p": [8.4, 12.2], "lift": 0.15},
		{"t": "prop", "room": "lobby", "kind": "bucket", "p": [11.4, 12.4]},
		{"t": "boxes", "room": "lobby", "p": [1.0, 12.2], "n": 4},
		{"t": "radiator", "room": "lobby", "p": [11.9, 11.5], "r": 90, "w": 0.8},
		{"t": "picture", "room": "lobby", "p": [6.0, 6.03], "r": 180, "w": 0.8, "h": 0.5, "y0": 1.9, "inner": "paper"},
		# ---- the lodge: his room. The key board's by the door.
		{"t": "bed", "room": "lodge", "p": [0.9, 2.2], "r": 0, "w": 1.0, "l": 2.0, "id": "lodge_bed", "unmade": true},
		{"t": "table", "room": "lodge", "p": [3.4, 1.4], "w": 1.0, "d": 0.7, "on": ["cup", "bottle"]},
		{"t": "prop", "room": "lodge", "kind": "radio", "p": [3.7, 1.4], "y": 0.76, "lift": 0.1},
		{"t": "keyboard", "room": "lodge", "p": [4.95, 4.8], "r": 90, "keys": ["key_apt13"]},
		{"t": "wardrobe", "room": "lodge", "p": [4.65, 2.6], "r": 90, "id": "lodge_wardrobe"},
		{"t": "boxes", "room": "lodge", "p": [0.6, 5.3], "n": 3},
		{"t": "prop", "room": "lodge", "kind": "bucket", "p": [2.2, 0.5]},
		# ---- the stairs: up is chained off; under them, a cupboard
		{"t": "stairs_down", "room": "stairs", "p": [10.6, 4.7], "r": 0},
		{"t": "hiding_closet", "room": "stairs", "p": [8.35, 4.2], "r": -90, "id": "under_stairs"},
		# ---- the corridor
		{"t": "radiator", "room": "corridor", "p": [20.5, 8.07], "r": 180, "w": 0.6},
		{"t": "prop", "room": "corridor", "kind": "box_big", "p": [24.0, 9.6]},
		{"t": "sticky", "room": "corridor", "p": [26.0, 8.03], "r": 180, "h": 1.7, "text": "13", "doc": "sticky_13"},
		# ---- the laundry: places to hide, things to throw
		{"t": "washer", "room": "laundry", "p": [20.0, 11.0], "r": -90},
		{"t": "washer", "room": "laundry", "p": [20.0, 11.8], "r": -90},
		{"t": "wardrobe", "room": "laundry", "p": [24.65, 12.5], "r": 90, "id": "laundry_cupboard"},
		{"t": "prop", "room": "laundry", "kind": "bucket", "p": [22.0, 13.4]},
		{"t": "prop", "room": "laundry", "kind": "bottle", "p": [23.0, 13.5], "lift": 0.15},
		# ---- apartment 13: the end of the chapter
		{"t": "coat_rack", "room": "apt13", "p": [23.05, 6.0], "r": -90},
		{"t": "table", "room": "apt13", "p": [26.5, 4.6], "w": 1.2, "d": 0.8, "cloth": true},
		{"t": "prop", "room": "apt13", "kind": "chair", "p": [26.5, 5.4], "lift": 0.46},
		{"t": "sticky", "room": "apt13", "p": [26.5, 3.03], "r": 180, "h": 1.6, "text": "WAIT HERE", "doc": "sticky_wait"},
	]
	return {
		"rooms": rooms, "openings": openings, "furniture": f,
		"circuits": {"A": {"live": true, "fuse": true}, "B": {"live": true, "fuse": true}},
		"spawns": {"entrance": [6.0, 0.0, 15.7, 0.0], "caught": [6.0, 0.0, 15.2, 0.0], "restore": [6.0, 0.0, 15.2, 0.0]},
		"triggers": [
			{"id": "lobby", "p": [6.0, 1.2, 11.8], "size": [3.0, 2.4, 1.6], "once": true},
			{"id": "arrive13", "p": [26.5, 1.2, 6.2], "size": [3.0, 2.4, 2.4], "once": true},
		],
		"patrol": [[2.5, 0, 3.4], [3.0, 0, 9.0], [9.0, 0, 11.0], [16.0, 0, 9.0], [28.5, 0, 9.0], [22.2, 0, 12.0], [14.0, 0, 9.0], [6.0, 0, 7.5], [9.0, 0, 5.4]],
		"super_start": [2.6, 0.0, 3.6],
		"fog_begin": 3.0, "fog_end": 15.0,
	}
