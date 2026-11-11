class_name Flat48Layout
## Flat 48: Flat 47 as reality only sketched it. Same plan, bare draft plaster, the rooms'
## names pencilled on the walls, the furniture pale blocks with paper tags. The chapter ends here;
## what comes after is not built yet (by design: brief §12).

static func layout() -> Dictionary:
	var lite := {"c": "#f0f0ea", "e": 0.9, "r": 7.0, "fix": "none"}
	var rooms := {
		"living48": {"rect": [0, 0, 5, 5], "wall": "draft", "floor": "concrete", "ceiling": "draft", "surface": "concrete", "skirting": false,
			"lights": [lite.merged({"p": [2.5, 2.4, 2.5]}, true)], "ambient": [0.12, 0.12, 0.115], "acoustics": {"size": 0.6, "damp": 0.2, "wet": 0.3}, "ambience": "drone"},
		"corridor48": {"rect": [0, 5, 13, 6.6], "wall": "draft", "floor": "concrete", "ceiling": "draft", "surface": "concrete", "skirting": false,
			"lights": [lite.merged({"p": [4.0, 2.4, 5.8]}, true), lite.merged({"p": [10.0, 2.4, 5.8]}, true)], "ambient": [0.1, 0.1, 0.1]},
		"entrance48": {"rect": [5, 6.6, 8, 10], "wall": "draft", "floor": "concrete", "ceiling": "draft", "surface": "concrete", "skirting": false,
			"lights": [lite.merged({"p": [6.5, 2.4, 8.3]}, true)], "ambient": [0.1, 0.1, 0.1]},
		"bath48": {"rect": [8, 6.6, 10.5, 10], "wall": "draft", "floor": "concrete", "ceiling": "draft", "surface": "concrete", "skirting": false,
			"lights": [lite.merged({"p": [9.25, 2.4, 8.3], "e": 0.6}, true)], "ambient": [0.08, 0.08, 0.08]},
		"balcony48": {"rect": [1, -1.4, 4, 0], "wall": "draft", "floor": "concrete", "open": ["n", "w", "e"], "no_ceiling": true, "surface": "concrete",
			"skirting": false, "ambient": [0.2, 0.2, 0.19]},
	}
	var openings := [
		{"p": [2.5, 5.0], "axis": "x", "w": 0.9},
		{"p": [6.5, 6.6], "axis": "x", "w": 1.4, "h": 2.2},
		{"p": [9.2, 6.6], "axis": "x", "w": 0.8},
		{"p": [6.5, 10.0], "axis": "x", "w": 0.95, "h": 2.1, "door": {"id": "f48_front", "style": "draft", "swing": -1}},
		{"p": [2.5, 0.0], "axis": "x", "w": 0.8, "h": 2.1, "door": {"id": "f48_balcony", "style": "draft", "swing": 1, "open": 1.0}},
		{"p": [9.6, 10.0], "axis": "x", "w": 0.6, "h": 0.6, "sill": 0.3, "ai": false},
	]
	var f := [
		{"t": "draft_block", "room": "living48", "p": [2.5, 2.2], "size": [1.4, 0.75, 0.85], "tag": "TABLE — dinner for three"},
		{"t": "draft_block", "room": "living48", "p": [2.5, 1.3], "size": [0.45, 0.9, 0.45], "tag": "CHAIR — hers"},
		{"t": "draft_block", "room": "living48", "p": [0.4, 3.4], "size": [0.6, 1.95, 1.1], "tag": "WARDROBE — something behind it"},
		{"t": "draft_block", "room": "living48", "p": [3.3, 4.5], "size": [1.8, 0.7, 0.85], "tag": "SOFA — the green one with the burn"},
		{"t": "draft_block", "room": "living48", "p": [4.7, 2.4], "size": [0.45, 0.85, 1.6], "tag": "SIDEBOARD — the good plates"},
		{"t": "draft_block", "room": "living48", "p": [4.3, 0.5], "size": [0.5, 0.5, 0.5], "tag": "BOX"},
		{"t": "draft_block", "room": "living48", "p": [4.3, 0.5], "y": 0.5, "size": [0.4, 0.4, 0.4], "tag": "BOX"},
		{"t": "draft_block", "room": "living48", "p": [4.3, 0.5], "y": 0.9, "size": [0.3, 0.3, 0.3], "tag": "BOX"},
		{"t": "draft_block", "room": "entrance48", "p": [5.3, 9.55], "size": [0.45, 0.3, 0.4], "tag": "TABLE — the telephone"},
		{"t": "draft_block", "room": "bath48", "p": [8.43, 8.9], "size": [0.75, 0.6, 1.7], "tag": "BATH — full"},
		{"t": "sticky", "room": "living48", "p": [2.5, 4.93], "h": 1.6, "text": "WAIT HERE", "doc": "sticky_48"},
	]
	return {
		"rooms": rooms, "openings": openings, "furniture": f,
		"spawns": {"door": [6.5, 0.0, 9.4, 0.0], "balcony": [2.5, 0.0, 0.5, 180.0], "vent": [9.6, 0.0, 9.3, 0.0], "start": [6.5, 0.0, 9.4, 0.0], "restore": [2.5, 0.0, 3.0, 0.0]},
		"triggers": [{"id": "arrive", "p": [2.5, 1.2, 2.8], "size": [3.6, 2.4, 3.2], "once": true}],
		"labels": [["КУХНЯ / KITCHEN", [7.0, 1.8, 5.03], 0], ["КОМНАТА / ROOM", [2.5, 2.0, 4.97], 0], ["ВАННАЯ / BATH", [9.25, 1.8, 6.63], 180], ["ПРИХОЖАЯ / HALL", [6.5, 2.0, 9.97], 0]],
		"fog_begin": 5.0, "fog_end": 20.0,
	}
