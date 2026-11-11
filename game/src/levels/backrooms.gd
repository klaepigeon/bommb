class_name BackroomsLayout
## The Backrooms: Flat 47, again, wrong. Built from the same Kit pieces and the same textures as
## Flat 47; the difference is arrangement, proportion, light, damp and repetition.
##
##   z=0  +----------+---------+---------+---------+
##        | ARRIVAL  | KITCHEN | KITCHEN | BEDROOM |      the corridor runs on past x=20
##        | (living) |    A    | B (wet) | (6 m)   |      and comes back round (a seam at 23)
##   z=5  +--D-------+--D------+--D------+--D------+-------------- . . .
##        |                 THE LONG CORRIDOR                      . . .
##  z=6.6 +--D-------+--arch---+--D--+---D--+---D--------+
##        | SONYA'S  | ENTRANCE| BATH| BOX  |  LIVING    |
##        | (wrong)  | fuses   |vent | ROOM |  AGAIN     |
##  z=10  +--board---+---D-----+-----+------+--D---------+
##        |crawlspace| LANDING: 48 ->|      | BALCONY    |  gap  | 48's BALCONY
##
## Ways into Flat 48 (all converge there): the padlock (key / cut / pry / smash / shoot), the vent
## behind the bathroom panel (unscrew / smash / shoot), the plank across to 48's balcony.

const WARM := "#ffc070"
const SICK := "#e8e0a0"
const W1 := {"wrong": 0.45, "mould": 0.35}
const W2 := {"wrong": 0.7, "mould": 0.55}
const W3 := {"wrong": 0.9, "mould": 0.8, "tint": "#d8d0b0"}

