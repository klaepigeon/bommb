class_name Flat47Layout
## Flat 47, Building 14, Ulitsa Gagarina, Kerzhansk. October 1996. Marta's and Sonya's flat.
##
##                  balcony
##   z=0  +----------+--------+----------+
##        | LIVING   | KITCH. | BEDROOM  |
##        | 0..5     | 5..9   | 9..13    |
##   z=5  +--D-------+--D-----+---D------+
##        |            CORRIDOR          |
##  z=6.6 +--D-------+-arch-+--D--+--D---+
##        | SONYA'S  | ENTR.| BATH| BOX  |
##        | ROOM     | 5..8 | 8.. | ROOM |
##  z=10  +----------+--D---+-----+------+
##                 LANDING (front door, 48, the stairs)
##
## x east, z south, y up; metres. Kit pieces face -Z unless rotated: r 0 = against a south wall,
## 180 = against a north wall, 90 = against an east wall, -90 = against a west wall.

const WARM := "#ffcf8a"
const TUBE := "#d0ecd8"

static func layout() -> Dictionary:
	var rooms := {
		"living": {"rect": [0, 0, 5, 5], "wall": "damask", "floor": "parquet", "circuit": "B", "surface": "wood",
			"lights": [{"p": [2.5, 2.05, 2.3], "c": WARM, "e": 1.3, "r": 6.0, "fix": "shade"}],
			"acoustics": {"size": 0.35, "damp": 0.7, "wet": 0.12}, "ambience": "drone"},
		"kitchen": {"rect": [5, 0, 9, 5], "wall": "plaster", "floor": "lino", "circuit": "A", "surface": "tile", "flicker": 0.35,
			"lights": [{"p": [7.0, 2.52, 2.4], "c": TUBE, "e": 1.0, "r": 6.0, "fix": "tube"}],
			"acoustics": {"size": 0.3, "damp": 0.3, "wet": 0.2}},
		"bedroom": {"rect": [9, 0, 13, 5], "wall": "floral", "floor": "parquet", "circuit": "B", "surface": "wood",
			"lights": [{"p": [11.0, 2.3, 2.6], "c": WARM, "e": 1.0, "r": 5.5, "fix": "bulb"}],
			"acoustics": {"size": 0.3, "damp": 0.8, "wet": 0.1}},
		"corridor": {"rect": [0, 5, 13, 6.6], "wall": "plaster", "floor": "parquet", "circuit": "A", "surface": "wood",
			"lights": [{"p": [3.0, 2.35, 5.8], "c": WARM, "e": 0.95, "r": 5.0, "fix": "bulb"}, {"p": [10.0, 2.35, 5.8], "c": WARM, "e": 0.85, "r": 5.0, "fix": "bulb"}],
			"acoustics": {"size": 0.4, "damp": 0.5, "wet": 0.18}},
		"entrance": {"rect": [5, 6.6, 8, 10], "wall": "plaster", "floor": "lino", "circuit": "A", "surface": "tile", "flicker": 0.3,
			"lights": [{"p": [6.5, 2.3, 8.3], "c": WARM, "e": 0.85, "r": 4.5, "fix": "bulb"}],
			"acoustics": {"size": 0.25, "damp": 0.5, "wet": 0.15}},
		"sonya": {"rect": [0, 6.6, 5, 10], "wall": "child", "floor": "parquet", "circuit": "B", "switch_on": false, "surface": "wood",
			"lights": [{"p": [2.5, 2.3, 8.3], "c": WARM, "e": 0.7, "r": 4.5, "fix": "bulb"}],
			"ambient": [0.16, 0.08, 0.03],            # orange streetlight through the boards
			"acoustics": {"size": 0.25, "damp": 0.85, "wet": 0.08}},
		"bathroom": {"rect": [8, 6.6, 10.5, 10], "wall": "tile_wall", "floor": "tile_floor", "circuit": "C", "surface": "tile",
			"lights": [{"p": [9.25, 2.35, 8.3], "c": "#e8e8ff", "e": 0.8, "r": 4.0, "fix": "bulb"}],
			"ambient": [0.02, 0.02, 0.025],
			"acoustics": {"size": 0.2, "damp": 0.1, "wet": 0.4}},
		"boxroom": {"rect": [10.5, 6.6, 13, 10], "wall": "plaster", "floor": "concrete", "circuit": "B", "surface": "concrete",
			"lights": [{"p": [11.75, 2.3, 8.3], "c": WARM, "e": 0.75, "r": 4.0, "fix": "bulb"}],
			"acoustics": {"size": 0.15, "damp": 0.6, "wet": 0.1}},
		"balcony": {"rect": [1, -1.4, 4, 0], "wall": "plaster", "floor": "concrete", "open": ["n", "w", "e"], "no_ceiling": true, "surface": "concrete",
			"skirting": false, "ambient": [0.02, 0.02, 0.025], "acoustics": {"size": 0.9, "damp": 0.9, "wet": 0.02}},
		"landing": {"rect": [3.5, 10, 9.5, 13], "wall": "green_paint", "floor": "concrete", "surface": "concrete", "skirting": false,
			"lights": [{"p": [6.5, 2.52, 11.5], "c": TUBE, "e": 0.7, "r": 5.0, "fix": "tube"}],
			"acoustics": {"size": 0.7, "damp": 0.3, "wet": 0.35}, "ambience": "drone"},
	}
	var openings := [
		# doors (swing +1 opens toward +Z / west-of-x? see Door; chosen so doors open into rooms)
		{"p": [2.5, 5.0], "axis": "x", "w": 0.9, "door": {"id": "living_door", "swing": -1, "open": 1.0}},
		{"p": [5.0, 1.6], "axis": "z", "w": 0.9, "door": {"id": "kitchen_side", "swing": 1}},
		{"p": [6.3, 5.0], "axis": "x", "w": 0.9, "door": {"id": "kitchen_door", "swing": -1, "open": 0.6}},
		{"p": [10.4, 5.0], "axis": "x", "w": 0.9, "door": {"id": "bedroom_door", "swing": -1}},
		{"p": [2.5, 6.6], "axis": "x", "w": 0.85, "door": {"id": "sonya_door", "swing": 1}},
		{"p": [6.5, 6.6], "axis": "x", "w": 1.4, "h": 2.2},
		{"p": [9.2, 6.6], "axis": "x", "w": 0.8, "door": {"id": "bath_door", "swing": 1, "bolt": 1}},
		{"p": [11.8, 6.6], "axis": "x", "w": 0.8, "door": {"id": "boxroom_door", "swing": 1, "bolt": -1, "bolt_on": true}},
		{"p": [6.5, 10.0], "axis": "x", "w": 0.95, "h": 2.1, "door": {"id": "front_door", "style": "door_padded", "swing": -1, "chain": -1, "key": "key:flat47"}},
		{"p": [2.5, 0.0], "axis": "x", "w": 0.8, "h": 2.1, "door": {"id": "balcony_door", "swing": 1, "jammed": "stuck"}},
		# the door across the landing
		{"p": [9.5, 11.6], "axis": "z", "w": 0.95, "h": 2.1, "door": {"id": "flat48_door", "style": "door_padded", "swing": 1, "locked": true, "key": "key:none", "pickable": false}},
		# windows
		{"p": [4.1, 0.0], "axis": "x", "w": 1.0, "h": 1.3, "sill": 0.85, "window": "night"},
		{"p": [7.6, 0.0], "axis": "x", "w": 1.0, "h": 1.2, "sill": 1.0, "window": "night"},
		{"p": [11.3, 0.0], "axis": "x", "w": 1.0, "h": 1.3, "sill": 0.85, "window": "night"},
		{"p": [2.5, 10.0], "axis": "x", "w": 1.0, "h": 1.3, "sill": 0.85, "window": "black"},
		# where the wardrobe stands: after the blackout, a hole (plugged until then; see scene_a.gd)
		{"p": [0.0, 3.4], "axis": "z", "w": 0.8, "h": 1.15, "sill": 0.12, "ai": false},
	]
	var f := [
		# ---- living room: dinner for three, Marta at her place
		{"t": "rug", "room": "living", "p": [2.5, 2.2], "w": 2.6, "l": 2.0},
		{"t": "table", "room": "living", "p": [2.5, 2.2], "w": 1.4, "d": 0.85, "cloth": true, "on": ["plate", "plate", "plate", "cup", "bottle"]},
		{"t": "prop", "room": "living", "kind": "chair", "p": [1.55, 2.2], "lift": 0.46},
		{"t": "prop", "room": "living", "kind": "chair", "p": [3.45, 2.25], "lift": 0.46},
		{"t": "prop", "room": "living", "kind": "chair", "p": [2.5, 3.05], "lift": 0.46},
		{"t": "sideboard", "room": "living", "p": [4.74, 2.95], "r": 90, "w": 1.6, "id": "living_sideboard",
			"contents": {"drawer0": ["photo_cut"], "drawer1": ["lighter", "battery"], "inside": ["bottle", "jar"]}},
		{"t": "prop", "room": "living", "kind": "radio", "p": [4.74, 3.4], "y": 0.86, "lift": 0.1},
		{"t": "wardrobe", "room": "living", "p": [0.36, 3.4], "r": -90, "pushable": true, "id": "living_wardrobe"},
		{"t": "sofa", "room": "living", "p": [3.95, 4.5], "r": 0, "w": 1.5},
		{"t": "armchair", "room": "living", "p": [3.9, 3.55], "r": 180, "id": "living_armchair"},
		{"t": "shelf", "room": "living", "p": [0.2, 1.1], "r": -90, "w": 1.0, "rows": ["", "books", "books", "", ["jar", "cup"]]},
		{"t": "boxes", "room": "living", "p": [4.3, 0.5], "n": 4, "label": "boxes_label"},
		{"t": "radiator", "room": "living", "p": [4.1, 0.1], "r": 180},
		{"t": "picture", "room": "living", "p": [3.6, 4.97], "r": 0, "w": 0.4, "h": 0.3},
		{"t": "picture", "room": "living", "p": [1.2, 0.03], "r": 180, "w": 0.5, "h": 0.4, "inner": "black"},
		{"t": "switch", "room": "living", "p": [1.9, 4.97], "r": 0},
		{"t": "coral", "room": "living", "p": [2.5, 1.0], "n": 9, "size": 0.45},
		# ---- kitchen: the one tube still lit, more or less
		{"t": "kitchen_unit", "room": "kitchen", "p": [5.45, 0.32], "r": 180, "w": 0.8, "id": "k_unit0", "contents": {"drawer0": ["key_flat47"], "inside": ["pot", "bucket"]}},
		{"t": "kitchen_unit", "room": "kitchen", "p": [6.27, 0.32], "r": 180, "w": 0.8, "sink": true, "id": "k_unit1", "contents": {"drawer0": ["fuse", "screwdriver"]}},
		{"t": "stove", "room": "kitchen", "p": [7.4, 0.32], "r": 180, "on": ["pot"]},
		{"t": "fridge", "room": "kitchen", "p": [8.6, 0.35], "r": 180, "note": "fridge_note", "id": "fridge", "contents": {"inside": ["jar", "bottle"]}},
		{"t": "wall_cupboard", "room": "kitchen", "p": [5.85, 0.17], "r": 180, "w": 1.2, "id": "k_wall0", "contents": {"inside": ["cup", "cup", "plate"]}},
		{"t": "table", "room": "kitchen", "p": [7.0, 3.3], "w": 1.0, "d": 0.7, "on": ["jar", "cup"]},
		{"t": "prop", "room": "kitchen", "kind": "stool", "p": [6.4, 3.35], "lift": 0.26},
		{"t": "prop", "room": "kitchen", "kind": "stool", "p": [7.6, 3.2], "lift": 0.26},
		{"t": "counter", "room": "kitchen", "p": [8.65, 2.8], "r": 90, "w": 1.6, "on": ["jar", "jar", "jar", "bottle"]},
		{"t": "paper", "room": "kitchen", "p": [8.95, 1.6], "r": 90, "doc": "calendar"},
		{"t": "switch", "room": "kitchen", "p": [5.7, 4.97], "r": 0},
		# ---- bedroom: the unmade bed, her pills, the clipping
		{"t": "bed", "room": "bedroom", "p": [11.0, 1.15], "r": 180, "w": 1.4, "l": 2.0, "unmade": true, "id": "bed_marta"},
		{"t": "nightstand", "room": "bedroom", "p": [12.2, 0.3], "r": 180, "id": "ns_marta", "contents": {"drawer0": ["pills"]}, "on": ["cup"]},
		{"t": "wardrobe", "room": "bedroom", "p": [12.68, 3.6], "r": 90, "id": "wardrobe_bedroom", "contents": {"inside": ["suitcase"]}},
		{"t": "dresser", "room": "bedroom", "p": [9.25, 3.4], "r": -90, "id": "dresser", "contents": {"drawer0": ["hairpin"], "drawer2": ["clipping"]}},
		{"t": "mirror", "room": "bedroom", "p": [9.04, 3.4], "r": -90},
		{"t": "prop", "room": "bedroom", "kind": "suitcase", "p": [10.0, 4.3], "lift": 0.1},
		{"t": "switch", "room": "bedroom", "p": [9.9, 4.97], "r": 0},
		# ---- corridor
		{"t": "paper", "room": "corridor", "p": [4.2, 6.57], "r": 0, "doc": "evacuation"},
		{"t": "radiator", "room": "corridor", "p": [12.9, 5.8], "r": 90, "w": 0.6},
		{"t": "picture", "room": "corridor", "p": [8.0, 5.03], "r": 180},
		# ---- entrance
		{"t": "coat_rack", "room": "entrance", "p": [5.04, 8.2], "r": -90},
		{"t": "fuse_box", "room": "entrance", "p": [7.96, 7.4], "r": 90},
		{"t": "phone_table", "room": "entrance", "p": [7.65, 9.2], "r": 90},
		{"t": "nightstand", "room": "entrance", "p": [5.3, 9.55], "r": -90, "id": "ns_hall", "contents": {"drawer0": ["torch"]}},
		{"t": "mirror", "room": "entrance", "p": [5.03, 7.2], "r": -90},
		# ---- Sonya's room: the only bed that's made
		{"t": "bed", "room": "sonya", "p": [0.55, 8.3], "r": 0, "w": 0.9, "l": 1.8, "id": "bed_sonya"},
		{"t": "toy_chest", "room": "sonya", "p": [3.4, 9.65], "r": 0, "id": "chest", "contents": {"inside": ["music_box"]}},
		{"t": "desk", "room": "sonya", "p": [4.68, 7.6], "r": 90, "w": 1.0, "id": "desk_sonya", "contents": {"drawer0": ["drawing"]}},
		{"t": "shelf", "room": "sonya", "p": [2.2, 9.83], "r": 0, "w": 0.8, "h": 1.2, "n": 3, "rows": ["", "books", ""]},
		{"t": "hole", "room": "sonya", "p": [2.5, 9.97], "r": 0, "id": "sonya_window_boards", "w": 1.0, "hh": 1.3, "y0": 1.5, "hp": 200.0},
		{"t": "switch", "room": "sonya", "p": [3.1, 6.63], "r": 180},
		# ---- bathroom: no light (the fuse is out), the bath full of black water
		{"t": "bath", "room": "bathroom", "p": [8.43, 8.9], "r": 0, "water": true, "id": "bath"},
		{"t": "sink", "room": "bathroom", "p": [10.2, 7.4], "r": 90},
		{"t": "toilet", "room": "bathroom", "p": [10.2, 9.5], "r": 90},
		{"t": "mirror_cabinet", "room": "bathroom", "p": [10.43, 7.4], "r": 90, "id": "bath_cab", "contents": {"inside": ["bandage", "pills"]}},
		{"t": "washer", "room": "bathroom", "p": [8.35, 7.0], "r": -90},
		# ---- the box room: bolted from outside. Someone lived in here.
		{"t": "bed", "room": "boxroom", "p": [11.3, 9.0], "r": 90, "w": 0.8, "l": 1.9, "id": "mattress", "hide": false, "style": "fabric_bed"},
		{"t": "shelf", "room": "boxroom", "p": [12.82, 7.6], "r": 90, "w": 1.2, "rows": [["box_small"], ["jar", "jar"], ["hammer"], ["box_small"]]},
		{"t": "boxes", "room": "boxroom", "p": [11.0, 7.1], "n": 5},
		{"t": "prop", "room": "boxroom", "kind": "diary_page", "p": [11.4, 9.0], "y": 0.42, "lift": 0.02},
		{"t": "prop", "room": "boxroom", "kind": "letter_returned", "p": [12.4, 9.6], "lift": 0.05},
		{"t": "prop", "room": "boxroom", "kind": "alarm_clock", "p": [12.1, 9.2], "lift": 0.05},
		# ---- the landing
		{"t": "stairs_down", "room": "landing", "p": [4.4, 12.4], "r": 90},
		{"t": "radiator", "room": "landing", "p": [7.6, 12.9], "r": 0, "w": 0.6},
		# ---- the balcony
		{"t": "railing", "room": "balcony", "p": [2.5, -1.38], "w": 3.0},
		{"t": "railing", "room": "balcony", "p": [1.02, -0.7], "r": 90, "w": 1.4},
		{"t": "railing", "room": "balcony", "p": [3.98, -0.7], "r": 90, "w": 1.4},
	]
	return {
		"rooms": rooms, "openings": openings, "furniture": f,
		"circuits": {"A": {"live": true, "fuse": true}, "B": {"live": true, "fuse": true}, "C": {"live": true, "fuse": false}},
		"spawns": {"start": [6.5, 0.0, 12.4, 0.0], "wake": [2.0, 0.0, 1.6, 200.0]},
		"triggers": [
			{"id": "see_flat", "p": [6.5, 1.2, 9.4], "size": [2.6, 2.4, 1.0], "once": true},
			{"id": "balcony", "p": [2.5, 1.2, -0.8], "size": [2.8, 2.4, 1.0]},
		],
		"fog_begin": 3.0, "fog_end": 14.0,
	}
