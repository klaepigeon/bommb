class_name BoardGraph
extends RefCounted
## The board as a graph. Two data formats:
##   "graph" (MURDERLAND, assets/data/murderland.json): explicit nodes, each with a type, a
##     district, a position on the table (0..1) and its edges; an edge can carry a GATE
##     ({to, gate, when}) and is walkable only while that gate is in that state. The gates
##     are the board's machines (BoardMachines changes them; they're saved).
##   loop + branches (the old function-room board): a main loop and detours.
## Rules walk next_of(); views lay it out from pos (or make one up for the old format).

var nodes: Array = []          # {id, type, district, pos, next: [ids], prev: [ids], edges: [{to, gate, when}], branch, toll}
var main_count := 0
var branches: Array = []
var districts: Array = []
var rat_spots: Array = []
var rat_price := 20
var notes: Array = []
var name := ""
var altered: Dictionary = {}   # node id -> type it was changed to mid-match
var gates: Dictionary = {}     # gate -> current value
var gate_defs: Dictionary = {}
var parade: Array = []         # the parade's route (node ids)


static func load_board(path := "res://assets/data/murderland.json") -> BoardGraph:
	var g := BoardGraph.new()
	g.build(Assets.load_json(path))
	return g


func build(d: Dictionary) -> void:
	name = str(d.get("name", "THE BOARD"))
	rat_price = int(d.get("rat_price", 20))
	notes = d.get("notes", [])
	if d.has("nodes"):
		_build_graph(d)
	else:
		_build_loop(d)
	for n in nodes:
		n.prev = []
	for n in nodes:
		for e in n.edges:
			nodes[int(e.to)].prev.append(int(n.id))
	_refresh()


func _build_graph(d: Dictionary) -> void:
	districts = d.get("districts", [])
	gate_defs = d.get("gates", {})
	for g in gate_defs.keys():
		gates[g] = str(gate_defs[g].get("start", gate_defs[g].values[0]))
	parade = d.get("parade", []).map(func(x): return int(x))
	rat_spots = d.get("rat_spots", []).map(func(x): return int(x))
	main_count = int(d.get("main_count", 0))
	for src in d.nodes:
		var n: Dictionary = (src as Dictionary).duplicate(true)
		n.id = int(n.id)
		n.edges = []
		for e in src.next:
			var ed := {"to": int(e.to)}
			if e.has("gate"):
				ed.gate = str(e.gate)
				ed.when = str(e.when)
			n.edges.append(ed)
		n.branch = str(n.get("branch", ""))
		n.toll = int(n.get("toll", 0))
		n.district = str(n.get("district", ""))
		nodes.append(n)
	for b in d.get("branches", []):
		branches.append({"name": b.name, "from": int(b.from), "to": int(b.to), "ids": b.ids.map(func(x): return int(x)), "toll": int(b.get("toll", 0)),
			"desc": str(b.get("desc", "")), "gate": str(b.get("gate", "")), "when": str(b.get("when", "")), "district": str(b.get("district", ""))})


func _build_loop(d: Dictionary) -> void:
	rat_spots = d.get("rat_spots", [])
	var main: Array = d.get("main", d.get("spaces", []))
	main_count = main.size()
	for i in main.size():
		var n: Dictionary = (main[i] as Dictionary).duplicate()
		n.edges = [{"to": (i + 1) % main.size()}]
		n.branch = ""
		n.toll = 0
		n.id = i
		n.district = ""
		nodes.append(n)
	var note_i := 0
	for n in nodes:
		if n.type == "note" and not n.has("text") and not notes.is_empty():
			n.text = notes[note_i % notes.size()]
			note_i += 1
	for b in d.get("branches", []):
		var from: int = int(b.from)
		var to: int = int(b.to)
		var ids := []
		for k in b.spaces.size():
			var n: Dictionary = (b.spaces[k] as Dictionary).duplicate()
			n.id = nodes.size()
			n.branch = str(b.name)
			n.toll = 0
			n.district = ""
			n.edges = []
			nodes.append(n)
			ids.append(n.id)
		for k in ids.size():
			nodes[ids[k]].edges = [{"to": ids[k + 1] if k + 1 < ids.size() else to}]
		nodes[from].edges.append({"to": ids[0]})
		nodes[ids[0]].toll = int(b.get("toll", 0))
		branches.append({"name": b.name, "from": from, "to": to, "ids": ids, "side": str(b.get("side", "in")), "toll": int(b.get("toll", 0)), "desc": str(b.get("desc", "")), "gate": "", "when": ""})


## The walkable exits of every node, given the gates as they are now.
func _refresh() -> void:
	for n in nodes:
		var out := []
		for e in n.edges:
			if e.has("gate") and str(gates.get(str(e.gate), "")) != str(e.when):
				continue
			out.append(int(e.to))
		if out.is_empty():
			# never strand anyone: a node whose every way is shut keeps its first
			out.append(int(n.edges[0].to))
		n.next = out


func set_gate(g: String, v: String) -> bool:
	if not gates.has(g) or gates[g] == v:
		return false
	gates[g] = v
	_refresh()
	return true


func gate_values(g: String) -> Array:
	return gate_defs.get(g, {}).get("values", [])


func size() -> int:
	return nodes.size()


func node(i: int) -> Dictionary:
	return nodes[posmod(i, nodes.size())]


func next_of(i: int) -> Array:
	return node(i).next


func prev_of(i: int) -> Array:
	return node(i).prev


func type_of(i: int) -> String:
	return str(node(i).type)


func district_of(i: int) -> String:
	return str(node(i).get("district", ""))


func district_name(id: String) -> String:
	for d in districts:
		if d.id == id:
			return str(d.name)
	return ""


func route_name(to: int) -> String:
	var b := str(node(to).branch)
	return b if b != "" else "THE MAIN ROAD"


func route_desc(to: int) -> String:
	var b := str(node(to).branch)
	for br in branches:
		if br.name == b:
			return str(br.desc)
	return "The long way round."


func find_type(t: String) -> int:
	for n in nodes:
		if n.type == t:
			return n.id
	return -1


func ahead(i: int, n: int) -> int:
	var at := i
	for k in n:
		at = int(next_of(at)[0])
	return at


func distances_from(i: int) -> Dictionary:
	var dist := {i: 0}
	var q := [i]
	while not q.is_empty():
		var c: int = q.pop_front()
		for nx in next_of(c):
			if not dist.has(int(nx)):
				dist[int(nx)] = dist[c] + 1
				q.append(int(nx))
	return dist


## Every node, ignoring gates (for "is the whole board connected").
func all_reachable_from(i: int) -> Dictionary:
	var dist := {i: 0}
	var q := [i]
	while not q.is_empty():
		var c: int = q.pop_front()
		for e in node(c).edges:
			if not dist.has(int(e.to)):
				dist[int(e.to)] = dist[c] + 1
				q.append(int(e.to))
	return dist


## A position for the view (0..1 on the board) even for the old format.
func pos_of(i: int) -> Vector2:
	var n := node(i)
	if n.has("pos"):
		return Vector2(float(n.pos[0]), float(n.pos[1]))
	var a := TAU * float(i % maxi(1, main_count)) / maxf(1.0, main_count)
	return Vector2(0.5 + cos(a) * 0.4, 0.5 + sin(a) * 0.38)
