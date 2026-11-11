class_name Interactable
extends Node
## The interaction contract. Attach as a child of any CollisionObject3D (or let a component that
## extends this create its own body) and the player's interactor finds it through the collider's
## "interactable" meta.
##
## A verb is a Dictionary:
##   id      what do_verb() receives
##   label   what the button says ("Open", "Pry with crowbar")
##   time    > 0: hold to complete (seconds); the interactor shows progress and can be interrupted
##   noise   > 0: noise radius emitted while/at doing it (Marta hears)
##   primary true for the one the main button does (else the first verb is primary)
## Components override get_verbs() and do_verb().

signal used(verb: String)

@export var display_name := ""
@export var enabled := true
## a stable id for saving and for the story ledger ("living_wardrobe", "flat48_padlock")
@export var persist_id := ""

var body: CollisionObject3D

func _ready() -> void:
	body = get_parent() as CollisionObject3D
	if body:
		body.set_meta("interactable", self)
	if persist_id != "":
		add_to_group("persist")

func get_verbs(_p: Node) -> Array:
	return []

func do_verb(_id: String, _p: Node) -> void:
	pass

## where the prompt anchors and what the interactor considers "this thing" for distance
func focus_point() -> Vector3:
	return body.global_position if body else Vector3.ZERO

## called every physics frame while a timed verb is being held (progress 0..1)
func verb_progress(_id: String, _k: float, _p: Node) -> void:
	pass

func get_state() -> Dictionary:
	return {}

func set_state(_d: Dictionary) -> void:
	pass

static func find(collider: Object) -> Interactable:
	if collider and collider.has_meta("interactable"):
		var i = collider.get_meta("interactable")
		if is_instance_valid(i):
			return i
	return null

static func v(id: String, label: String, extra := {}) -> Dictionary:
	var d := {"id": id, "label": label}
	d.merge(extra)
	return d
