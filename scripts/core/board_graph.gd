class_name BoardGraph
extends RefCounted
## The board as a graph (assets/data/board.json): a main loop, and branches that leave it
## and rejoin it (a risky short cut, a long safe way round, a toll shortcut). Node ids: the
## main loop is 0..N-1 in order; branch spaces follow. Rules walk next(); views lay it out.

var nodes: Array = []          # {type, clue?, text?, next: [ids], prev: [ids], branch: "", toll: 0}
var main_count := 0
var branches: Array = []
var rat_spots: Array = []
var rat_price := 20
var notes: Array = []
var name := ""
var altered: Dictionary = {}   # node id -> type it was changed to mid-match (renovations)


static func load_board(path := "res://assets/data/board.json") -> BoardGraph:
	var g := BoardGraph.new()
	g.build(Assets.load_json(path))
	return g


func build(d: Dictionary) -> void:
	name = str(d.get("name", "THE BOARD"))
	rat_price = int(d.get("rat_price", 20))
	notes = d.get("notes", [])
	rat_spots = d.get("rat_spots", [])
	var main: Array = d.get("main", d.get("spaces", []))
	main_count = main.size()
	for i in main.size():
		var n: Dictionary = (main[i] as Dictionary).duplicate()
		n.next = [(i + 1) % main.size()]
		n.prev = [(i - 1 + main.size()) % main.size()]
		n.branch = ""
		n.toll = 0
		n.id = i
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
			n.next = []
			n.prev = []
			if n.type == "note" and not notes.is_empty():
				n.text = notes[k % notes.size()]
			nodes.append(n)
			ids.append(n.id)
		for k in ids.size():
			nodes[ids[k]].next = [ids[k + 1]] if k + 1 < ids.size() else [to]
			nodes[ids[k]].prev = [ids[k - 1]] if k > 0 else [from]
		nodes[from].next.append(ids[0])
		nodes[to].prev.append(ids[ids.size() - 1])
		nodes[ids[0]].toll = int(b.get("toll", 0))
		branches.append({"name": b.name, "from": from, "to": to, "ids": ids, "side": str(b.get("side", "in")), "toll": int(b.get("toll", 0)), "desc": str(b.get("desc", ""))})


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


## What each way out of a junction is called.
func route_name(to: int) -> String:
	var b := str(node(to).branch)
	return b if b != "" else "THE MAIN ROAD"


func find_type(t: String) -> int:
	for n in nodes:
		if n.type == t:
			return n.id
	return -1


func route_desc(to: int) -> String:
	var b := str(node(to).branch)
	for br in branches:
		if br.name == b:
			return str(br.desc)
	return "The long way round."


## n squares on along the main way (first exit each time).
func ahead(i: int, n: int) -> int:
	var at := i
	for k in n:
		at = int(next_of(at)[0])
	return at


## Every node's distance from `i` going forwards (BFS), for the AI and the view.
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
