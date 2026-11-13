class_name Station
extends Node3D
## A place where an inhabitant does something (docs/CHAPTER2.md): the washing machine, the stove,
## the bath, the desk, the mailboxes. An inhabitant stands at it (this node's position), faces
## where it faces (-Z), and does `activity` for `secs`: the body works (Inhabitant animates by
## activity), `sound` plays there, and every `noise_every` seconds it makes a noise others hear.
## `item` (optional): what you can take here or leave here (the Caretaker's meat; the laundry).

var kind := ""                  # "laundry", "fold", "stove", "bath", "fridge", "desk", "mailbox", "chute", "window"...
var activity := "work"          # the body: "work" (hands busy), "stir", "scrub", "feed", "sit", "stand", "bang"
var secs := 6.0
var sound := ""
var sound_db := -8.0
var noise := 0.0
var noise_every := 0.0
var item := ""
var busy_by: Node = null
var enabled := true             # (power off: the washing machine won't run)

static func make(parent: Node3D, kind_: String, at: Vector3, facing_y: float, opts := {}) -> Station:
	var s := Station.new(); s.kind = kind_; s.name = "Station_" + kind_
	for k in opts: s.set(k, opts[k])
	parent.add_child(s); s.global_position = at; s.rotation.y = facing_y
	s.add_to_group("station")
	return s

static func find(tree: SceneTree, kind_: String) -> Array:
	var out := []
	for s in tree.get_nodes_in_group("station"):
		if s.kind == kind_ and s.enabled: out.append(s)
	return out