static func layout() -> Dictionary:
	var rooms := {
		"arrival": {"rect": [0, 0, 5, 5], "h": 3.0, "wall": "damask", "floor": "parquet", "circuit": "B", "surface": "wood", "alter": W1,
			"lights": [{"p": [2.5, 2.4, 2.3], "c": SICK, "e": 0.9, "r": 5.5, "fix": "shade"}], "flicker": 0.15,
			"acoustics": {"size": 0.5, "damp": 0.6, "wet": 0.25}, "ambience": "drone_wrong"},
		"kitchen_a": {"rect": [5, 0, 9, 5], "wall": "plaster", "floor": "lino", "circuit": "B", "surface": "tile", "alter": W1,
			"lights": [{"p": [7.0, 2.52, 2.4], "c": "#c8f0c8", "e": 0.8, "r": 5.5, "fix": "tube"}], "flicker": 0.4,
			"acoustics": {"size": 0.35, "damp": 0.3, "wet": 0.3}},
		"kitchen_b": {"rect": [9, 0, 13, 5], "wall": "plaster", "floor": "lino", "circuit": "C", "surface": "wet", "alter": W2,
			"lights": [{"p": [11.0, 2.52, 2.4], "c": "#c8f0c8", "e": 0.7, "r": 5.5, "fix": "tube"}],
			"acoustics": {"size": 0.35, "damp": 0.2, "wet": 0.45}},
		"bedtall": {"rect": [13, 0, 17, 5], "h": 6.0, "wall": "floral", "floor": "parquet", "circuit": "B", "surface": "wood", "alter": W2,
			"lights": [{"p": [15.0, 5.4, 2.5], "c": WARM, "e": 1.1, "r": 7.5, "fix": "bulb"}],
			"acoustics": {"size": 0.8, "damp": 0.5, "wet": 0.45}},
		"corridor": {"rect": [0, 5, 26, 6.6], "wall": "plaster", "floor": "parquet", "circuit": "A", "surface": "wood", "alter": W1,
			"lights": [{"p": [2.0, 2.35, 5.8], "c": WARM, "e": 0.8, "r": 4.5}, {"p": [8.0, 2.35, 5.8], "c": WARM, "e": 0.8, "r": 4.5},
				{"p": [14.0, 2.35, 5.8], "c": WARM, "e": 0.7, "r": 4.5}, {"p": [22.0, 2.35, 5.8], "c": WARM, "e": 0.8, "r": 4.5}],
			"acoustics": {"size": 0.7, "damp": 0.4, "wet": 0.35}, "ambience": "drone_wrong"},
		"sonya_w": {"rect": [0, 6.6, 5, 10], "wall": "child", "floor": "parquet", "circuit": "B", "surface": "wood", "alter": W3,
			"lights": [{"p": [2.5, 2.3, 8.3], "c": "#ffb070", "e": 0.6, "r": 4.5}],
			"acoustics": {"size": 0.3, "damp": 0.85, "wet": 0.1}},
		"entrance_w": {"rect": [5, 6.6, 8, 10], "wall": "plaster", "floor": "lino", "circuit": "A", "surface": "tile", "alter": W1,
			"lights": [{"p": [6.5, 2.3, 8.3], "c": WARM, "e": 0.75, "r": 4.5}],
			"acoustics": {"size": 0.3, "damp": 0.5, "wet": 0.2}},
		"bath_w": {"rect": [8, 6.6, 10.5, 10], "wall": "tile_wall", "floor": "tile_floor", "circuit": "C", "surface": "wet", "alter": W2,
			"lights": [{"p": [9.25, 2.35, 8.3], "c": "#e0e0ff", "e": 0.7, "r": 4.0}],
			"acoustics": {"size": 0.25, "damp": 0.1, "wet": 0.5}},
		"box_w": {"rect": [10.5, 6.6, 13, 10], "wall": "plaster", "floor": "concrete", "circuit": "B", "surface": "concrete", "alter": W2,
			"lights": [{"p": [11.75, 2.3, 8.3], "c": WARM, "e": 0.6, "r": 4.0}],
			"acoustics": {"size": 0.2, "damp": 0.5, "wet": 0.15}},
		"living_again": {"rect": [13, 6.6, 18, 11], "wall": "damask", "floor": "parquet", "circuit": "B", "surface": "wood", "alter": W3,
			"lights": [{"p": [15.5, 2.05, 8.8], "c": SICK, "e": 1.0, "r": 6.0, "fix": "shade"}],
			"acoustics": {"size": 0.4, "damp": 0.7, "wet": 0.2}},
		"balcony": {"rect": [14, 11, 17, 12.4], "wall": "plaster", "floor": "concrete", "open": ["s", "w", "e"], "no_ceiling": true,
			"surface": "concrete", "skirting": false, "ambient": [0.12, 0.12, 0.11], "acoustics": {"size": 0.95, "damp": 0.95, "wet": 0.02}},
		"balcony48": {"rect": [14, 13.6, 17, 15], "wall": "draft", "floor": "concrete", "open": ["n", "w", "e"], "no_ceiling": true,
			"surface": "concrete", "skirting": false, "ambient": [0.14, 0.14, 0.13], "acoustics": {"size": 0.95, "damp": 0.95, "wet": 0.02}},
		"threshold48": {"rect": [8, 11.0, 9.0, 12.2], "wall": "black", "floor": "concrete", "ceiling": "black", "surface": "concrete", "skirting": false,
			"ambient": [0.0, 0.0, 0.0], "acoustics": {"size": 0.1, "damp": 0.9, "wet": 0.05}},
		"landing": {"rect": [3.5, 10, 8, 13], "wall": "green_paint", "floor": "concrete", "surface": "concrete", "skirting": false, "alter": W1,
			"lights": [{"p": [5.75, 2.52, 11.5], "c": "#c8f0d0", "e": 0.8, "r": 5.0, "fix": "tube"}], "flicker": 0.25,
			"acoustics": {"size": 0.7, "damp": 0.3, "wet": 0.4}, "ambience": "drone_wrong"},
		"crawl": {"rect": [0.5, 10, 3.5, 11.2], "h": 1.3, "wall": "concrete", "floor": "concrete", "ceiling": "concrete", "surface": "concrete",
			"skirting": false, "alter": W3, "ambient": [0.05, 0.04, 0.03], "acoustics": {"size": 0.1, "damp": 0.9, "wet": 0.05}},
	}
	var openings := [
		# arrival: the hole he came out of (no way back), the door to the corridor, the side door
		{"p": [0.0, 3.4], "axis": "z", "w": 0.8, "h": 1.15, "sill": 0.12, "ai": false},
		{"p": [2.5, 5.0], "axis": "x", "w": 0.9, "door": {"id": "b_arrival", "swing": -1, "bolt": -1}},
		{"p": [5.0, 1.6], "axis": "z", "w": 0.9, "door": {"id": "b_side", "swing": 1}},
		# kitchens and the tall bedroom, in a row (a second way through, behind the corridor)
		{"p": [6.3, 5.0], "axis": "x", "w": 0.9, "door": {"id": "b_kitchen_a", "swing": -1, "open": 0.5}},
		{"p": [9.0, 2.6], "axis": "z", "w": 0.9, "door": {"id": "b_kab", "swing": -1}},
		{"p": [10.4, 5.0], "axis": "x", "w": 0.9, "door": {"id": "b_kitchen_b", "swing": -1, "locked": true, "key": "key:none", "pickable": true}},
		{"p": [13.0, 2.6], "axis": "z", "w": 0.9, "door": {"id": "b_kb_bed", "swing": 1}},
		{"p": [15.0, 5.0], "axis": "x", "w": 0.9, "h": 2.6, "door": {"id": "b_bedtall", "swing": -1, "open": 0.3}},
		# the corridor's south side
		{"p": [2.5, 6.6], "axis": "x", "w": 0.85, "door": {"id": "b_sonya", "swing": 1}},
		{"p": [6.5, 6.6], "axis": "x", "w": 1.4, "h": 2.2},
		{"p": [9.2, 6.6], "axis": "x", "w": 0.8, "door": {"id": "b_bath", "swing": 1, "bolt": 1}},
		{"p": [11.8, 6.6], "axis": "x", "w": 0.8, "door": {"id": "b_box", "swing": 1, "locked": true, "key": "key:storage"}},
		{"p": [15.5, 6.6], "axis": "x", "w": 0.9, "door": {"id": "b_living2", "swing": 1}},
		# doors to nowhere (jammed): the corridor's other doors
		{"p": [19.5, 5.0], "axis": "x", "w": 0.9, "door": {"id": "b_nowhere1", "swing": -1, "jammed": "nowhere"}},
		{"p": [20.5, 6.6], "axis": "x", "w": 0.9, "door": {"id": "b_nowhere2", "swing": 1, "jammed": "nowhere"}},
		# the front door, out to the landing; 48 across it
		{"p": [6.5, 10.0], "axis": "x", "w": 0.95, "h": 2.1, "door": {"id": "b_front", "style": "door_padded", "swing": -1, "chain": -1, "chain_on": true}},
		{"p": [8.0, 11.6], "axis": "z", "w": 0.95, "h": 2.1, "door": {"id": "flat48_door", "style": "door_padded", "swing": -1, "padlock": "key:padlock48", "padlock_side": 1.0}},
		# the bathroom's vent (a panel over it: see furniture) and Sonya's boarded window
		{"p": [9.6, 10.0], "axis": "x", "w": 0.6, "h": 0.6, "sill": 0.3, "ai": false},
		{"p": [3.0, 10.0], "axis": "x", "w": 1.0, "h": 1.25, "sill": 0.0, "ai": false},
		# living again: balcony door
		{"p": [15.5, 11.0], "axis": "x", "w": 0.8, "h": 2.1, "door": {"id": "b_balcony", "swing": -1}, "ai": false},
		# windows that look at nothing
		{"p": [3.8, 0.0], "axis": "x", "w": 1.0, "h": 1.3, "sill": 0.85, "window": "black"},
		{"p": [11.0, 0.0], "axis": "x", "w": 1.0, "h": 1.2, "sill": 1.0, "window": "void"},
		{"p": [15.0, 0.0], "axis": "x", "w": 1.0, "h": 3.4, "sill": 1.0, "window": "black"},
	]
	var f := [
		# ---- arrival: the living room, again. The table's gone; the chairs are still round it.
		{"t": "rug", "room": "arrival", "p": [2.5, 2.2], "w": 2.6, "l": 2.0},
		{"t": "prop", "room": "arrival", "kind": "chair", "p": [1.55, 2.2], "lift": 0.46},
		{"t": "prop", "room": "arrival", "kind": "chair", "p": [3.45, 2.25], "lift": 0.46},
		{"t": "prop", "room": "arrival", "kind": "chair", "p": [2.5, 3.05], "lift": 0.46},
		{"t": "prop", "room": "arrival", "kind": "chair", "p": [2.5, 1.35], "lift": 0.46},
		{"t": "coral", "room": "arrival", "p": [2.5, 1.35], "n": 22, "size": 0.7},
		{"t": "wardrobe", "room": "arrival", "p": [4.65, 3.6], "r": 90, "id": "b_wardrobe_arrival"},
		{"t": "sideboard", "room": "arrival", "p": [0.24, 1.2], "r": -90, "w": 1.6, "id": "b_sb", "contents": {"drawer0": ["battery"]}},
		{"t": "boxes", "room": "arrival", "p": [4.3, 0.5], "n": 6},
		{"t": "paper", "room": "arrival", "p": [2.5, 4.93], "r": 0, "doc": "backrooms_note"},
		{"t": "switch", "room": "arrival", "p": [1.9, 4.97], "r": 0},
		# ---- kitchen A: the bolt cutters in the cupboard under the sink, the radio
		{"t": "kitchen_unit", "room": "kitchen_a", "p": [5.45, 0.32], "r": 180, "w": 0.8, "id": "ba_unit0", "contents": {"drawer0": ["ammo"]}},
		{"t": "kitchen_unit", "room": "kitchen_a", "p": [6.27, 0.32], "r": 180, "w": 0.8, "sink": true, "id": "ba_unit1", "contents": {"inside": ["bolt_cutters"]}},
		{"t": "stove", "room": "kitchen_a", "p": [7.4, 0.32], "r": 180},
		{"t": "fridge", "room": "kitchen_a", "p": [8.6, 0.35], "r": 180, "id": "b_fridge", "note": "fridge_note"},
		{"t": "table", "room": "kitchen_a", "p": [7.0, 3.3], "w": 1.0, "d": 0.7, "on": ["jar", "cup"]},
		{"t": "prop", "room": "kitchen_a", "kind": "radio", "p": [7.2, 3.3], "y": 0.76, "lift": 0.1},
		{"t": "prop", "room": "kitchen_a", "kind": "stool", "p": [6.4, 3.35], "lift": 0.26},
		{"t": "switch", "room": "kitchen_a", "p": [5.7, 4.97], "r": 0},
		# ---- kitchen B: the same kitchen, mirrored, flooded. The key to the box room's in the far drawer.
		{"t": "kitchen_unit", "room": "kitchen_b", "p": [12.55, 0.32], "r": 180, "w": 0.8, "id": "bb_unit0", "contents": {"drawer0": ["key_storage"]}},
		{"t": "kitchen_unit", "room": "kitchen_b", "p": [11.73, 0.32], "r": 180, "w": 0.8, "sink": true, "id": "bb_unit1"},
		{"t": "stove", "room": "kitchen_b", "p": [10.6, 0.32], "r": 180},
		{"t": "fridge", "room": "kitchen_b", "p": [9.4, 0.35], "r": 180, "id": "bb_fridge"},
		{"t": "table", "room": "kitchen_b", "p": [11.0, 3.3], "w": 1.0, "d": 0.7},
		{"t": "prop", "room": "kitchen_b", "kind": "bucket", "p": [10.2, 2.0]},
		{"t": "water", "room": "kitchen_b", "p": [11.0, 2.8], "w": 3.6, "l": 4.0},
		{"t": "paper", "room": "kitchen_b", "p": [12.95, 1.6], "r": 90, "doc": "calendar"},
		# ---- the tall bedroom: the bed, the gun on it. Wardrobes stacked to the ceiling.
		{"t": "bed", "room": "bedtall", "p": [15.0, 1.15], "r": 180, "w": 1.4, "l": 2.0, "unmade": true, "id": "b_bed"},
		{"t": "prop", "room": "bedtall", "kind": "revolver", "p": [15.1, 1.4], "y": 0.47, "lift": 0.04, "id": "the_gun", "frozen": true},
		{"t": "nightstand", "room": "bedtall", "p": [16.2, 0.3], "r": 180, "id": "b_ns", "contents": {"drawer0": ["ammo"]}},
		{"t": "wardrobe", "room": "bedtall", "p": [16.65, 3.4], "r": 90, "id": "b_wardrobe_bed", "contents": {"inside": ["crowbar"]}},
		{"t": "wardrobe", "room": "bedtall", "p": [16.65, 3.4], "y": 1.95, "r": 90, "id": "b_wardrobe_bed2", "hide": false},
		{"t": "wardrobe", "room": "bedtall", "p": [16.65, 3.4], "y": 3.9, "r": 90, "id": "b_wardrobe_bed3", "hide": false},
		{"t": "dresser", "room": "bedtall", "p": [13.25, 3.4], "r": -90, "id": "b_dresser"},
		{"t": "mirror", "room": "bedtall", "p": [13.04, 3.4], "r": -90},
		# ---- the corridor: the plank, closets to hide in, doors that go nowhere
		{"t": "hiding_closet", "room": "corridor", "p": [18.0, 5.32], "r": 180, "id": "b_closet1"},
		{"t": "hiding_closet", "room": "corridor", "p": [4.4, 6.28], "r": 0, "id": "b_closet2"},
		{"t": "radiator", "room": "corridor", "p": [9.0, 5.07], "r": 180, "w": 0.6},
		{"t": "picture", "room": "corridor", "p": [8.0, 5.03], "r": 180},
		{"t": "picture", "room": "corridor", "p": [12.0, 5.03], "r": 180},
		{"t": "picture", "room": "corridor", "p": [16.0, 5.03], "r": 180},
		{"t": "picture", "room": "corridor", "p": [22.0, 5.03], "r": 180},
		{"t": "switch", "room": "corridor", "p": [3.2, 6.57], "r": 0},
		# ---- Sonya's room, wrong: three of her bed, the chest, the boards over the window
		{"t": "bed", "room": "sonya_w", "p": [0.55, 8.3], "r": 0, "w": 0.9, "l": 1.8, "id": "b_bed_s1"},
		{"t": "bed", "room": "sonya_w", "p": [1.6, 8.3], "r": 0, "w": 0.9, "l": 1.8, "id": "b_bed_s2", "hide": false},
		{"t": "toy_chest", "room": "sonya_w", "p": [4.3, 9.65], "r": 0, "id": "b_chest", "contents": {"inside": ["ammo", "ammo"]}},
		{"t": "hole", "room": "sonya_w", "p": [3.0, 9.97], "r": 0, "id": "crawl_boards", "w": 1.0, "hh": 1.25, "y0": 0.62, "hp": 45.0},
		# ---- the entrance: the fuse box (A: corridor and hall, B: rooms, C: the wet rooms)
		{"t": "fuse_box", "room": "entrance_w", "p": [7.96, 7.4], "r": 90},
		{"t": "coat_rack", "room": "entrance_w", "p": [5.04, 8.2], "r": -90},
		{"t": "nightstand", "room": "entrance_w", "p": [5.3, 9.55], "r": -90, "id": "b_ns_hall", "contents": {"drawer0": ["alarm_clock", "battery"]}},
		{"t": "phone_table", "room": "entrance_w", "p": [7.65, 9.2], "r": 90},
		# ---- the bathroom: full bath, the cabinet, the panel over the vent
		{"t": "bath", "room": "bath_w", "p": [8.43, 8.9], "r": 0, "water": true, "id": "b_bath"},
		{"t": "sink", "room": "bath_w", "p": [10.2, 7.4], "r": 90},
		{"t": "mirror_cabinet", "room": "bath_w", "p": [10.43, 7.4], "r": 90, "id": "b_bath_cab", "contents": {"inside": ["ammo", "bandage"]}},
		{"t": "hole", "room": "bath_w", "p": [9.6, 9.96], "r": 0, "id": "vent", "cover": "metal", "w": 0.6, "hh": 0.6, "y0": 0.6, "hp": 70.0, "unscrew": true, "label": "Smash the panel"},
		# ---- the box room: shelves, boxes, the key to 48's padlock in a jar
		{"t": "shelf", "room": "box_w", "p": [12.82, 7.6], "r": 90, "w": 1.2, "rows": [["box_small"], [], ["box_small"], []]},
		{"t": "prop", "room": "box_w", "kind": "jar", "p": [12.82, 7.4], "y": 0.98, "lift": 0.1, "contents": ["key_padlock"], "id": "key_jar"},
		{"t": "boxes", "room": "box_w", "p": [11.0, 7.1], "n": 5},
		{"t": "bed", "room": "box_w", "p": [11.3, 9.0], "r": 90, "w": 0.8, "l": 1.9, "id": "b_mattress"},
		# ---- living room, again (it's the same room)
		{"t": "table", "room": "living_again", "p": [15.5, 8.8], "w": 1.4, "d": 0.85, "cloth": true, "on": ["plate", "plate", "plate"]},
		{"t": "prop", "room": "living_again", "kind": "chair", "p": [14.55, 8.8], "lift": 0.46},
		{"t": "prop", "room": "living_again", "kind": "chair", "p": [16.45, 8.8], "lift": 0.46},
		{"t": "sofa", "room": "living_again", "p": [17.5, 8.6], "r": 90, "w": 1.8},
		{"t": "armchair", "room": "living_again", "p": [14.0, 7.4], "r": -140, "id": "b_armchair"},
		{"t": "wardrobe", "room": "living_again", "p": [13.35, 9.0], "r": -90, "id": "b_wardrobe_l2"},
		{"t": "paper", "room": "living_again", "p": [17.95, 10.0], "r": 90, "doc": "plank_note"},
		{"t": "prop", "room": "living_again", "kind": "plank", "p": [14.7, 10.5], "r": 90, "lift": 0.05, "id": "the_plank"},
		# ---- balconies, and nothing between them
		{"t": "railing", "room": "balcony", "p": [14.02, 11.7], "r": 90, "w": 1.4},
		{"t": "railing", "room": "balcony", "p": [16.98, 11.7], "r": 90, "w": 1.4},
		{"t": "railing", "room": "balcony", "p": [14.6, 12.38], "w": 1.2},
		{"t": "railing", "room": "balcony", "p": [16.4, 12.38], "w": 1.2},
		{"t": "railing", "room": "balcony48", "p": [14.02, 14.3], "r": 90, "w": 1.4},
		{"t": "railing", "room": "balcony48", "p": [16.98, 14.3], "r": 90, "w": 1.4},
		{"t": "railing", "room": "balcony48", "p": [14.6, 13.62], "w": 1.2},
		{"t": "railing", "room": "balcony48", "p": [16.4, 13.62], "w": 1.2},
		{"t": "sticky", "room": "balcony48", "p": [15.5, 14.98], "h": 1.5, "text": "IN HERE", "doc": "sticky_48"},
		# ---- the crawlspace behind Sonya's boards (hidden)
		{"t": "prop", "room": "crawl", "kind": "ammo", "p": [1.2, 10.7], "lift": 0.05},
		{"t": "paper", "room": "crawl", "p": [3.45, 10.6], "r": 90, "h": 0.6, "doc": "backrooms_note2"},
		{"t": "prop", "room": "crawl", "kind": "photo_cut", "p": [2.6, 10.8], "lift": 0.05},
		# ---- the landing: 48, with a note on it
		{"t": "sticky", "room": "landing", "p": [7.95, 11.2], "r": 90, "h": 1.6, "text": "IN HERE", "doc": "sticky_48"},
		{"t": "stairs_down", "room": "landing", "p": [4.4, 12.4], "r": 90},
	]
	return {
		"rooms": rooms, "openings": openings, "furniture": f,
		"circuits": {"A": {"live": true, "fuse": true}, "B": {"live": true, "fuse": true}, "C": {"live": true, "fuse": true}},
		"spawns": {"arrival": [0.45, 0.0, 3.4, -90.0], "caught": [2.5, 0.0, 3.8, 180.0], "restore": [2.5, 0.0, 3.8, 0.0]},
		"triggers": [
			{"id": "corridor_first", "p": [2.5, 1.2, 5.8], "size": [1.6, 2.4, 1.4], "once": true},
			{"id": "bedtall", "p": [15.0, 1.2, 3.0], "size": [3.5, 2.4, 3.5], "once": true},
			{"id": "living_again", "p": [15.5, 1.2, 8.0], "size": [4.0, 2.4, 3.0], "once": true},
			{"id": "to48_door", "p": [8.65, 1.2, 11.6], "size": [0.5, 2.4, 1.0]},
			{"id": "to48_balcony", "p": [15.5, 1.2, 14.4], "size": [2.6, 2.4, 1.0]},
			{"id": "crawlspace", "p": [2.2, 0.6, 10.6], "size": [2.6, 1.2, 1.0], "once": true},
			{"id": "fall", "p": [15.5, -6.0, 13.0], "size": [20.0, 4.0, 20.0]},
		],
		"seams": [{"a": [23.0, 0.0, 5.8], "b": [3.0, 0.0, 5.8], "size": [0.4, 2.4, 1.5]}],
		"hazards": [{"type": "water", "rect": [9.2, 0.8, 12.8, 4.8], "circuit": "C"}],
		"plank_socket": {"from": [15.5, 0.02, 12.4], "to": [15.5, 0.02, 13.6]},
		"patrol": [[3.0, 0, 5.8], [12.0, 0, 5.8], [20.0, 0, 5.8], [15.0, 0, 3.0], [11.0, 0, 3.0], [7.0, 0, 2.6], [6.5, 0, 8.2], [5.75, 0, 11.5], [15.5, 0, 8.5]],
		"marta_start": [21.0, 0.0, 5.8],
		"wrong_grade": 0.6, "fog_begin": 2.5, "fog_end": 12.0,
	}
